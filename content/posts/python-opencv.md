---
title: "Python3にOpenCVをインストールした"
date: 2016-06-22T00:00:00+09:00
draft: true
---

環境はOS X Yosemite 10.10.5．

Python3はHomebrewからインストールしたものを使用した．

Homebrewが入っていない場合は[Homebrew公式](http://brew.sh/index_ja.html)の「インストール」の部分に書いてあるコマンドを実行してインストールしておく．

## HomebrewからOpenCVをインストール
下記コマンドを実行してOpenCVをインストールする．

```
$ brew tap homebrew/science
$ brew install opencv3 --with-python3
```
インストール後，Homebrewの指示に従ってパスを通す．（<username>の箇所は自分のユーザー名に置き換える）

```
echo /usr/local/opt/opencv3/lib/python2.7/site-packages >> /usr/local/lib/python2.7/site-packages/opencv3.pth
mkdir -p /Users/<username>/.local/lib/python3.5/site-packages
echo 'import site; site.addsitedir("/usr/local/lib/python2.7/site-packages")' >> /Users/<username>/.local/lib/python3.5/site-packages/homebrew.pth
```

ここまで完了したら，下記コマンドで確認．バージョンが出ればインストール完了．

```
$ python -c 'import cv2; print(cv2.__version__)'
3.1.0
```
※Homebrewでは上記のように出てきたが，自分の環境では実際に実行してもOpenCVのパスは通らなかった．上のコマンドの代わりに下記のように実行するとうまく行った．

```
echo /usr/local/opt/opencv3/lib/python3.5/site-packages >> /usr/local/lib/python3.5/site-packages/opencv3.pth
mkdir -p /Users/<username>/.local/lib/python3.5/site-packages
echo 'import site; site.addsitedir("/usr/local/lib/python3.5/site-packages")' >> /Users/<username>/.local/lib/python3.5/site-packages/homebrew.pth
```
