#!/bin/bash

USER_POOL_ID="ap-northeast-1_owwW23cX9"
CLIENT_ID="28pbs1v5v549utukg74m89o2q3"
REGION="ap-northeast-1"
NUM_TEAMS=$1

# 既存のユーザーを削除する
EXISTING_USERS=$(aws cognito-idp list-users --user-pool-id ${USER_POOL_ID} --region ${REGION} --query "Users[].Username" --output text)
for EXISTING_USER in ${EXISTING_USERS}; do
    aws cognito-idp admin-delete-user --user-pool-id ${USER_POOL_ID} --username ${EXISTING_USER} --region ${REGION}
done

# admin ユーザーの作成
ADMIN_USERNAME="admin"
ADMIN_PASSWORD=$(openssl rand -base64 12 | sed 's/[+/=]/#/g')'1!'
aws cognito-idp sign-up \
  --client-id ${CLIENT_ID} \
  --username ${ADMIN_USERNAME} \
  --password ${ADMIN_PASSWORD} \
  --region ${REGION} > /dev/null 2>&1

aws cognito-idp admin-confirm-sign-up \
  --user-pool-id ${USER_POOL_ID} \
  --username ${ADMIN_USERNAME} \
  --region ${REGION} > /dev/null 2>&1

# AWS Secrets Managerにパスワードを保存
if aws secretsmanager describe-secret --secret-id "${ADMIN_USERNAME}_password" --region ${REGION} > /dev/null 2>&1; then
    aws secretsmanager update-secret --secret-id "${ADMIN_USERNAME}_password" --secret-string "${ADMIN_PASSWORD}" --region ${REGION}
else
    aws secretsmanager create-secret --name "${ADMIN_USERNAME}_password" --secret-string "${ADMIN_PASSWORD}" --region ${REGION}
fi

# チームごとのユーザーの作成
for ((i=1; i<=NUM_TEAMS; i++)); do
  TEAM_USERNAME="team${i}"
  TEAM_PASSWORD=$(openssl rand -base64 12 | sed 's/[+/=]/#/g')'1!'
  aws cognito-idp sign-up \
    --client-id ${CLIENT_ID} \
    --username ${TEAM_USERNAME} \
    --password ${TEAM_PASSWORD} \
    --region ${REGION} > /dev/null 2>&1

  aws cognito-idp admin-confirm-sign-up \
    --user-pool-id ${USER_POOL_ID} \
    --username ${TEAM_USERNAME} \
    --region ${REGION} > /dev/null 2>&1

  # AWS Secrets Managerにパスワードを保存
  if aws secretsmanager describe-secret --secret-id "${TEAM_USERNAME}_password" --region ${REGION} > /dev/null 2>&1; then
      aws secretsmanager update-secret --secret-id "${TEAM_USERNAME}_password" --secret-string "${TEAM_PASSWORD}" --region ${REGION}
  else
      aws secretsmanager create-secret --name "${TEAM_USERNAME}_password" --secret-string "${TEAM_PASSWORD}" --region ${REGION}
  fi
done
