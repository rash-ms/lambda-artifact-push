# # 1) Look up the source object (US)
data "aws_s3_bucket_object" "src_zip_eu" {
  provider = aws.us
  bucket   = var.lambda_s3_bucket
  key      = "${var.s3_key}/${var.handler_zip}.zip"
}


resource "null_resource" "zip_change_detector_eu" {
  triggers = {
    # Multiple triggers to detect changes
    source_etag = try(data.aws_s3_bucket_object.src_zip_eu.etag)
    # source_etag = try(data.aws_s3_bucket_object.src_zip_eu.etag, timestamp())
    source_key = "${var.s3_key}/${var.handler_zip}.zip"
    handler    = var.handler_zip
  }

  lifecycle {
    create_before_destroy = true
  }
}


resource "aws_s3_object_copy" "zip_eu" {
  provider = aws.eu
  bucket   = "cn-infra-lambda-artifacts-stg-eu"
  key      = "${var.s3_key}/${var.handler_zip}.zip"

  source = "${var.lambda_s3_bucket}/${var.s3_key}/${var.handler_zip}.zip"

  # Recopy when the source changes
  lifecycle {
    replace_triggered_by = [null_resource.zip_change_detector_eu]
  }

  depends_on = [data.aws_s3_bucket_object.src_zip_eu]
}


# resource "null_resource" "s3_copy_eu" {
#   triggers = {
#     source_etag = try(data.aws_s3_bucket_object.src_zip_eu.etag, timestamp())
#     source_key  = "${var.s3_key}/${var.handler_zip}.zip"
#   }
#
#   provisioner "local-exec" {
#     command = <<-EOT
#       aws s3 cp \
#         s3://cn-infra-lambda-artifacts/${var.s3_key}/${var.handler_zip}.zip \
#         s3://cn-infra-lambda-artifacts-stg-eu/${var.s3_key}/${var.handler_zip}.zip
#     EOT
#
#     environment = {
#       AWS_DEFAULT_REGION = "eu-central-1"
#     }
#   }
#
#   depends_on = [data.aws_s3_bucket_object.src_zip_eu]
# }


data "aws_kinesis_firehose_delivery_stream" "userplatform_cpp_firehose_delivery_stream_eu" {
  provider = aws.eu
  name     = "userplatform_cpp_firehose_delivery_stream_eu"
}

# data "aws_kms_alias" "cppv2_kms_key_lambda_eu" {
#   provider = aws.eu
#   name     = "alias/aws/lambda"
# }


resource "aws_sqs_queue" "userplatform_cppv2_sqs_dlq_eu" {
  provider                  = aws.eu
  name                      = "userplatform_cppv2_sqs_dlq_eu"
  message_retention_seconds = 1209600 # 14 days
}

resource "aws_sqs_queue" "userplatform_cppv2_sqs_eu" {
  provider = aws.eu
  name     = "userplatform_cppv2_sqs_eu"

  visibility_timeout_seconds = 1080   #  6x >= lambda timeout
  message_retention_seconds  = 604800 # 7 days
  receive_wait_time_seconds  = 10     # polling period

  redrive_policy = jsonencode({
    deadLetterTargetArn = aws_sqs_queue.userplatform_cppv2_sqs_dlq_eu.arn
    maxReceiveCount     = 5
  })
}

# ================= Lambda Function =================

resource "aws_lambda_function" "cppv2_sqs_lambda_firehose_eu" {
  provider         = aws.eu
  function_name    = "cppv2_sqs_lambda_firehose_eu"
  s3_bucket        = aws_s3_object_copy.zip_eu.bucket
  s3_key           = aws_s3_object_copy.zip_eu.key
  source_code_hash = aws_s3_object_copy.zip_eu.etag

  # s3_bucket = "cn-infra-lambda-artifacts-stg-eu"
  # s3_key    = "${var.s3_key}/${var.handler_zip}.zip"
  # source_code_hash = null_resource.s3_copy_eu.triggers.source_etag

  handler     = "${var.handler_zip}.send_to_firehose"
  runtime     = "python3.9"
  timeout     = 180
  memory_size = 1024
  role        = aws_iam_role.cppv2_integration_sqs_lambda_firehose_role.arn

  kms_key_arn = null
  # kms_key_arn = data.aws_kms_alias.cppv2_kms_key_lambda_eu.target_key_arn

  environment {
    variables = {
      FIREHOSE_STREAM     = data.aws_kinesis_firehose_delivery_stream.userplatform_cpp_firehose_delivery_stream_eu.name
      REGION              = local.route_configs["eu"].region
      EVENTS_BUCKET       = local.route_configs["eu"].bucket
      ERROR_EVENTS_PREFIX = "raw/cpp-v2-raw-errors"
    }
  }
  depends_on = [aws_s3_object_copy.zip_eu]
  # depends_on = [null_resource.s3_copy_eu]
}

resource "aws_cloudwatch_log_group" "cpv2_sqs_lambda_firehose_log_eu" {
  provider          = aws.eu
  name              = "/aws/lambda/${aws_lambda_function.cppv2_sqs_lambda_firehose_eu.function_name}"
  retention_in_days = 14
}


resource "aws_lambda_event_source_mapping" "cpp_sqs_lambda_trigger_eu" {
  provider                           = aws.eu
  event_source_arn                   = aws_sqs_queue.userplatform_cppv2_sqs_eu.arn
  function_name                      = aws_lambda_function.cppv2_sqs_lambda_firehose_eu.arn
  batch_size                         = 10
  maximum_batching_window_in_seconds = 5
  function_response_types            = ["ReportBatchItemFailures"]
  enabled                            = true

  depends_on = [aws_cloudwatch_log_group.cpv2_sqs_lambda_firehose_log_eu]
}
