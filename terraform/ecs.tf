################################
# ECR Repository
################################
resource "aws_ecr_repository" "strapi" {
  name = "strapi-app"
}

################################
# RDS PostgreSQL
################################
resource "aws_db_subnet_group" "strapi_db_subnet" {
  name       = "strapi-db-subnet"
  subnet_ids = aws_subnet.public[*].id
}

resource "aws_db_instance" "strapi_db" {
  allocated_storage       = 20
  engine                  = "postgres"
  engine_version          = "15.3"
  instance_class          = "db.t3.micro"
  name                    = "strapi_db"                # Fixed database name
  username                = "strapiuser"
  password                = var.strapi_db_password
  skip_final_snapshot     = true
  db_subnet_group_name    = aws_db_subnet_group.strapi_db_subnet.name
  vpc_security_group_ids  = [aws_security_group.sg.id]

  # Ensure RDS is created after SG & subnet
  depends_on = [
    aws_db_subnet_group.strapi_db_subnet,
    aws_security_group.sg
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

  container_definitions = jsonencode([{
    name      = "strapi"
    image     = "${aws_ecr_repository.strapi.repository_url}:latest"
    essential = true
    portMappings = [{ containerPort = 1337, hostPort = 1337, protocol = "tcp" }]
    environment = [
      { name = "DATABASE_CLIENT", value = "postgres" },
      { name = "DATABASE_HOST", value = aws_db_instance.strapi_db.address },
      { name = "DATABASE_PORT", value = "5432" },
      { name = "DATABASE_NAME", value = "strapi_db" },   # Fixed
      { name = "DATABASE_USERNAME", value = "strapiuser" },
      { name = "DATABASE_PASSWORD", value = var.strapi_db_password }
    ]
  }])

  depends_on = [
    aws_db_instance.strapi_db
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
