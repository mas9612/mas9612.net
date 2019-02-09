---
title: "Base64のデコード・エンコード"
date: 2016-05-13T00:00:00+09:00
draft: false
---

Webの世界などで使用されているBase64のデコード・エンコードについて．
CTF (Capture The Flag) でも使用されることがあるので，軽くまとめてみた．

## UNIXコマンド

#### エンコード`Base64`コマンドを使用する．
```
$ echo -n 'base64 encode' | base64
YmFzZTY0IGVuY29kZQo=
```

`-i`オプションを使用すると，ファイルから文字列を読み込んでエンコードする．
`-o`オプションを使用すると，結果をファイルに書き込む．

```
$ base64 -i input.txt -o output.txt
```

input.txtの中身

```
base64 encode
```

output.txtの中身

```
YmFzZTY0IGVuY29kZQo=
```

#### デコード`-D`オプションをつける．
```
$ echo -n 'YmFzZTY0IGVuY29kZQo=' | base64 -D
base64 encode
```
エンコードと同じく，`-i`オプションと`-o`オプションは有効．

## Python
標準ライブラリであるbase64モジュールを使用する．

#### エンコード`base64.b64encode()`メソッドを使う．
```
>>> import base64
>>> s = 'base64 encode'
>>> base64.b64encode(s.encode('utf-8'))
b'YmFzZTY0IGVuY29kZQ=='
```

#### デコード`base64.b64decode()`メソッドを使う．
```
>>> import base64
>>> encoded = b'YmFzZTY0IGVuY29kZQ=='
>>> base64.b64decode(encoded)
b'base64 encode'
```
どちらのメソッドも引数，返り値ともにバイトオブジェクトということに注意．
