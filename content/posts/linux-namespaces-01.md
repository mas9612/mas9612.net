---
title: "Linux Namespaces (1)"
date: 2019-02-18T23:24:23+09:00
draft: false
toc: true
images:
tags: 
  - linux
---

前回は chroot(2) について調査・テストしたので，今回はnamespacesについて勉強した．
少々長いので，2つの記事に分けて投稿する．

今回使った環境はDebian 9 Stretch．

```shell
$ uname -a
Linux debian 4.9.0-8-amd64 #1 SMP Debian 4.9.130-2 (2018-10-27) x86_64 GNU/Linux
```

## namespacesについて
namespacesは，Linuxが持つシステムリソースをプロセスごとに分離するための技術．
これを用いると，異なるnamespace間でネットワークやPID等の資源を独立して持つことができるようになる．

Linux namespacesでは，次の7つが提供されている．

* Cgroup namespace
* IPC namespaces
* Network namespaces
* Mount namespaces
* PID namespaces
* User namespaces
* UTS namespaces

それぞれのnamespacesについては以下の節で順番に説明していく．

## namespacesを使うためのシステムコール
新しいnamespaceを作成してそれを使用するには，次の2つのどちらかを使用する．

* clone(2)
    - 新しいプロセスを作成するとともに，引数に指定したフラグに対応する新しいnamespaceを作成し，新しいプロセスをそれに所属させる
* unshare(2)
    - システムコールを呼び出したプロセスを新しいnamespaceに移動させる．

また，プロセスを **既存の** namespaceに移動させるには，setns(2)システムコールを使用する．

User namespacesを除き，新しいnamespaceを作成するには特権（ `CAP_SYS_ADMIN` ）が必要となる．

## /proc/[pid]/nsディレクトリ
`/proc/[pid]/ns` ディレクトリ内には，そのプロセスが所属している各namespaceを表すエントリがおかれている．これらは，setns(2)システムコールで操作することができる．

例えば，すでに動作しているプロセスのnamespaceに入りたい場合は，次のようにすることで可能．

1. 入りたいnamespaceに所属しているプロセスのnsディレクトリ内にある適切なエントリ（e.g. Network namespacesなら `net` ）をオープン
1. オープンしたファイルディスクリプタをsetns(2)の引数に渡してあげる

## PID namespaces
比較的わかりやすいPID namespacesから順番に見ていく．

PID namespacesは，その名の通りPIDの空間を分離するために用いられる．
異なるPID namespace間では異なるプロセスツリーを持ち，それらはそれぞれ独立している．
そのため，異なるPID namespace間で同じPIDを持つ可能性もある．

unshare(2)システムコールを使って新しいPID namespaceを作成し，そこに子プロセスを所属させるという簡単なプログラムを使ってテストした．

プログラム全体は[GitHub](https://github.com/mas9612/study/blob/master/container/pid_namespace.c)にpushしている．

新しいPID namespaceを作成するためには，unshare(2)の引数に `CLONE_NEWPID` を指定する．
unshare(2)を呼び出した以降に作成した子プロセスは，新しいPID namespace内で実行される（新しいPID namespaceでは，PIDは1から順番に振られる）．

**unshare(2)を呼び出したプロセス自体は，これまでと同じPID namespaceで動作していることに注意**．
このため，サンプルプログラムではfork(2)を使って子プロセスを作成することで動作確認をしている．

```c
    ret = unshare(CLONE_NEWPID);
    if (ret == -1) {
        perror("unshare()");
        exit(1);
    }
```

サンプルプログラムを実行すると次のような実行結果が得られる．

```
$ gcc pid_namespaces.c
$ sudo ./a.out
PID: 5516
Forking new process...
  Child PID: 5517

Create new PID namespaces...
PID: 5516
Forking new process...
  Child PID: 1
```

この結果から次のことが読み取れる．

* unshare(2)を呼び出したプロセス自体（PID 5516）はPID namespaceの移動はしていない
* unshare(2)を呼び出す前の子プロセスはPID 5516と同じPID namespaceに所属しているので，PIDはその続き（PID 5517）となっている
* unshare(2)を呼び出した後の子プロセスは新しいPID namespaceに所属しているので，PIDは1となっている

## Network namespaces
次はNetwork namespacesについて見ていく．

名前の通りで理解しやすいと思うが，ネットワーク関連のリソースを分離するための技術．
ネットワークデバイスやIPプロトコルスタック，ルーティングテーブルやファイアウォールルール等をnamespaceごとで分離することができる．
各ネットワークデバイスは1つのnetwork namespacesのみに割り当てられる．

これも[サンプルプログラム](https://github.com/mas9612/study/blob/master/container/network_namespaces.c)を書いて試してみた．
サンプルでは， `ip a` コマンドを使ってネットワークデバイスの情報を出力してみた．

新しいnetwork namespaceに移動するには，unshare(2)の引数に `CLONE_NEWNET` を渡してあげれば良い．

```c
    ret = unshare(CLONE_NEWNET);
    if (ret == -1) {
        perror("unshare()");
        exit(1);
    }
```

サンプルプログラムを実行するとつぎのような実行結果が得られる．

```
$ gcc network_namespaces.c
$ sudo ./a.out
1: lo: <LOOPBACK,UP,LOWER_UP> mtu 65536 qdisc noqueue state UNKNOWN group default qlen 1
    link/loopback 00:00:00:00:00:00 brd 00:00:00:00:00:00
    inet 127.0.0.1/8 scope host lo
       valid_lft forever preferred_lft forever
    inet6 ::1/128 scope host
       valid_lft forever preferred_lft forever
2: enp0s3: <BROADCAST,MULTICAST,UP,LOWER_UP> mtu 1500 qdisc pfifo_fast state UP group default qlen 1000
    link/ether 08:00:27:ad:47:43 brd ff:ff:ff:ff:ff:ff
    inet 10.0.2.15/24 brd 10.0.2.255 scope global enp0s3
       valid_lft forever preferred_lft forever
    inet6 fe80::a00:27ff:fead:4743/64 scope link
       valid_lft forever preferred_lft forever
3: enp0s8: <BROADCAST,MULTICAST,UP,LOWER_UP> mtu 1500 qdisc pfifo_fast state UP group default qlen 1000
    link/ether 08:00:27:75:06:24 brd ff:ff:ff:ff:ff:ff
    inet 192.168.56.80/24 brd 192.168.56.255 scope global enp0s8
       valid_lft forever preferred_lft forever
    inet6 fe80::a00:27ff:fe75:624/64 scope link
       valid_lft forever preferred_lft forever

Enter new network namespace:
1: lo: <LOOPBACK> mtu 65536 qdisc noop state DOWN group default qlen 1
    link/loopback 00:00:00:00:00:00 brd 00:00:00:00:00:00
```

実行結果から，network namespaceを移動した後の `ip a` では，ループバックデバイス以外のネットワークデバイスが割り当てられていないことがわかる．
ネットワークデバイスは一度に1つのnetwork namespaceにしか所属できないので，新しいnetwork namespaceに移動した後の `ip a` の出力には現れなかった．

## UTS namespaces
UTS namespacesは，ホスト名およびNISドメイン名をnamespaceごとに分離するための技術．
これを用いると，各UTS namespaceごとにそれぞれ個別のホスト名をつけることができる．

プログラムを書いて検証するのが少し面倒なので，unshare(1)コマンドで試す．

```shell
$ hostname
debian
$ sudo unshare --uts
[sudo] password for yamazaki:

# hostname
debian
# hostname inside-uts-namespace
# hostname
inside-uts-namespace
# exit
logout

$ hostname
debian
```

`unshare --uts` コマンドで，新しいUTS namespaceを作成してそれに移動することができる．
その後， `hostname` コマンドを使って適当なホスト名をセットしてみる．

正常にホスト名が変更できたことを確認して，作成したUTS namespaceからexitで抜ける．
抜けた後にもう一度ホスト名を確認してみると，UTS namespace内で行った変更が反映されておらず，namespaceごとで独立していたことがわかる．

## References
* namespaces(7)
* unshare(2)
* setns(2)
* pid_namespaces(7)
* network_namespaces(7)
