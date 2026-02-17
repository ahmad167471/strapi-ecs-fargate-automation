variable "aws_region" {
  default = "ap-south-1"
}

variable "aws_account_id" {
  description = "AWS account ID"
}

variable "strapi_db_password" {
  description = "RDS password"
  default     = "StrapiPass123!"
}

variable "image_tag" {
  description = "Docker image tag for Strapi"
  type        = string
}
