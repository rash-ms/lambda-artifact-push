locals {
  sns_topic_arns = [
    "arn:aws:sns:us-east-1:273354624134:userplatform_cpp_firehose_failure_alert_topic_us",
    "arn:aws:sns:eu-central-1:273354624134:userplatform_cpp_firehose_failure_alert_topic_eu",
    "arn:aws:sns:ap-northeast-1:273354624134:userplatform_cpp_firehose_failure_alert_topic_ap"
  ]
}
