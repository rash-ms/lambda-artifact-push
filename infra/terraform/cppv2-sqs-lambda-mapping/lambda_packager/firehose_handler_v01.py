import os
import json
import time
import boto3
from json import JSONDecodeError
from typing import List, Dict
from botocore.exceptions import BotoCoreError, ClientError

REGION = os.environ["REGION"]
FIREHOSE_STREAM = os.environ["FIREHOSE_STREAM"]
QUARANTINE_BUCKET = os.environ.get("QUARANTINE_BUCKET")
QUARANTINE_PREFIX = os.environ.get("QUARANTINE_PREFIX", "quarantine/")
MAX_FIREHOSE_RECORD_BYTES = 1000 * 1024  # ~1 MB
RETRYABLE_ERR_CODES = {"ThrottlingException", "ServiceUnavailableException", "InternalFailure"}
MAX_LOCAL_RETRIES = 3
BACKOFF_BASE_SECONDS = 0.25

fh = boto3.client("firehose", region_name=REGION)
s3 = boto3.client("s3", region_name=REGION) if QUARANTINE_BUCKET else None


def strict_parse(raw: str):
    try:
        return True, json.loads(raw)
    except JSONDecodeError:
        return False, raw


def encode_line(obj: dict) -> bytes:
    return json.dumps(obj, separators=(",", ":")).encode("utf-8")


def quarantine(msg_id: str, body: str, reason: str):
    if not s3:
        return

    event_wrapper = {"reason": reason, "raw": body}

    s3.put_object(
        Bucket=QUARANTINE_BUCKET,
        Key=f"{QUARANTINE_PREFIX}{msg_id}.json",
        Body=json.dumps(event_wrapper, separators=(",", ":")).encode("utf-8"),
        ContentType="application/json"
    )


def send_to_firehose(event, _ctx):
    failures: List[Dict[str, str]] = []

    for rec in event.get("Records", []):
        msg_id = rec["messageId"]
        body = rec.get("body", "")

        ok, parsed = strict_parse(body)

        if not ok:
            quarantine(msg_id, body, reason="invalid_json")
            continue

        payload = parsed if isinstance(parsed, dict) else {"payload": parsed}
        payload.setdefault("source", "cpp-api-streamhook")

        data = encode_line(payload)

        if len(data) > MAX_FIREHOSE_RECORD_BYTES:
            quarantine(msg_id, body, reason="record_exceeds_1mb")
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
            quarantine(msg_id, body, reason="firehose_put_failed")
            continue

    return {"batchItemFailures": failures}
