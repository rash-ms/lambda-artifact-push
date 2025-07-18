import boto3
import json
import uuid

def get_bucket_region(bucket_name):
    if "eu" in bucket_name:
        return "eu-central-1"
    elif "ap" in bucket_name:
        return "ap-northeast-1"
    else:
        return "us-east-1"


def presigner_url_s3(event, context):
    path_params = event.get("pathParameters", {})
    bucket = path_params.get("bucket")
    prefix = path_params.get("prefix", "raw/cppv2-replay-sync")

    if not bucket:
        return {
            "statusCode": 400,
            "body": json.dumps({"error": "Missing bucket name in path"}),
            "headers": {"Content-Type": "application/json"}
        }

    region = get_bucket_region(bucket)
    body = json.loads(event.get("body") or "{}")
    content_type = body.get("content_type", "application/json")

    filename = f"{uuid.uuid4()}.json"
    key = f"{prefix}/{filename}"

    try:
        s3 = boto3.client("s3", region_name=region)

        url = s3.generate_presigned_url(
            "put_object",
            Params={
                "Bucket": bucket,
                "Key": key,
                "ContentType": content_type
            },
            ExpiresIn=900
        )

        return {
            "statusCode": 200,
            "body": json.dumps({
                "upload_url": url,
                "s3_key": key,
                "bucket": bucket,
                "region": region
            }),
            "headers": {"Content-Type": "application/json"}
        }

    except Exception as e:
        return {
            "statusCode": 500,
            "body": json.dumps({"error": str(e)}),
            "headers": {"Content-Type": "application/json"}
        }
