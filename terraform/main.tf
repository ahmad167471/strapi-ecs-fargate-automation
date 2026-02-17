provider "aws" {
  region = var.aws_region
}

################################
# Availability Zones Data
################################
data "aws_availability_zones" "available" {}

################################
# VPC & Subnets
################################
resource "aws_vpc" "strapi_vpc" {
  cidr_block = "10.0.0.0/16"

  tags = {
    Name = "strapi-vpc-${var.env}"
  }
}

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
# Security Group
################################
resource "aws_security_group" "sg" {
  name   = "strapi-sg-${var.env}"
  vpc_id = aws_vpc.strapi_vpc.id

  ingress {
    from_port   = 1337
    to_port     = 1337
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    from_port   = 5432
    to_port     = 5432
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"] # restrict in production
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
# RDS DB Subnet Group
################################
resource "aws_db_subnet_group" "strapi_db_subnet" {
  name       = "strapi-db-subnet-${var.env}"
  subnet_ids = [aws_subnet.public[0].id, aws_subnet.public[1].id]

  tags = {
    Name = "strapi-db-subnet-${var.env}"
  }
}
