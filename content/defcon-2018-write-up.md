---
title: "DEFCON 2018 Write Up"
date: 2018-05-17T00:00:00+09:00
draft: true
---

Welcome問1つだけしか解けなかった．

## ELF Crumble
問題文より，ELFバイナリがいくつかに分割されていると推測できる．
与えられた圧縮ファイルを解凍すると，次のようなファイル群がある．

    $ ls -l
    total 80
    -rwxr-xr-x@ 1 MasatoYamazaki  staff  7500  5  2 05:37 broken
    -rw-r--r--@ 1 MasatoYamazaki  staff    79  5  2 05:42 fragment_1.dat
    -rw-r--r--@ 1 MasatoYamazaki  staff    48  5  2 05:46 fragment_2.dat
    -rw-r--r--@ 1 MasatoYamazaki  staff   175  5  2 05:47 fragment_3.dat
    -rw-r--r--@ 1 MasatoYamazaki  staff    42  5  2 05:48 fragment_4.dat
    -rw-r--r--@ 1 MasatoYamazaki  staff   128  5  2 05:56 fragment_5.dat
    -rw-r--r--@ 1 MasatoYamazaki  staff    22  5  2 05:56 fragment_6.dat
    -rw-r--r--@ 1 MasatoYamazaki  staff   283  5  2 06:00 fragment_7.dat
    -rw-r--r--@ 1 MasatoYamazaki  staff    30  5  2 06:00 fragment_8.dat

また， `broken` の中身を見てみると， `X` が大量に続いているところがあるのが確認できる．

    $ xxd broken | less
    ...
    000005a0: 5589 e55d e957 ffff ff8b 1424 c358 5858  U..].W.....$.XXX
    000005b0: 5858 5858 5858 5858 5858 5858 5858 5858  XXXXXXXXXXXXXXXX
    000005c0: 5858 5858 5858 5858 5858 5858 5858 5858  XXXXXXXXXXXXXXXX
    000005d0: 5858 5858 5858 5858 5858 5858 5858 5858  XXXXXXXXXXXXXXXX
    000005e0: 5858 5858 5858 5858 5858 5858 5858 5858  XXXXXXXXXXXXXXXX
    ...

続いている `X` の長さは `807` ， `fragment_*.dat` の総バイト数も `807` である．

    $ strings broken | grep XXX | wc -c
    808     # 最後の改行文字がカウントされているので1多い
    $ ll fragment* | awk '{sum+=print$5} END {print sum}'
    807

これより， `broken` 中にある `X` の部分を取り出して分割したものが `fragment_*.dat` であると考えられる．

というわけで，単純に結合してみる．

    $ dd if=broken bs=1 count=1453 of=head.bin  # XXXまでを取り出し
    $ dd bs=1 if=broken skip=2260 of=tail.bin   # XXXより後を取り出し
    $ cat head.bin fragment* tail.bin > restored
    $ chmod 755 restored
    $ ./restored
    Segmentation fault (core dumped)

だめだった．おそらく，結合する順番がおかしい．

ここで，結合する組み合わせが何通りあるかを考える．
分割されたバイナリは全部で8個あり，それぞれの順番も考慮する必要があるということから， `8! = 40320` 通りであることがわかる．
この程度なら全部試してもそこまで時間がかからないはずなので，総当りで試してみる．

    # -*- coding: utf-8 -*-

    import itertools


    with open('head.bin', 'rb') as f:
        header = f.read()

    with open('tail.bin', 'rb') as f:
        footer = f.read()

    filename = 'fragment_%d.dat'
    permutations = itertools.permutations(range(1, 9))

    count = 0
    for permutation in permutations:
        output = 'binaries/binary%05d' % count
        with open(output, 'wb') as wf:
            wf.write(header)

            for i in permutation:
                with open(filename % i, 'rb') as rf:
                    data = rf.read()
                wf.write(data)

            wf.write(footer)

        count += 1

このプログラムを実行すると， `binaries` ディレクトリ以下に結合されたバイナリが格納される．
あとは，これらに実行権限を付与して実行してあげれば，どれかのバイナリがフラグを出力してくれるはず．

    $ chmod 755 binaries/*
    $ cd binaries
    $ for file in `ls`; do $file >> output.txt; done
    $ cat output.txt
    welcOOOme
