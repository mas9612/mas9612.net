---
title: "PythonからMySQLを使う"
date: 2016-07-13T00:00:00+09:00
draft: false
---

DjangoでデータベースにMySQLを使用するときはmysqlclientを使用することが推奨されている．Djangoが勝手にデータベースに接続などの処理をしてくれるのでモジュールの使い方は知らなくても使うことは可能だが，せっかくなら使い方もわかるほうが良いので調べてみた．

基本的に，Python標準ライブラリのsqlite3と使い方は同じ．
まずコネクションオブジェクトを作成し，そこからカーソルオブジェクトを作る．できたカーソルオブジェクトを使って様々なクエリを実行する．

## インストール

```
$ pip install mysqlclient
```

## MySQLに接続する

```python
conn = MySQLdb.connect(
    user='username',
    passwd='password',
    host='host',
    db='dbname'
)
```

返り値はコネクションオブジェクト．`user` と `passwd` は名前の通り．MySQLに登録されているユーザー情報を記述する． `host` はデータベースの置いてある場所を指定する．ローカルのMySQLに接続する場合は `localhost` を指定する． `db` には使用するデータベース名を指定する．

## カーソルオブジェクトの作成

```python
c = conn.cursor()
```

`MySQLdb.connect` で作成したオブジェクトを使ってカーソルオブジェクトを作成する．

## クエリの実行

```python
c.execute(query)
```

`query` に指定したクエリを実行する．

### プレースホルダ
クエリ中に `%s` を記述すると，プレースホルダとして扱える．ここに値を埋め込む場合は，与えたい値を `execute()` の第2引数にタプルで渡す．

```python
c.execute('select * from test where id = %s', (2,))
```

### レコードの取得`execute()` でselect文を実行した後，レコードを得るためには以下のいずれかを使用する．

* `fetchone()` : レコードを1件取得
* `fetchmany(n)` : レコードをn件取得
* `fetchall()` : レコードをすべて取得

## データベースへの変更を保存

```python
conn.commit()
```

このメソッドを呼び出すことで，変更を保存できる． **これを呼び出し忘れると，追加・削除などの変更が破棄される** ので注意．

このメソッドはカーソルオブジェクトではなく，コネクションオブジェクトが持っていることにも注意．

## サンプルコード

```python
# coding: utf-8

import MySQLdb

def main():
    conn = MySQLdb.connect(
        user='testuser',
        passwd='testuser',
        host='192.168.33.3',
        db='testdb'
    )
    c = conn.cursor()

    # テーブルの作成
    sql = 'create table test (id int, content varchar(32))'
    c.execute(sql)
    print('* testテーブルを作成\n')

    # テーブル一覧の取得
    sql = 'show tables'
    c.execute(sql)
    print('===== テーブル一覧 =====')
    print(c.fetchone())

    # レコードの登録
    sql = 'insert into test values (%s, %s)'
    c.execute(sql, (1, 'hoge'))  # 1件のみ
    datas = [
        (2, 'foo'),
        (3, 'bar')
    ]
    c.executemany(sql, datas)    # 複数件
    print('\n* レコードを3件登録\n')

    # レコードの取得
    sql = 'select * from test'
    c.execute(sql)
    print('===== レコード =====')
    for row in c.fetchall():
        print('Id:', row[0], 'Content:', row[1])

    # レコードの削除
    sql = 'delete from test where id=%s'
    c.execute(sql, (2,))
    print('\n* idが2のレコードを削除\n')

    # レコードの取得
    sql = 'select * from test'
    c.execute(sql)
    print('===== レコード =====')
    for row in c.fetchall():
        print('Id:', row[0], 'Content:', row[1])

    # データベースへの変更を保存
    conn.commit()

    c.close()
    conn.close()

if __name__ == '__main__':
    main()
```

実行結果

```
* testテーブルを作成

===== テーブル一覧 =====
('test',)

* レコードを3件登録

===== レコード =====
Id: 1 Content: hoge
Id: 2 Content: foo
Id: 3 Content: bar

* idが2のレコードを削除

===== レコード =====
Id: 1 Content: hoge
Id: 3 Content: bar
```
