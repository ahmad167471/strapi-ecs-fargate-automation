terraform {
  backend "s3" {
    bucket         = "my-terraform-state-bucket"   # <-- create this S3 bucket first
    key            = "strapi/terraform.tfstate"
    region         = "ap-south-1"
    dynamodb_table = "terraform-locks"            # <-- optional but recommended for locking
    encrypt        = true
  }
}
