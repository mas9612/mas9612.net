---
title: "HTTP Keep-Aliveについて"
date: 2018-07-05T00:00:00+09:00
draft: false
---

HTTP Keep-Aliveについて調査した．
とりあえず調査しただけなので，次回にでも実際に挙動確認をしたい．

* 1つのTCPコネクションで複数リクエストを処理できるしくみ
* HTTP/1.1ではKeep-Aliveがデフォルトでオン
    * オフにするにはそれを明示的に指定する必要がある
        * `Connection: close` ヘッダを指定

## Apache
### Keep-Aliveの設定`KeepAlive` ディレクティブで，Keep-Aliveを有効にするかどうかを設定できる．
Keep-Aliveによるコネクション持続時間は， `KeepAliveTimeout` ディレクティブで設定する．

例) コネクション持続時間を10秒に設定する

    KeepAlive On
    KeepAliveTimeout 10

また，1つのKeep-Aliveによるコネクションで処理できるコネクション数を制限するには， `MaxKeepAliveRequests` ディレクトティブを使用する．
例えば， `MaxKeepAliveRequests 10` と設定すると，1つのコネクションで10個までのコネクションを処理することができる．

## Nginx
### Keep-Aliveの設定
Nginxでは，Keep-AliveのOn/Offは `keepalive_timeout` の値によって決まる．

* `keepalive_timeout` が `0` : Keep-Alive Off
* `keepalive_timeout` が `0` 以外: Keep-Alive On

Keep-Aliveによるコネクション持続時間は，On/Offの設定同様 `keepalive_timeout` で設定する．

例) コネクション持続時間を10秒に設定する

    keepalive_timeout 10

## References
* [RFC2068](https://tools.ietf.org/html/rfc2068)
* [Hypertext Transfer Protocol (HTTP) Keep-Alive Header](https://tools.ietf.org/id/draft-thomson-hybi-http-timeout-01.html)
* [Apache Core Features](https://httpd.apache.org/docs/2.4/en/mod/core.html)
