---
title: "Linuxのロードアベレージについて"
date: 2019-04-02T22:26:20+09:00
draft: false
type: post
toc: true
images:
tags: 
  - linux
---

Linuxを使ってサーバ運用をしていると，ロードアベレージという単語をよく聞くかと思う．
ふわっとした認識しかなかったので，改めて調査してみた．

## ロードアベレージとは
Linuxの負荷を表す指標の一つ．現在の実行待ちプロセス数の平均と説明されていることが多い．

## ロードアベレージを知る方法
ロードアベレージはいくつかの方法で知ることができる．

### uptimeコマンド
uptimeコマンドを使うと，システムの稼働時間と同時にロードアベレージが報告される．
ロードアベレージの値は3つ表示され，左から順番に1分，5分，15分の平均を表している．

```sh
$ uptime
 23:37:07 up 5 days, 18:41,  1 user,  load average: 0.00, 0.00, 0.00
```

### wコマンド
wコマンドは，現在システムにログインしているユーザが表示される．
それと同時に，1行目にuptimeコマンドと同様の内容が出力される．

```sh
$ w
 23:37:23 up 5 days, 18:41,  1 user,  load average: 0.00, 0.00, 0.00
USER     TTY      FROM             LOGIN@   IDLE   JCPU   PCPU WHAT
yamazaki pts/0    192.168.56.1     23:17    1.00s  0.04s  0.00s w
```

### topコマンド
topコマンドを使うと，現在動いているプロセスの内容が表示される．
それに加え，ロードアベレージの値が1行目に表示される．

```sh
$ top | head
top - 23:37:37 up 5 days, 18:41,  1 user,  load average: 0.00, 0.00, 0.00
Tasks:  67 total,   1 running,  66 sleeping,   0 stopped,   0 zombie
%Cpu(s):  0.0 us,  0.0 sy,  0.0 ni,100.0 id,  0.0 wa,  0.0 hi,  0.0 si,  0.0 st
KiB Mem :  1020332 total,   114692 free,    64304 used,   841336 buff/cache
KiB Swap:  1046524 total,  1046524 free,        0 used.   762628 avail Mem

  PID USER      PR  NI    VIRT    RES    SHR S %CPU %MEM     TIME+ COMMAND
    1 root      20   0   57104   6868   5276 S  0.0  0.7   0:03.66 systemd
    2 root      20   0       0      0      0 S  0.0  0.0   0:00.04 kthreadd
    3 root      20   0       0      0      0 S  0.0  0.0   0:01.32 ksoftirqd/0
```

### /proc/loadavg
`/proc/loadavg` には，ロードアベレージの値と現在のプロセス数，最後に使用したPIDが記録されている．

```sh
$ cat /proc/loadavg
0.00 0.00 0.00 1/73 21068
```

## ロードアベレージの算出方法
それでは，実際にロードアベレージがどのような値を元に算出されているのかを調べていく．
今回は，Linuxカーネル v4.20 のソースコードを使って調査している．

### 実行待ちプロセス
ロードアベレージを計算する時に使われる **現在の実行待ちプロセス数** は，現在存在しているプロセスの中で， `TASK_RUNNING` もしくは `TASK_UNINTERRUPTIBLE` と呼ばれる状態のプロセス数を数えたものとなる．

`TASK_RUNNING` 等，プロセスの状態を表す定数は `include/linux/sched.h` で定義されている．

```c
/* Used in tsk->state: */
#define TASK_RUNNING            0x0000
#define TASK_INTERRUPTIBLE        0x0001
#define TASK_UNINTERRUPTIBLE        0x0002
...
```

それぞれの状態がどういう意味を表しているのかは，ps(1)のマニュアルの `PROCESS STATE CODES` で説明されている．

* `TASK_RUNNING` : プロセスが実行中もしくは実行可能な状態
* `TASK_UNINTERRUPTIBLE` : 割り込み不可能なスリープ状態（IO待ち等）

psコマンドの出力を見ると， `STAT` の列に各プロセスの状態が示されているのがわかる．ここが `R` の場合は `TASK_RUNNING` ， `D` の場合は `TASK_UNINTERRUPTIBLE` 状態である．
```sh
$ ps aux | head
USER       PID %CPU %MEM    VSZ   RSS TTY      STAT START   TIME COMMAND
root         1  0.0  0.6  57104  6868 ?        Ss   Mar27   0:03 /sbin/init
root         2  0.0  0.0      0     0 ?        S    Mar27   0:00 [kthreadd]
root         3  0.0  0.0      0     0 ?        S    Mar27   0:01 [ksoftirqd/0]
root         5  0.0  0.0      0     0 ?        S<   Mar27   0:00 [kworker/0:0H]
root         7  0.0  0.0      0     0 ?        S    Mar27   1:16 [rcu_sched]
root         8  0.0  0.0      0     0 ?        S    Mar27   0:00 [rcu_bh]
root         9  0.0  0.0      0     0 ?        S    Mar27   0:00 [migration/0]
root        10  0.0  0.0      0     0 ?        S<   Mar27   0:00 [lru-add-drain]
root        11  0.0  0.0      0     0 ?        S    Mar27   0:01 [watchdog/0]
```

これら2つの状態にあるプロセス数をカウントし，それを元にしてロードアベレージを計算していく．
このプロセス数は `kernel/sched/loadavg.c` で宣言されている `calc_load_tasks` 変数で管理されており，定期的に呼び出される `calc_global_load_tick()` 関数で更新される．

```c
atomic_long_t calc_load_tasks;

/*
 * Called from scheduler_tick() to periodically update this CPU's
 * active count.
 */
void calc_global_load_tick(struct rq *this_rq)
{
    long delta;

    if (time_before(jiffies, this_rq->calc_load_update))
        return;

    /* 前回の計測と差分があれば，その差分をcalc_load_tasksに適用 */
    delta  = calc_load_fold_active(this_rq, 0);
    if (delta)
        atomic_long_add(delta, &calc_load_tasks);

    this_rq->calc_load_update += LOAD_FREQ;
}
```

実際のプロセス数のカウントは `calc_global_load_tick()` 関数内部で呼び出されている `calc_load_fold_active()` 関数で行われている．
この関数では，前回カウントしたときのプロセス数と今回のカウント数を比較し，異なっていればその差分を返却するという実装となっている．

```c
long calc_load_fold_active(struct rq *this_rq, long adjust)
{
    long nr_active, delta = 0;

    /* TASK_RUNNINGとTASK_UNINTERRUPTIBLEのプロセス数をカウントし，nr_activeに保存 */
    nr_active = this_rq->nr_running - adjust;
    nr_active += (long)this_rq->nr_uninterruptible;

    /* 前回の計測結果と異なっていれば，差分をdeltaに保存 */
    if (nr_active != this_rq->calc_load_active) {
        delta = nr_active - this_rq->calc_load_active;
        this_rq->calc_load_active = nr_active;
    }

    return delta;
}
```

### ロードアベレージの計算
実行待ちプロセス数がどのようにカウントされるのかがわかったので，実際のロードアベレージの計算方法について見ていく．
Linuxカーネルでは，ロードアベレージは `kernel/sched/loadavg.c` で宣言されている `avenrun` 配列に保存される．

```c
unsigned long avenrun[3];
```

この配列は，タイマーによって定期的に呼び出されている `kernel/sched/loadavg.c` の `calc_global_load()` 関数で更新される．

```c
void calc_global_load(unsigned long ticks)
{
    unsigned long sample_window;
    long active, delta;

    ...

    /* 実行待ちプロセス数ををcalc_load_tasksから読み出す */
    active = atomic_long_read(&calc_load_tasks);
    active = active > 0 ? active * FIXED_1 : 0;

    /* 1，5，15分ごとのロードアベレージをそれぞれ計算する */
    avenrun[0] = calc_load(avenrun[0], EXP_1, active);
    avenrun[1] = calc_load(avenrun[1], EXP_5, active);
    avenrun[2] = calc_load(avenrun[2], EXP_15, active);

    ...
}
```

この関数を見ると，実際の計算は `calc_load()` 関数で行っていることがわかる． `calc_load()` 関数は `include/linux/sched/loadavg.h` で定義されている．

```c
/*
 * a1 = a0 * e + a * (1 - e)
 */
static inline unsigned long
calc_load(unsigned long load, unsigned long exp, unsigned long active)
{
    unsigned long newload;

    /* load: 前回計算したloadavgの値 */
    newload = load * exp + active * (FIXED_1 - exp);
    if (active >= load)
        newload += FIXED_1-1;

    return newload / FIXED_1;
}
```

ここで，いくつか出てきた定数について整理しておく． `calc_global_load()` ， `calc_load()` で出てきた定数はいずれも `include/linux/sched/loadavg.h` で次のように定義されている．

```c
#define FSHIFT		11		/* nr of bits of precision */
#define FIXED_1		(1<<FSHIFT)	/* 1.0 as fixed-point */
#define EXP_1		1884		/* 1/exp(5sec/1min) as fixed-point */
#define EXP_5		2014		/* 1/exp(5sec/5min) */
#define EXP_15		2037		/* 1/exp(5sec/15min) */
```

コメントを見ると， `FIXED_1` は `1` を固定小数点で表現しているものだとわかる．そして `EXP_*` は，それぞれ $e^{\frac{5}{60}}$ ， $e^{\frac{5}{300}}$ ， $e^{\frac{5}{900}}$ の固定小数点表現であることがわかる．

それでは `calc_load()` に戻って，ロードアベレージを計算している箇所を見てみる．
新しいロードアベレージは， `calc_load()` の次の行で計算されている．

```c
    newload = load * exp + active * (FIXED_1 - exp);
```

これは[指数移動平均](https://ja.wikipedia.org/wiki/%E7%A7%BB%E5%8B%95%E5%B9%B3%E5%9D%87#%E6%8C%87%E6%95%B0%E7%A7%BB%E5%8B%95%E5%B9%B3%E5%9D%87)と呼ばれ，最近のデータを重視して古いデータを完全に切り捨てないという特徴を持つ平均のとり方らしい．

このようにして計算された値が，ロードアベレージとして普段目にするものになるようだ．
