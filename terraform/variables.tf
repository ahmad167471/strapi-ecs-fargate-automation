variable "aws_region" {
  description = "AWS region to deploy resources"
  type        = string
  default     = "ap-south-1"
}

variable "aws_account_id" {
  description = "AWS account ID"
  type        = string
}

variable "strapi_db_password" {
  description = "RDS PostgreSQL password"
  type        = string
  sensitive   = true
}

variable "image_tag" {
  description = "Docker image tag for Strapi"
  type        = string
}
