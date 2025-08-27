resource "aws_iam_role" "cppv2_integration_sqs_lambda_firehose_role" {
  name = "cppv2_integration_sqs_lambda_firehose_role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Principal = {
          Service = "lambda.amazonaws.com"
        }
        Action = "sts:AssumeRole"
      }
    ]
  })
}

# CloudWatch Logs
resource "aws_iam_role_policy_attachment" "cppv2_lambda_basic_logging" {
  role       = aws_iam_role.cppv2_integration_sqs_lambda_firehose_role.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
}

# SQS permissions
resource "aws_iam_role_policy" "cppv2_lambda_sqs_permissions" {
  name = "cppv2_lambda_sqs_permissions"
  role = aws_iam_role.cppv2_integration_sqs_lambda_firehose_role.name

  policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Effect = "Allow",
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
        ],
        Resource = [
          aws_sqs_queue.userplatform_cppv2_sqs_us.arn,
          aws_sqs_queue.userplatform_cppv2_sqs_eu.arn,
          aws_sqs_queue.userplatform_cppv2_sqs_ap.arn,
          aws_sqs_queue.userplatform_cppv2_sqs_dlq_us.arn,
          aws_sqs_queue.userplatform_cppv2_sqs_dlq_eu.arn,
          aws_sqs_queue.userplatform_cppv2_sqs_dlq_ap.arn
        ]
      },

      # Firehose permissions (Lambda code pushes to Firehose)
      {
        Effect = "Allow",
        Action = [
          "firehose:PutRecord",
          "firehose:PutRecordBatch"
        ],
        Resource = [
          data.aws_kinesis_firehose_delivery_stream.userplatform_cpp_firehose_delivery_stream_us.arn,
          data.aws_kinesis_firehose_delivery_stream.userplatform_cpp_firehose_delivery_stream_eu.arn,
          data.aws_kinesis_firehose_delivery_stream.userplatform_cpp_firehose_delivery_stream_ap.arn
        ]
      },

      # KMS permissions
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
        Resource = "*"
      },
      {
        Effect = "Allow",
        Action = [
          "s3:AbortMultipartUpload",
          "s3:GetBucketLocation",
          "s3:GetObject",
          "s3:ListBucket",
          "s3:ListBucketMultipartUploads",
          "s3:PutObject",
          "s3:PutObjectAcl"
        ],
        Resource = "*"
      },
    ]
  })
}
