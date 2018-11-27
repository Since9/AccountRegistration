#!/bin/sh
# 実行時に指定された引数が 一致しなければエラー終了。

if [ $# -ne 2 ]; then
  echo "引数の数が正常ではありません"
  echo "引数1 : 追加ユーザー公開鍵ファイルの指定"
  echo "引数2 : 作業者用パスワードファイルの指定"
  exit 1
fi

scpfile=`basename $1`
scpfilefullpass=`readlink -f $1`
passwdfile=$2
passwdfullpass=`readlink -f $2`
hostnames_ports_fullpass="/home/infra/ZohoAccount/hostnames_ports"

if [ ! -e "$scpfilefullpass" ];then
  echo "1番目引数で指定された追加ユーザー公開鍵ファイルが存在しません。"
  exit 1
fi

if [ ! -e "$passwdfullpass" ];then
  echo "2番目引数で指定された作業者用パスワードファイルが存在しません。"
  exit 1
fi

if [ ! -e "$hostnames_ports_fullpass" ];then
  echo "転送先サーバーのホストリストファイルhostnames_portsが存在しません。"
  echo "/home/infra/ZohoAccount/の直下に入れてください。"
  exit 1
fi

#外部ファイルpasswdfileに記述された変数(パスフレーズとsudoパスワード)を利用する。
source $passwdfullpass

read -p 'ユーザ名 フルネームを入力(例：yamada-123 Yamada Taro): ' users fullname

if [ -n "$users" -a -n "$fullname" ]; then
  echo "ユーザ名:$users フルネーム:$fullname"
 else
  echo \"ユーザ名とフルネームが入力されていません。\"
  echo \"スクリプトをもう一度実行してください。\"
  exit 1
fi

while read line
do
  hostname=`echo $line | cut -f 1 -d ":"`
  port=`echo $line | cut -f 2 -d ":"`

  expect -c "
    set timeout 5
    spawn scp -P $port $scpfilefullpass $hostname:./
  expect \"Enter passphrase for key '\"
    send \"$PASSWORD\n\"
  expect eof
  "

  expect -c "
    set timeout 10   
    spawn ssh -p $port $hostname
  expect \"Enter passphrase for key '\"
    send \"$PASSWORD\n\"
  expect \"Last login:\"
    send \"sudo su\n\"
  expect \"\[sudo\] password for\"
    send \"$SUDOPASS\n\"
  expect \"root@\"
    send \"/usr/sbin/useradd_sky $users \\\"$fullname\\\" $scpfile\n\"
  expect eof
    exit
  "
done < $hostnames_ports_fullpass
