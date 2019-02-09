---
title: "HTML等をGitHubへpushした時にWebサーバへ自動でデプロイする"
date: 2017-10-21T00:00:00+09:00
draft: true
---

HTMLなどの静的サイトをGitHubで管理していると，それを毎回手動でWebサーバへ反映させるのが面倒になってくる．

これを解決するために，GitHubとTravis CIを使って，GitHubのmasterブランチへpushした時に自動でWebサーバへデプロイする環境を作ったので，手順をまとめておく．

## GitHubのリポジトリを準備
まずはHTML等を置いておくためのリポジトリをGitHubに作成しておく．

## Travis CIとの連携
次に，[Travis CI](https://travis-ci.org/)にGitHubのアカウントでログインする．

ログインしたら，右上のアカウント名の部分をから，「Accounts」へ移動する．すると，自分のGitHubリポジトリの一覧が表示される．
ここから，自動デプロイしたいリポジトリを探し出し，リポジトリ名の左側にある「×」をクリックして「◯」へ変更する．これでTravis CIとの連携設定が完了した．

## サーバ側での設定
Webサーバ側で，自動デプロイ用に新しいユーザとグループを作成しておく．例ではCentOS7を使用している．

    # useradd app
    # passwd app
    # groupadd deploy
    # usermod -aG deploy app

ユーザとグループを作成し終えた後に，先程作成したユーザに切り替えてSSHのキーペアを作成する．この際， **作成するキーペアにパスフレーズを設定してはいけない**ことに注意する．ここでパスフレーズを設定してしまうと，Travis CIがWebサーバにデプロイしようとする際にパスフレーズ待ちで停止してしまうため，デプロイが完了しない．

    # su - app
    $ ssh-keygen
    $ mv ~/.ssh/id_rsa.pub ~/.ssh/authorized_keys

SSHキーペアの作成が完了したら，自動デプロイしたいリポジトリをサーバ側にcloneする．clone先はDocumentRootなど，実際に本番で配置する場所にする．

    $ git clone <repository url> /path/to/document/root

リポジトリのclone後，Travis側からのpushを許可するために以下の設定を行う．

    $ git config --local receive.denyCurrentBranch updateInstead

上記の設定まで完了したら，cloneしたリポジトリのディレクトリ内に移動し，SSH秘密鍵の暗号化を行う．暗号化にはTravis CLIを使用するため，必要に応じてインストールをしておく．

    $ cd /path/to/repository
    $ touch .travis.yml     # .travis.ymlを作成しておく
    $ gem install travis -v 1.8.8 --no-rdoc --no-ri
    $ travis login --org    # GitHubのアカウントでログイン
    $ travis encrypt-file /path/to/private/key --add

秘密鍵の暗号化が完了すると， `<秘密鍵の名前>.enc` というファイルが生成されるので，存在を確認しておく．
暗号化した秘密鍵は，リポジトリ内に `.travis` ディレクトリを作成してその中に入れておくと良い．

    $ mkdir .travis
    $ mv id_rsa.enc .travis

ここまでの作業が終了したら，再度Travis CIの画面に戻る．先程GitHubリポジトリとTravis CIの連携を行った画面で，リポジトリ名の左にある歯車マークをクリックして設定画面へ移る．

設定画面へ移動したら，Environment Variablesの部分までスクロールし， `encrypted_` から始まる環境変数が2つ設定されていることを確認する．もしこれらの変数が存在していない場合は，Travis CLIでログインが正しく出来ていないか，先程の秘密鍵暗号化の手順が上手くいっていない可能性があるので再度やり直す．

自動デプロイ用に次の3つの環境変数を追加する．追加の際，「Display value in build log」はOFFにしておく．これがONになっていると，ビルドログ中に設定した環境変数の値が表示されてしまう．

* `IP` : デプロイ先WebサーバのIPアドレス
* `PORT` : デプロイ先Webサーバへpushする際のポート．SSHを使う場合は22を指定する．
* `DEPLOY_DIR` : Webサーバ内でのリポジトリ配置先を指定（例: `/var/www/html` ）．
ここまで完了すればTravis CI側での設定は以上となる．

最後に， `.travis.yml` とデプロイ用に使用するシェルスクリプトを用意してリポジトリ内に配置する．
下記に `.travis.yml` と デプロイ用シェルスクリプト（ `deploy.sh` ）の例を掲載しておく．
`.travis.yml` 内の `$encrypted_xxxxxx_key` と `$encrypted_xxxxxx_iv` に関しては，各自Travis CIのEnvironment Variablesに設定されていたものに変更する．

### .travis.yml

    addons:
        ssh_known_hosts: $IP

    before_install:
    - openssl aes-256-cbc -K $encrypted_xxxxxx_key -iv $encrypted_xxxxxx_iv
        -in .travis/id_rsa.enc -out .travis/id_rsa -d

    script: ""

    after_success:
        - ssh-keyscan -t rsa $IP >> ~/.ssh/known_hosts
        - bash .travis/deploy.sh

### deploy.sh

    #!/bin/bash

    eval "$(ssh-agent -s)"
    chmod 600 .travis/id_rsa
    ssh-add .travis/id_rsa

    git config --global push.default matching
    git remote add deploy ssh://git@$IP:$PORT$DEPLOY_DIR
    git push deploy master
`.travis.yml` はリポジトリの最上位階層， `deploy.sh` は `.travis` ディレクトリ内に配置した．
最終的なディレクトリ構造は次のようになる．

    .
    ├── index.html
    ├── .travis.yml
    └── .travis
           ├── deploy.sh
           └── id_rsa.enc

ここまで完了したら，後はリポジトリにpushするたびに自動でTravis CIが動作し，サーバへ自動で変更を反映してくれるはず．
