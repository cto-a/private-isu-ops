####################################################
# vpc
####################################################
resource "aws_vpc" "main" {
  cidr_block           = "10.0.0.0/16"
  enable_dns_support   = true
  enable_dns_hostnames = true

  tags = {
    Name = "benchmarker-vpc"
  }
}

####################################################
# Subnets
####################################################
resource "aws_subnet" "public_0" {
  vpc_id            = aws_vpc.main.id
  cidr_block        = "10.0.1.0/24"
  availability_zone = "ap-northeast-1a"

  tags = {
    Name = "benchmarker-public-0"
  }
}

resource "aws_subnet" "public_1" {
  vpc_id            = aws_vpc.main.id
  cidr_block        = "10.0.2.0/24"
  availability_zone = "ap-northeast-1c"

  tags = {
    Name = "benchmarker-public-1"
  }
}

resource "aws_subnet" "private_0" {
  vpc_id            = aws_vpc.main.id
  cidr_block        = "10.0.11.0/24"
  availability_zone = "ap-northeast-1a"

  tags = {
    Name = "benchmarker-private-0"
  }
}

resource "aws_subnet" "private_1" {
  vpc_id            = aws_vpc.main.id
  cidr_block        = "10.0.12.0/24"
  availability_zone = "ap-northeast-1c"

  tags = {
    Name = "benchmarker-private-1"
  }
}

####################################################
# Internet Gateway
####################################################
resource "aws_internet_gateway" "gw" {
  vpc_id = aws_vpc.main.id

  tags = {
    Name = "benchmarker-gw"
  }
}

####################################################
# EIP
####################################################
resource "aws_eip" "nat_eip_0" {
  domain     = "vpc"
  depends_on = [aws_internet_gateway.gw]

  tags = {
    Name = "benchmarker-nat-eip-0"
  }
}

resource "aws_eip" "nat_eip_1" {
  domain     = "vpc"
  depends_on = [aws_internet_gateway.gw]

  tags = {
    Name = "benchmarker-nat-eip-1"
  }
}

####################################################
# NAT Gateway
####################################################
resource "aws_nat_gateway" "nat_gateway_0" {
  allocation_id = aws_eip.nat_eip_0.id
  subnet_id     = aws_subnet.public_0.id
  depends_on    = [aws_internet_gateway.gw]

  tags = {
    Name = "benchmarker-nat-gw-0"
  }
}

resource "aws_nat_gateway" "nat_gateway_1" {
  allocation_id = aws_eip.nat_eip_1.id
  subnet_id     = aws_subnet.public_1.id
  depends_on    = [aws_internet_gateway.gw]

  tags = {
    Name = "benchmarker-nat-gw-1"
  }
}

####################################################
# Route Table
####################################################
resource "aws_route_table" "public_route_table" {
  vpc_id = aws_vpc.main.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.gw.id
  }
  tags = {
    Name = "benchmarker-public-rtb"
  }
}

resource "aws_route_table_association" "public_subnet_association_0" {
  subnet_id      = aws_subnet.public_0.id
  route_table_id = aws_route_table.public_route_table.id
}

resource "aws_route_table_association" "public_subnet_association_1" {
  subnet_id      = aws_subnet.public_1.id
  route_table_id = aws_route_table.public_route_table.id
}

resource "aws_route_table" "private_route_table_0" {
  vpc_id = aws_vpc.main.id

  route {
    cidr_block     = "0.0.0.0/0"
    nat_gateway_id = aws_nat_gateway.nat_gateway_0.id
  }
  tags = {
    Name = "benchmarker-private-rtb-0"
  }
}

resource "aws_route_table" "private_route_table_1" {
  vpc_id = aws_vpc.main.id

  route {
    cidr_block     = "0.0.0.0/0"
    nat_gateway_id = aws_nat_gateway.nat_gateway_1.id
  }
  tags = {
    Name = "benchmarker-private-rtb-1"
  }
}

resource "aws_route_table_association" "private_subnet_association_0" {
  subnet_id      = aws_subnet.private_0.id
  route_table_id = aws_route_table.private_route_table_0.id
}

resource "aws_route_table_association" "private_subnet_association_1" {
  subnet_id      = aws_subnet.private_1.id
  route_table_id = aws_route_table.private_route_table_1.id
}

####################################################
# Security Group
####################################################
# 外部からの HTTP,HTTPSアクセスを許可
resource "aws_security_group" "allow_http" {
  name        = "allow_http"
  description = "allow http,https access."
  vpc_id      = aws_vpc.main.id
  ingress {
    description = "allow http access."
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    description = "allow https access."
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port        = 0
    to_port          = 0
    protocol         = "-1"
    cidr_blocks      = ["0.0.0.0/0"]
    ipv6_cidr_blocks = ["::/0"]
  }

  tags = {
    Name = "alb"
  }
}

# 上記に関連付けられた SG からの内部アクセスを許可
resource "aws_security_group" "allow_internal" {
  name        = "allow_internal"
  description = "allow internal access."
  vpc_id      = aws_vpc.main.id

  ingress {
    description     = "allow internal http access."
    from_port       = 80
    to_port         = 80
    protocol        = "tcp"
    security_groups = [aws_security_group.allow_http.id]
  }

  ingress {
    description     = "allow internal https access."
    from_port       = 443
    to_port         = 443
    protocol        = "tcp"
    security_groups = [aws_security_group.allow_http.id]
  }

  egress {
    from_port        = 0
    to_port          = 0
    protocol         = "-1"
    cidr_blocks      = ["0.0.0.0/0"]
    ipv6_cidr_blocks = ["::/0"]
  }

  tags = {
    Name = "internal"
  }
}

####################################################
# ALB
####################################################
resource "aws_lb" "benchmarker_alb" {
  name               = "benchmarker-alb"
  load_balancer_type = "application"
  internal           = false
  idle_timeout       = 60
  # 今はfalse
  enable_deletion_protection = false

  subnets = [
    aws_subnet.public_0.id,
    aws_subnet.public_1.id
  ]

  security_groups = [aws_security_group.allow_http.id]

  # access_logs {
  #   bucket  = "your-bucket-name"
  #   prefix  = "benchmarker-alb-logs"
  #   enabled = true
  # }

  tags = {
    Name = "benchmarker-alb"
  }
}

resource "aws_lb_listener" "benchmarker_lb_listener" {
  load_balancer_arn = aws_lb.benchmarker_alb.arn
  port              = 80
  protocol          = "HTTP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.benchmarker_lb_target_group.arn
  }
}

resource "aws_lb_target_group" "benchmarker_lb_target_group" {
  name        = "benchmarker-lb-target-group"
  port        = 80
  protocol    = "HTTP"
  target_type = "ip"
  vpc_id      = aws_vpc.main.id

  deregistration_delay = 300

  health_check {
    path                = "/"
    port                = 80
    protocol            = "HTTP"
    healthy_threshold   = 5
    unhealthy_threshold = 2
    timeout             = 5
    interval            = 30
    matcher             = 200
  }

  depends_on = [aws_lb.benchmarker_alb]
  tags = {
    Name = "benchmarker-lb-tg"
  }
}

####################################################
# ECS
####################################################
# キャパシティプロバイダ
resource "aws_ecs_capacity_provider" "fargate_spot" {
  name = "FARGATE_SPOT"
}

resource "aws_ecs_capacity_provider" "fargate" {
  name = "FARGATE"
}

# ECSクラスター
resource "aws_ecs_cluster" "benchmarker_ecs_cluster" {
  name = "benchmarker-ecs-cluster"

  capacity_providers = [
    aws_ecs_capacity_provider.fargate_spot.name,
    aws_ecs_capacity_provider.fargate.name
  ]

  default_capacity_provider_strategy {
    capacity_provider = aws_ecs_capacity_provider.fargate_spot.name
    weight            = 1
  }

  setting {
    name  = "containerInsights"
    value = "enabled"
  }
}

# ECSタスク
resource "aws_ecs_task_definition" "benchmarker_ecs_task" {
  family                   = "benchmarker-task-definition"
  cpu                      = "256"
  memory                   = "512"
  network_mode             = "awsvpc"
  requires_compatibilities = ["FARGATE"]
  container_definitions    = file("./container_definitions.json")
  execution_role_arn       = aws_iam_role.ecs_task_execution_role.arn
  task_role_arn            = aws_iam_role.ecs_task_role.arn
}

# ECSサービス
resource "aws_ecs_service" "benchmarker_ecs_service" {
  name                              = "benchmark-ecs-service"
  cluster                           = aws_ecs_cluster.benchmarker_ecs_cluster.arn
  task_definition                   = aws_ecs_task_definition.benchmarker_ecs_task.arn
  desired_count                     = 1
  launch_type                       = "FARGATE"
  platform_version                  = "1.4.0"
  health_check_grace_period_seconds = 60

  network_configuration {
    assign_public_ip = false
    security_groups  = [aws_security_group.allow_internal.id]

    subnets = [
      aws_subnet.private_0.id,
      aws_subnet.private_1.id
    ]
  }

  load_balancer {
    target_group_arn = aws_lb_target_group.benchmarker_lb_target_group.arn
    container_name   = "benchmarker-container"
    container_port   = 80
  }

  # Fargateの場合、デプロイのたびにタスク定義が更新される
  # `terraform plan` で差分が出るため、初回のリソース作成時を除き変更を無視する
  # Terraformでのタスク定義の変更は初回以外無視する
  # lifecycle {
  #   ignore_changes = [task_definition]
  # }
}

# ECSタスク実行ロール
resource "aws_iam_role" "ecs_task_execution_role" {
  name = "ecs-task-execution-role"

  assume_role_policy = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Principal": {
        "Service": "ecs-tasks.amazonaws.com"
      },
      "Action": "sts:AssumeRole"
    }
  ]
}
EOF
}

resource "aws_iam_policy" "ecs_task_execution_role_policy" {
  name   = "ecs-task-execution-role-policy"
  policy = <<-EOS
  {
    "Version": "2012-10-17",
    "Statement": [
        {
            "Effect": "Allow",
            "Action": [
                "ecr:GetAuthorizationToken",
                "ecr:BatchCheckLayerAvailability",
                "ecr:GetDownloadUrlForLayer",
                "ecr:BatchGetImage",
                "logs:CreateLogStream",
                "logs:PutLogEvents",
                "logs:CreateLogGroup"
            ],
            "Resource": "*"
        }
    ]
  }
  EOS
}

resource "aws_iam_policy" "ssm_policy" {
  name   = "ecs-task-execution-ssm-policy"
  policy = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Action": "ssm:GetParameters",
      "Resource": "*"
    }
  ]
}
EOF
}

resource "aws_iam_role_policy_attachment" "ecs_task_execution_ssm_policy" {
  role       = aws_iam_role.ecs_task_execution_role.name
  policy_arn = aws_iam_policy.ssm_policy.arn
}

resource "aws_iam_role_policy_attachment" "ecs_task_execution_role_policy" {
  role       = aws_iam_role.ecs_task_execution_role.name
  policy_arn = aws_iam_policy.ecs_task_execution_role_policy.arn
}

resource "aws_iam_role" "ecs_task_role" {
  name = "ecs-task-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "ecs-tasks.amazonaws.com"
        }
      }
    ]
  })
}

resource "aws_iam_policy" "ecs_sqs_access_policy" {
  name        = "ecs-sqs-access-policy"
  description = "Allow ECS tasks to access SQS"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "sqs:ReceiveMessage",
          "sqs:DeleteMessage",
          "sqs:GetQueueAttributes"
        ]
        Resource = "arn:aws:sqs:ap-northeast-1:009160051284:benchmark_queue"
      }
    ]
  })
}

resource "aws_iam_role_policy_attachment" "ecs_sqs_policy_attachment" {
  role       = aws_iam_role.ecs_task_role.name
  policy_arn = aws_iam_policy.ecs_sqs_access_policy.arn
}

resource "aws_cloudwatch_log_group" "ecs_log" {
  name              = "/ecs/benchmarker"
  retention_in_days = 3
}
