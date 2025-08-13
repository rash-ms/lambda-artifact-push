
locals {
  route_configs = {
    us = {
      region = "us-east-1",
      bucket = var.userplatform_s3_bucket["us"],

    },
    eu = {
      region = "eu-central-1",
      bucket = var.userplatform_s3_bucket["eu"],
    },
    ap = {
      region = "ap-northeast-1",
      bucket = var.userplatform_s3_bucket["ap"],
    }
  }
}