terraform {
  backend "s3" {
    bucket = "my-terraform-state-bucket-ahmad"   # your bucket name
    key    = "strapi/terraform.tfstate"
    region = "us-east-1"                  # match your bucket's region
  }
}
