terraform {
  backend "s3" {
    bucket         = "nexacommerce-tf-state"
    key            = "dev/terraform.tfstate"
    region         = "us-east-1"
    encrypt        = true
    dynamodb_table = "nexacommerce-tf-locks"
  }
}
