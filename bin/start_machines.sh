#!/bin/bash

# 引数の数が正しいかチェック
if [ $# -ne 1 ]; then
  echo "Usage: $0 <instance_num>"
  exit 1
fi

KEY_PAIR_NAME="CtoaIsuInitialKeyPair"
INSTANCE_NUM=$1
AMI_ID="ami-047fdc2b851e73cad" # https://github.com/catatsuy/private-isu
INSTANCE_TYPE="c7a.large" # 推奨タイプ
SECURITY_GROUP_ID="sg-01e0a41b433867351" # 22と80が全開放されているSG

# 実行するたびにキーペアを作り直す
aws ec2 delete-key-pair --key-name $KEY_PAIR_NAME
aws ec2 create-key-pair --key-name $KEY_PAIR_NAME --query 'KeyMaterial' --output text > $KEY_PAIR_NAME.pem

# 権限を適切にする
chmod 400 $KEY_PAIR_NAME.pem

# EC2インスタンスを起動する
aws ec2 run-instances --image-id $AMI_ID --count $INSTANCE_NUM --instance-type $INSTANCE_TYPE --key-name $KEY_PAIR_NAME --security-group-ids $SECURITY_GROUP_ID 

# 起動したインスタンスのIPアドレスを取得する
aws ec2 describe-instances --query 'Reservations[*].Instances[*].PublicIpAddress' --output text
