################################
# AWS Region
################################
variable "aws_region" {
  description = "AWS region to deploy resources"
  type        = string
  default     = "us-east-1"
}

################################
# AWS Account ID
################################
variable "aws_account_id" {
  description = "AWS account ID"
  type        = string
}

################################
# Strapi RDS Password
################################
variable "strapi_db_password" {
  description = "RDS PostgreSQL password for Strapi"
  type        = string
  sensitive   = true
}

################################
# Docker Image Tag for Strapi
################################
variable "image_tag" {
  description = "Docker image tag for Strapi application"
  type        = string
}

################################
# Deployment Environment
################################
variable "env" {
  description = "Deployment environment (e.g., dev, staging, prod)"
  type        = string
  default     = "dev"
}
