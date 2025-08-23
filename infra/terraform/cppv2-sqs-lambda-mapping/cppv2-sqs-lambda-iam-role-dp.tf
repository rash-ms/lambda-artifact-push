# resource "aws_iam_role_policy" "cppv2_lambda_sqs_permissions" {
#   name = "cppv2_lambda_sqs_permissions"
#   role = data.aws_iam_role.cpp_integration_apigw_evtbridge_firehose_logs_role.name
#
#   policy = jsonencode({
#     Version = "2012-10-17"
#     Statement = [
#       {
#         Effect = "Allow"
#         Action = [
#           "sqs:ReceiveMessage",
#           "sqs:DeleteMessage",
#           "sqs:GetQueueAttributes",
#           "sqs:ChangeMessageVisibility",
#           "sqs:GetQueueUrl",
#           "sqs:ListDeadLetterSourceQueues",
#           "sqs:SendMessageBatch",
#           "sqs:PurgeQueue",
#           "sqs:SendMessage",
#           "sqs:CreateQueue",
#           "sqs:ListQueueTags",
#           "sqs:ChangeMessageVisibilityBatch",
#           "sqs:SetQueueAttributes"
#         ]
#         Resource = [
#           aws_sqs_queue.userplatform_cppv2_sqs_us.arn,
#           aws_sqs_queue.userplatform_cppv2_sqs_dlq_us.arn,
#           aws_sqs_queue.userplatform_cppv2_sqs_eu.arn,
#           aws_sqs_queue.userplatform_cppv2_sqs_dlq_eu.arn,
#           aws_sqs_queue.userplatform_cppv2_sqs_ap.arn,
#           aws_sqs_queue.userplatform_cppv2_sqs_dlq_ap.arn
#         ]
#       },
#       {
#         "Effect" : "Allow",
#         Action : [
#           "sqs:GetQueueUrl",
#           "sqs:ListQueues"
#         ],
#         Resource = [
#           aws_sqs_queue.userplatform_cppv2_sqs_us.arn,
#           aws_sqs_queue.userplatform_cppv2_sqs_dlq_us.arn,
#           aws_sqs_queue.userplatform_cppv2_sqs_eu.arn,
#           aws_sqs_queue.userplatform_cppv2_sqs_dlq_eu.arn,
#           aws_sqs_queue.userplatform_cppv2_sqs_ap.arn,
#           aws_sqs_queue.userplatform_cppv2_sqs_dlq_ap.arn
#         ]
#       },
#       {
#         "Effect" : "Allow",
#         Action : [
#           "kms:Decrypt",
#           "kms:DescribeKey",
#           "kms:Encrypt",
#           "kms:ReEncrypt*",
#           "kms:GenerateDataKey*",
#           "kms:DescribeKey",
#           "kms:GenerateDataKeyWithoutPlaintext"
#         ],
#         Resource = "*"
#         # Resource = [
#         #   "arn:aws:kms:${local.route_configs["us"].region}:${var.account_id}:alias/aws/lambda",
#         #   "arn:aws:kms:${local.route_configs["eu"].region}:${var.account_id}:alias/aws/lambda",
#         #   "arn:aws:kms:${local.route_configs["ap"].region}:${var.account_id}:alias/aws/lambda"
#         # ]
#         # Resource = [
#         #   data.aws_kms_alias.cppv2_kms_key_lambda_us.target_key_arn,
#         #   data.aws_kms_alias.cppv2_kms_key_lambda_eu.target_key_arn,
#         #   data.aws_kms_alias.cppv2_kms_key_lambda_ap.target_key_arn
#         # ]
#       }
#     ]
#   })
# }