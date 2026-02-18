################################
# AWS Provider
################################
provider "aws" {
  region = var.aws_region
}

################################
# Availability Zones
################################
data "aws_availability_zones" "available" {}

################################
# VPC
################################
resource "aws_vpc" "strapi_vpc" {
  cidr_block           = "10.0.0.0/16"
  enable_dns_hostnames = true
  enable_dns_support   = true

  tags = {
    Name = "strapi-vpc-${var.env}"
  }
}

################################
# Internet Gateway
################################
resource "aws_internet_gateway" "igw" {
  vpc_id = aws_vpc.strapi_vpc.id

  tags = {
    Name = "strapi-igw-${var.env}"
  }
}

################################
# Public Subnets (For ECS)
################################
resource "aws_subnet" "public" {
  count                   = 2
  vpc_id                  = aws_vpc.strapi_vpc.id
  map_public_ip_on_launch = true

  cidr_block = cidrsubnet(aws_vpc.strapi_vpc.cidr_block, 8, count.index)

  availability_zone = element(
    data.aws_availability_zones.available.names,
    count.index
  )

  tags = {
    Name = "strapi-public-subnet-${count.index}-${var.env}"
  }
}

################################
# Private Subnets (For RDS)
################################
resource "aws_subnet" "private" {
  count  = 2
  vpc_id = aws_vpc.strapi_vpc.id

  cidr_block = cidrsubnet(aws_vpc.strapi_vpc.cidr_block, 8, count.index + 10)

  availability_zone = element(
    data.aws_availability_zones.available.names,
    count.index
  )

  tags = {
    Name = "strapi-private-subnet-${count.index}-${var.env}"
  }
}

################################
# Elastic IP for NAT
################################
resource "aws_eip" "nat_eip" {
  domain = "vpc"
}

################################
# NAT Gateway
################################
resource "aws_nat_gateway" "nat" {
  allocation_id = aws_eip.nat_eip.id
  subnet_id     = aws_subnet.public[0].id

  depends_on = [aws_internet_gateway.igw]

  tags = {
    Name = "strapi-nat-${var.env}"
  }
}

################################
# Public Route Table
################################
resource "aws_route_table" "public" {
  vpc_id = aws_vpc.strapi_vpc.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.igw.id
  }

  tags = {
    Name = "strapi-public-rt-${var.env}"
  }
}

resource "aws_route_table_association" "public" {
  count          = length(aws_subnet.public)
  subnet_id      = aws_subnet.public[count.index].id
  route_table_id = aws_route_table.public.id
}

################################
# Private Route Table
################################
resource "aws_route_table" "private" {
  vpc_id = aws_vpc.strapi_vpc.id

  route {
    cidr_block     = "0.0.0.0/0"
    nat_gateway_id = aws_nat_gateway.nat.id
  }

  tags = {
    Name = "strapi-private-rt-${var.env}"
  }
}

resource "aws_route_table_association" "private" {
  count          = length(aws_subnet.private)
  subnet_id      = aws_subnet.private[count.index].id
  route_table_id = aws_route_table.private.id
}

################################
# Security Group
################################
resource "aws_security_group" "sg" {
  name   = "strapi-sg-${var.env}"
  vpc_id = aws_vpc.strapi_vpc.id

  # Strapi Public Access
  ingress {
    from_port   = 1337
    to_port     = 1337
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  # Allow PostgreSQL only from same SG (ECS -> RDS)
  ingress {
    from_port                = 5432
    to_port                  = 5432
    protocol                 = "tcp"
    self                     = true
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "strapi-sg-${var.env}"
  }
}

################################
# DB Subnet Group (PRIVATE ONLY)
################################
resource "aws_db_subnet_group" "strapi_db_subnet" {
  name       = "strapi-db-subnet-${var.env}"
  subnet_ids = aws_subnet.private[*].id

  tags = {
    Name = "strapi-db-subnet-${var.env}"
  }
}

################################
# RDS PostgreSQL
################################
resource "aws_db_instance" "strapi_db" {
  identifier              = "strapi-db-${var.env}"
  engine                  = "postgres"
  engine_version          = "15"
  instance_class          = "db.t3.micro"
  allocated_storage       = 20
  db_name                 = "strapi_db"
  username                = "strapiuser"
  password                = var.strapi_db_password

  publicly_accessible     = false
  skip_final_snapshot     = true

  db_subnet_group_name    = aws_db_subnet_group.strapi_db_subnet.name
  vpc_security_group_ids  = [aws_security_group.sg.id]

  depends_on = [
    aws_db_subnet_group.strapi_db_subnet
  ]
}
