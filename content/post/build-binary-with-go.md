---
title: "Goでバイナリを作る"
date: 2018-07-27T00:00:00+09:00
draft: true
---

ネットワークパケットを作るために，構造体や変数からバイト型のスライスへの変換方法を調べた．

テストで書いてみたプログラムは次の通り．
とりあえずint型の変数をいくつか対象としてバイト変換を試してみた．

<script src="https://gist.github.com/mas9612/ea067ea7436b28e2054a12c7630758b1.js"></script>

何らかの型（構造体やint等のプリミティブ型）からバイト型のスライスに変換するには， `encoding/binary` パッケージの `Write` メソッドを使用すると良い．

`binary.Write()` メソッドは次のような定義になっている．

    func Write(w io.Writer, order ByteOrder, data interface{}) error

第3引数に指定したデータを，第2引数で指定したバイトオーダーで第1引数の `w` に書き込む．

このメソッドを使うために，まず `io.Writer` インタフェースを実装したものが必要になる．
バイト型のデータを書き込みたいので， `bytes` パッケージの `Buffer` を使用することにする．

    buf := new(bytes.Buffer)

注意点として， `new()` を使う点が挙げられる．
`bytes.Buffer` の `Write()` メソッドはポインタ型（ `*bytes.Buffer` ）がレシーバとなっているため， `new()` を使ってポインタを取得してあげる必要がある．

これで `io.Writer` を用意できたので， `binary.Write()` を使ってデータを書き込む．
適当にint型の変数を用意して `binary.Write()` による書き込みを行う．
なお，今回はネットワークパケットを作りたいので，第2引数のバイトオーダはビッグエンディアンを指定する．

    var val32bit int32
    val32bit = 123

    err = binary.Write(buf, binary.BigEndian, val32bit)
    if err != nil {
        log.Fatalln(err)
    }
    fmt.Printf("uint32: % x\n", buf.Bytes())

これで無事書き込みができた．

サンプルプログラムの実行結果

    uint8: 7b
    uint16: 00 7b
    uint32: 00 00 00 7b

今回はint型のみを扱ったが，構造体を書き込みたいときも同じようにして扱うことができるようだ．
