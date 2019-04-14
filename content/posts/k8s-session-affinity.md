---
title: "Kubernetesでセッションを維持する"
date: 2018-03-28T00:00:00+09:00
draft: true
type: post
---

ログインが必要なタイプのWebアプリケーションをKubernetesで動かす際，何も考えずにPodを複数動かしてしまうと，正常にセッション管理ができない場合がある．

例えば，ログインしたという情報をWebアプリケーション側で保持しておく場合を考える．
1. DeploymentでPodのreplicaを3つ作る（Pod A，Pod B，Pod C）
2. クライアントがServiceを経由してPod Aにアクセスする．
3. クライアントはPod Aでログインする
4. ログインを終えたクライアントが，次の画面に遷移するために新しいリクエストを送る
5. リクエストを受け取ったServiceが，Pod A以外のPod（例えばPod B）にリクエストを振り分ける
6. Pod Bではクライアントがログインしたという記録がないので，再度ログイン画面に飛ばされる
7. 同様に，ログイン -> 次のPodに振り分けられるというのが続いてしまう

このような問題を解決するため，Serviceを作成する時に `sessionAffinity` を `ClientIP` に設定する．
`ClientIP` にすることで，クライアントのIPアドレスを考慮しながらPodへリクエストを流してくれるので，ステートフルなアプリケーションもKubernetes上で実行できる．

文章で説明するのは得意ではないので，実際にテスト．
例として，GrafanaをKubernetesで動かしてみる．
DeploymentとServiceを次のように作成する．

    apiVersion: apps/v1
    kind: Deployment
    metadata:
      name: grafana-deployment
    spec:
      replicas: 3
      template:
        metadata:
          labels:
            app: grafana
        spec:
          containers:
            - name: grafana
              image: grafana/grafana
              ports:
                - name: grafana-port
                  containerPort: 3000
                  protocol: TCP
      selector:
        matchLabels:
          app: grafana
    ---
    apiVersion: v1
    kind: Service
    metadata:
      name: grafana-service
    spec:
      ports:
        - name: grafana
          port: 3000
          protocol: TCP
          targetPort: grafana-port
      selector:
        app: grafana
      type: NodePort
      sessionAffinity: ClientIP

上のマニフェストを用いて作成．

    $ kubectl create -f grafana.yml

`sessionAffinity` を `ClientIP` に設定しているので，正常にログインができるはず．
