resource "aws_lambda_function" "benchmarker_starter" {
  filename      = "../index.zip"
  function_name = "bemchmarker_starter"
  role          = aws_iam_role.lambda_role.arn
  handler       = "index.handler"
  runtime       = "nodejs20.x"

  source_code_hash = filebase64sha256("../index.zip")
  timeout          = 900

  environment {
    variables = {
      SQS_QUEUE_URL            = aws_sqs_queue.benchmark_queue.url
      GOOGLE_SHEETS_API        = var.GOOGLE_SHEETS_API
      ECS_CLUSTER_NAME         = "benchmarker-ecs-cluster"
      ECS_TASK_DEFINITION_NAME = "benchmarker-task-definition:7"
      ECS_SUBNET_IDS           = "subnet-000f7d2047cb7ff75,subnet-09cf922de49fb4503"
      ECS_SECURITY_GROUP_ID    = "sg-0aaa16ac8d3cc8c71"
    }
  }
}

resource "aws_iam_role" "lambda_role" {
  name = "benchmarker_starter_lambda_role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "lambda.amazonaws.com"
        }
      },
    ]
  })
}

resource "aws_iam_role_policy_attachment" "lambda_policy" {
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
  role       = aws_iam_role.lambda_role.name
}

resource "aws_iam_role_policy" "lambda_sqs_policy" {
  name = "lambda_sqs_policy"
  role = aws_iam_role.lambda_role.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "sqs:SendMessage",
          "sqs:ReceiveMessage",
          "sqs:DeleteMessage",
          "sqs:GetQueueAttributes"
        ]
        Resource = aws_sqs_queue.benchmark_queue.arn
      },
      {
        Effect = "Allow"
        Action = [
          "ecs:RunTask",
          "ecs:DescribeTasks"
        ]
        Resource = [
          "arn:aws:ecs:ap-northeast-1:009160051284:task-definition/benchmarker-task-definition:*"
        ]
      },
      {
        Effect = "Allow"
        Action = [
          "iam:PassRole"
        ]
        Resource = "*"
        Condition = {
          StringLike = {
            "iam:PassedToService" : "ecs-tasks.amazonaws.com"
          }
        }
      },
    ]
  })
}

# API Gateway
resource "aws_apigatewayv2_api" "lambda_api" {
  name          = "benchmarker-starter-api"
  protocol_type = "HTTP"
}

resource "aws_apigatewayv2_stage" "lambda_stage" {
  api_id      = aws_apigatewayv2_api.lambda_api.id
  name        = "$default"
  auto_deploy = true
}

resource "aws_apigatewayv2_integration" "lambda_integration" {
  api_id                 = aws_apigatewayv2_api.lambda_api.id
  integration_type       = "AWS_PROXY"
  integration_method     = "POST"
  integration_uri        = aws_lambda_function.benchmarker_starter.invoke_arn
  payload_format_version = "2.0"
}

resource "aws_apigatewayv2_route" "lambda_route" {
  api_id    = aws_apigatewayv2_api.lambda_api.id
  route_key = "ANY /"
  target    = "integrations/${aws_apigatewayv2_integration.lambda_integration.id}"
}

# Lambda関数にAPI Gatewayからの呼び出しを許可
resource "aws_lambda_permission" "api_gw" {
  statement_id  = "AllowExecutionFromAPIGateway"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.benchmarker_starter.function_name
  principal     = "apigateway.amazonaws.com"
  source_arn    = "${aws_apigatewayv2_api.lambda_api.execution_arn}/*/*"
}
