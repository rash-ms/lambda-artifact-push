# resource "aws_iam_role" "cppv2_generatePresignedURL_S3_role" {
#   name = "cppv2_generatePresignedURL_S3_role"
#   # permissions_boundary = ""

#   assume_role_policy = jsonencode({
#     Version = "2012-10-17",
#     Statement = [{
#       Effect = "Allow",
#       Principal = {
#         Service = "lambda.amazonaws.com"
#       },
#       Action = "sts:AssumeRole"
#     }]
#   })
# }

# resource "aws_iam_role_policy" "cppv2_generatePresignedURL_S3_policy" {
#   name = "cppv2_generatePresignedURL_S3_policy"
#   role = aws_iam_role.cppv2_generatePresignedURL_S3_role.id

#   policy = jsonencode({
#     Version = "2012-10-17",
#     Statement = [
#       {
#         Effect = "Allow",
#         Action = [
#           "s3:PutObject",
#           "s3:GetObject"
#         ],
#         Resource = [
#           "arn:aws:s3:::byt-userplatform-dev-eu/*",
#           "arn:aws:s3:::byt-userplatform-dev-us/*",
#           "arn:aws:s3:::byt-userplatform-dev-ap/*"
#         ]
#       },
#       {
#         Effect = "Allow",
#         Action = [
#           "logs:CreateLogGroup",
#           "logs:CreateLogStream",
#           "logs:PutLogEvents"
#         ],
#         Resource = "*"
#       }
#     ]
#   })
# }


# # =================  ********** =================
# # ================= IAM Role for Lambda =================
# resource "aws_iam_role" "cppv2_generatePresignedURL_S3_role" {
#   name = "cppv2_generatePresignedURL_S3_role"

#   assume_role_policy = jsonencode({
#     Version = "2012-10-17",
#     Statement = [{
#       Effect = "Allow",
#       Principal = {
#         Service = "lambda.amazonaws.com"
#       },
#       Action = "sts:AssumeRole"
#     }]
#   })
# }

# # resource "aws_iam_role_policy_attachment" "cppv2_generatePresignedURL_S3_policy" {
# #   role       = aws_iam_role.cppv2_generatePresignedURL_S3_role.name
# #   policy_arn = "arn:aws:iam::aws:policy/AmazonS3FullAccess"
# # }

# resource "aws_iam_role_policy" "cppv2_generatePresignedURL_S3_policy" {
#   name = "cppv2_generatePresignedURL_S3_policy"
#   role = aws_iam_role.cppv2_generatePresignedURL_S3_role.id

#   policy = jsonencode({
#     Version = "2012-10-17",
#     Statement = [
#       {
#         Effect = "Allow",
#         Action = [
#           "s3:PutObject",
#           "s3:GetObject"
#         ],
#         Resource = [
#           "arn:aws:s3:::byt-userplatform-dev-eu/*",
#           "arn:aws:s3:::byt-userplatform-dev-us/*",
#           "arn:aws:s3:::byt-userplatform-dev-ap/*"
#         ]
#       }
#     ]
#   })
# }


# # ================= Lambda Function =================
# resource "aws_lambda_function" "cppv2_generatePresignedURL_S3_lambda" {
#   function_name = "cppv2_generatePresignedURL_S3_lambda"
#   s3_bucket     = var.lambda_s3_bucket
#   s3_key        = "${var.s3_key}/${var.handler_zip}.zip"
#   handler       = "${var.handler_zip}.presigner_url_s3"
#   runtime       = "python3.9"
#   role          = aws_iam_role.cppv2_generatePresignedURL_S3_role.arn
#   timeout       = 10 # Set to 10 seconds or more
# }

# # ================= API Gateway =================
# resource "aws_api_gateway_rest_api" "cppv2_generatePresignedURL_S3_api" {
#   name = "cppv2_generatePresignedURL_S3_api"
# }

# # /{bucket}
# resource "aws_api_gateway_resource" "bucket_path" {
#   rest_api_id = aws_api_gateway_rest_api.cppv2_generatePresignedURL_S3_api.id
#   parent_id   = aws_api_gateway_rest_api.cppv2_generatePresignedURL_S3_api.root_resource_id
#   path_part   = "{bucket}"
# }

# # /{bucket}/{prefix+}
# resource "aws_api_gateway_resource" "prefix_path" {
#   rest_api_id = aws_api_gateway_rest_api.cppv2_generatePresignedURL_S3_api.id
#   parent_id   = aws_api_gateway_resource.bucket_path.id
#   path_part   = "{prefix+}"
# }

# resource "aws_api_gateway_method" "cppv2_generatePresignedURL_S3_method" {
#   rest_api_id      = aws_api_gateway_rest_api.cppv2_generatePresignedURL_S3_api.id
#   resource_id      = aws_api_gateway_resource.prefix_path.id
#   http_method      = "POST"
#   authorization    = "NONE"
#   api_key_required = true

#   request_parameters = {
#     "method.request.path.bucket" = true,
#     "method.request.path.prefix" = true
#   }
# }

# resource "aws_api_gateway_integration" "cppv2_generatePresignedURL_S3_lambda" {
#   rest_api_id             = aws_api_gateway_rest_api.cppv2_generatePresignedURL_S3_api.id
#   resource_id             = aws_api_gateway_resource.prefix_path.id
#   http_method             = aws_api_gateway_method.cppv2_generatePresignedURL_S3_method.http_method
#   integration_http_method = "POST"
#   type                    = "AWS_PROXY"
#   uri                     = aws_lambda_function.cppv2_generatePresignedURL_S3_lambda.invoke_arn
# }

# # ================= API Key and Usage Plan =================
# resource "aws_api_gateway_api_key" "cppv2_generatePresignedURL_S3_key" {
#   name        = "CppV2-Presign-ApiKey"
#   description = "API key to access the pre-signed URL generator"
#   enabled     = true
# }

# resource "aws_api_gateway_usage_plan" "cppv2_generatePresignedURL_S3_PlanUsage" {
#   name = "cppv2_generatePresignedURL_S3_PlanUsage"

#   api_stages {
#     api_id = aws_api_gateway_rest_api.cppv2_generatePresignedURL_S3_api.id
#     stage  = aws_api_gateway_stage.cppv2_generatePresignedURL_S3_stage.stage_name
#   }

#   throttle_settings {
#     rate_limit  = 10
#     burst_limit = 5
#   }

#   quota_settings {
#     limit  = 1000
#     period = "MONTH"
#   }
# }

# resource "aws_api_gateway_usage_plan_key" "cppv2_generatePresignedURL_S3_plan_key" {
#   key_id        = aws_api_gateway_api_key.cppv2_generatePresignedURL_S3_key.id
#   key_type      = "API_KEY"
#   usage_plan_id = aws_api_gateway_usage_plan.cppv2_generatePresignedURL_S3_PlanUsage.id
# }

# # ================= Lambda Permission for API Gateway =================
# resource "aws_lambda_permission" "cppv2_generatePresignedURL_S3_api_gw" {
#   statement_id  = "AllowAPIGatewayInvoke"
#   action        = "lambda:InvokeFunction"
#   function_name = aws_lambda_function.cppv2_generatePresignedURL_S3_lambda.function_name
#   principal     = "apigateway.amazonaws.com"
#   source_arn    = "${aws_api_gateway_rest_api.cppv2_generatePresignedURL_S3_api.execution_arn}/*/*"
# }

# # ================= API Deployment and Stage =================
# resource "aws_api_gateway_deployment" "cppv2_generatePresignedURL_S3_deploy" {
#   depends_on  = [aws_api_gateway_integration.cppv2_generatePresignedURL_S3_lambda]
#   rest_api_id = aws_api_gateway_rest_api.cppv2_generatePresignedURL_S3_api.id
#   description = "Production deployment"
# }

# resource "aws_cloudwatch_log_group" "cppv2_generatePresignedURL_S3_logs" {
#   name              = "/aws/apigateway/cppv2_generatePresignedURL_S3_logs"
#   retention_in_days = 7

# }
# resource "aws_api_gateway_stage" "cppv2_generatePresignedURL_S3_stage" {
#   stage_name    = "prod"
#   rest_api_id   = aws_api_gateway_rest_api.cppv2_generatePresignedURL_S3_api.id
#   deployment_id = aws_api_gateway_deployment.cppv2_generatePresignedURL_S3_deploy.id

#   access_log_settings {
#     destination_arn = aws_cloudwatch_log_group.cppv2_generatePresignedURL_S3_logs.arn
#     format = jsonencode({
#       requestId         = "$context.requestId",
#       extendedRequestId = "$context.extendedRequestId",
#       requestTime       = "$context.requestTime",
#       httpMethod        = "$context.httpMethod",
#       resourcePath      = "$context.resourcePath",
#       status            = "$context.status",
#       responseLength    = "$context.responseLength"
#     })
#   }
# }

# resource "aws_api_gateway_method_settings" "cppv2_logging_settings" {
#   rest_api_id = aws_api_gateway_rest_api.cppv2_generatePresignedURL_S3_api.id
#   stage_name  = aws_api_gateway_stage.cppv2_generatePresignedURL_S3_stage.stage_name
#   method_path = "*/*"

#   settings {
#     logging_level      = "INFO"
#     data_trace_enabled = true
#     metrics_enabled    = true
#   }
# }
