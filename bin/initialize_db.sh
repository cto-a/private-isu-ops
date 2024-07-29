#!/bin/bash

# Table name
TABLE_NAME="portal_scores"
REGION="ap-northeast-1"

# Delete the table
aws dynamodb delete-table --table-name $TABLE_NAME --region $REGION

# Wait until the table is deleted
aws dynamodb wait table-not-exists --table-name $TABLE_NAME --region $REGION

# Create the table
aws dynamodb create-table --table-name $TABLE_NAME \
  --attribute-definitions AttributeName=team_id,AttributeType=N AttributeName=timestamp,AttributeType=N \
  --key-schema AttributeName=team_id,KeyType=HASH AttributeName=timestamp,KeyType=RANGE \
  --billing-mode PAY_PER_REQUEST --region $REGION

# Wait until the table is created
aws dynamodb wait table-exists --table-name $TABLE_NAME --region $REGION

TEAM_COUNT=$1

# Get the current UNIX timestamp from WorldTimeAPI in UTC
current_timestamp=$(curl -s 'http://worldtimeapi.org/api/timezone/Etc/UTC' | grep -oP '(?<="unixtime":)\d+')

# Insert initial scores for each team
for i in $(seq 0 $((TEAM_COUNT-1)))
do
  aws dynamodb put-item \
    --table-name portal_scores \
    --item '{
        "team_id": {"N": "'"$i"'"},
        "score": {"N": "0"},
        "pass": {"BOOL": false},
        "success": {"N": "0"},
        "fail": {"N": "0"},
        "timestamp": {"N": "'"$current_timestamp"'"},
        "messages": {"L": []}
    }' \
    --region $REGION
done
