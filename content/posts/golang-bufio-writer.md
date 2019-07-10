---
title: "Goのbufio.Writerについて"
date: 2019-07-10T19:08:35+09:00
draft: false
type: post
toc: true
images:
tags:
 - programming
 - golang
---

GoのbufioパッケージにあるWriterについて，少し実装を見てみたのでメモ．

```sh
$ go version
go version go1.12.6 darwin/amd64
```

## bufio.Writer
バッファリング機構を持った `io.Writer` インタフェースの実装．
特に何も指定せずに `bufio.Writer` を作成すると，バッファサイズは4096バイトになる．

### 使用したサンプルコード
GoDocにある `bufio.Writer` のExampleそのまま．

```go
package main

import (
	"bufio"
	"fmt"
	"os"
)

func main() {
	w := bufio.NewWriter(os.Stdout)
	fmt.Fprint(w, "Hello, ")
	fmt.Fprint(w, "world!")
	w.Flush()
}
```

これを実行すると，おなじみの `Hello, world!` がコンソールに出力される．
```sh
$ go run main.go
Hello, world!
```

それでは中身を見ていく．
Writer関連のメソッドは [golang/go: The Go programming language](https://github.com/golang/go) の `src/bufio/bufio.go` で定義されている．

`bufio.NewWriter` は `bufio.NewWriterSize` のラッパーになっており，デフォルトのバッファサイズ（4096バイト）でバッファを作成して `bufio.Writer` を返却する．
バッファサイズをデフォルト値以外にしたい場合は， `bufio.NewWriterSize` の引数に好きな値を指定してあげれば良い．

```go
const (
	defaultBufSize = 4096
)

// ...

func NewWriterSize(w io.Writer, size int) *Writer {
	// Is it already a Writer?
	b, ok := w.(*Writer)
	if ok && len(b.buf) >= size {
		return b
	}
	if size <= 0 {
		size = defaultBufSize
	}
	return &Writer{
		buf: make([]byte, size),
		wr:  w,
	}
}

func NewWriter(w io.Writer) *Writer {
	return NewWriterSize(w, defaultBufSize)
}
```

なお， `bufio.NewWriter` および `bufio.NewWriterSize` の引数として `bufio.Writer` を渡した場合，そのバッファサイズが十分に大きければ新しいオブジェクトは作成されずにそのまま返却される．
```go
func NewWriterSize(w io.Writer, size int) *Writer {
	// Is it already a Writer?
	b, ok := w.(*Writer)
	if ok && len(b.buf) >= size {   // バッファサイズが十分ある場合はここでreturn
		return b
	}
    // ...
}
```

ちなみに， `bufio.Writer` は次のような構造体として定義されている．
```go
type Writer struct {
	err error
	buf []byte
	n   int
	wr  io.Writer
}
```

それぞれ `err` が書き込み時に発生したエラー， `buf` がバッファ， `n` が現在バッファに溜まっているバイト数， `wr` がバッファの書き込み先．

サンプルコードでは `fmt.Fprint` を使って文字列を書き込んでいるが， `fmt.Fprint` の内部で `Write` メソッドが呼ばれている．
`bufio.Writer` の `Write` メソッドは次のように実装されている．
```go
func (b *Writer) Write(p []byte) (nn int, err error) {
	for len(p) > b.Available() && b.err == nil {
		var n int   // 1回のforループ中に書き込んだバイト数
		if b.Buffered() == 0 {
			// Large write, empty buffer.
			// Write directly from p to avoid copy.
			n, b.err = b.wr.Write(p)
		} else {
			n = copy(b.buf[b.n:], p)
			b.n += n
			b.Flush()
		}
		nn += n
		p = p[n:]
	}
	if b.err != nil {
		return nn, b.err
	}
	n := copy(b.buf[b.n:], p)
	b.n += n
	nn += n     // このWriteメソッド全体で書き込んだバイト数．バッファ・io.Writerどちらに書き込んだかは関係ない
	return nn, nil
}
```

引数に与えられたデータの長さがバッファの空きスペース（ `b.Available()` ）よりも小さい場合はforループがスキップされ，データをバッファにコピーして終了となる．
```go
func (b *Writer) Write(p []byte) (nn int, err error) {
	for len(p) > b.Available() && b.err == nil {
        // ...
	}
	if b.err != nil {
		return nn, b.err
	}
	n := copy(b.buf[b.n:], p)   // ここでデータをバッファにコピーしている
	b.n += n
	nn += n
	return nn, nil
}
```

データの長さがバッファの空きスペースよりも大きい場合は，forループの中で少しずつデータの書き込みが行われていく．
基本的には次のような手順で処理が進んでいく．

1. バッファの空きスペース分だけデータをバッファにコピーする
1. バッファがいっぱいになったら，バッファの内容を書き込み先の `io.Writer` に書き込む（ `bufio.Writer.Flush()` に相当）
1. データの最後に到達するまで1, 2の繰り返し

ここで，手順1の時にバッファが空の場合（ `b.Buffered() == 0` ）は，一度バッファにデータをコピーしてからバッファの内容を Write すると無駄なコピーが発生してしまう．
そこで，バッファが空の場合はデータを直接書き込み先の `io.Writer` に書き込んでしまっている．
```go
func (b *Writer) Write(p []byte) (nn int, err error) {
	for len(p) > b.Available() && b.err == nil {
		var n int
		if b.Buffered() == 0 {
			// Large write, empty buffer.
			// Write directly from p to avoid copy.
			n, b.err = b.wr.Write(p)
    // ...
}
```

### Flush()の呼び出し
ドキュメントにも記述があるように，最後にFlushメソッドを呼ぶことが推奨されている．

> After all data has been written, the client should call the Flush method to guarantee all data has been forwarded to the underlying io.Writer.

Flushメソッドを呼ばなかった時の挙動を調べるためのプログラムを書いてみた．
```go
package main

import (
	"bufio"
	"fmt"
	"os"
)

func main() {
	w := bufio.NewWriterSize(os.Stdout, 8)
	fmt.Fprint(w, "Hello, ")
	fmt.Fprint(w, "world!")
	// w.Flush()
}
```

先程のサンプルプログラムとほとんど同じだが，下の2点を変更した．

1. バッファサイズを8バイトに
1. 最後の `w.Flush()` をコメントアウト

このプログラムを実行すると，次のように途中までしかデータが書き出されずに終了する．
```sh
$ go run main.go
Hello, w
```

はじめに `Hello, ` を書き込むときは，データのサイズよりもバッファの空きスペースのほうが大きいため（ `7 < 8` ），データはそのままバッファにコピーされる．

![bufio-writer-01](/images/bufio-writer-01.png)

このとき， `w` のバッファに溜まっているのは7文字なので，バッファにはあと `8 - 7 = 1` 文字格納できることになる．

次に `world!` を書き込むが，バッファの空きスペースよりもデータのサイズが大きいので，まずはバッファに入る分だけコピーされる．

![bufio-writer-02](/images/bufio-writer-02.png)

これでバッファがいっぱいになったので，一度Flushされて標準出力に書き込まれる．
バッファの内容を書き出したあと，残りのデータを処理する．
残りのデータ（ `orld!` ）はバッファの空きスペースよりも小さいので，ここではバッファにコピーされるだけとなる．
最終的にバッファの状態は次の図のようになる．

![bufio-writer-03](/images/bufio-writer-03.png)

ここで書き込むデータはすべて終了したが，Flushメソッドが呼ばれていないために，バッファに残っているデータは書き出されないままプログラムが終了してしまう．
そのため，標準出力には途中までしか文字が出力されなかった．
