---
title: "はてなブログからエクスポートした記事からはてなキーワードのリンクを削除する"
date: 2017-09-24T00:00:00+09:00
draft: false
type: post
---

はてなブログから他のブログへ移行する際，はてなブログから記事をエクスポートし，移行先のサービスへ記事をインポートするという作業をする．
しかし，はてなブログの無料版だと，はてなキーワードのリンクを削除することができない．

手作業で一つ一つ削除していくのは非常に面倒くさい．
そのため，一度データをエクスポートし，それを正規表現を使って編集することで対応した．

Vimでエクスポートしたファイルを開き，置換コマンドを使うと一発で完了する．

`:%s/\v\<a>]+\>([^<]+)\<\/a\>/\1/g`

これで完了．
