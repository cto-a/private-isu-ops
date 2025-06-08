# benchmaker


以下のコマンドでimageをデプロイできる。--profileはローカルの環境にてecrにpushできる権限を持ったものを指定してください。

```bash
aws ecr get-login-password --region ap-northeast-1 | docker login --username AWS --password-stdin 528452590477.dkr.ecr.ap-northeast-1.amazonaws.com
docker build -t private-isu-benchmarker-repository .
docker tag private-isu-benchmarker-repository:latest 528452590477.dkr.ecr.ap-northeast-1.amazonaws.com/private-isu-benchmarker-repository:latest
docker push 528452590477.dkr.ecr.ap-northeast-1.amazonaws.com/private-isu-benchmarker-repository:latest
```
