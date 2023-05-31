####################################################
# vpc
####################################################
module "vpc" {
  source = "terraform-aws-modules/vpc/aws"

  name = "benchmarker-vpc"
  cidr = "10.0.0.0/16"

  azs = ["ap-northeast-1a", "ap-northeast-1c"]

  public_subnets  = ["10.0.1.0/24", "10.0.2.0/24"]
  private_subnets = ["10.0.11.0/24", "10.0.12.0/24"]

  enable_dns_hostnames = true
  enable_dns_support   = true
  enable_nat_gateway   = true
  single_nat_gateway   = false
}

####################################################
# Internet Gateway
####################################################
resource "aws_internet_gateway" "gw" {
  vpc_id = module.vpc.vpc_id

  tags = {
    Name = "benchmarker-gw"
  }
}

####################################################
# NAT Gateway
####################################################
resource "aws_eip" "nat_eip_0" {
  vpc        = true
  depends_on = [aws_internet_gateway.gw]

  tags = {
    Name = "benchmarker-nat-eip-0"
  }
}

resource "aws_eip" "nat_eip_1" {
  vpc        = true
  depends_on = [aws_internet_gateway.gw]

  tags = {
    Name = "benchmarker-nat-eip-1"
  }
}

resource "aws_nat_gateway" "nat_gateway_0" {
  allocation_id = aws_eip.nat_eip_0.id
  subnet_id     = module.vpc.public_subnets[0]
  depends_on    = [aws_internet_gateway.gw]

  tags = {
    Name = "benchmarker-nat-gw-0"
  }
}

resource "aws_nat_gateway" "nat_gateway_1" {
  allocation_id = aws_eip.nat_eip_1.id
  subnet_id     = module.vpc.public_subnets[1]
  depends_on    = [aws_internet_gateway.gw]

  tags = {
    Name = "benchmarker-nat-gw-1"
  }
}

####################################################
# Route Table
####################################################
resource "aws_route_table" "public_route_table" {
  vpc_id = module.vpc.vpc_id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.gw.id
  }
  tags = {
    Name = "benchmarker-public-rtb"
  }
}

resource "aws_route_table_association" "public_subnet_association_0" {
  subnet_id      = module.vpc.public_subnets[0]
  route_table_id = aws_route_table.public_route_table.id
}

resource "aws_route_table_association" "public_subnet_association_1" {
  subnet_id      = module.vpc.public_subnets[1]
  route_table_id = aws_route_table.public_route_table.id
}

resource "aws_route_table" "private_route_table_0" {
  vpc_id = module.vpc.vpc_id

  route {
    cidr_block     = "0.0.0.0/0"
    nat_gateway_id = aws_nat_gateway.nat_gateway_0.id
  }
  tags = {
    Name = "benchmarker-private-rtb-0"
  }
}

resource "aws_route_table" "private_route_table_1" {
  vpc_id = module.vpc.vpc_id

  route {
    cidr_block     = "0.0.0.0/0"
    nat_gateway_id = aws_nat_gateway.nat_gateway_1.id
  }
  tags = {
    Name = "benchmarker-private-rtb-1"
  }
}

resource "aws_route_table_association" "private_subnet_association_0" {
  subnet_id      = module.vpc.private_subnets[0]
  route_table_id = aws_route_table.private_route_table_0.id
}

resource "aws_route_table_association" "private_subnet_association_1" {
  subnet_id      = module.vpc.private_subnets[1]
  route_table_id = aws_route_table.private_route_table_1.id
}

####################################################
# Security Group
####################################################
# 外部からの HTTP,HTTPSアクセスを許可
resource "aws_security_group" "allow_http" {
  name        = "allow_http"
  description = "allow http,https access."
  vpc_id      = module.vpc.vpc_id

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
  vpc_id      = module.vpc.vpc_id

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
    module.vpc.public_subnets[0],
    module.vpc.public_subnets[1]
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
  vpc_id      = module.vpc.vpc_id

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
# ECSクラスター
resource "aws_ecs_cluster" "benchmarker_ecs_cluster" {
  name = "benchmarker-ecs-cluster"

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
  # コンテナイメージは仮で Nginx
  container_definitions = file("./container_definitions.json")
  execution_role_arn    = aws_iam_role.ecs_task_execution_role.arn
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
      module.vpc.private_subnets[0],
      module.vpc.private_subnets[1]
    ]
  }

  load_balancer {
    target_group_arn = aws_lb_target_group.benchmarker_lb_target_group.arn
    container_name   = "benchmarker-container"
    container_port   = 80
  }

  # Terraformでのタスク定義の変更は初回以外無視する
  # lifecycle {
  #   ignore_changes = [task_definition]
  # }
}

# CloudWatch Logs
resource "aws_cloudwatch_log_group" "benchmark_ecs_log" {
  name              = "/ecs/benchmarker"
  retention_in_days = 3
}

# ECSタスク実行ロール
resource "aws_iam_role" "ecs_task_execution_role" {
  name               = "ecs-task-execution-role"
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

resource "aws_iam_role_policy_attachment" "ecs_task_execution_role_attachment" {
  role       = aws_iam_role.ecs_task_execution_role.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonECSTaskExecutionRolePolicy"
}
