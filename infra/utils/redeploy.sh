#!/usr/bin/env bash
set -euo pipefail

YAML_FILE="${1:-lambdas_config/manifest.yaml}"

yq -c '.[]' "$YAML_FILE" | while read -r lambda; do
  FN=$(echo "$lambda" | yq -r '.function_name')
  BUCKET=$(echo "$lambda" | yq -r '.bucket')
  KEY=$(echo "$lambda" | yq -r '.key')

  echo "=== Processing $FN ==="

  if ! aws lambda get-function --function-name "$FN" >/dev/null 2>&1; then
    echo "[$FN] Lambda not found. Skipping."
    continue
  fi

  CUR_HASH=$(aws lambda get-function-configuration \
    --function-name "$FN" \
    --query 'CodeSha256' --output text)

  TMP_ZIP="$(mktemp)"
  aws s3 cp "s3://$BUCKET/$KEY" "$TMP_ZIP" >/dev/null
  NEW_HASH=$(openssl dgst -binary -sha256 "$TMP_ZIP" | openssl base64)
  rm -f "$TMP_ZIP"

  if [[ "$CUR_HASH" == "$NEW_HASH" ]]; then
    echo "[$FN] No code change. Skipping."
    continue
  fi

  aws lambda update-function-code \
    --function-name "$FN" \
    --s3-bucket "$BUCKET" \
    --s3-key "$KEY" \
    --publish >/dev/null

  echo "[$FN] Updated from s3://$BUCKET/$KEY"
done
