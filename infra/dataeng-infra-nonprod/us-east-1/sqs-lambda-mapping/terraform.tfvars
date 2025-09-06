account_id       = "273354624134"
region           = "us-east-1"
environment      = "dev"
lambda_s3_bucket = "cn-infra-lambda-artifacts"
s3_key           = "sqs-lambda-mapping/lambda_packager" ## '<module_name>/<folder_name>'
handler_zip      = "firehose_handler_v0"
userplatform_s3_bucket = {
  us = "byt-userplatform-dev-us"
  eu = "byt-userplatform-dev-eu"
  ap = "byt-userplatform-dev-ap"
}