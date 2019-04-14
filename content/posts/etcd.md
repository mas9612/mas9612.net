---
title: "etcd入門"
date: 2018-10-27T00:00:00+09:00
draft: false
type: post
---

Kubernetesにも採用されている分散型KVSについて，何回かに分けて勉強していく．
今回のモチベーションとして，Kubernetesのアーキテクチャを詳しく勉強したい，Terraformのstate保存をローカルではなくetcdにしたいという2つがある．

まず，インストールとクラスタの作成について見ていく．

## インストール
クラスタ作成のためには，まずetcd本体のバイナリが必要になる．
[GitHubのreleaseページ](https://github.com/etcd-io/etcd/releases)から，自分のOSにあったバイナリをダウンロードしてくる．

```shell
$ curl -LO https://github.com/etcd-io/etcd/releases/download/v3.3.10/etcd-v3.3.10-linux-amd64.tar.gz
```

ダウンロードしたファイルは圧縮されており，それを解凍するといくつかのファイルの中に2つのバイナリが確認できる．
```shell
$ tar xzf etcd-v3.3.10-linux-amd64.tar.gz
$ cd etcd-v3.3.10-linux-amd64.tar.gz
$ ll etcd*
-rwxr-xr-x. 1 yamazaki yamazaki 19237536 Oct 11  2018 etcd
-rwxr-xr-x. 1 yamazaki yamazaki 15817472 Oct 11  2018 etcdctl
```

`etcd` はetcd本体， `etcdctl` はetcdのクライアントとなるプログラム．
これら2つをPATHが通っている場所に置いてあげる．
```shell
$ sudo mv etcd* /usr/local/bin/
$ ll /usr/local/bin/etcd*
-rwxr-xr-x. 1 yamazaki yamazaki 19237536 Oct 11  2018 /usr/local/bin/etcd
-rwxr-xr-x. 1 yamazaki yamazaki 15817472 Oct 11  2018 /usr/local/bin/etcdctl
```

これでインストールは完了．
きちんとインストールされているか一応確認する．
```shell
$ etcd --version
etcd Version: 3.3.10
Git SHA: 27fc7e2
Go Version: go1.10.4
Go OS/Arch: linux/amd64
```

## クラスタの作成
まず，1台のみでetcdクラスタを作成して簡単に使い方を把握し，その後複数メンバでのetcdクラスタを作成していく．

### 1台のetcdクラスタ作成
基本的に[GitHubに書いてある手順](https://github.com/etcd-io/etcd#running-etcd)通りに試していく．

1台のみでetcdクラスタを作成するときは，特に何も考えずに `etcd` コマンドを実行する．
```shell
$ etcd
```

`etcd` コマンドを実行すると，多くのログが出力される．
ここで，作成したetcdクラスタを使って，データの登録と取得を試してみる．

etcdクラスタとのやり取りには， `etcdctl` コマンドを使用する．
`etcd` コマンドを実行しているシェルとは別にもう1つシェルを起動し，そこで `etcdctl` コマンドを使用していく．
なお，etcd APIにはバージョンがいくつかあるが，今回はバージョン3を使用する．
**`etcdctl` を普通に使うとv2 APIが使われてしまうので，v3 APIを使うために `ETCDCTL_API` という環境変数の値を `3` に設定する必要があることに注意する．**
公式のREADMEのように `etcdctl` コマンドを実行するごとに毎回 `ETCDCTL_API` を指定してもよいが，毎回記述するのも面倒なのであらかじめexportしておく．
```shell
$ export ETCDCTL_API=3
```

etcdクラスタにデータを登録するには，putコマンドを使用する．
```shell
# Usage
$ etcdctl put <key> <value>

$ etcdctl put mykey "this is awesome"
OK
```

putコマンドを実行して， `OK` と表示されれば成功している．

登録した値を取得するにはgetコマンドを使用する．
```shell
# Usage
$ etcdctl get <key>

$ etcdctl get mykey
mykey
this is awesome
```

指定したキーの名前とデータが続けて出力されれば成功．

次に，複数台のetcdクラスタを作成してみる．
その前に，今使っていたetcdクラスタを停止させておく．
`etcd` コマンドを実行していたシェルに戻り，Ctrl-Cで終了する．

### 複数メンバでのetcdクラスタ作成
今回は1つのノードの中にetcdを複数立ち上げることで，複数メンバで構成されるetcdクラスタを作成する．
もちろん，複数のノードを使ってノード1台につきetcdを1つ動作させるという形で作成することもできる．

公式には，etcdはTCP 2379番・2380番のポートを使用する．

* 2379/tcp: クライアントとの通信
* 2380/tcp: etcdメンバ間の通信

今回は同じノード内に複数etcdを立ち上げるため，それぞれのetcdでポートが競合しないようにしておく．
今回は3つのetcdメンバを動作させ，それぞれの名前，ポートは次の表のようにした．

| メンバ | クライアント通信用 | メンバ間通信用 |
|:-------|-------------------:|---------------:|
| etcd1  | 2379               | 2380           |
| etcd2  | 12379              | 12380          |
| etcd3  | 22379              | 22380          |

実際に3つのetcdメンバを動かしていく．
ターミナルのウィンドウを3つ開いて，それぞれのターミナルにつき1つのetcdメンバを起動する．
それぞれのターミナルで，次のようなコマンドを実行する．

1つ目のターミナル
```shell
$ etcd --name etcd1 \
    --initial-advertise-peer-urls http://localhost:2380 \
    --listen-peer-urls http://localhost:2380 \
    --advertise-client-urls http://localhost:2379 \
    --listen-client-urls http://localhost:2379 \
    --initial-cluster etcd1=http://localhost:2380,etcd2=http://localhost:12380,etcd3=http://localhost:22380 \
    --initial-cluster-state new \
    --initial-cluster-token etcd-cluster-1
```

2つ目のターミナル
```shell
$ etcd --name etcd2 \
    --initial-advertise-peer-urls http://localhost:12380 \
    --listen-peer-urls http://localhost:12380 \
    --advertise-client-urls http://localhost:12379 \
    --listen-client-urls http://localhost:12379 \
    --initial-cluster etcd1=http://localhost:2380,etcd2=http://localhost:12380,etcd3=http://localhost:22380 \
    --initial-cluster-state new \
    --initial-cluster-token etcd-cluster-1
```

3つ目のターミナル
```shell
$ etcd --name etcd3 \
    --initial-advertise-peer-urls http://localhost:22380 \
    --listen-peer-urls http://localhost:22380 \
    --advertise-client-urls http://localhost:22379 \
    --listen-client-urls http://localhost:22379 \
    --initial-cluster etcd=http://localhost:2380,etcd2=http://localhost:12380,etcd3=http://localhost:22380 \
    --initial-cluster-state new \
    --initial-cluster-token etcd-cluster-1
```

正しくコマンドを入力できていれば，正常にetcdクラスタが起動しているはず．
出力されるログでエラー等が出ていなければひとまずOK．

コマンドラインオプションをたくさん使っているので複雑に見えるが，一度理解してしまうとそこまで難しくはないと思う．
今回指定しているコマンドラインオプションは，大きく分けて次の2つに分かれている．

* 新しいクラスタを作成するときに使用するもの（[Clustering flags](https://github.com/etcd-io/etcd/blob/master/Documentation/op-guide/configuration.md#clustering-flags)）
* 他のメンバやクライアントとの通信や，etcdの設定に関するもの（[Member flags](https://github.com/etcd-io/etcd/blob/master/Documentation/op-guide/configuration.md#member-flags)）

Clustering flagsでは，新しいクラスタを一から作成するときに必要となる情報を指定する．
今回使用したものは次の通り．

| flags                           | description                                                                                                  |
|:--------------------------------|:-------------------------------------------------------------------------------------------------------------|
| `--initial-advertise-peer-urls` | クラスタ内の他のetcdメンバからの通信を受け付けるURLを指定する                                                |
| `--advertise-client-urls`       | クライアントからの通信を受け付けるURLを指定する                                                              |
| `--initial-cluster`             | クラスタを構成するetcdメンバの情報をカンマ区切りで指定する                                                   |
| `--initial-cluster-state`       | 新しいクラスタを作成する場合は `new` を指定する                                                              |
| `--initial-cluster-token`       | クラスタ作成中に用いられるトークン．複数クラスタを管理している際，意図せず別のクラスタに影響を与えるのを防ぐ |

Member flagsでは，作成するメンバに関する情報等の設定ができる．
今回使用したものは次の通り．

| flags                  | description                                                   |
|:-----------------------|:--------------------------------------------------------------|
| `--name`               | メンバ名                                                      |
| `--listen-peer-urls`   | クラスタ内の他のetcdメンバからの通信を受け付けるURLを指定する |
| `--listen-client-urls` | クライアントからの通信を受け付けるURLを指定する               |

注意点として， `--initial-cluster` で指定しているメンバ情報は， `--name` と `--listen-peer-urls` で指定した名前とURLに一致させなければならない．
もし一致していないと，クラスタ起動時にエラーとなる．

次のコマンドで，きちんと3つのメンバが表示されたら成功．

```shell
$ etcdctl member list
29727fd1bdf9fb62, started, etcd1, http://localhost:2380, http://localhost:2379
44dd3cd8faa339d0, started, etcd3, http://localhost:22380, http://localhost:22379
b59b01c27098773e, started, etcd2, http://localhost:12380, http://localhost:12379
```

次は，作成したクラスタを使ってもう少しetcdctlの使い方を勉強し，その後TLSの設定やDiscoveryを使ったクラスタ作成，無停止でのメンバアップグレード等について勉強していく予定．
