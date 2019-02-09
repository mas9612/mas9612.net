---
title: "Lilypondのインストールと環境設定"
date: 2016-09-07T00:00:00+09:00
draft: false
---

今まで楽譜を書くときにはFinaleを使用していたが，いつも使用していたFinale2011はYosemite以降，プレイバック関係でちゃんと使えない．仕事で使っているわけではないのでわざわざ新しいバージョンを購入するのはどうかと思い，前から気になっていたLilypondを導入した．

環境はOS X v10.11.6 El Capitan．エディタにはVimを使用する．

## Lilypondのインストール
homebrewで簡単にインストールできる．
事前に `homebrew/tex` をtapする必要がある．

```
$ brew tap homebrew/tex
$ brew install lilypond
```

## Vimの設定

### runtimepathの設定
Lilypondをインストールすると，一緒にVimのftpluinなどがついてくる．これを有効にするために， `~/.vimrc` に以下を追記する．

```
filetype off
set runtimepath+=/usr/local/share/lilypond/2.18.2/vim/
filetype on
```

2行目で `runtimepath` に追加するパスは，インストールされたバージョンに応じて変更する必要があるかも．

### quickrunの設定`vim-quickrun` を使用して，Vimから直接コンパイルしてPDFを確認できるように設定する．

`~/.vim/ftplugin/` 以下にLilypond用の設定ファイルを追加する．今回は `lilypond_quickrun.vim` というファイル名で作成した．
( `~/.vim/ftplugin/lilypond_quickrun.vim` )

```
let g:quickrun_config = {}

let g:quickrun_config['lilypond'] = {
\   'command' : 'lilypond',
\   'outputter' : 'error',
\   'outputter/error/success' : 'null',
\   'outputter/error/error' : 'quickfix',
\   'srcfile' : expand("%"),
\   'exec': '%c %o %a %s',
\ }

let s:hook = {
\   'name': 'open_pdf',
\   'kind': 'hook',
\   'config': {
\     'enable': 1,
\   },
\ }

function! s:hook.on_success(...)
  let l:fileName = expand("%")
  let l:fileName = substitute(l:fileName, "ly", "pdf", "")
  " if not store retval to variable, E492 error occur
  let l:result = system("open " . l:fileName)
endfunction

call quickrun#module#register(s:hook, 1)
```

もっと良い設定方法があるかもしれないが，まだquickrunの設定をきちんと理解していないのでとりあえずこんな感じで．

`s:hook.on_success` の部分でコンパイル後に生成されたPDFを開く処理を定義している．無理矢理感はあるが良い方法が思いつかなかった．

これで `:QuickRun` を実行すると，自動的にPDFが開くようになった．

#### 9/10追記
出力ファイル名を指定しない時はこの方法で上手くPDFが開くが，複数ファイルで楽譜を書いている時など，出力ファイル名を指定している時は上手くPDFを開けない．
とりあえず解決策が思いつかないのでMakefile作ってVimから `:make` することにした．

### テンプレートファイルの作成
Lilypondは，ファイルの頭にバージョンを指定しなければいけないらしい．毎回書くのは面倒なので，Vimのテンプレート機能を使用する．

`~/.vim/template/lilypond.txt` に，自動的に挿入してほしい内容を記述する．とりあえずバージョンの宣言だけ書いた．

```
\version "2.18.2"
```

次に，FiletypeがLilypondの時にこのテンプレートを読み込むように設定する． `~/.vimrc` に以下を追加する．

```
autocmd BufNewFile *.ly 0r $HOME/.vim/template/lilypond.txt
```

## 終わりに
これでとりあえずVim+Lilypondでの楽譜作成環境の構築が完了したので，Lilypondのチュートリアルでもやって勉強しようと思います．
MusicXMLへの変換もできるようにしたいので，これから調べます．
