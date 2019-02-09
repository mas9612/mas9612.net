---
title: "Docker Engine API試用"
date: 2018-03-17T00:00:00+09:00
draft: false
---

前に少し気になっていたDocker Engine APiを使ってみたので，それについて．

特に複雑なことはせず，引数に与えたイメージを削除するというプログラムを作ってみた．
ただ単純に削除するだけではつまらないので，何世代分保存しておくか，というのをオプションで指定できるようにした．

コードは [mas9612/docker-tools/image-remove](https://github.com/mas9612/docker-tools/tree/master/image-remove) に置いてある．
あまりきれいなコードではないのでご注意ください．

`Client.ImageList()` メソッドでローカルにあるイメージの一覧が取得できるが， `filter` でイメージ名を指定できなさそうだったので，愚直にfor文で1つ1つ確認している．
アルゴリズムは得意ではないので，良い方法があれば教えてください…

    images, err := client.ImageList(ctx, types.ImageListOptions{})
    if err != nil {
        log.Fatalf("[ERROR] client.ImageList(): %s\n", err)
    }

    for _, image := range images {
        for _, repotag := range image.RepoTags {
            repository := strings.Split(repotag, ":")
            if repository[0] == *imageName {
                imageInfos = append(imageInfos, imageInfo{
                    ID:      image.ID,
                    Created: image.Created,
                    Name:    repotag,
                })
            }
        }
    }

削除対象のイメージをリスト出来たら，それを作成日時でソートし，指定した世代分は残してそれ以外を `Client.ImageRemove()` メソッドで削除している．
デフォルトでは，イメージ名にマッチしたもの全てを削除するようになっているのでお気をつけください．

    if *generation > len(imageInfos) {
        *generation = len(imageInfos)
    }
    removeOptions := types.ImageRemoveOptions{
        Force: *force,
    }
    for _, image := range imageInfos[*generation:] {
        _, err := client.ImageRemove(ctx, image.ID, removeOptions)
        if err != nil {
            log.Fatalf("[ERROR] client.ImageRemove(): %s\n", err)
        }
        fmt.Printf("Image %s was deleted.\n", image.Name)
    }

やっている事自体は簡単なので，ドキュメントと見比べて頂ければわかると思います．
