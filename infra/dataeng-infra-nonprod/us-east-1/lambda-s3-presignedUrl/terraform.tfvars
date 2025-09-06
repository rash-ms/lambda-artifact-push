account_id       = "273354624134"
region           = "us-east-1"
environment      = "dev"
lambda_s3_bucket = "cn-infra-lambda-artifacts"
s3_key           = "lambda-s3-presignedUrl/lambda_packager" ## '<module_name>/<folder_name>'
handler_zip      = "presignedurl_handler_v00"
api_stage        = "stg-presigns3url"