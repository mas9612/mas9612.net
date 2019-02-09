---
title: "USENIX 2018の論文読み"
date: 2018-07-03T00:00:00+09:00
draft: false
---

軽く読んだので，雑なまとめ．
ほぼ自分用のメモ．

## Elastic Scaling of Stateful Network Functions
* https://www.usenix.org/conference/nsdi18/presentation/woo
* NFV（Network Functions Virtualization）におけるスケーリングの弾力性は重要な要素
    * 実用レベルでの実現は難しかった
        * 多くのNFs（Network Functions）はステートフル
        * NFを構成するインスタンス同士での状態共有が必要である
        * NFでのスループットとレイテンシの要件を満たしたステート共有の実装は難しい
* S6を提案
    * パフォーマンスの低下なしにNFにスケーリングの弾力性を提供するフレームワーク
    * ステートをDSO（distributed shared object）とする
        * 弾力性と高パフォーマンスの要件を満たすために拡張したもの
    * NFの管理者は，ステートがどのように分散・共有されているかを気にすることなくプログラミングできる
        * S6が透過的に処理をしてくれる（データの局所性や整合性等を抽象化する）
* 実験・評価の結果
    * 現在のNFの動的スケーリング手法と比較
        * スケーリング: 100倍のパフォーマンス向上
        * 通常時: 2〜5倍のパフォーマンス向上

## Stroboscope: Declarative Network Monitoring on a Budget
* https://www.usenix.org/conference/nsdi18/presentation/tilmans
* ISPにとって，ネットワークの動作がどうなっているのか等を正確に知ることは困難
    * エンドホストを制御するのは不可能
    * 大量にトラフィックの統計を取る，という方法に頼るしかなかった
        * 情報の粒度が粗いという問題がある
* Stroboscopeを提案
    * どんなトラフィックフローでもきめ細かいモニタリングが可能
    * 高レベルのクエリを入力すると，自動でいろいろやってくれる
        * どのフローをミラーリングするか
        * ルールをどこに配置するか
        * カバレッジを最大化するためにはいつルールをスケジューリングすれば良いか
    * 既存のルータ上で動作する

## SafeBricks: Shielding Network Functions in the Cloud
* Network Function Virtualization (NFV) の出現により，企業等ではネットワークでの処理をクラウド側に任せることが増えた
    * セキュリティリスクもある
    * クラウドは攻撃の影響を受けやすい
* SafeBricksを提案
    * 信頼できないクラウドからNFを守るシステム
    * 暗号化されたトラフィックのみがクラウドプロバイダの方に流れる
        * トラフィックとNFの両方の完全性を保つ
    * クライアントに最小権限を強制する
    * SafeBricks leverages a combination of hardware enclaves and language-based enforcement
    * SafeBricksによるオーバーヘッドは0〜15%
