################################
# ECR Repository (Data Source)
################################
data "aws_ecr_repository" "strapi" {
  name = "strapi-ahmad-app"  # Make sure this matches the existing repo in your AWS account
}

################################
# IAM Role ARN for ECS Task (Use Existing)
################################
variable "ecs_task_role_arn" {
  description = "IAM Role ARN for ECS Task"
  type        = string
  default     = "arn:aws:iam::373317459749:role/ecs_fargate_execution_minimal"
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

  # Use existing role for both execution and task roles
  execution_role_arn = var.ecs_task_role_arn
  task_role_arn      = var.ecs_task_role_arn

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

    # Removed logConfiguration to bypass CloudWatch permission issue
  }])

  depends_on = [
    aws_db_instance.strapi_db
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
