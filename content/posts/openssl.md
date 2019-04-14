---
title: "OpenSSLでTLS証明書を作る"
date: 2018-11-14T00:00:00+09:00
draft: false
type: post
---

etcdクラスタをTLS有効にして運用するため，TLS証明書を作成する必要があった．
ちゃんとした手順をあまり理解できていなかったため，備忘録として残しておく．

## TLS証明書発行までの流れ
TLS証明書は次にような流れで発行する．

1. 秘密鍵を作成
1. CSRを作成
1. TLS証明書を作成

これ以降，上記の具体的な手順について説明する．

今回使用したOpenSSLのバージョンは次の通り．
```shell
$ openssl version
OpenSSL 1.1.1  11 Sep 2018
```

### 秘密鍵を作成
秘密鍵の作成は， `genpkey` サブコマンドを使用する．
`genrsa` サブコマンドでもできるようだが，マニュアルに `genrsa` 含めいくつかのコマンドは `genpkey` に置き換えられたという記述があるので，今回は `genpkey` を使用する．

今回は次のような鍵を作成する．

* 公開鍵アルゴリズム: RSA
* 鍵長: 2048bit
* 秘密鍵を暗号化するためのアルゴリズム: AES 128bit

この条件で秘密鍵を作成するには次のようなコマンドを使用する．

```shell
$ openssl genpkey -algorithm rsa -pkeyopt rsa_keygen_bits:2048 -aes128 -out ca.key
```

コマンドを実行するとパスフレーズを求められるので，適当なものを入力する．
実行すると次のようになる．

```shell
$ openssl genpkey -algorithm rsa -pkeyopt rsa_keygen_bits:2048 -aes128 -out ca.key
..........................................................+++++
................................................+++++
Enter PEM pass phrase:
Verifying - Enter PEM pass phrase:
```

オプションの意味は次の通り．

* `-algorithm rsa` : 公開鍵アルゴリズムとしてRSAを使用する
* `-pkeyopt rsa_keygen_bits:2048` : RSAの鍵長を2048bitにする
* `-aes128` : 秘密鍵をAES 128bitで暗号化する
* `-out ca.key` : `ca.key` という名前で秘密鍵を生成する

### CSRを作成
TLS証明書を作成するには，まずCSR (Certificate Signing Request) を作成する必要がある．
このCSRを元に，CA (Certificate Authority) がTLS証明書を作成するという流れになる．

この手順では，前手順で作成した秘密鍵を使ってCSRを作成する．
これは `req` サブコマンドで行うことができる．

```shell
$ openssl req -new -key ca.key -out ca.csr
```

実行すると次のようになる．
まずパスフレーズを聞かれるので，秘密鍵を作成したときに入力したのと同じものを入力する．

その後，いくつか情報を聞かれるので必要に応じて入力する．
このとき，何も入力せずにEnterを押すとデフォルト値が使用されるが，フィールドを空にしておきたい場合は `.` （ピリオド）を入力してからEnterを押すようにする．
`.` をつけることにより，このフィールドは空だと明示的に指定できる．

```shell
$ openssl req -new -key ca.key -out ca.csr
Enter pass phrase for ca.key:
You are about to be asked to enter information that will be incorporated
into your certificate request.
What you are about to enter is what is called a Distinguished Name or a DN.
There are quite a few fields but you can leave some blank
For some fields there will be a default value,
If you enter '.', the field will be left blank.
-----
Country Name (2 letter code) [AU]:JP
State or Province Name (full name) [Some-State]:.
Locality Name (eg, city) []:.
Organization Name (eg, company) [Internet Widgits Pty Ltd]:.
Organizational Unit Name (eg, section) []:.
Common Name (e.g. server FQDN or YOUR name) []:mas9612.net
Email Address []:.

Please enter the following 'extra' attributes
to be sent with your certificate request
A challenge password []:.
An optional company name []:.
```

オプションの意味は次の通り．

* `-new` : 新しいCSRを作成するときに指定する
* `-key ca.key` : 秘密鍵を指定する．この鍵とペアになる公開鍵が署名される
* `-out ca.csr` : `ca.csr` という名前でCSRを作成する

### TLS証明書を作成
CSRが作成できたら，最後にTLS証明書を作成する．

今回は，次の2種類の方法を試す．

* 自己署名: 自分の秘密鍵を使って署名する
* 別に用意したCAによる署名: CAの秘密鍵を使って署名する

#### 自己署名
自己署名を行うには，次のようなコマンドを実行する．

```shell
$ openssl x509 -req -in ca.csr -out ca.crt -signkey ca.key -days 365
```

コマンドを実行すると次のようになる．
ここでもパスフレーズを聞かれるので，秘密鍵作成時のものを入力する．

```shell
$ openssl x509 -req -in ca.csr -out ca.crt -signkey ca.key -days 365
Signature ok
subject=C = JP, CN = mas9612.net
Getting Private key
Enter pass phrase for ca.key:
```

オプションの意味は次の通り．

* `-req` : このオプションを指定すると，CSRを読み込んでTLS証明書を作成する
* `-in ca.csr` : 読み込むCSRファイルを指定
* `-out ca.crt` : `ca.crt` という名前でTLS証明書を出力する
* `-signkey ca.key` : `ca.key` を使って署名を行う
* `-days 365` : TLS証明書の期限を365日にする

#### CAによる署名
次に，CAによる署名を試してみる．
といっても，自分で何かCAを運用しているわけではないので，今回は先程作った秘密鍵とTLS証明書をCAのものと仮定し，それを使って署名をするということを試す．

まず，先ほどとは別の秘密鍵とCSRを作成しておく．

```shell
$ openssl genpkey -algorithm rsa -pkeyopt rsa_keygen_bits:2048 -aes128 -out etcd0.key
$ openssl req -new -key ca.key -out etcd0.csr
```

CSRまで作成できたら，それをCAの証明書で署名する手順に移る．
これも自己署名と同様に， `x509` サブコマンドを使うと簡単にできる．
次のようなコマンドを実行する．

```shell
$ openssl x509 -req -in etcd0.csr -out etcd0-ca.crt -days 365 -CA ca.crt -CAkey ca.key -CAcreateserial
```

実行すると次のようになる．

```shell
$ openssl x509 -req -in etcd0.csr -out etcd0-ca.crt -days 365 -CA ca.crt -CAkey ca.key -CAcreateserial
Signature ok
subject=C = JP, CN = mas9612.net
Getting CA Private Key
Enter pass phrase for ca.key:
```

CA関連のオプションは次の通り．

* `-CA ca.crt` : 署名に使用するCAのTLS証明書を指定する
* `-CAkey ca.key` : 署名に使用するCA秘密鍵を指定する
* `-CAcreateserial` : CAのシリアルナンバーファイルが存在しない場合，自動で作成する

## 秘密鍵やCSR，TLS証明書の内容を確認する
上記の手順でTLS証明書までの作成ができた．
作成した各種ファイルは，opensslコマンドを使用することでその内容を確認することができる．

ここではそれについて説明する．

### 秘密鍵の内容確認
秘密鍵の内容を確認するには， `rsa` サブコマンドを使用する．

普通に秘密鍵を読み込むには， `-in` オプションに秘密鍵のファイル名を指定するだけでできる．
なお，このコマンドを実行してもただ単にファイルの内容がそのまま表示されるだけである．

```shell
$ openssl rsa -in ca.key
Enter pass phrase for ca.key:
writing RSA key
-----BEGIN RSA PRIVATE KEY-----
MIIEogIBAAKCAQEAoTo44Vgr5vUZvhlfhDGrUK3DBVKexWoG5Hq29oMhEc5HCSTk
XBL28/gGVoW6NtW7HMiM2zkPE0ETC/Hi8ef9CVjE414F5OpIgppBjYxjjmDEDita
...（省略）
bBxlNDpyMteIfxg1cix3U2V+D1mWhBAKqF95xJNASQZtfeabZHZzCH7YbO0eGFIv
m9ZFXwYPhq+ORWBJE9+hL1PsgvkiruEECIKTE2Pfeb8TkiO1Gls=
-----END RSA PRIVATE KEY-----
```

これに `-text` オプションを指定すると，秘密鍵の内容を調べてNやE，Dを値を表示してくれる．

```shell
$ openssl rsa -in ca.key -text
Enter pass phrase for ca.key:
RSA Private-Key: (2048 bit, 2 primes)
modulus:
    00:a1:3a:38:e1:58:2b:e6:f5:19:be:19:5f:84:31:
    ...（省略）
    43:c8:f7:b1:7f:e0:9f:5f:9c:25:83:55:1d:d4:b7:
    de:9f
publicExponent: 65537 (0x10001)
privateExponent:
    58:d7:6d:5a:77:2c:91:f2:c3:81:a6:17:a5:0f:7d:
    ...（省略）
    b4:d7:70:bb:59:56:df:92:9f:99:40:a4:42:97:4d:
    c9
prime1:
    00:d1:a0:9d:d8:96:8d:8d:48:d0:76:c8:76:8e:b9:
    ...（諸略）
    a0:30:e1:b3:b5:d2:e8:d4:00:f3:65:93:ab:d5:b3:
    2f:0e:aa:bd:94:75:2d:a2:05
prime2:
    00:c4:e4:ac:2a:c5:59:aa:a1:d2:3c:2a:8c:dd:bf:
    ...（省略）
    bf:32:c3:4b:98:dc:57:ab:53
exponent1:
    4c:d1:5f:06:8f:a5:2f:b1:0f:33:78:22:7a:0a:ef:
    ...（省略）
    ac:16:45:82:b1:ae:17:41
exponent2:
    41:b8:e3:0f:53:d8:de:70:2d:b1:0f:b2:fd:c2:17:
    ...（省略）
    ee:9d:e9:fa:18:72:db:29
coefficient:
    2f:ba:6e:47:c5:bb:60:2e:4f:35:4f:c2:d1:12:61:
    ...（省略）
    79:bf:13:92:23:b5:1a:5b
writing RSA key
-----BEGIN RSA PRIVATE KEY-----
MIIEogIBAAKCAQEAoTo44Vgr5vUZvhlfhDGrUK3DBVKexWoG5Hq29oMhEc5HCSTk
XBL28/gGVoW6NtW7HMiM2zkPE0ETC/Hi8ef9CVjE414F5OpIgppBjYxjjmDEDita
...（省略）
m9ZFXwYPhq+ORWBJE9+hL1PsgvkiruEECIKTE2Pfeb8TkiO1Gls=
-----END RSA PRIVATE KEY-----
```

いろいろ出力されるが，NやEに対応するのは次の部分．

* N: modulus
* E: publicExponent
* D: privateExponent
* prime1: p
* prime2: q

また， `-noout` オプションを指定すると，秘密鍵をエンコーディングした内容は出力されなくなる（ `BEGIN RSA PRIVATE KEY` から `END RSA PRIVATE KEY` の部分）．

### CSRの内容確認
CSRの内容確認には， `req` サブコマンドを使用する．
秘密鍵の内容確認と同じように， `-in` ， `-text` ， `-noout` が使える．

```shell
$ openssl req -in ca.csr -text -noout
```

### TLS証明書の内容確認
TLS証明書の内容確認には， `x509` サブコマンドを使用する．
これも同じように， `-in` ， `-text` ， `-noout` が使える．

```shell
$ openssl x509 -in ca.crt -text -noout
```
