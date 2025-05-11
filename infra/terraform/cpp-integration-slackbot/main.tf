resource "aws_iam_role" "cpp_integration_slackbot_lambda_role" {
  name = "cpp_integration_slackbot_lambda_role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Action = "sts:AssumeRole"
      Effect = "Allow"
      Principal = {
        Service = "lambda.amazonaws.com"
      }
    }]
  })
}

resource "aws_iam_policy_attachment" "cpp_integration_slackbot_lambda_logs" {
  name       = "cpp_integration_slackbot_lambda_logs"
  roles      = [aws_iam_role.cpp_integration_slackbot_lambda_role.name]
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
}

resource "aws_lambda_function" "cpp_integration_slackbot_lambda" {
  provider      = aws.us
  function_name = "cpp_integration_slackbot_lambda-function"
  s3_bucket     = var.lambda_s3_bucket
  s3_key        = "${var.s3_key}/${var.shared_handler_zip}.zip"
  handler       = "${var.shared_handler_zip}.send_to_slack"
  runtime       = "python3.9"
  role          = aws_iam_role.cpp_integration_slackbot_lambda_role.arn

  environment {
    variables = {
      SLACK_WEBHOOK_URL = var.slack_webhook_url
      SLACK_USER_ID     = join(" ", var.slack_user_id)
    }
  }
}

# resource "aws_lambda_permission" "cpp_integration_lambda_sns_invoke" {
#   provider = aws.us
#
#   for_each = local.sns_topic_arns
#
#   statement_id  = "AllowExecutionFromSNS-${each.key}"
#   action        = "lambda:InvokeFunction"
#   function_name = aws_lambda_function.cpp_integration_slackbot_lambda.function_name
#   principal     = "sns.amazonaws.com"
#   source_arn    = each.value
# }
#
# resource "aws_sns_topic_subscription" "cpp_integration_sns_subscription_us" {
#   provider  = aws.us
#   topic_arn = local.sns_topic_arns["US"]
#   protocol  = "lambda"
#   endpoint  = aws_lambda_function.cpp_integration_slackbot_lambda.arn
# }
#
# resource "aws_sns_topic_subscription" "cpp_integration_sns_subscription_eu" {
#   provider  = aws.eu
#   topic_arn = local.sns_topic_arns["EU"]
#   protocol  = "lambda"
#   endpoint  = aws_lambda_function.cpp_integration_slackbot_lambda.arn
# }
#
# resource "aws_sns_topic_subscription" "cpp_integration_sns_subscription_ap" {
#   provider  = aws.ap
#   topic_arn = local.sns_topic_arns["AP"]
#   protocol  = "lambda"
#   endpoint  = aws_lambda_function.cpp_integration_slackbot_lambda.arn
# }
