provider "aws" {
  alias               = "us"
  region              = "us-east-1"
  allowed_account_ids = [var.account_id]
  default_tags {
    tags = var.tags
  }
}