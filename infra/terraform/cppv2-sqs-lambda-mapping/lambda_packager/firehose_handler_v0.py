import os
import json
import time as _time
import uuid
from datetime import datetime, timezone
from typing import Any, Dict, List, Tuple

import boto3
from botocore.exceptions import BotoCoreError, ClientError
from json import JSONDecodeError


REGION          = os.environ.get("REGION")
EVENTS_BUCKET       = os.environ.get("EVENTS_BUCKET")
ERROR_EVENTS_PREFIX = os.environ.get("ERROR_EVENTS_PREFIX", "raw/cpp-v2-errors")

FIREHOSE_STREAM = os.environ["FIREHOSE_STREAM"]
DETAIL_TYPE = os.environ.get("DETAIL_TYPE")
SOURCE      = os.environ.get("EVENT_SOURCE", "cpp-api-streamhook")

MAX_LOCAL_RETRIES  = 3
BACKOFF_BASE_SECS  = 0.25
MAX_RECORD_BYTES   = 1000 * 1024  # ~1MB
RETRYABLE_ERRS     = {"ThrottlingException", "ServiceUnavailableException", "InternalFailure"}

fh = boto3.client("firehose", region_name=REGION)
s3 = boto3.client("s3", region_name=REGION) if EVENTS_BUCKET else None


def parse_json(raw: str) -> Tuple[bool, Any]:
    try:
        return True, json.loads(raw)
    except JSONDecodeError:
        return False, raw


def pass_ts_isoz() -> str:
    return datetime.now(tz=timezone.utc).replace(microsecond=0).isoformat().replace("+00:00", "Z")


def build_envelope(body: Any) -> Dict[str, Any]:
    """
    Wraps incoming SQS body (which starts at {"payload": [...]}) into EB-like shape:
    {
      "version": "0",
      "id": "...",
      "detail-type": "...",
      "source": "...",
      "account": None,
      "time": "2025-04-30T12:18:20Z",
      "region": "...",
      "resources": [],
      "detail": { "payload": [...] }
    }
    """
    if not isinstance(body, dict) or "payload" not in body:
        raise ValueError("SQS body must be a JSON object with a top-level 'payload' key")

    return {
        "version": "0",
        "id": f"lmbd-{uuid.uuid4()}",
        "detail-type": DETAIL_TYPE,
        "source": SOURCE,
        "account": None,
        "time": pass_ts_isoz(),
        "region": REGION,
        "resources": [],
        "detail": {"payload": body["payload"]},
    }


def encode(obj: Dict[str, Any]) -> bytes:
    return json.dumps(obj, separators=(",", ":")).encode("utf-8")


def archive_error(msg_id: str, body: str, reason: str) -> bool:
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
            Bucket=EVENTS_BUCKET,
            Key=key,
            Body=json.dumps(event_wrapper, separators=(",", ":")).encode("utf-8"),
            ContentType="application/json",
        )
        return True
    except Exception as e:
        print(f"[archive_error] failed: bucket={EVENTS_BUCKET} key={key} reason={reason} err={e}")
        return False


def send_to_firehose(event, _ctx):
    failures: List[Dict[str, str]] = []

    # mark record for success or retry/DLQ
    def archive_or_retry(msg_id: str, body: str, reason: str):
        if not archive_error(msg_id, body, reason):
            failures.append({"itemIdentifier": msg_id})

    for rec in event.get("Records", []):
        msg_id = rec.get("messageId", "unknown")
        body = rec.get("body", "")

        ok, parsed = parse_json(body)

        if not ok or not isinstance(parsed, dict):
            archive_or_retry(msg_id, body, "invalid_json")
            continue

        try:
            envelope = build_envelope(parsed)
        except Exception as e:
            print(f"[build_envelope] msg_id={msg_id} err={e}")
            archive_or_retry(msg_id, body, "missing_payload")
            continue

        data = encode(envelope)
        if len(data) > MAX_RECORD_BYTES:
            archive_or_retry(msg_id, body, "exceeds_1mb")
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
                if code not in RETRYABLE_ERRS or attempt == MAX_LOCAL_RETRIES:
                    break

            if not success and attempt < MAX_LOCAL_RETRIES:
                _time.sleep(BACKOFF_BASE_SECS * (2 ** (attempt - 1)))

        if not success:
            archive_or_retry(msg_id, body, "firehose_put_failed")

    return {"batchItemFailures": failures}






# import os
# import json
# import time
# import boto3
# from json import JSONDecodeError
# from typing import List, Dict
# from botocore.exceptions import BotoCoreError, ClientError
#
# REGION = os.environ["REGION"]
# FIREHOSE_STREAM = os.environ["FIREHOSE_STREAM"]
# EVENTS_BUCKET = os.environ.get("EVENTS_BUCKET")
# ERROR_EVENTS_PREFIX = os.environ.get("ERROR_EVENTS_PREFIX", "raw/cppv2-raw-errors/")
#
# MAX_FIREHOSE_RECORD_BYTES = 1000 * 1024  # ~1 MB
# RETRYABLE_ERR_CODES = {"ThrottlingException", "ServiceUnavailableException", "InternalFailure"}
# MAX_LOCAL_RETRIES = 3
# BACKOFF_BASE_SECONDS = 0.25
#
#
# fh = boto3.client("firehose", region_name=REGION)
# s3 = boto3.client("s3", region_name=REGION) if EVENTS_BUCKET else None
#
#
# def strict_parse(raw: str):
#     try:
#         return True, json.loads(raw)
#     except JSONDecodeError:
#         return False, raw
#
#
# def encode_line(obj: dict) -> bytes:
#     return json.dumps(obj, separators=(",", ":")).encode("utf-8")
#
#
# def archive_error_s3(msg_id: str, body: str, reason: str) -> bool:
#     """Write to S3; return True if dump to s3 or False if error."""
#     if not s3:
#         return True
#
#     try:
#         if reason in ("firehose_put_failed", "firehose_exceeds_1mb"):
#             key = f"{ERROR_EVENTS_PREFIX}/firehose_put_failed/{msg_id}.json"
#         else:
#             key = f"{ERROR_EVENTS_PREFIX}/{reason}/{msg_id}.json"
#
#         event_wrapper = {"reason": reason, "raw": body}
#
#         s3.put_object(
#             Bucket=EVENTS_BUCKET,
#             Key=key,
#             Body=json.dumps(event_wrapper, separators=(",", ":")).encode("utf-8"),
#             ContentType="application/json",
#         )
#         return True
#     except Exception as e:
#         print(f"[archive_error_s3] failed: bucket={EVENTS_BUCKET} key={key} reason={reason} err={e}")
#         return False
#
# def send_to_firehose(event, _ctx):
#     failures: List[Dict[str, str]] = []
#
#     # mark record for success or retry/DLQ
#     def archive_or_retry(msg_id: str, body: str, reason: str):
#         if not archive_error_s3(msg_id, body, reason):
#             failures.append({"itemIdentifier": msg_id})
#
#     for rec in event.get("Records", []):
#         msg_id = rec["messageId"]
#         body = rec.get("body", "")
#
#         ok, parsed = strict_parse(body)
#
#         if not ok:
#             archive_or_retry(msg_id, body, reason="invalid_json")
#             continue
#
#         payload = parsed if isinstance(parsed, dict) else {"payload": parsed}
#         payload.setdefault("source", "cpp-api-streamhook")
#
#         data = encode_line(payload)
#
#         if len(data) > MAX_FIREHOSE_RECORD_BYTES:
#             archive_or_retry(msg_id, body, reason="firehose_exceeds_1mb")
#             continue
#
#         # --------- explicit Firehose send with retries ---------
#
#         success = False
#         for attempt in range(1, MAX_LOCAL_RETRIES + 1):
#             try:
#                 resp = fh.put_record(
#                     DeliveryStreamName=FIREHOSE_STREAM,
#                     Record={"Data": data}
#                 )
#                 if "RecordId" in resp:
#                     success = True
#                     break
#
#             except (BotoCoreError, ClientError) as e:
#                 code = getattr(e, "response", {}).get("Error", {}).get("Code", "BotoCoreError")
#                 if code not in RETRYABLE_ERR_CODES or attempt == MAX_LOCAL_RETRIES:
#                     break
#
#             if attempt < MAX_LOCAL_RETRIES:
#                 time.sleep(BACKOFF_BASE_SECONDS * (2 ** (attempt - 1)))
#
#         # --------------------------------------------------------
#
#         if not success:
#             archive_or_retry(msg_id, body, reason="firehose_put_failed")
#             continue
#
#     return {"batchItemFailures": failures}
