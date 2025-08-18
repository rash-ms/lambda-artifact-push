import os
import json
import time
import boto3
from json import JSONDecodeError
from typing import List, Dict
from botocore.exceptions import BotoCoreError, ClientError

REGION = os.environ["REGION"]
FIREHOSE_STREAM = os.environ["FIREHOSE_STREAM"]
EVENTS_BUCKET = os.environ.get("EVENTS_BUCKET")
ERROR_EVENTS_PREFIX = os.environ.get("ERROR_EVENTS_PREFIX", "raw/cpp-v2-raw-errors/")

MAX_FIREHOSE_RECORD_BYTES = 1000 * 1024  # ~1 MB
RETRYABLE_ERR_CODES = {"ThrottlingException", "ServiceUnavailableException", "InternalFailure"}
MAX_LOCAL_RETRIES = 3
BACKOFF_BASE_SECONDS = 0.25


fh = boto3.client("firehose", region_name=REGION)
s3 = boto3.client("s3", region_name=REGION) if EVENTS_BUCKET else None


def strict_parse(raw: str):
    try:
        return True, json.loads(raw)
    except JSONDecodeError:
        return False, raw


def encode_line(obj: dict) -> bytes:
    return json.dumps(obj, separators=(",", ":")).encode("utf-8")


def archive_error_s3(msg_id: str, body: str, reason: str) -> bool:
    """Write to S3; return True if dump to s3 or False if error."""
    if not s3:
        return True

    try:
        if reason in ("firehose_put_failed", "firehose_exceeds_1mb"):
            key = f"{ERROR_EVENTS_PREFIX}/firehose_put_failed/{msg_id}.json"
        else:
            key = f"{ERROR_EVENTS_PREFIX}/{reason}/{msg_id}.json"

        event_wrapper = {"reason": reason, "raw": body}

        s3.put_object(
            Bucket=ERROR_EVENTS_PREFIX,
            Key=key,
            Body=json.dumps(event_wrapper, separators=(",", ":")).encode("utf-8"),
            ContentType="application/json",
        )
        return True
    except Exception:
        return False

def send_to_firehose(event, _ctx):
    failures: List[Dict[str, str]] = []

    # mark record for success or retry/DLQ
    def archive_or_retry(msg_id: str, body: str, reason: str):
        if not archive_error_s3(msg_id, body, reason):
            failures.append({"itemIdentifier": msg_id})

    for rec in event.get("Records", []):
        msg_id = rec["messageId"]
        body = rec.get("body", "")

        ok, parsed = strict_parse(body)

        if not ok:
            archive_or_retry(msg_id, body, reason="invalid_json")
            continue

        payload = parsed if isinstance(parsed, dict) else {"payload": parsed}
        payload.setdefault("source", "cpp-api-streamhook")

        data = encode_line(payload)

        if len(data) > MAX_FIREHOSE_RECORD_BYTES:
            archive_or_retry(msg_id, body, reason="firehose_exceeds_1mb")
            continue

        # --------- explicit Firehose send with retries ---------

        success = False
        for attempt in range(1, MAX_LOCAL_RETRIES + 1):
            try:
                resp = fh.put_record(
                    DeliveryStreamName=FIREHOSE_STREAM,
                    Record={"Data": data}
                )
                if "RecordId" in resp:
                    success = True
                    break

            except (BotoCoreError, ClientError) as e:
                code = getattr(e, "response", {}).get("Error", {}).get("Code", "BotoCoreError")
                if code not in RETRYABLE_ERR_CODES or attempt == MAX_LOCAL_RETRIES:
                    break

            if attempt < MAX_LOCAL_RETRIES:
                time.sleep(BACKOFF_BASE_SECONDS * (2 ** (attempt - 1)))

        # --------------------------------------------------------

        if not success:
            archive_or_retry(msg_id, body, reason="firehose_put_failed")
            continue

    return {"batchItemFailures": failures}
