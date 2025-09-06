#!/usr/bin/env bash
set -euo pipefail

# update this path to your actual file:
YAML_FILE="${1:-utils/lambda_config/manifest.yaml}"

# yq v4: produce TSV rows: function_name \t bucket \t key
yq -r '.[] | [.function_name, .bucket, .key] | @tsv' "$YAML_FILE" |
while IFS=$'\t' read -r FN BUCKET KEY; do
  echo "=== Processing $FN ==="

  # 1) skip if lambda doesn't exist
  if ! aws lambda get-function --function-name "$FN" >/dev/null 2>&1; then
    echo "[$FN] Lambda not found. Skipping."
    continue
  fi

  # 2) current deployed hash
  CUR_HASH=$(aws lambda get-function-configuration \
    --function-name "$FN" \
    --query 'CodeSha256' --output text)

  # 3) new artifact hash from S3
  TMP_ZIP="$(mktemp)"
  aws s3 cp "s3://$BUCKET/$KEY" "$TMP_ZIP" >/dev/null
  NEW_HASH=$(openssl dgst -binary -sha256 "$TMP_ZIP" | openssl base64)
  rm -f "$TMP_ZIP"

  # 4) skip if no change
  if [[ "$CUR_HASH" == "$NEW_HASH" ]]; then
    echo "[$FN] No code change. Skipping."
    continue
  fi

  # 5) update from S3
  aws lambda update-function-code \
    --function-name "$FN" \
    --s3-bucket "$BUCKET" \
    --s3-key "$KEY" \
    --publish >/dev/null

  echo "[$FN] Updated from s3://$BUCKET/$KEY"
done
