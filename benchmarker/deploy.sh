#!/bin/bash

aws ecr get-login-password --region ap-northeast-1 --profile cto-a | docker login --username AWS --password-stdin 254374927794.dkr.ecr.ap-northeast-1.amazonaws.com
docker build -t private-isu-benchmarker-repository .
docker tag private-isu-benchmarker-repository:latest 254374927794.dkr.ecr.ap-northeast-1.amazonaws.com/private-isu-benchmarker-repository:latest
docker push 254374927794.dkr.ecr.ap-northeast-1.amazonaws.com/private-isu-benchmarker-repository:latest