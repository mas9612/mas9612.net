---
title: "プロミスキャスモード（Promiscuous Mode）"
date: 2019-03-23T22:18:44+09:00
draft: false
type: post
toc: true
images:
tags: 
  - linux
  - network
---

通常，NIC（Network Interface Card）は自分宛て（=自分のMACアドレス宛）のフレームと，ブロードキャスト・マルチキャストのフレームのみをCPUに渡す．
それ以外のフレームの場合，CPUへの割り込みを行わずに破棄する．

しかし，プロミスキャスモードを有効にすると，宛先MACアドレスが自分宛てかどうかにかかわらず，すべてのフレームをCPUに渡すようになる．
この機能は，主にtcpdumpやWireshark等のパケットキャプチャを行うプログラムで使われている．

ここでは，プロミスキャスモードの設定について簡単にまとめる．

## 環境
Debian 9

```sh
$ uname -a
Linux debian 4.9.0-8-amd64 #1 SMP Debian 4.9.130-2 (2018-10-27) x86_64 GNU/Linux
$ cat /etc/*-release
PRETTY_NAME="Debian GNU/Linux 9 (stretch)"
NAME="Debian GNU/Linux"
VERSION_ID="9"
VERSION="9 (stretch)"
ID=debian
HOME_URL="https://www.debian.org/"
SUPPORT_URL="https://www.debian.org/support"
BUG_REPORT_URL="https://bugs.debian.org/"
```

## プロミスキャスモードの設定
プロミスキャスモードの設定は，コマンドを用いる方法とプログラムから設定する方法の2つがある．
それぞれの設定方法を見ていく．

### コマンドによる設定
`ip` コマンドと `ifconfig` 2種類が使えるが， `ifconfig` はすでに非推奨となっているため， `ip` コマンドを使った方法で行う．

`ip` コマンドを使ってプロミスキャスモードを有効にするには， `ip link set <device name> promisc on` と実行する．
なお，設定には特権が必要である．

```sh
$ ip a show enp0s8
3: enp0s8: <BROADCAST,MULTICAST,UP,LOWER_UP> mtu 1500 qdisc pfifo_fast state UP group default qlen 1000
    link/ether 08:00:27:75:06:24 brd ff:ff:ff:ff:ff:ff
    inet 192.168.56.80/24 brd 192.168.56.255 scope global enp0s8
       valid_lft forever preferred_lft forever
    inet6 fe80::a00:27ff:fe75:624/64 scope link
       valid_lft forever preferred_lft forever

$ ip link set enp0s8 promisc on
RTNETLINK answers: Operation not permitted
$ sudo ip link set enp0s8 promisc on

$ ip a show enp0s8
3: enp0s8: <BROADCAST,MULTICAST,PROMISC,UP,LOWER_UP> mtu 1500 qdisc pfifo_fast state UP group default qlen 1000
    link/ether 08:00:27:75:06:24 brd ff:ff:ff:ff:ff:ff
    inet 192.168.56.80/24 brd 192.168.56.255 scope global enp0s8
       valid_lft forever preferred_lft forever
    inet6 fe80::a00:27ff:fe75:624/64 scope link
       valid_lft forever preferred_lft forever
```

### プログラムによる設定
プログラムから設定するには，ioctl(2)で `SIOCSIFFLAGS` を使用する．
`ip` コマンドと同様，設定には特権が必要である．

サンプルプログラムは [study/promisc_sample.c at master · mas9612/study](https://github.com/mas9612/study/blob/master/networking/promiscuous_mode/promisc_sample.c) にあります．

実際にプロミスキャスモードを設定している部分は次の部分．
```c
    // set promiscuous mode
    memset(&ifr, 0, sizeof(ifr));
    strncpy(ifr.ifr_name, argv[1], IFNAMSIZ);
    ret = ioctl(soc, SIOCGIFFLAGS, &ifr);
    if (ret == -1) {
        perror("failed to get interface flag");
        close(soc);
        exit(EXIT_FAILURE);
    }
    ifr.ifr_flags |= IFF_PROMISC;
    ret = ioctl(soc, SIOCSIFFLAGS, &ifr);
    if (ret == -1) {
        perror("failed to set interface flag");
        close(soc);
        exit(EXIT_FAILURE);
    }
```

まず， `SIOCGIFFLAGS` で現在NICに設定されているフラグを取得して，それに `IFF_PROMISC` フラグを追加するという形で設定する．
プログラムをコンパイルし，実行してみるとうまく設定されていることが確認できる．

```sh
# ensure promisc mode is off before run program
$ sudo ip link set enp0s8 promisc off
$ ip a show enp0s8
3: enp0s8: <BROADCAST,MULTICAST,UP,LOWER_UP> mtu 1500 qdisc pfifo_fast state UP group default qlen 1000
    link/ether 08:00:27:75:06:24 brd ff:ff:ff:ff:ff:ff
    inet 192.168.56.80/24 brd 192.168.56.255 scope global enp0s8
       valid_lft forever preferred_lft forever
    inet6 fe80::a00:27ff:fe75:624/64 scope link
       valid_lft forever preferred_lft forever

$ gcc -Wall promisc_sample.c
$ ./a.out enp0s8
failed to create socket: Operation not permitted
$ sudo ./a.out enp0s8

$ ip a show enp0s8
3: enp0s8: <BROADCAST,MULTICAST,PROMISC,UP,LOWER_UP> mtu 1500 qdisc pfifo_fast state UP group default qlen 1000
    link/ether 08:00:27:75:06:24 brd ff:ff:ff:ff:ff:ff
    inet 192.168.56.80/24 brd 192.168.56.255 scope global enp0s8
       valid_lft forever preferred_lft forever
    inet6 fe80::a00:27ff:fe75:624/64 scope link
       valid_lft forever preferred_lft forever
```

## おわりに
今回は設定する方法のみをまとめたが，プロミスキャスモードを検出する方法もいくつかあるようなので，今後検証したい．

## References
* [Sniffers Basics and Detection](http://www.just.edu.jo/~tawalbeh/nyit/incs745/presentations/Sniffers.pdf)

