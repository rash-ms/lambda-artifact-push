account_id          = "253218528366"
region              = "us-east-1"
environment         = "stg"
slack_channel_id    = "TXXXXXXX" # PLACE_HOLDER: Slack Channel ID
slack_workspace_id  = "TVVVVVVV" # PLACE_HOLDER: Slack Workspace ID
stage_name          = "stg-api-v01"
route_path = {
  us = "cpp-us-interface"
  eu = "cpp-eu-interface"
  ap = "cpp-ap-interface"
}
userplatform_s3_bucket = {
  us = "cn-dse-userplatform-stg"
  eu = "cn-dse-userplatform-eu-stg"
  ap = "cn-dse-userplatform-ap-stg"
}