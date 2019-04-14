---
title: "Pythonでsqlite"
date: 2016-05-12T00:00:00+09:00
draft: false
type: post
---

Pythonでデータベースを使ってみたかったので，標準ライブラリに含まれているsqlite3モジュールを触ってみた．

サンプルコードはこちら．
[GitHub](https://github.com/mas9612/python-sqlite3)にもあげました．

```python
# -*- coding: utf-8 -*-

import sqlite3

dbname = 'database.db'
conn = sqlite3.connect(dbname)

c = conn.cursor()
# executeメソッドでSQL文を実行する
create_table = '''create table users (id int, name varchar(64),
                  age int, gender varchar(32))'''
c.execute(create_table)

# SQL文に値をセットする場合は，Pythonのformatメソッドなどは使わずに，
# セットしたい場所に?を記述し，executeメソッドの第2引数に?に当てはめる値を
# タプルで渡す．
sql = 'insert into users (id, name, age, gender) values (?,?,?,?)'
user = (1, 'Taro', 20, 'male')
c.execute(sql, user)

# 一度に複数のSQL文を実行したいときは，タプルのリストを作成した上で
# executemanyメソッドを実行する
insert_sql = 'insert into users (id, name, age, gender) values (?,?,?,?)'
users = [
    (2, 'Shota', 54, 'male'),
    (3, 'Nana', 40, 'female'),
    (4, 'Tooru', 78, 'male'),
    (5, 'Saki', 31, 'female')
]
c.executemany(insert_sql, users)
conn.commit()

select_sql = 'select * from users'
for row in c.execute(select_sql):
    print(row)

conn.close()
```

以下，サンプルコードの解説を少し．

## データベースへ接続
データベースに接続するには，`sqlite3.connect()`メソッドを使用する．

```
conn = sqlite3.connect(dbname)
```

`sqlite3.connect()`メソッドではConnectionオブジェクトが作成される．
SQL文を実行するには，ConnectionオブジェクトからさらにCursorオブジェクトを作成する必要がある．

```
c = conn.cursor()
```
このCursorオブジェクトを使用することでデータベースに対して様々なコマンドを実行することができる．

## SQLの実行
SQL文を実行するには，Cursorオブジェクトの`execute()`メソッドを使用する．

```
c.execute(sql[, parameters])
```
第1引数のSQL文に?を埋め込んだ場合は，第2引数で?にセットしたい値をタプルで渡す．

Example

```
user = (1, 'Taro', 20, 'male')
c.execute('insert into users (id, name, age, gender) values (?,?,?,?)', user)
```

こうすることで，SQLの?部分にタプル内の値がそれぞれ当てはめられ，最終的に以下のようなSQL文が実行される．

```
insert into users (id, name, age, gender) values (1, 'Taro', 20, 'male')
```
なお，一度に複数のSQLを実行したい場合は，`executemany()`メソッドを使用し，第2引数にタプルのリストを渡す（サンプルコード参照）．

## 変更をデータベースに保存
`execute()`メソッドや`executemany()`メソッドでデータベースに追加・削除などを行った後には，必ず`commit()`メソッドを呼び出す．このメソッドを呼び出さずにデータベースを閉じてしまうと，変更が保存されない．

```
conn.commit()
```

## データベースを閉じる
プログラムの最後には忘れずにデータベースコネクションを閉じます．これには`close()`メソッドを使用する．**このメソッドは自動的に`commit()`を呼び出さないことに注意．**

```
conn.close()
```
