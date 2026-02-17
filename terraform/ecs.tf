################################
# ECR Repository (Data Source)
################################
data "aws_ecr_repository" "strapi" {
  name = "strapi-ahmad-app"
}

################################
# IAM Role for ECS Task Execution
################################
resource "aws_iam_role" "ecs_task_execution_role" {
  name = "ecsTaskExecutionRole-strapi-${var.env}"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Action    = "sts:AssumeRole"
      Effect    = "Allow"
      Principal = {
        Service = "ecs-tasks.amazonaws.com"
      }
    }]
  })
}

resource "aws_iam_role_policy_attachment" "ecs_task_execution_policy" {
  role       = aws_iam_role.ecs_task_execution_role.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonECSTaskExecutionRolePolicy"
}

################################
# CloudWatch Logs
################################
resource "aws_cloudwatch_log_group" "strapi_logs" {
  name              = "/ecs/strapi-${var.env}"
  retention_in_days = 7
}

################################
# ECS Cluster
################################
resource "aws_ecs_cluster" "strapi_cluster" {
  name = "strapi-cluster-${var.env}"
}

################################
# ECS Task Definition
################################
resource "aws_ecs_task_definition" "strapi" {
  family                   = "strapi-task-${var.env}"
  network_mode             = "awsvpc"
  requires_compatibilities = ["FARGATE"]
  cpu                      = "512"
  memory                   = "1024"
  execution_role_arn       = aws_iam_role.ecs_task_execution_role.arn

  container_definitions = jsonencode([{
    name      = "strapi"
    image     = "${data.aws_ecr_repository.strapi.repository_url}:${var.image_tag}"
    essential = true

    portMappings = [{
      containerPort = 1337
      protocol      = "tcp"
    }]

    environment = [
      { name = "DATABASE_CLIENT",   value = "postgres" },
      { name = "DATABASE_HOST",     value = aws_db_instance.strapi_db.address },
      { name = "DATABASE_PORT",     value = "5432" },
      { name = "DATABASE_NAME",     value = "strapi_db" },
      { name = "DATABASE_USERNAME", value = "strapiuser" },
      { name = "DATABASE_PASSWORD", value = var.strapi_db_password }
    ]

    logConfiguration = {
      logDriver = "awslogs"
      options = {
        awslogs-group         = aws_cloudwatch_log_group.strapi_logs.name
        awslogs-region        = var.aws_region
        awslogs-stream-prefix = "ecs"
      }
    }
  }])

  depends_on = [
    aws_db_instance.strapi_db,
    aws_iam_role_policy_attachment.ecs_task_execution_policy
  ]
}

################################
# ECS Service
################################
resource "aws_ecs_service" "strapi_service" {
  name            = "strapi-service-${var.env}"
  cluster         = aws_ecs_cluster.strapi_cluster.id
  task_definition = aws_ecs_task_definition.strapi.arn
  launch_type     = "FARGATE"
  desired_count   = 1

  network_configuration {
    subnets          = [for s in aws_subnet.public : s.id]
    security_groups  = [aws_security_group.sg.id]
    assign_public_ip = true
  }

  depends_on = [
    aws_ecs_task_definition.strapi
  ]
}
