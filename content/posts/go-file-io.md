---
title: "GoでのファイルI/O"
date: 2019-01-13T00:00:00+09:00
draft: false
type: post
---

GoでのファイルI/Oについて，改めてまとめた．
いろいろな方法があるので，それぞれどういったものかを確認しながらまとめる．

## ファイルオープン
読み書きを行う前に，まずファイルオープンしないとどうにもならないのでそこから．
osパッケージを見ると，2つのファイルオープンメソッドがあることがわかる．

* `os.Open`
* `os.OpenFile`

### os.Open
```go
func Open(name string) (*File, error)
```
引数に与えられた名前のファイルを **読み取り専用** でオープンする．
そのため，もしファイルが存在しなければエラーとなる（ `*PathError` が返却される）

例
```go
// os.Open attempts to open given file as read only mode.
// Therefore, if it doesn't exist, then *os.PathError will occur.
_, err := os.Open("thisdoesntexist.txt")
if err != nil {
    if os.IsNotExist(err) {
        log.Println("file not found", err)
    } else {
        log.Println(err)
    }
}
```

上の例では便利メソッドとして `os.IsNotExist` を使っている．
このメソッドに `os.Open` から返却されたエラーを渡すと，ファイルが存在しないために発生したエラーかどうかを教えてくれる．
`os.IsNotExist` の返り値が `true` なら，ファイルが存在しないという意味になる．

### os.OpenFile
```go
func OpenFile(name string, flag int, perm FileMode) (*File, error)
```
引数に与えられた名前のファイルを，指定したモード，パーミッションでオープンする．
`flag` の指定方法次第で，追記モードや，存在しない場合に作成する，等が可能になる．

例
```go
// os.OpenFile attempts to open given file as given mode and permission.
// In this example, open "newfile.txt" as write-only mode and it permission is 0600 (r/w only allowed to file owner)
file, err := os.OpenFile("newfile.txt", os.O_WRONLY|os.O_CREATE, 0600)
if err != nil {
    log.Fatalln(err)
}
defer file.Close()
```

## （おそらく）最も基本となる方法
ファイルをオープンし，バイト型のスライスを使ってデータの読み書きを行う方法．

### Read
前提として，ファイルからの読み取りができるモードでオープンされている必要がある．

```go
file, err := os.Open("newfile.txt")
if err != nil {
    log.Fatalln(err)
}
defer file.Close()

// *File.Read reads slice of bytes up to len(slice) from file.
buffer := make([]byte, 1024)
n, err := file.Read(buffer)
if err != nil {
    log.Fatalln(err)
}
log.Printf("%d bytes read by *File.Read()\n", n)
log.Printf("file content: %s\n", string(buffer))
```

### Write
前提として，ファイルに書き込みができるモードでオープンされている必要がある．
```go
// os.OpenFile attempts to open given file as given mode and permission.
// In this example, open "newfile.txt" as write-only mode and it permission is 0600 (r/w only allowed to file owner)
file, err := os.OpenFile("newfile.txt", os.O_WRONLY|os.O_CREATE, 0600)
if err != nil {
    log.Fatalln(err)
}
defer file.Close()

// *File.Write writes slice of bytes to file.
byteData := []byte("Hello world\n")
n, err := file.Write(byteData)
if err != nil {
    log.Fatalln(err)
}
log.Printf("%d bytes written by os.Write()\n", n)
```

また，バイト型のスライスの代わりにstringを書き込むこともできる．
stringの書き込みには `WriteString` メソッドを使用する．
```go
// *File.WriteString writes strings to file instead of slice of bytes.
stringData := "We can write not only []byte but also string :)"
n, err = file.WriteString(stringData)
if err != nil {
    log.Fatalln(err)
}
log.Printf("%d bytes written by os.WriteString()\n", n)
```

### ファイルの内容すべてを読み込む
io/ioutilパッケージの `ReadAll` メソッドを使用すると，ファイルの内容すべてを読み込むことができる．
```go
type Reader interface {
    Read(p []byte) (n int, err error)
}

func ReadAll(r io.Reader) ([]byte, error)
```

ReadAllの引数に与える `io.Reader` は， `Read` メソッドを持つインタフェースと定義されている．
そのため，通常通りオープンしたファイルをそのまま渡すことができる．

例
```go
file, err := os.Open("newfile.txt")
if err != nil {
    log.Fatalln(err)
}
defer file.Close()

bytes, err := ioutil.ReadAll(file)
if err != nil {
    log.Fatalln(err)
}
log.Printf("Read all contents by ioutil.ReadAll(): %s\n", string(bytes))
```

## バッファありのファイルI/O
bufioパッケージのメソッドを使用すると，読み書きの際に内部でバッファを使ってくれる．
そのため，そのままデータを読み書きするよりも効率的に処理を行うことができる．

ファイルI/Oに使えそうなものは次の3種類．

* bufio.Reader
* bufio.Scanner
* bufio.Writer

### bufio.Reader
基本的な使い方は通常のファイルと似ているが，いくつか便利なメソッドが定義されている．
```go
reader := bufio.NewReader(file)
buffer := make([]byte, 5)
// basic Read method
if _, err := reader.Read(buffer); err != nil {
    log.Fatalln(err)
}
log.Printf("content: %s\n", string(buffer))

// ReadBytes reads until delimiter found.
// Read contents is slice of bytes.
// In this example, read until first '\n' character found.
bytes, err := reader.ReadBytes('\n')
if err != nil {
    log.Fatalln(err)
}
log.Printf("content: %s\n", string(bytes))

// ReadString reads until delimiter found.
// Read contents is string.
// In this example, read until first '\n' character found.
str, err := reader.ReadString('\n')
if err != nil {
    log.Fatalln(err)
}
log.Printf("content: %s\n", str)
```

### bufio.Scanner
bufio.Readerと似ているが，こちらは改行区切りのテキストを扱う時に便利なものになっている．
```go
file, err := os.Open("newfile.txt")
if err != nil {
    log.Fatalln(err)
}
scanner := bufio.NewScanner(file)
for scanner.Scan() {
    log.Println(scanner.Text())
}
```

`Text` メソッドを呼ぶと，改行文字まで（＝1行分の文字）を返してくれる．

`Scan` が `true` の間は，まだ読んでいない行があるということを示している．
なので， `Scan` が `false` になるまでループを回してあげれば結果的にファイルの内容すべてを読むことができる．

### bufio.Writer
Readerと同様，io.Writerと似ている．
注意しなければならない点として，最後に `Writer.Flush` を呼び出す必要がある点がある．
これを呼び出さないと正常に書き込みされないので注意する．

```go
file, err := os.OpenFile("newfile.txt", os.O_WRONLY|os.O_CREATE, 0600)
if err != nil {
    log.Fatalln(err)
}
defer file.Close()

writer := bufio.NewWriter(file)

byteData := []byte("Hello world\n")
n, err := writer.Write(byteData)
if err != nil {
    log.Fatalln(err)
}
log.Printf("%d bytes written\n", n)

stringData := "Write string :)"
n, err = writer.WriteString(stringData)
if err != nil {
    log.Fatalln(err)
}
log.Printf("%d bytes written\n", n)

writer.Flush()
```

## References
* [os - GoDoc](https://godoc.org/os)
* [io - GoDoc](https://godoc.org/io)
* [ioutil - GoDoc](https://godoc.org/io/ioutil)
