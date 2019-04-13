---
title: "Linuxのプロセスについて"
date: 2019-04-13T22:38:11+09:00
draft: false
toc: true
images:
tags: 
  - linux
---

## プロセスとは
一般的に，プロセスはプログラムの実行時におけるインスタンスであると定義されている．

> プロセスとは、情報処理においてプログラムの動作中のインスタンスを意味し、プログラムのコードおよび全ての変数やその他の状態を含む

[プロセス - Wikipedia](https://ja.wikipedia.org/wiki/%E3%83%97%E3%83%AD%E3%82%BB%E3%82%B9)より

同じプログラムを複数起動した場合でも，それらはそれぞれ異なるプロセスとして動作する．
例えば，2人のユーザがそれぞれvimを起動すると，プログラム自体は同じだがプロセスは2つ作成されている（もちろん，1人のユーザがvimを2つ起動した場合も同様に2つのプロセスが作成される）．

すべてのプロセスは親となるプロセス（親プロセス）を持っており[^1]，サーバ上に存在するプロセスは木構造として捉えることもできる．
親プロセスで作成された新しいプロセス（子プロセス）は，親プロセスのメモリの複製を持ち[^2]，同じプログラムコードを実行するので，2つはほとんど同じ状態と言える．
しかし，子プロセスは親プロセスとは別のメモリ空間を持つため，子プロセス内でのメモリ内容の変更は親プロセス側では知ることができない．

プロセスと似ている概念としてスレッドというものもあるが，スレッドの場合はメモリ空間を始めとしていくつかのリソースをスレッド間で共有している点がプロセスと異なっている．

[^1]: 一番始めに生成されるプロセスは親を持たない（PID 0のプロセス．swapperプロセスと呼ばれる）．
[^2]: 実際には，子プロセス作成時にメモリ空間の複製が行われるわけではなく，子プロセス作成直後は親プロセスと同じメモリ空間を参照している．子プロセス側でメモリの内容を変更しようとした際に初めて複製が行われる（Copy On Write）．

## プロセスの一生
動かすプログラムによってプロセスが動作する時間は異なるが，基本的な流れは全プロセスで共通している．
ここでは，bashから実行されるlsコマンドを例にとってみると，大まかな流れは次のようになる．

1. bashに `ls` と入力してlsコマンドを実行する
1. bashが fork システムコールを使って子プロセスを作成する
    - ここで作成された子プロセスは，親プロセスと同じbashのプログラムコードを実行している
1. 子プロセス側で execve システムコールを使い，lsコマンドの実行を開始する
    - 実行するプログラムコードがbashからlsコマンドに置き換えられる
1. lsコマンドが実行されることにより，カレントディレクトリの一覧が表示される
1. lsコマンドを実行していたプロセスが終了する

### プロセスの状態

Linuxでは，各プロセスにそれぞれ state と呼ばれる値が設定されており，それがプロセスの状態を表している．
stateの値を見ることで，そのプロセスが実行中なのか，何らかの待ち状態に入っているのか等を知ることができる．

stateの値は幾つか種類があるが，ここではその一部について説明する．
stateは， `linux/sched.h` にて定義されている．
```c
#define TASK_RUNNING			0x0000
#define TASK_INTERRUPTIBLE		0x0001
#define TASK_UNINTERRUPTIBLE		0x0002
```

それぞれ，プロセスが現在次のような状態であることを表している．

* `TASK_RUNNING` : プロセスが実行中もしくは実行待ちの状態
* `TASK_INTERRUPTIBLE` : プロセスが一時休止している状態
* `TASK_UNINTERRUPTIBLE` :  プロセスが一時休止している状態． `TASK_INTERRUPTIBLE` とは違い，プロセスにシグナルが届いてもそのハンドラはすぐに実行されずに保留となる．デバイスドライバでよく使われる．

現在動いているプロセスのstateは，psコマンドで確認することができる．psコマンドを引数無しで実行した場合はstateが表示されないが， `a` 等のオプションを付けるとstateが表示されるようになる．
```sh
$ ps a
  PID TTY      STAT   TIME COMMAND
  444 tty1     Ss+    0:00 /sbin/agetty --noclear tty1 linux
25878 pts/0    Ss     0:00 -bash
25887 pts/0    S+     0:00 man ps
25897 pts/0    S+     0:00 pager
25912 pts/1    Ss     0:00 -bash
25930 pts/1    R+     0:00 ps a
```

psコマンドの結果の中で， `STAT` の列がstateを表している．それぞれの意味は，psコマンドのマニュアルの中の `PROCESS STATE CODES` に説明がある．

* `R` : `TASK_RUNNING`
* `S` : `TASK_INTERRUPTIBLE`
* `D` : `TASK_UNINTERRUPTIBLE`

psコマンドの出力には `R` や `S` といった文字の他に `s` や `+` がついているが，ここでは保留としておく．

## プロセスの管理
### プロセスディスクリプタ
Linuxカーネルは，プロセスディスクリプタというものを使ってプロセスを管理している．プロセスディスクリプタは， `task_struct` 構造体というデータ構造に保存されている．
`task_struct` 構造体は `linux/sched.h` で定義されている．

```c
struct task_struct {
#ifdef CONFIG_THREAD_INFO_IN_TASK
	/*
	 * For reasons of header soup (see current_thread_info()), this
	 * must be the first element of task_struct.
	 */
	struct thread_info		thread_info;
#endif
	/* -1 unrunnable, 0 runnable, >0 stopped: */
	volatile long			state;

/* （省略...） */
```

前節で説明したstateは，task_struct構造体のなかの `state` メンバに保存されている．
```c
	volatile long			state;
```

### プロセスID
Linuxカーネルは各プロセスを識別するためにプロセスディスクリプタのアドレスを使用しているが，ユーザはプロセスID（PID）を使ってプロセスを識別することができる．
PIDも，プロセスディスクリプタのpidメンバに保存されている．
```c
struct task_struct {

/* （省略...） */
	pid_t				pid;
```

PIDは1から始まり，新しいプロセスが生成されるごとに1ずつ増加していく．この値は上限が決まっており，sysctlコマンドもしくは `/proc/sys/kernel/pid_max` の内容を表示すれば知ることができる．
```sh
$ sysctl kernel.pid_max
kernel.pid_max = 32768

$ cat /proc/sys/kernel/pid_max
32768
```

PIDが上限に達したら，使われていないPIDを再利用することになる．

### プロセスの親子関係
先に説明したとおり，プロセスには親子関係が存在する．
プロセスディスクリプタには，親プロセスや子プロセスの情報を格納しておくメンバが存在している．
```c
struct task_struct {

/* （省略...） */
	/* Recipient of SIGCHLD, wait4() reports: */
	struct task_struct __rcu	*parent;

	/*
	 * Children/sibling form the list of natural children:
	 */
	struct list_head		children;
```

`parent` には親プロセスのプロセスディスクリプタへのポインタ， `children` には子プロセスの双方向リストへのポインタが格納される．

ここで `children` の型として使用されている `list_head` 構造体について少し掘り下げてみる．
`list_head` 構造体は `linux/types.h` で次のように定義されている．
```c
struct list_head {
	struct list_head *next, *prev;
};
```

定義からわかるように，この構造体は一つ前の要素・一つあとの要素へのポインタをそれぞれ持ち，それ以外のデータは何も持っていない．
そのため，この構造体だけでは何かしらのデータを保持することができない．

通常の連結リストとは異なり，この構造体を使って連結リストを作るときは， `task_struct` 構造体の `children` のように，データを保持する構造体の中に `list_head` 構造体を埋め込むという形で実装していく．
しかし， `list_head` 構造体のアドレスが得られても，それを埋め込んでいる本来の構造体（＝データを保持している構造体）へアクセスできなければ意味がない．
そのため， `list_head` 構造体で実現された連結リストを操作するために，いくつかのマクロが定義されている．

## References
* 詳解LINUXカーネル 第3版
* [プロセス - Wikipedia](https://ja.wikipedia.org/wiki/%E3%83%97%E3%83%AD%E3%82%BB%E3%82%B9)
* [Understanding Linux Process States](https://access.redhat.com/sites/default/files/attachments/processstates_20120831.pdf)
