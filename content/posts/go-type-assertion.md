---
title: "GoのType AssertionとType Switches"
date: 2018-10-02T00:00:00+09:00
draft: true
---

Goでは，型を `interface{}` として宣言してあげることで，とりあえずどんな値でも格納することが出来る．
SlackのEvent API等，メッセージの形式がEventごとに異なるといった場合に使うと便利．

Example
```go
func eventHandler(w http.ResponseWriter, r *http.Request) {
    var event map[string]interface{}
    decoder := json.NewDecoder(r.Body)
    if err := decoder.Decode(&event); err != nil {
        log.Fatalln(err)
    }
}
```

この例だと，変数 `event` に受け取ったイベントが格納される．
`event` は `map[string]interface{}` として宣言されているので， `event["token"]` のように値を取得しても返ってくるのは `interface{}` 型である．
そのため，値を使いたいときに適切な型へ変換してあげる必要がある．

このような場合に，Goの言語仕様として用意されているType AssertionやType Switchesというものを使ってあげるとうまく型変換が出来る．

## Type assertions
Type assertionsを使うと， `interface{}` から指定した型に変換することが出来る．
Type assertionsでは，次のような順番で処理が行われる．

1. 値がnilであるかどうかを検査
1. 指定した型に変換して値を返却

書き方は次の2つある．

### 1. 基本形
```go
var x interface{} = 7   // interface{}としてxを宣言
i := x.(int)            // Type assertionsを使ってint型に変換
```

Type assertionsが成功すると，指定した型に変換された値が返り値として返される（上の例だと `int` に変換された `7` が返ってくる）．
もし次の例のように正しく変換できなかった場合は，panicが発生する．
```go
var x interface{} = "hello" // interface{}としてxを宣言
i := x.(int)                // xの値 "hello" はint型に変換できない => panic発生
```

### 2. 別の書き方
別の書き方として，次のように返り値を2つ受け取るバージョンがある．
```go
var x interface{} = 7   // interface{}としてxを宣言
i, ok := x.(int)        // okには正しく変換できたかどうかがboolで格納される．成功した場合はtrue
```

この書き方を使うと，失敗したときでもpanicは発生せず， `ok` に `false` が設定されるだけとなる．
この時，1つめの返り値は指定した型のゼロ値となる．
```go
var x interface{} = "hello" // interface{}としてxを宣言
i, ok := x.(int)            // xの値 "hello" はint型に変換できない => okはfalse
fmt.Println(i)              // 0（intのゼロ値）が出力される
```

## Type Switches
ドキュメントでは，Type SwitchesはType assertionの特別形であると説明されている．
Type assertionでは変換したい型名を指定していたが，Type Switchesでは代わりに `type` を指定する．
```go
var x interface{} = "hello"
switch i := x.(type) {
    case int:
        fmt.Println("x is int")
    case string:
        fmt.Println("x is string")
}
```

これを使うと，複数の型候補がある場合にswitch文を使って分岐させることが出来る．

## 参考文献
* [Type assertions](https://golang.org/ref/spec#Type_assertions)
* [Switch Statements](https://golang.org/ref/spec#Switch_statements)
