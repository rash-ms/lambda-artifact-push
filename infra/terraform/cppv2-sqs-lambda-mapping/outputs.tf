# ================= Outputs =================
# output "presign_api_key" {
#   value     = aws_api_gateway_api_key.cppv2_generatePresignedURL_S3_key.value
#   sensitive = true
# }

# output "presign_api_url" {
#   value = "https://${aws_api_gateway_rest_api.cppv2_generatePresignedURL_S3_api.id}.execute-api.${var.region}.amazonaws.com/${aws_api_gateway_stage.cppv2_generatePresignedURL_S3_stage.stage_name}"
# }
