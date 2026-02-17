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
  name = "ecsTaskExecutionRole-strapi"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Action = "sts:AssumeRole"
      Effect = "Allow"
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
  name              = "/ecs/strapi"
  retention_in_days = 7
}

################################
# RDS Subnet Group
################################
resource "aws_db_subnet_group" "strapi_db_subnet" {
  name       = "strapi-db-subnet"
  subnet_ids = aws_subnet.public[*].id

  tags = {
    Name = "strapi-db-subnet"
  }

  lifecycle {
    prevent_destroy = false
    ignore_changes  = [name]
  }
}

################################
# RDS PostgreSQL
################################
resource "aws_db_instance" "strapi_db" {
  allocated_storage      = 20
  engine                 = "postgres"
  engine_version         = "15"
  instance_class         = "db.t3.micro"
  identifier             = "strapi-db"
  username               = "strapiuser"
  password               = var.strapi_db_password
  db_name                = "strapi_db"
  skip_final_snapshot    = true
  publicly_accessible    = false

  db_subnet_group_name   = aws_db_subnet_group.strapi_db_subnet.name
  vpc_security_group_ids = [aws_security_group.sg.id]

  depends_on = [
    aws_db_subnet_group.strapi_db_subnet
  ]
}

################################
# ECS Cluster
################################
resource "aws_ecs_cluster" "strapi_cluster" {
  name = "strapi-cluster"
}

################################
# ECS Task Definition
################################
resource "aws_ecs_task_definition" "strapi" {
  family                   = "strapi-task"
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
  name            = "strapi-service"
  cluster         = aws_ecs_cluster.strapi_cluster.id
  task_definition = aws_ecs_task_definition.strapi.arn
  launch_type     = "FARGATE"
  desired_count   = 1

  network_configuration {
    subnets          = aws_subnet.public[*].id
    security_groups  = [aws_security_group.sg.id]
    assign_public_ip = true
  }

  depends_on = [
    aws_ecs_task_definition.strapi
  ]
}
