---
title: "GoでMySQLを使う - database/sql package"
date: 2018-02-15T00:00:00+09:00
draft: true
---

GoからMySQLを使う方法について調べた．
O/Rマッパーを使う方法も気になったが，まずGo標準パッケージで用意されている機能を使い，SQLを地道に実行していく方法を試した．

ソースコードは以下．

## 実行
Dockerを使って簡単にローカルにMySQLを準備する．

    $ docker run -p 3306:3306 -e MYSQL_ROOT_PASSWORD=mypass -e MYSQL_DATABASE=testdb -e MYSQL_USER=mysql -e MYSQL_PASSWORD=mypass -d --name mysql mysql

DBの準備後，作成したソースコードを実行する．

    $ go run mysql_example.go
    ID: 1, Name: Tom
    ID: 2, Name: Bob
    ID: 3, Name: Alice

INSERTしたデータが正しく取得できていそうである．
念のため，MySQLに入って確認してみる．

    $ docker exec -it mysql mysql -u root -p
    Enter password:

    mysql> show databases;
    +--------------------+
    | Database           |
    +--------------------+
    | information_schema |
    | mysql              |
    | performance_schema |
    | sys                |
    | testdb             |
    +--------------------+
    5 rows in set (0.01 sec)

    mysql> use testdb;
    Database changed

    mysql> show tables;
    +------------------+
    | Tables_in_testdb |
    +------------------+
    | test_tbl         |
    +------------------+
    1 row in set (0.00 sec)

    mysql> select * from test_tbl;
    +------+-------+
    | id   | name  |
    +------+-------+
    |    1 | Tom   |
    |    2 | Bob   |
    |    3 | Alice |
    +------+-------+
    3 rows in set (0.00 sec)

上記の通り，正常にテーブルの作成とデータの追加が行えていることが確認できた．

## 解説
### 準備
Goの `database/sql` パッケージを使うと，色々なDBを扱うことができる．
しかし， `database/sql` パッケージとは別に，[ここ](https://github.com/golang/go/wiki/SQLDrivers)から使いたいDBのdriverを探してインストールしておく必要がある．
今回はMySQLを使いたいので，[go-sql-driver/mysql](https://github.com/go-sql-driver/mysql/)を利用した．
下記コマンドで `go-sql-driver/mysql` をインストールする．

    $ go get -u github.com/go-sql-driver/mysql

### データベースへの接続
データベースへ接続するには， `sql.Open()` メソッドを使用する．
第1引数に使用したいdriver名，第2引数に接続先を指定する．

    db, err := sql.Open("mysql", "mysql:mypass@/testdb")

接続確認を行いたい場合は， `sql.Open()` の後に `DB.Ping()` メソッドを呼び出すことでできる．

    if err = db.Ping(); err != nil {
        log.Fatalf("db.Ping(): %s\n", err)
    }

### SQLの実行
SQLの実行は， `DB.Exec()` 及び `DB.Query()` メソッドで行うことができる．
CREATE文やINSERT文など，DBからデータが返ってこないものに関しては `DB.Exec()` メソッドを用い，SELECT文などDBからデータを取得するのが目的であるものに関しては `DB.Query()` メソッドを用いる．

#### Exec()

    _, err = db.Exec("create table test_tbl (id int, name varchar(32))")
    if err != nil {
        log.Fatalf("db.Exec(): %s\n", err)
    }

#### Query()
DBからの結果は `sql.Rows` に入っている．
`Rows.Scan()` メソッドで，1レコードの中から値（今回であればSELECT文での取得対象に `*` をしているため，全てのカラム =  `id` と `name` ）を取得することができる．
`Rows.Scan()` メソッドの引数にはポインタを渡すことに注意する．

1レコード分の処理が終了し，次のレコードに移るためには `Rows.Next()` メソッドを呼び出す．

    var rows *sql.Rows
    rows, err = db.Query("select * from test_tbl")
    if err != nil {
        log.Fatalf("db.Query(): %s\n", err)
    }
    defer rows.Close()

    for rows.Next() {
        var (
            id   int
            name string
        )
        err = rows.Scan(&id, &name)
        if err != nil {
            log.Fatalf("rows.Scan(): %s\n", err)
        }

        fmt.Printf("ID: %d, Name: %s\n", id, name)
    }
    if err = rows.Err(); err != nil {
        log.Fatalf("rows.Err(): %s\n", err)
    }
