---
title: "RyuによるOpenFlow入門 (2)"
date: 2018-06-24T00:00:00+09:00
draft: true
---

前回の続き．今回はMACアドレス学習機能のある，スイッチングハブを作成する．
前回同様，OpenFlowのバージョンは1.0を使用します．

## スイッチングハブ
ソースコードは以下の通り．

<script src="https://gist-it.appspot.com/github/mas9612/ryu-study/blob/master/l2_switch.py"></script>

L2のフレームをスイッチの他のポートに送信するという基本機能は前回実装したリピータハブと変わらない．
そのため，プログラムの大枠は同じである．

リピータハブとスイッチングハブの違いとして，スイッチングハブではMACアドレスの学習機能があるという点がある．
このため，一度MACアドレスの学習をした後は，そのMACアドレス宛のフレームはその機器が接続されているポートのみに送信するようになる．
（リピータハブでは，全てのフレームを全てのポート（フレームが入ってきたポート以外）に送信する）

では，プログラムを見てみる．
なお，リピータハブのプログラムと似たような部分は省略します．

`L2Switch` クラスのインスタンスを作成する際に，MACアドレスとポートの対応付けをするためのディクショナリ（ `mac_to_port` ）を作成しておく（19行目）．
MACアドレスを学習したら，この辞書にポートとの対応付けを登録していく．

    def __init__(self, *args, **kwargs):
        super(L2Switch, self).__init__(*args, **kwargs)
        self.mac_to_port = {}

MACアドレスの学習は，Packet Inでスイッチからのデータを受け取ったときに行う．
まず，スイッチから入ってきたフレームのMACアドレスとポートの対応付けを `mac_to_port` に登録する（63行目）．

    self.mac_to_port[dpid][src] = msg.in_port

その後，出力ポートを決定するために，宛先MACアドレスの対応付け情報が `mac_to_port` の中に存在するかどうかを確認する（66行目〜70行目）．
もし存在していたら，見つかったポートを出力ポートとしてPacket Outメッセージを作成する．
もし存在していなかったら，全てのポートを出力ポートとしてPacket Outメッセージを作成する．

    ofproto = dp.ofproto
    if dst in self.mac_to_port[dpid]:
        out_port = self.mac_to_port[dpid][dst]
    else:
        out_port = ofproto.OFPP_FLOOD

加えて，もし宛先MACアドレスの対応付け情報が存在していた場合，同じ宛先MACアドレスのフレームが再度コントローラに来るのを防ぐため，FlowModメッセージを使ってスイッチにフローエントリを書き込む（76行目〜77行目）．
FlowModを使うのは，毎回コントローラにフレームが来てしまうとその分パフォーマンスが落ちてしまうため，それを避けるため．

    if out_port != ofproto.OFPP_FLOOD:
        self.add_flow(dp, msg.in_port, dst, src, actions)
