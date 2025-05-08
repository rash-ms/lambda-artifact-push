variable "region" {
  type = string
}

variable "account_id" {
  type = string
}

variable "environment" {
  type    = string
  default = "stg"
}

variable "s3_key" {
  description = "Path to the Lambda zip file in S3"
  type        = string
}

variable "source_code_hash" {
  description = "Base64-encoded SHA256 hash of the Lambda zip"
  type        = string
}

variable "lambda_s3_bucket" {
  description = "The S3 bucket where the Lambda ZIP is stored"
  type        = string
}

variable "slack_mentions" {
  description = "List of Slack usernames to mention"
  type        = list(string)
  default     = []
}

variable "slack_webhook_url" {
  description = "Slack webhook URL"
  type        = string
}

variable "tenant_name" {
  type    = string
  default = "data-platform"
}

# tags to be applied to resource
variable "tags" {
  type = map(any)

  default = {
    "created_by"  = "terraform"
    "application" = "aws-infra-resources"
    "owner"       = "data-platform"
  }
}