#!/usr/bin/env bash
set -euo pipefail

# Folder that holds your per-region manifests
# (fix the path — you had a small typo "redeplot" vs "redeploy")
MANIFEST_DIR="${1:-infra/utils/lambda_config/redeploy_manifest}"

# Map filename prefix → AWS region
map_region() {
  case "$1" in
    us) echo "us-east-1" ;;
    eu) echo "eu-central-1" ;;
    ap) echo "ap-northeast-1" ;;
    *)  echo ""; return 1 ;;
  esac
}

# Find all "*-lambda-manifest.yaml" files in the directory
mapfile -t MANIFESTS < <(find "$MANIFEST_DIR" -type f -name '*-lambda-manifest.yaml' | sort)
if ((${#MANIFESTS[@]} == 0)); then
  echo "No manifests found in: $MANIFEST_DIR"
  exit 0
fi

for MF in "${MANIFESTS[@]}"; do
  base="$(basename "$MF")"          # e.g., us-lambda-manifest.yaml
  prefix="${base%%-*}"              # "us" | "eu" | "ap"
  REGION="$(map_region "$prefix" || true)"

  if [[ -z "$REGION" ]]; then
    echo "Cannot infer region from filename: $base — skipping."
    continue
  fi

  echo -e "\n==============================="
  echo "Manifest: $MF"
  echo "Region:   $REGION"
  echo "===============================\n"

  # Each item in the manifest needs: function_name, bucket, key
  yq -r '.[] | [.function_name, .bucket, .key] | @tsv' "$MF" |
  while IFS=$'\t' read -r FN BUCKET KEY; do
    [[ -z "${FN:-}" ]] && continue
    echo "→ $FN"

    # 1) Skip if function doesn't exist in this region
    if ! aws lambda get-function --region "$REGION" --function-name "$FN" >/dev/null 2>&1; then
      echo "[$FN] not found in $REGION — skipping."
      continue
    fi

    # 2) Current deployed code hash
    CUR_HASH=$(aws lambda get-function-configuration \
      --region "$REGION" \
      --function-name "$FN" \
      --query 'CodeSha256' --output text)

    # 3) New artifact hash from S3 (download to temp, hash, remove)
    TMP_ZIP="$(mktemp)"
    aws s3 cp --region "$REGION" "s3://$BUCKET/$KEY" "$TMP_ZIP" >/dev/null
    NEW_HASH=$(openssl dgst -binary -sha256 "$TMP_ZIP" | openssl base64)
    rm -f "$TMP_ZIP"

    # 4) Skip if no change
    if [[ "$CUR_HASH" == "$NEW_HASH" ]]; then
      echo "[$FN] no code change — skip."
      continue
    fi

    # 5) Update Lambda from S3
    aws lambda update-function-code \
      --region "$REGION" \
      --function-name "$FN" \
      --s3-bucket "$BUCKET" \
      --s3-key "$KEY" \
      --publish >/dev/null

    echo "[$FN] updated in $REGION from s3://$BUCKET/$KEY"
  done
done
