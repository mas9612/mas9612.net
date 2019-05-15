---
title: "TCPについて学ぶ - HTTP通信の流れを見てみる"
date: 2019-05-15T20:21:57+09:00
draft: false
type: post
toc: true
images:
tags:
 - network
 - tcp
---

<style>
img {
  display: block;
  margin: 0 auto;
}

img.small {
  width: 100%;
  max-width: 350px !important;
}
</style>

TCPのコネクションが確立されてからクローズされるまでどのような流れで進んでいくのか，実際にパケットキャプチャをして確認した．
ここではHTTPサーバへGETリクエストを送ったときのトラフィックを対象としている．

## 環境
* macOS Mojave v10.14.4
* Web server: Go v1.12.5

## サンプルのWebサーバを準備する
Goを使って検証用にWebサーバを作成する．GETでHTTPリクエストを投げると `Hello world` と返すだけのWebサーバを作成した．ソースコードは次の通り．

<script src="https://gist.github.com/mas9612/edfc7b6efa28d9002e282070ecd5e4e6.js"></script>

これを `main.go` として保存してサーバを実行しておく．
```sh
$ go run main.go
```

## HTTP通信のパケットをキャプチャする
Webサーバは準備できたので，早速HTTP通信をキャプチャしていく．
ここではtcpdumpを使っているが，Wiresharkでキャプチャしても構わない．

Webサーバを動かしているのとは別のコンソールを開き，次のコマンドでHTTP通信をキャプチャする．
後からWiresharkで中身を詳しく見たいので， `-w` オプションでファイルに書き出しておく．
ポート番号やpcapファイル名は必要に応じて変更してほしい．
```sh
$ tcpdump -i lo0 -X tcp port 8080 -w http.pcap
```

Webサーバとtcpdumpを動作させている状態でさらに別のコンソールを開き，次のコマンドでHTTP GETリクエストを投げる．
なお，レスポンスボディだけでなくレスポンスヘッダもあわせて表示するために `--include` オプションを指定している．
```sh
$ curl --include 127.0.0.1:8080
HTTP/1.1 200 OK
Date: Wed, 15 May 2019 06:13:22 GMT
Content-Length: 11
Content-Type: text/plain; charset=utf-8

Hello world
```

これでpcapファイルにHTTP通信が記録されたはずなので，tcpdumpを実行しているコンソールに戻り，Ctrl-Cでtcpdumpを終了しておく．

## HTTP通信の中身を確認する
それでは一つ一つ通信内容を見ていく．ここでは，Wiresharkを使ってpcapファイルを見ていくことにする．
今回見ていくpcapファイルは[ここ](/files/http.pcap)から取得することができる．

なお，一般的にTCPでやり取りされるデータのまとまり一つ一つは **セグメント** と呼ばれるが，ここではわかりやすさのため **パケット** と呼ぶことにする．

大きく分けて，HTTP通信が完了するまでの流れは次のようになっていた．

1. TCPコネクションの確立
1. HTTP GETリクエストの送信
1. HTTPレスポンスの返却
1. TCPコネクションのクローズ

### TCPコネクションの確立
TCPでは，データの送受信に先立ちまず3-way handshakeと呼ばれるやり取りを行いTCPコネクションを確立する必要がある．
3-way handshakeは次のような手順で行われる．

<img src="/images/tcp-3-way-handshake.png" class="small" alt="TCP 3-way handshake">

1. クライアント（データ送信側）がサーバ（受信側）にSYNパケット（SYNフラグがセットされたパケット）を送信する
1. クライアントからのSYNパケットを受信したサーバは，クライアントにSYN/ACKパケット（SYN・ACKの2つのフラグがセットされたパケット）を送り返す
1. サーバからのSYN/ACKパケットを受信したクライアントは，サーバにACKパケット（ACKフラグがセットされたパケット）を送信する

3-way handshakeによりクライアント・サーバ間でTCPコネクションが確立され，お互いがデータの送受信を行う準備ができたことになる．
キャプチャされた通信を見ると，始めの3つのパケットで3-way handshakeを行っていることが読み取れる．

![3-way handshake](/images/pcap_3-way-handshake.png)

キャプチャされた通信では，3-way handshakeの後にTCP Window Updateというパケットがサーバからクライアントに向けて送信されていた．

![TCP Window Update](/images/pcap_window-update.png)

これは，TCPのフロー制御と呼ばれる機能によるもので，受信側が「私は今これだけのデータを一度に受け取ることができます」ということを送信側に通知するためのパケットである．この「一度に受け取れるデータサイズ」のことを **ウィンドウサイズ** と呼ぶ．データの送信側は，受信側から通知されたウィンドウサイズを超えないようにしてデータを送信していく．
受信側が受け取れるデータのサイズは，送信側から送られてくるデータ量等により変化する．
もし受信側の余裕がなくなってくれば，TCP Window Updateを使って現在よりも小さいウィンドウサイズを送信側に通知し，送られてくるデータのサイズを調整する．

RFC 793[^1] 1.5節によると，このTCP Window UpdateはACKパケットに通知したいウィンドウサイズをのせて送ることで実現されているようだ．

> This is achieved by returning a "window" with every ACK indicating a range of acceptable sequence numbers beyond the last segment successfully received.

ウィンドウサイズはTCPヘッダに16bitで格納されているが，ネットワークの速度向上により16bitでは不足するようになってきている（TCPヘッダの形式については割愛）．
そのため，RFC1323 2節[^2]で定義されているWindow Scaleオプションを用いてウィンドウサイズの値を32bitに拡張できるようになっている．
このオプションはSYNフラグがONとなっているパケットにしか付加できないため，3-way handshakeの始め2つ（SYNパケット，SYN/ACKパケット）で指定されることになる．

Window Scaleオプションは次のような形式となっている．

<img src="/images/tcp-window-scale-option.png" class="small" alt="TCP Window Scale Option">

このオプションが有効になっている場合は，TCPヘッダに格納されているウィンドウサイズを `shift.cnt` 分だけビットシフトした値が実際のウィンドウサイズとなる．
これにより，16bitで表せる最大の65535よりも大きな値をウィンドウサイズとして指定できるようになる．
例えば今回の通信では，クライアントからサーバに通知されているウィンドウサイズは `6379` だが，Window Scaleオプションで `shift.cnt` が `6` と指定されている．
そのため，実際のウィンドウサイズは `6379` を6ビット左シフトした `408256` となる．

```sh
$ python -c 'print(6379 << 6)'
408256
```

### HTTP GETリクエストの送信
HTTPは平文のプロトコルなので，Wiresharkで中身をそのまま見ることができる．
3-way handshakeとTCP Window Updateが終わった次のパケットで，HTTPリクエストがクライアントからサーバに送信されている．

![HTTP Request](/images/pcap_http-request.png)

今回はTCPの詳細を見るのが目的のためHTTPの詳細については割愛する．
HTTPリクエストがサーバで受け取れたことをクライアントに通知するため，サーバはクライアントに向けてACKパケットを送信する．

![ACK packet](/images/pcap_http-req-ack.png)

このACKパケットには，TCPヘッダのAcknowledgment numberフィールドに，何バイト目までを受け取ったかという情報が格納されている．
上のスクリーンショットを見ると，Acknowledgment numberフィールドは `79` となっているので，サーバは79バイトのデータを受け取ったということがわかる．

### HTTPレスポンスの返却
クライアントからのHTTPリクエストを受け取ったサーバは，それに対して適切なHTTPレスポンスを返却していく．
とはいえ流れはHTTPリクエストの場合と同様で，クライアントとサーバの役割が逆になっただけである．
サーバはHTTPレスポンスをクライアントに向けて送信し，それを受け取ったクライアントはサーバにACKパケットを送信して受信応答を行う．

### TCPコネクションのクローズ
無事にHTTPリクエストとレスポンスのやり取りが終了したので，最後にTCPコネクションのクローズ処理を行う．
コネクションのクローズはクライアント・サーバどちらからでも行うことができる．
クローズ処理は次のような流れで進んでいく．

（クライアントからクローズ処理を開始すると仮定する）

<img src="/images/tcp-connection-close.png" class="small" alt="TCP Connection Close">

1. クライアントがサーバにFINパケットを送信する
1. サーバがクライアントに対してACKパケットを送信し，FINパケットの受信応答を行う
1. サーバからもクライアントにFINパケットを送信する
1. クライアントがサーバにACKパケットを送信し，FINパケットの受信応答を行う

この4つの手順を経ることで，正常にTCPコネクションをクローズすることができる．

![TCP Connection Close](/images/pcap_tcp-close.png)

[^1]: [RFC 793 - Transmission Control Protocol](https://tools.ietf.org/html/rfc793)
[^2]: [RFC 1323 - TCP Extensions for High Performance](https://tools.ietf.org/html/rfc1323#section-2)
