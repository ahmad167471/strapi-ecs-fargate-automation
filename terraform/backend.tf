terraform {
  backend "s3" {
    bucket = "my-terraform-state-bucket-ahmad"   # your bucket name
    key    = "strapi/terraform.tfstate"
    region = "ap-south-1"                  # match your bucket's region
  }
}
