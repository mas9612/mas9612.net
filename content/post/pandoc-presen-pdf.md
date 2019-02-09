---
title: "Pandocを使用してMarkdownからプレゼン用PDFを作成する"
date: 2016-11-17T00:00:00+09:00
draft: true
---

タイトルの通り．エディタで完結するならそっちのほうが良いので試してみた．

環境はOS X 10.11.6．

## pandocのインストールなど
必要なもののインストールなどは以下の記事を参考にさせて頂きました．ただし，TeXはMacTeXをインストールしました．

[markdownの原稿を、pandocを使って、Texのbeamerを利用して、プレゼンスライドPDFに変換](http://qiita.com/danpansa/items/7ea8db3942a7946dd56a)

## スタイルファイルの導入
設定などを済ませた後に，Keynote風のスタイルファイルを導入した．beamerthemeKeynoteLikeGradient.styというスタイルファイルを使うとできるみたいなので，それをダウンロードしてきてインストールする．

beamerthemeKeynoteLikeGradient.styは[ここ](https://bitbucket.org/kasajei/latex-setting/src/f56429d33fc070d89b74c8c3b0075dedd8c8bca9/texmf/tex/latex/beamerthemeKeynoteLikeGradient.sty?at=master&fileviewer=file-view-default)からお借りしました．

```
$ mkdir -p /usr/local/texlive/texmf-local/tex/latex/
$ mv beamerthemeKeynoteLikeGradient.sty /usr/local/texlive/texmf-local/tex/latex/
$ sudo texhash
```

最後の `texhash` を実行しないと，スタイルファイルを配置してもコンパイル時にスタイルファイルが見つからないというエラーになるので注意．

## プレゼン用PDFの作成
次のコマンドを実行するだけ． `OUTFILE` と `INFILE` は適当に変えてください．

```
$ pandoc --latex-engine=lualatex \
    -t beamer \
    -V theme:KeynoteLikeGradient \
    -H h-luatexja.tex \
    -o OUTFILE \
    INFILE
```

しかし，毎回これを打つのはめんどくさいため，ラッパースクリプトを書いた．

ソースは以下．

```
#!/bin/sh

CMDNAME=`basename $0`
USAGE="Usage: $CMDNAME [-o OUTFILE] INFILE"

while getopts o: OPT
do
    case $OPT in
        "o" )
        OUTFILE=$OPTARG
        ;;
    * ) echo $USAGE
        exit 1;;
    esac
done

shift `expr $OPTIND - 1`

if [ $# == 0 -o $# -gt 1 ]; then
    echo $USAGE
    exit 1
fi

INFILE=$1

if [ -n "$OUTFILE" ]; then
    pandoc --latex-engine=lualatex \
        -t beamer \
        -V theme:KeynoteLikeGradient \
        -H h-luatexja.tex \
        -o $OUTFILE \
        $INFILE
else
    pandoc --latex-engine=lualatex \
        -t beamer \
        -V theme:KeynoteLikeGradient \
        -H h-luatexja.tex \
        $INFILE
fi
```

このスクリプトを適当な所に配置することで，次のようにすればPDFを作成できるようになる．

```
$ pandoc_wrapper -o OUTFILE INFILE
```

スクリプトを書くまでもなかった気がするが，気にしないことにする．

なお，pandocに `--listings` オプションを指定し， `-H` オプションで指定するヘッダファイル内でlistingsの設定をすることでソースコード部分にlistingsを使ったシンタックスハイライトが可能になる．
