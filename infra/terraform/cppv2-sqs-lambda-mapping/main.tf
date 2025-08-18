data "aws_iam_role" "cpp_integration_apigw_evtbridge_firehose_logs_role" {
  name = "cpp_integration_apigw_evtbridge_firehose_logs_role"
}

data "aws_kinesis_firehose_delivery_stream" "userplatform_cpp_firehose_delivery_stream_us" {
  provider = aws.us
  name     = "userplatform_cpp_firehose_delivery_stream_us"
}

data "aws_kms_alias" "cppv2_kms_key_lambda" {
  name = "alias/aws/lambda"
}

resource "aws_iam_role_policy" "cppv2_lambda_sqs_permissions" {
  provider = aws.us
  name     = "cppv2_lambda_sqs_permissions"
  role     = data.aws_iam_role.cpp_integration_apigw_evtbridge_firehose_logs_role.name

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "sqs:ReceiveMessage",
          "sqs:DeleteMessage",
          "sqs:GetQueueAttributes",
          "sqs:ChangeMessageVisibility",
          "sqs:GetQueueUrl",
          "sqs:ListDeadLetterSourceQueues",
          "sqs:SendMessageBatch",
          "sqs:PurgeQueue",
          "sqs:SendMessage",
          "sqs:CreateQueue",
          "sqs:ListQueueTags",
          "sqs:ChangeMessageVisibilityBatch",
          "sqs:SetQueueAttributes"
        ]
        Resource = [
          aws_sqs_queue.userplatform_cppv2_sqs_us.arn,
          aws_sqs_queue.userplatform_cppv2_sqs_dlq_us.arn
        ]
      },
      {
        "Effect" : "Allow",
        Action : [
          "sqs:GetQueueUrl",
          "sqs:ListQueues"
        ],
        Resource = [
          aws_sqs_queue.userplatform_cppv2_sqs_us.arn,
          aws_sqs_queue.userplatform_cppv2_sqs_dlq_us.arn
        ]
      },
      {
        "Effect" : "Allow",
        Action : [
          "kms:Decrypt",
          "kms:DescribeKey",
          "kms:Encrypt",
          "kms:ReEncrypt*",
          "kms:GenerateDataKey*",
          "kms:DescribeKey",
          "kms:GenerateDataKeyWithoutPlaintext"
        ],
        Resource = data.aws_kms_alias.cppv2_kms_key_lambda.target_key_arn
      }
    ]
  })
}

resource "aws_sqs_queue" "userplatform_cppv2_sqs_dlq_us" {
  provider                  = aws.us
  name                      = "userplatform_cppv2_sqs_dlq_us"
  message_retention_seconds = 1209600 # 14 days
}

resource "aws_sqs_queue" "userplatform_cppv2_sqs_us" {
  provider = aws.us
  name     = "userplatform_cppv2_sqs_us"

  visibility_timeout_seconds = 1080   #  6x >= lambda timeout
  message_retention_seconds  = 604800 # 7 days
  receive_wait_time_seconds  = 10     # polling period

  redrive_policy = jsonencode({
    deadLetterTargetArn = aws_sqs_queue.userplatform_cppv2_sqs_dlq_us.arn
    maxReceiveCount     = 5
  })
}

# ================= Lambda Function =================

resource "aws_lambda_function" "cpv2_sqs_lambda_firehose_us" {
  provider      = aws.us
  function_name = "cppv2_sqs_lambda_firehose_us"
  s3_bucket     = var.lambda_s3_bucket
  s3_key        = "${var.s3_key}/${var.handler_zip}.zip"
  handler       = "${var.handler_zip}.send_to_firehose"
  runtime       = "python3.9"
  timeout       = 180
  memory_size   = 1024
  role          = data.aws_iam_role.cpp_integration_apigw_evtbridge_firehose_logs_role.arn

  kms_key_arn = data.aws_kms_alias.cppv2_kms_key_lambda.target_key_arn

  environment {
    variables = {
      FIREHOSE_STREAM     = data.aws_kinesis_firehose_delivery_stream.userplatform_cpp_firehose_delivery_stream_us.name
      REGION              = local.route_configs["us"].region
      EVENTS_BUCKET       = local.route_configs["us"].bucket
      ERROR_EVENTS_PREFIX = "raw/cpp-v2-raw-errors/"
    }
  }
}

resource "aws_cloudwatch_log_group" "cpv2_sqs_lambda_firehose_log_us" {
  provider          = aws.us # ← add this so it’s in us-east-1
  name              = "/aws/lambda/${aws_lambda_function.cpv2_sqs_lambda_firehose_us.function_name}"
  retention_in_days = 14
}


resource "aws_lambda_event_source_mapping" "cpp_sqs_lambda_trigger_us" {
  provider                           = aws.us
  event_source_arn                   = aws_sqs_queue.userplatform_cppv2_sqs_us.arn
  function_name                      = aws_lambda_function.cpv2_sqs_lambda_firehose_us.arn
  batch_size                         = 10
  maximum_batching_window_in_seconds = 5
  function_response_types            = ["ReportBatchItemFailures"]
  enabled                            = true

  depends_on = [aws_cloudwatch_log_group.cpv2_sqs_lambda_firehose_log_us]
}
