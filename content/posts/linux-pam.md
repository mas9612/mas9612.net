---
title: "Linux PAMについて"
date: 2019-03-02T23:13:05+09:00
draft: false
toc: true
images:
tags: 
  - linux
  - pam
---

LDAPと連携させてLinuxサーバにログインしたいとき等，PAMの設定をいじることは今までにもあった．
しかし，PAMについてしっかりと理解できているわけではなかったので，PAMやその設定について調査した．

## PAMとは
マニュアルによると，PAM（Pluggable Authentication Module）はシステム上のアプリケーション（サービス）による認証を処理するためのライブラリであるとのこと．
API経由で認証タスクを呼び出すことができるので，アプリケーション側で認証のやり方等の深いところまで考えることなく使えるよ，という感じ．

> Linux-PAM is a system of libraries that handle the authentication tasks of applications (services) on the system.
> The library provides a stable general interface (Application Programming Interface - API) that privilege granting programs (such as login(1) and su(1)) defer to to perform standard authentication tasks.

PAMでは，認証に関するタスクを役割ごとに次の4つのグループに分け，それぞれのグループごとに設定できる．

* account: ユーザパスワードの期限が切れていないか，要求しているサービスにアクセスする権限があるか，等を検証
* authentication: パスワード等によるユーザ認証を行う部分．認証方法は問わない（パスワード，ハードウェアトークン等）
* password: 例えばパスワード認証の場合，パスワードの変更等に関連する部分を担当する（e.g. 弱いパスワードでないか，前回と同じでないか等）
* session: サービス利用前と利用後に実施される処理について．e.g. ログやユーザディレクトリのマウント等

## PAMの設定
PAMの設定は `/etc/pam.conf` もしくは `/etc/pam.d/` 以下のファイルによって行う．
`/etc/pam.d/` が存在している場合は， `/etc/pam.conf` は無視されて `/etc/pam.d/` 以下のファイルにある設定が有効となる．

設定のフォーマットは次の通り．基本的に1行に1つの設定を書いていく感じ．
```
service type control module-path module-arguments
```

なお，先頭が `#` の場合はコメントとなる．

`/etc/pam.conf` と `/etc/pam.d` 以下のファイルは基本的に設定フォーマットは同じである．
しかし， `/etc/pam.d/` 以下のファイルでは，そのファイル名自体が `service` を示すため，1カラム目にある `service` は省略される．

### service
serviceは，設定が反映される対象のアプリケーションを示す．
例えば，serviceが `sshd` の場合（ `/etc/pam.d/sshd` ）はSSHサーバのデーモンに対しての設定が記述される．

### type
typeは，その行にある設定が上記4つの内どのグループの設定かを示す．

* `account`
* `auth`
* `password`
* `session`

### control
単純な設定と複雑な設定があるが，単純な設定の場合に有効な値は次の通り．

* required: モジュールから返ってきた結果がfailure（失敗）だった場合，PAM全体としての返却値もfailureになる．しかし，後に続く設定は引き続き評価される．
* requisite: 基本はrequiredと同じ．requiredと異なり，モジュールの返却値がfailureだった場合はそこで即座に終了し，後に続く設定は評価されない．
* sufficient: モジュールの返却値が成功なら，そこで処理を終了してPAMも成功を返却する．後に続く設定は評価されない．モジュールの返却値が失敗なら引き続き後に続く設定の評価に移る．
* optional: このモジュールの結果は，このモジュールが唯一の設定であった場合のみ有効となる．
    - e.g.) sshdのauthタイプとして設定されているモジュールが一つだけ存在し，それのcontrolがoptionalである場合
* include: 他のファイルに定義されている設定を読みこむ．
* substack: includeと同様に他のファイルから設定を読み込むが，その中に即座に評価を終了するような設定がその中にあった場合（e.g. requisite），その効力は読み込んだファイルに対してのみ有効となる
    - e.g.) substackの中で定義されているrequisiteが失敗した場合，substack内の評価のみがそこで終了し，substackを呼び出した側の評価は終了せずに引き続き続行される．
    - スコープが分かれるイメージ

複雑な方の設定は今回確認するファイルの中には出てこなかったので割愛する．

### module-path, module-arguments
適用されるPAMモジュールのパスとその引数を指定する．
モジュールは共有ライブラリとなっており， `/lib64/security/` の下にあるかと思う．
それぞれのモジュールについての説明は， `man` コマンドで確認することができる（e.g. `man pam_unix` ）．

## sshdの設定を見てみる
PAMがどういったものかというのは簡単に理解できたので，実際に設定を見てみる．
今回は，LDAPログインの設定でも編集対象となるsshdの設定ファイルを見ることにする．
なお，一つ一つのモジュールについて逐一説明を入れていくとキリがないので，モジュール自体の説明は一部に留める．

今回使用している環境はCentOS 7である．
```sh
$ cat /etc/redhat-release
CentOS Linux release 7.6.1810 (Core)
```

`/etc/pam.d/sshd` の中身は次のようになっていた．
```sh
$ cat /etc/pam.d/sshd
#%PAM-1.0
auth       required     pam_sepermit.so
auth       substack     password-auth
auth       include      postlogin
# Used with polkit to reauthorize users in remote sessions
-auth      optional     pam_reauthorize.so prepare
account    required     pam_nologin.so
account    include      password-auth
password   include      password-auth
# pam_selinux.so close should be the first session rule
session    required     pam_selinux.so close
session    required     pam_loginuid.so
# pam_selinux.so open should only be followed by sessions to be executed in the user context
session    required     pam_selinux.so open env_params
session    required     pam_namespace.so
session    optional     pam_keyinit.so force revoke
session    include      password-auth
session    include      postlogin
# Used with polkit to reauthorize users in remote sessions
-session   optional     pam_reauthorize.so prepare
```

設定ファイルは上から順番に評価されていくので，設定を読むときも上から順番に読んでいく．

authに関連する部分を見てみる．
auth関連の部分は次の4行（コメントを除く）．

```
auth       required     pam_sepermit.so
auth       substack     password-auth
auth       include      postlogin
# Used with polkit to reauthorize users in remote sessions
-auth      optional     pam_reauthorize.so prepare
```

1つ目の `pam_sepermit.so` は，このユーザはSELinuxが有効になっている場合のみログインを許可する，といった設定が可能になるモジュール．

2つ目と3つ目は，それぞれ `/etc/pam.d/password-auth` と `/etc/pam.d/postlogin` というファイルから設定を読み込んでいる．
2つ目は `substack` となっているので，もし `password-auth` の中でrequisiteのように即座に評価を終了するものが適用された場合は，その段階で `password-auth` の評価が終了するだけで引き続き次の`postlogin` の評価に移る．

4つ目の `auth` には，頭に `-` がついている．これは，もしモジュールが存在しなかった場合はこの行を無視して次に進むということを意味している．

次に，password-authとpostloginの部分について見てみる．
なお， `include` や `substack` は，それが書かれたtypeに関する設定のみを読み込む．今回だと `auth` の部分のみを読み込む．

```
$ cat /etc/pam.d/password-auth | grep -E '^-?auth'
auth        required      pam_env.so
auth        required      pam_faildelay.so delay=2000000
auth        sufficient    pam_unix.so nullok try_first_pass
auth        requisite     pam_succeed_if.so uid >= 1000 quiet_success
auth        required      pam_deny.so
$ cat /etc/pam.d/postlogin | grep -E '^-?auth'
```

## おわりに
PAMとは何か，どのようにPAMを設定していくのかについて調査した．
PAM APIの方針に従っていれば，自由に新しいモジュールを作成することができるので，理解を深めるためになにか簡単なモジュールでも作ってみようかと考えている．

## References
* PAM(8)
* pam.conf(5)
