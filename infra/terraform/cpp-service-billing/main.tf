# resource "aws_iam_role" "cpp_integration_slackbot_lambda_test_role" {
#   name = "cpp_integration_slackbot_lambda_test_role"
#
#   assume_role_policy = jsonencode({
#     Version = "2012-10-17"
#     Statement = [{
#       Action = "sts:AssumeRole"
#       Effect = "Allow"
#       Principal = {
#         Service = "lambda.amazonaws.com"
#       }
#     }]
#   })
# }
#
# resource "aws_iam_policy_attachment" "cpp_integration_slackbot_lambda_test_logs" {
#   name       = "cpp_integration_slackbot_lambda_test_logs"
#   roles      = [aws_iam_role.cpp_integration_slackbot_lambda_test_role.name]
#   policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
# }
#
#
# resource "aws_lambda_function" "cpp_integration_slackbot_lambda_test" {
#   provider      = aws.us
#   function_name = "cpp_integration_slackbot_lambda-test-function"
#   s3_bucket     = var.lambda_s3_bucket
#   s3_key        = "${var.s3_key}/${var.handler_zip}.zip"
#   handler       = "${var.handler_zip}.send_to_slack"
#   runtime       = "python3.9"
#   role          = aws_iam_role.cpp_integration_slackbot_lambda_test_role.arn
#
#   environment {
#     variables = {
#       SLACK_WEBHOOK_URL = var.slack_webhook_url
#       SLACK_MENTIONS    = join(" ", var.slack_mentions)
#     }
#   }
# }
