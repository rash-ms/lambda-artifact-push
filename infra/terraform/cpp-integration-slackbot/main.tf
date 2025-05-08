data "aws_lambda_function" "slack_alert_lambda" {
  function_name = "slack-alert-function"
}

resource "aws_iam_role" "lambda_exec_role" {
  name = "lambda_exec_role"

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

resource "aws_iam_policy_attachment" "lambda_logs" {
  name       = "lambda_logs"
  roles      = [aws_iam_role.lambda_exec_role.name]
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
}

resource "aws_lambda_function" "slack_alert_lambda" {
  function_name    = "slack-alert-function"
  filename         = "function.zip"
  handler          = "index.handler"
  runtime          = "python3.9"
  role             = aws_iam_role.lambda_exec_role.arn
  source_code_hash = filebase64sha256("function.zip")

  environment {
    variables = {
      SLACK_WEBHOOK_URL = var.slack_webhook_url
      SLACK_MENTIONS    = join(",", var.slack_mentions)
    }
  }
}

# resource "aws_lambda_permission" "allow_sns_invoke" {
#   statement_id  = "AllowExecutionFromSNS"
#   action        = "lambda:InvokeFunction"
#   function_name = aws_lambda_function.slack_alert_lambda.function_name
#   principal     = "sns.amazonaws.com"
#   source_arn    = "arn:aws:sns:us-east-1:123456789012:cloudwatch-alerts-topic"
# }

resource "aws_lambda_permission" "allow_sns" {
  for_each = toset(local.sns_topic_arns)

  statement_id  = "AllowExecutionFromSNS-${replace(each.value, "[:/]", "-")}"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.slack_alert_lambda.function_name
  principal     = "sns.amazonaws.com"
  source_arn    = each.value
}

resource "aws_sns_topic_subscription" "us" {
  provider  = aws.us
  topic_arn = "arn:aws:sns:us-east-1:123456789012:us-alerts"
  protocol  = "lambda"
  endpoint  = aws_lambda_function.slack_alert_lambda.arn
}

resource "aws_sns_topic_subscription" "eu" {
  provider  = aws.eu
  topic_arn = "arn:aws:sns:eu-central-1:123456789012:eu-alerts"
  protocol  = "lambda"
  endpoint  = aws_lambda_function.slack_alert_lambda.arn
}

resource "aws_sns_topic_subscription" "ap" {
  provider  = aws.ap
  topic_arn = "arn:aws:sns:ap-northeast-1:123456789012:apac-alerts"
  protocol  = "lambda"
  endpoint  = aws_lambda_function.slack_alert_lambda.arn
}
