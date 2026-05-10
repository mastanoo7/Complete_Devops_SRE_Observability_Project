# ============================================================
# Production Environment — Backend Configuration
# Remote state stored in S3 with DynamoDB locking
# ============================================================

terraform {
  backend "s3" {
    bucket         = "nexacommerce-tf-state"
    key            = "prod/terraform.tfstate"
    region         = "us-east-1"
    encrypt        = true
    kms_key_id     = "alias/nexacommerce-terraform-state"
    dynamodb_table = "nexacommerce-tf-locks"

    # Enable state locking
    use_lockfile = true
  }
}
