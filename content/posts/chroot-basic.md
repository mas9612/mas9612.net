---
title: "chrootの基礎"
date: 2019-02-12T00:40:00+09:00
draft: false
toc: true
images:
tags: 
  - linux
  - chroot
  - container
---

DockerやKubernetesといったコンテナ関連の技術にはよくお世話になっているが，コンテナの実装やそれを実現している技術については深く知らなかった．
しかし，詳細を知らないまま使い続けるのは少し気持ち悪いので，少しずつ勉強していくことにする．

今回はまず手始めに，chrootについて勉強した．

## chrootとは
chroot (change root) とは，名前の通り呼び出したプロセスのルートディレクトリを変更することができる仕組みのこと．

> chroot() changes the root directory of the calling process to that specified in path

chroot(2) より引用

chrootによって変更されたルートディレクトリは，fork等で生成された子プロセスにも引き継がれる．

## chrootの使い方
chrootは， `chroot` コマンドを使ってコマンドラインで使用する方法と，chroot(2)システムコールを使ってプログラムから呼び出す方法がある．
以降，2つの方法について順番に説明する．

### chrootコマンドを使う
chrootコマンドの使い方は以下の通り．
```shell
$ chroot [OPTION] NEWROOT [COMMAND [ARG]...]
```

`chroot` の後に，新しいルートディレクトリとして設定したいディレクトリを指定する．
また，その後に実行したいコマンドを指定することもできるが，これを省略すると `${SHELL} -i` が実行される．

ちなみに，rootユーザ（正確には `CAP_SYS_CHROOT` capabilityを持つユーザ）のみがこのコマンドを実行することができる．

試しに `chroot_test` ディレクトリを作成して，それを新しいルートディレクトリとしてbashを起動してみる．

```shell
$ mkdir chroot_test 
# 通常ユーザでは権限が足りずにエラーとなる
$ chroot chroot_test bash
chroot: cannot change root directory to chroot_test/: Operation not permitted

$ sudo chroot chroot_test bash
chroot: failed to run command ‘/bin/bash’: No such file or directory
```

`sudo` を使ってrootとして `chroot` を実行すると，権限の問題はなくなったがbashが見つからないというエラーになった．
chrootによってルートディレクトリが変更されると元々の `/bin` にはアクセスできなくなるので，chroot先にbashコマンドを用意してあげる必要がある．

```shell
$ mkdir chroot chroot_test/bin
$ cp `which bash` chroot_test/bin
$ sudo chroot chroot_test bash
chroot: failed to run command ‘/bin/bash’: No such file or directory

# lsコマンドの実行にはいくつか動的ライブラリが必要となるので，
# それもchroot先に用意してあげなければならない
$ ldd `which bash`
        linux-vdso.so.1 =>  (0x00007ffc956cb000)
        libselinux.so.1 => /lib64/libselinux.so.1 (0x00007fe3914d4000)
        libcap.so.2 => /lib64/libcap.so.2 (0x00007fe3912cf000)
        libacl.so.1 => /lib64/libacl.so.1 (0x00007fe3910c6000)
        libc.so.6 => /lib64/libc.so.6 (0x00007fe390cf9000)
        libpcre.so.1 => /lib64/libpcre.so.1 (0x00007fe390a97000)
        libdl.so.2 => /lib64/libdl.so.2 (0x00007fe390893000)
        /lib64/ld-linux-x86-64.so.2 (0x00007fe3916fb000)
        libattr.so.1 => /lib64/libattr.so.1 (0x00007fe39068e000)
        libpthread.so.0 => /lib64/libpthread.so.0 (0x00007fe390472000)
$ cp /lib64/libtinfo.so.5 /lib64/libdl.so.2 /lib64/libc.so.6    \
    /lib64/ld-linux-x86-64.so.2 chroot_test/lib64
$ sudo chroot chroot_test bash
bash-4.2# pwd
/
bash-4.2# ls
bash: ls: command not found
bash-4.2# exit
exit

$ cp `which ls` chroot_test/bin
$ cp /lib64/libselinux.so.1 /lib64/libcap.so.2 /lib64/libacl.so.1   \
    /lib64/libpcre.so.1 /lib64/libdl.so.2 /lib64/libattr.so.1       \
    /lib64/libpthread.so.0 chroot_test/lib64
$ sudo chroot chroot_test bash
bash-4.2# pwd
/
bash-4.2# ls
bin  lib64
bash-4.2# exit
exit
```

### chroot(2)システムコールを使う
chroot(2)システムコールは次のような関数となっている．

```c
#include <unistd.h>

int chroot(const char *path);
```

引数に新しいルートディレクトリとなるパスを指定する．
成功すると `0` ，失敗すると `-1` が返却されて `errno` が設定される．

[サンプルプログラム](https://github.com/mas9612/study/blob/master/container/chroot_basic.c)はGitHubにあります．

注意点として，chroot(2)を使っても，パスの解決方法が変わるだけでカレントディレクトリは変更されない．
なので，サンプルプログラムでは予めchroot先に移動してからchroot(2)を実行している．

もしchdir(2)なしでchroot(2)を実行すると，カレントディレクトリは変更されない．
この状態でgetcwd(2)を呼び出した場合，カレントディレクトリがルートディレクトリの外となるため，エラーとなってしまう．

```c
    ret = chdir(path);
    if (ret == -1) {
        perror("chdir()");
        exit(1);
    }
    ret = chroot(path);
    if (ret == -1) {
        perror("chroot()");
        exit(1);
    }

    if (getcwd(buf, sizeof(buf)) == NULL) {
        perror("getcwd()");
        exit(1);
    }
```

## chrootを抜け出す
前節で，chroot(2)を使ってもカレントディレクトリは変更されないということを述べた．
これを利用して，chroot(2)を使う権限があるプロセスがchrootの外に抜け出すことが可能になる．

ここではこれを試してみる．
プログラムの全体は[GitHub](https://github.com/mas9612/study/blob/master/container/chroot_escape.c)にあります．

やることは簡単で，つぎのような順番で処理を進めていく．

1. chrootによって設定されたルートディレクトリに移動
1. 適当なサブディレクトリを作成
1. 作成したサブディレクトリにchroot
1. 一つ上の階層に移動する

これで，元々のchrootされたルートディレクトリの一つ上に移動することができる．

プログラムにすると次のようになる．

```c
    // create foo directory and chroot to it
    ret = mkdir("foo", 0755);
    if (ret == -1) {
        perror("mkdir()");
        exit(1);
    }
    ret = chroot("foo");
    if (ret == -1) {
        perror("chroot()");
        exit(1);
    }


    // after chroot to foo directory, attempt to escape upper directory
    // than original chrooted directory (chroot_test directory)
    ret = chdir("..");
    if (ret == -1) {
        perror("chdir()");
        exit(1);
    }
```

chrootはパスの解決方法を変更しているだけであり，複数適用させることができない．
そのため，2回目のchroot(2)呼び出しを行うと前回のchrootで設定した効果はなくなり，新しいものだけが効力を持つ．

上の手順を進めると，作成したサブディレクトリにchrootした段階で，元々のchrootの効果はなくなる．
また，chrootはカレントディレクトリを変更しないという性質より，手順3. の時点ですでにルートディレクトリの外にいることになる．

この状態では上の階層への移動が可能なので，結果的に元々のchrootされたルートディレクトリより上に移動することが実現できる．

実は，このことはchroot(2)のマニュアルにも記されており，仕様通りのようだ．

> This call does not change the current working directory, so that after the call '.' can be outside the tree rooted at '/'.  In  particular,  the  supe‐
> ruser can escape from a "chroot jail" by doing:
>
>     mkdir foo; chroot foo; cd ..
