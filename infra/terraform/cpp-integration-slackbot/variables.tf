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

variable "userplatform_s3_bucket" {
  type = map(string)
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

variable "slack_channel_id" {
  type = string
}

variable "slack_workspace_id" {
  type = string
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