# private-isu-ops

CTO 協会の新人向け ISUCON 準備のリポジトリです

## 運用手順

### ポータル

#### アプリケーションのデプロイ

[サブモジュールのリポジトリ](https://github.com/kesompochy/cto-a-isucon-portal)において、master ブランチに対して変更を push することで、自動的にデプロイが行われます。

このデプロイプロセスでは Amplify が使用されています。

#### 当日の手順

1. ワークフロー `Initialize Users`を回して、ポータル画面の認証用username, passwordを生成する
  - AWS Secrets Managerに保存されるのでコンソールから取得する
  - 各チームにssh鍵と一緒に渡すことを想定している
2. ワークフロー `Initialize Dynamo DB Table`でデータの初期化をする 
