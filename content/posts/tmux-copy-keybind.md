---
title: "tmux コピーモードでのキーバインド"
date: 2017-06-18T00:00:00+09:00
draft: true
---

tmuxの設定を読み込み直す際に次のようなエラーが出現．

```
invalid or unknown command: bind-key -t vi-copy v begin-selection
invalid or unknown command: bind-key -t vi-copy y copy-pipe "reattach-to-user-namespace pbcopy"
```

そういえば周りで同じエラーが出てる人を見たことがある気がするなあと思いながら調べると，
いつの間にか設定方法が変わっていたらしい．結構前からの変更だったようだが，
今までエラーが出なかったのはなぜかわからない．

というわけで，変更に合わせて次のように設定を書き換えた．

以前の設定

```
bind-key -t vi-copy v begin-selection
bind-key -t vi-copy y copy-pipe "reattach-to-user-namespace pbcopy"
```

新しい設定

```
bind-key -T copy-mode-vi v send-keys -X begin-selection
bind-key -T copy-mode-vi y send-keys -X copy-pipe-and-cancel "reattach-to-user-namespace pbcopy"
```

emacs-copyとvi-copyがそれぞれcopy-modeとcopy-mode-viに変更となったためにエラーが出ていたようです．

上記に限らず，emacs-copy，vi-copyに関しては次のように修正を加えれば良い．

1.  `-t` を `-T` に変更する
2.  `emacs-copy` と `vi-copy` は，それぞれ `copy-mode` と `copy-mode-vi` に変更する
3.  コマンドの頭に `send-keys -X` をつける

これで今まで通りの操作をすることができるようになった．
