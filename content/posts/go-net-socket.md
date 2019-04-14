---
title: "Go net package – Goでソケット通信"
date: 2018-02-04T00:00:00+09:00
draft: false
type: post
---

Goのnetパッケージについて軽く勉強した．
簡単なソケット通信についてまとめる．

## ソケット通信
ソースコードは以下．

    package main

    import (
        "fmt"
        "log"
        "net"
    )

    func main() {
        host := "localhost"
        port := "8000"
        address := net.JoinHostPort(host, port)
        conn, err := net.Dial("tcp", address)
        if err != nil {
            log.Fatalf("net.Dial(): %s\n", err)
        }
        defer conn.Close()

        request := "GET / HTTP/1.1\n\n"
        fmt.Println([]byte(request))
        _, err = conn.Write([]byte(request))
        if err != nil {
            log.Fatalf("Conn.Write(): %s\n", err)
        }

        buffer := make([]byte, 1024)
        var n int
        for {
            n, err = conn.Read(buffer)
            if n == 0 {
                break
        }
        if err != nil {
            log.Fatalf("Conn.Read(): %s\n", err)
        }
        fmt.Print(string(buffer))
        }
    }

以下に簡単な解説を．

Goでのソケット通信は， `Conn` オブジェクトを作成するところから始まる．
まず， `net.Dial()` で `Conn` オブジェクトを作成する．

    conn, err := net.Dial("tcp", address)

第1引数にはネットワークの種類を，第2引数には接続したい先のアドレスを指定する．
今回はサンプルとしてローカルに立てたHTTPサーバへ接続してみるので，ネットワークの種類は `TCP` を指定しておく．

`Conn` オブジェクトを作成できたら，後は `Conn.Read()` と `Conn.Write()` でデータの読み書きができる．

    _, err = conn.Write([]byte(request))
    ...
    ...
    n, err = conn.Read(buffer)

簡単なソケット通信は以上の3つのメソッドを使うことで簡単にできる．

Pythonで簡単にローカルHTTPサーバをたて，作成したプログラムを実行してみる．

    $ python -m http.server
    $ go run main.go
    HTTP/1.0 200 OK
    Server: SimpleHTTP/0.6 Python/3.6.2
    Date: Sun, 04 Feb 2018 12:47:14 GMT
    Content-type: text/html; charset=utf-8
    Content-Length: 336

    <!DOCTYPE HTML PUBLIC "-//W3C//DTD HTML 4.01//EN" "http://www.w3.org/TR/html4/strict.dtd">
    <html>
    <head>
    <meta http-equiv="Content-Type" content="text/html; charset=utf-8">
    <title>Directory listing for /</title>
    </head>
    <body>
    <h1>Directory listing for /</h1>
    <hr>
    <ul>
    <li><a href="main.go">main.go</a></li>
    </ul>
    <hr>
    </body>
    </html>

### JoinHostPort()/SplitHostPort()
上の例でも使っているが，これらのメソッドを使うことでアドレスとポート番号の結合・分離が簡単にできる．

    address := net.JoinHostPort("localhost", "8000")
    fmt.Println(address) // localhost:8000

    host, port, err := net.SplitHostPort("localhost:3000")
    if err != nil {
    log.Fatalf("net.SplitHostPort(): %s\n", err)
    }
    fmt.Printf("Host: %s, Port: %s\n", host, port) // Host: localhost, Port: 3000
