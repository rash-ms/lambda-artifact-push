import boto3
import json
import uuid
import traceback

def get_bucket_region(bucket_name):
    if "eu" in bucket_name:
        return "eu-central-1"
    elif "ap" in bucket_name:
        return "ap-northeast-1"
    else:
        return "us-east-1"

def presigner_url_s3(event, context):
    print("DEBUG: Received event =>", json.dumps(event))

    path_params = event.get("pathParameters", {})
    bucket = path_params.get("bucket")
    prefix = path_params.get("prefix", "raw/cppv2-replay-sync")

    if not bucket:
        return {
            "statusCode": 400,
            "body": json.dumps({"error": "Missing bucket name in invoke url"}),
            "headers": {"Content-Type": "application/json"}
        }

    region = get_bucket_region(bucket)

    try:
        body = json.loads(event.get("body") or "{}")
        content_type = body.get("content_type", "application/json")

        filename = f"{uuid.uuid4()}.json"
        key = f"{prefix}/{filename}"

        print(f"DEBUG: Using bucket: {bucket}, region: {region}, key: {key}, content_type: {content_type}")

        s3 = boto3.client("s3", region_name=region)

        ##ExpiresIn: (1 hour:3600, 24 hours:86400, 7 days: 604800(maximum allowed by S3))
        url = s3.generate_presigned_url(
            "put_object",
            Params={
                "Bucket": bucket,
                "Key": key,
                "ContentType": content_type
            },
            ExpiresIn=3600
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
        print("ERROR:", traceback.format_exc())

        return {
            "statusCode": 500,
            "body": json.dumps({"error": str(e)}),
            "headers": {"Content-Type": "application/json"}
        }
