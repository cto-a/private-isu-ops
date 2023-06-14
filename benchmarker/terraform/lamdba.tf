resource "aws_sns_topic" "benchmark_sns_topic" {
  name = "benchmark_sns_topic"
}

resource "aws_sqs_queue" "benchmark_sqs_queue" {
  name = "benchmark_sqs_queue"
}

# SNSトピックとSQSキューを紐づけるサブスクリプション
resource "aws_sns_topic_subscription" "benchmark_subscription" {
  topic_arn = aws_sns_topic.benchmark_sns_topic.arn
  protocol  = "sqs"
  endpoint  = aws_sqs_queue.benchmark_sqs_queue.arn
}

data "aws_iam_policy_document" "benchmarker_lambda_policy" {
  statement {
    effect = "Allow"

    principals {
      type        = "Service"
      identifiers = ["lambda.amazonaws.com"]
    }

    actions = ["sts:AssumeRole"]
  }
}

resource "aws_iam_role" "benchmarker_lambda_role" {
  name               = "benchmarker_lambda_role"
  assume_role_policy = data.aws_iam_policy_document.benchmarker_lambda_policy.json
}

resource "aws_iam_role_policy_attachment" "benchmarker_lambda_role_policy" {
  role       = aws_iam_role.benchmarker_lambda_role.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
}

resource "aws_lambda_function" "benchmarker_lambda" {
  # Lambda関数のコードが含まれるディレクトリへのパスを指定してください
  # ディレクトリには、index.pyとlambda_handler関数が含まれている必要があります
  # サンプルコードでは、index.pyというファイルにlambda_handler関数が含まれていると仮定しています
  filename      = "benchmarker_lambda_function.zip"
  function_name = "benchmarker_lambda_function"
  role          = aws_iam_role.benchmarker_lambda_role.arn
  handler       = "index.handler"
  runtime       = "nodejs18.x"
  timeout       = 60
  memory_size   = 128

  environment {
    variables = {
      SNS_TOPIC_ARN = aws_sns_topic.benchmark_sns_topic.arn,
      # SQSキューのURLを参照し、キューからメッセージを受信
      SQS_QUEUE_URL = aws_sqs_queue.benchmark_sqs_queue.url
    }
  }
}

# Lambdaプログラムをテスト
resource "aws_lambda_function_url" "test_lambda_function_urls" {
  function_name = aws_lambda_function.benchmarker_lambda.function_name
  # NONE　はパブリックAPI
  authorization_type = "NONE"
}
