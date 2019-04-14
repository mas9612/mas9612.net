---
title: "RyuによるOpenFlow入門 (1)"
date: 2018-06-10T00:00:00+09:00
draft: false
type: post
---

Ryuを使って簡単なL2スイッチを作ってみた．
Ryuについての理解が浅い状態でいきなりMACアドレスの学習機能を持ったL2スイッチを作成するのは難しいかと思ったので，まずMACアドレス学習機能のない単純なL2スイッチ（リピータハブ）を作成し，その後スイッチングハブを実装してみる．

## リピータハブ
ソースコードは以下の通り．

<script src="https://gist-it.appspot.com/github/mas9612/ryu-study/blob/master/dumb_l2_switch.py"></script>

OpenFlowスイッチに入ってきたパケットは，スイッチ内にあるフローテーブルを参照し，テーブル内にマッチするエントリがなければOpenFlowコントローラへPacket Inメッセージを送出する．
リピータハブでは，入ってきたパケットをそれ以外のポート全てにそのまま送信する（フラッディング）ので，Packet Inで入ってきたデータをそのまますべてのポートに向けて送ってあげれば良い．

コントローラからPacket Outメッセージを送ることで，OpenFlowスイッチからパケットを送出することができる．
これを利用して，データのフラッディングを行う．

Packet Outメッセージの作成部分は次のようになる．

    actions = [ofp_parser.OFPActionOutput(ofp.OFPP_FLOOD)]
    out = ofp_parser.OFPPacketOut(
        datapath=dp, buffer_id=msg.buffer_id, in_port=msg.in_port,
        actions=actions
    )

Packet Outメッセージでは，アクションを指定することで，パケットの出力先を指定することができる．
今回は入力ポート以外全てに送りたいため， `OFPActionOutput` の引数として `ofp.OFPP_FLOOD` を指定する．

作成したアクション等の情報を `OFPPacketOut` の引数として与えてあげ，Packet Outメッセージを作成する．
指定した引数は次のような感じ．

* `datapath` : データパス．OpenFlowスイッチを表す（みたい）．それぞれのOpenFlowスイッチはユニークなID（Datapath ID）を持つ．
* `buffer_id` : OpenFlowスイッチにバッファされているデータのID．
* `in_port` : パケットの受信ポート．
* `actions` : 上で作ったアクションを指定する．

最後に，作成したメッセージを `send_msg()` で送信してあげれば完了．

mininetを使って動作確認を行ってみる．

    $ ryu-manager dumb_l2_switch.py

    $ mn --switch ovs --controller remote
    ...
    *** Starting CLI:
    mininet> pingall
    *** Ping: testing ping reachability
    h1 -> h2
    h2 -> h1
    *** Results: 0% dropped (2/2 received)

ちゃんと疎通しているみたい．

スイッチングハブについては違う記事に分けて書きます．
