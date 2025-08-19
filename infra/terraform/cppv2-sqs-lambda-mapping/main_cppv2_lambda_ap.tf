data "aws_s3_bucket_object" "src_zip_ap" {
  provider = aws.us
  bucket   = var.lambda_s3_bucket
  key      = "${var.s3_key}/${var.handler_zip}.zip"
}

# resource "null_resource" "zip_change_detector_ap" {
#   triggers = {
#     # Multiple triggers to detect changes
#     source_etag = try(data.aws_s3_bucket_object.src_zip_ap.etag, timestamp())
#     source_key  = "${var.s3_key}/${var.handler_zip}.zip"
#     handler     = var.handler_zip
#   }
#
#   lifecycle {
#     create_before_destroy = true
#   }
# }
#
# resource "aws_s3_object_copy" "zip_ap" {
#   provider = aws.ap
#   bucket   = "cn-infra-lambda-artifacts-stg-ap"
#   key      = "${var.s3_key}/${var.handler_zip}.zip"
#
#   source = "arn:aws:s3:::${var.lambda_s3_bucket}/${var.s3_key}/${var.handler_zip}.zip"
#
#   # Recopy when the source changes
#   lifecycle {
#     replace_triggered_by = [null_resource.zip_change_detector_ap]
#   }
#
#   depends_on = [data.aws_s3_bucket_object.src_zip_ap]
# }


resource "null_resource" "s3_copy_ap" {
  triggers = {
    source_etag = try(data.aws_s3_bucket_object.src_zip_ap.etag, timestamp())
    source_key  = "${var.s3_key}/${var.handler_zip}.zip"
  }

  provisioner "local-exec" {
    command = <<-EOT
      aws s3 cp \
        s3://cn-infra-lambda-artifacts/${var.s3_key}/${var.handler_zip}.zip \
        s3://cn-infra-lambda-artifacts-stg-ap/${var.s3_key}/${var.handler_zip}.zip
    EOT

    environment = {
      AWS_DEFAULT_REGION = "ap-southeast-1"
    }
  }

  depends_on = [data.aws_s3_bucket_object.src_zip_ap]
}

data "aws_kinesis_firehose_delivery_stream" "userplatform_cpp_firehose_delivery_stream_ap" {
  provider = aws.ap
  name     = "userplatform_cpp_firehose_delivery_stream_ap"
}

# data "aws_kms_alias" "cppv2_kms_key_lambda_ap" {
#   provider = aws.ap
#   name     = "alias/aws/lambda"
# }

resource "aws_sqs_queue" "userplatform_cppv2_sqs_dlq_ap" {
  provider                  = aws.ap
  name                      = "userplatform_cppv2_sqs_dlq_ap"
  message_retention_seconds = 1209600 # 14 days
}

resource "aws_sqs_queue" "userplatform_cppv2_sqs_ap" {
  provider = aws.ap
  name     = "userplatform_cppv2_sqs_ap"

  visibility_timeout_seconds = 1080   #  6x >= lambda timeout
  message_retention_seconds  = 604800 # 7 days
  receive_wait_time_seconds  = 10     # polling period

  redrive_policy = jsonencode({
    deadLetterTargetArn = aws_sqs_queue.userplatform_cppv2_sqs_dlq_ap.arn
    maxReceiveCount     = 5
  })
}

# ================= Lambda Function =================

resource "aws_lambda_function" "cpv2_sqs_lambda_firehose_ap" {
  provider      = aws.ap
  function_name = "cpv2_sqs_lambda_firehose_ap"
  # s3_bucket     = var.lambda_s3_bucket
  # s3_key        = "${var.s3_key}/${var.handler_zip}.zip"
  s3_bucket        = aws_s3_object_copy.zip_ap.bucket
  s3_key           = aws_s3_object_copy.zip_ap.key
  source_code_hash = aws_s3_object_copy.zip_ap.etag

  handler     = "${var.handler_zip}.send_to_firehose"
  runtime     = "python3.9"
  timeout     = 180
  memory_size = 1024
  role        = data.aws_iam_role.cpp_integration_apigw_evtbridge_firehose_logs_role.arn

  # kms_key_arn = null
  # kms_key_arn = data.aws_kms_alias.cppv2_kms_key_lambda_ap.target_key_arn

  environment {
    variables = {
      FIREHOSE_STREAM     = data.aws_kinesis_firehose_delivery_stream.userplatform_cpp_firehose_delivery_stream_ap.name
      REGION              = local.route_configs["ap"].region
      EVENTS_BUCKET       = local.route_configs["ap"].bucket
      ERROR_EVENTS_PREFIX = "raw/cpp-v2-raw-errors/"
    }
  }
  depends_on = [aws_s3_object_copy.zip_ap]
}

resource "aws_cloudwatch_log_group" "cpv2_sqs_lambda_firehose_log_ap" {
  provider          = aws.ap
  name              = "/aws/lambda/${aws_lambda_function.cpv2_sqs_lambda_firehose_ap.function_name}"
  retention_in_days = 14
}


resource "aws_lambda_event_source_mapping" "cpp_sqs_lambda_trigger_ap" {
  provider                           = aws.ap
  event_source_arn                   = aws_sqs_queue.userplatform_cppv2_sqs_ap.arn
  function_name                      = aws_lambda_function.cpv2_sqs_lambda_firehose_ap.arn
  batch_size                         = 10
  maximum_batching_window_in_seconds = 5
  function_response_types            = ["ReportBatchItemFailures"]
  enabled                            = true

  depends_on = [aws_cloudwatch_log_group.cpv2_sqs_lambda_firehose_log_ap]
}
