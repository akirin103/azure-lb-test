# azure-lb-test
本リポジトリはAzureの内部ロードバランサを実験するためのものです。  
webサーバ用のVMを2台(`server1`,`server2`)、踏み台用のVM(`bastion`)を1台、ロードバランサを1つデプロイします。  
webサーバにはそれぞれ`nginx`がインストールされており、`bastion`からアクセスすることができます。  
アクセスするwebサーバによって、表示される画面が異なります。  
(`server1`にアクセスすると「Hello FROM VM1」、`server2`にアクセスすると「Hello FROM VM2」と表示されます。)  
`stress-ng`を使用して一方のWebサーバに負荷をかけた時に、他方のページに切り替わることを確認できれば成功です。  

<br />

## 前準備
```
# SSHキーに`~/.ssh/id_rsa`を使用します。
# リソースのデプロイ
$ terraform apply --auto-approve
# SSHでbastionに接続
$ ssh -i ~/.ssh/id_rsa azureuser@<public ip>
# ロードバランサーのIPは`10.0.3.6`に固定している。
$ curl 10.0.3.6
```

## VMに負荷をかける
負荷をかけたいVMにbastionから多段SSH接続し、下記のコマンドで負荷をかけます。

```
# バックグラウンドでCPU
$ stress-ng -c 1 -l 80 -q &
# プロセスの確認
$ ps -C stress-ng,stress-ng-cpu -o comm,pid,ppid,wchan,%cpu
# ジョブの確認
$ jobs
# プロセスのリソース消費量を確認
$ top
# ジョブの停止
$ kill <プロセス番号>
```

<br />

## bastionVMから閉域のVMに多段SSHする
```sh
$ ssh -o ProxyCommand='ssh -i ~/ssh/id_rsa -W %h:%p azureuser@<public ip>' -i ~/ssh/id_rsa azureuser@<private ip>
```

[踏み台サーバ経由の多段SSH接続をローカル端末の秘密鍵のみで実施する](https://dev.classmethod.jp/articles/bastion-multi-stage-ssh-only-local-pem/)

<br />

## sshで中間者攻撃を疑われる対策
```
# ~/.ssh/known_hostsを手動で消してもいいが、下記コマンドで一発解決。
$ ssh-keygen -R <host名>
```
[sshのknown_hostsをコマンドで削除](https://jnst.hateblo.jp/entry/2014/04/09/115445)

<br />

## cloud-init logの確認方法
```
$ sudo vi /var/log/cloud-init-output.log
```

<br />
