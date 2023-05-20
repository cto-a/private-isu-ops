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
