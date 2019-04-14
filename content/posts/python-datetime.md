---
title: "Pythonで日付を使う"
date: 2016-05-06T00:00:00+09:00
draft: false
type: post
---

Pythonのdatetimeモジュールについて少し勉強した．
今回はdateオブジェクトのみ．

Python公式ドキュメントより

> datetime モジュールでは、日付や時間データを簡単な方法と複雑な方法の両方で操作するためのクラスを提供しています。日付や時刻を対象にした四則演算がサポートされている一方で、このモジュールの実装では出力の書式化や操作を目的とした属性の効率的な取り出しに焦点を絞っています。

## date オブジェクト
```
datetime.date(year, month, day)
```

すべての引数が必要．引数で指定した日時のdateオブジェクトが作成される．

```
date.today()
```

現在のローカルな日付を返す．

```
date.fromtimestamp(timestamp)
```

引数に与えられたPOSIXタイムスタンプに対応するローカルな日付を返す．timestampがプラットフォームのC関数 localtime() がサポートする値の範囲から外れていた場合，OverflowErrorを送出する可能性がある．localtime() 呼び出しが失敗した場合にはOSErrorを送出する可能性がある．

```
date.replace(year, month, day)
```

キーワード引数で指定されたパラメタが置き換えられたdataオブジェクトを返す．

```
date.weekday()
```

月曜日を0，日曜日を6として曜日を整数で返す．

```
date.isoweekday()
```

月曜日を1，日曜日を7として曜日を整数で返す．

```
date.strftime(format)
```

formatで指定された書式文字列に合わせて，日付を表現する文字列を返す．

```
>>> import datetime
>>> datetime.date(2000, 1, 1)   # 2000年1月1日を表すdateオブジェクトを作成
datetime.date(2000, 1, 1)
>>> datetime.date.today()   # 今日の日付を表すdateオブジェクトを作成
datetime.date(2016, 5, 6)
>>> d = datetime.date.today()
>>> d
datetime.date(2016, 5, 6)
>>> d.replace(year=1990)    # dateオブジェクトのyearを変更
datetime.date(1990, 5, 6)
>>> d.weekday() # 曜日を整数で返す（月曜日を0として）
4
>>> d.isoweekday()  # 曜日を整数で返す（月曜日を1として）
5
>>> d.strftime('%Y-%m-%d')  # 引数に与えられた書式で表示
'2016-05-06'
```
