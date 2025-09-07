#!/usr/bin/env bash
set -euo pipefail

# Colors
RED="\033[1;31m"; GREEN="\033[1;32m"; YELLOW="\033[1;33m"
MAGENTA="\033[1;35m"; CYAN="\033[1;36m"; RESET="\033[0m"

MANIFEST_DIR="infra/utils/lambda_config/redeploy_manifest"

map_region() {
  case "$1" in
    us) echo "us-east-1" ;;
    eu) echo "eu-central-1" ;;
    ap) echo "ap-northeast-1" ;;
    *)  echo ""; return 1 ;;
  esac
}

pick_zip_key() {
  # Args: REGION BUCKET PREFIX
  local REGION="$1" BUCKET="$2" PREFIX="$3"
  local CANDIDATES KEY

  # List all keys
  CANDIDATES=$(aws s3api list-objects-v2 \
                 --region "$REGION" \
                 --bucket "$BUCKET" \
                 --prefix "$PREFIX" \
                 --query 'Contents[].Key' \
                 --output text 2>/dev/null || true)

  KEY="$(printf '%s\n' $CANDIDATES | awk '/\.zip$/ {print; exit}')"
  echo "$KEY"
}

mapfile -t MANIFESTS < <(find "$MANIFEST_DIR" -type f -name '*-lambda-manifest.yaml' | sort)

for MF in "${MANIFESTS[@]}"; do
  base="$(basename "$MF")"
  prefix_tag="${base%%-*}"
  REGION="$(map_region "$prefix_tag" || true)"

  echo -e "\n${MAGENTA}================================"
  echo -e " Manifest: ${CYAN}$MF${RESET}"
  echo -e " Region:   ${YELLOW}${REGION:-<unknown>}${RESET}"
  echo -e "================================${RESET}\n"

  # TSV: function_name, bucket, key/prefix, handler(export only)
  yq -r '.[] | [.function_name, .bucket, (.key // .prefix // ""), .handler] | @tsv' "$MF" |
  while IFS=$'\t' read -r FN BUCKET PREFIX HANDLER_EXPORT; do
    [[ -z "${FN:-}" ]] && continue
    echo -e "→ ${CYAN}$FN${RESET}"
    echo -e "   ${CYAN}bucket=${BUCKET} prefix=${PREFIX} handler=${HANDLER_EXPORT}${RESET}"

    # normalize handler
    if [[ -z "${HANDLER_EXPORT:-}" || "${HANDLER_EXPORT}" == "null" ]]; then
      HANDLER_EXPORT=""
    fi

    if [[ -z "$REGION" ]]; then
      echo -e "   ${RED}No region mapped '${prefix_tag}' — skipping.${RESET}"
      continue
    fi
    if ! aws lambda get-function --region "$REGION" --function-name "$FN" >/dev/null 2>&1; then
      echo -e "   ${RED}[$FN] not found in $REGION — skipping.${RESET}"
      continue
    fi

    # normalize prefix
    if [[ -z "${PREFIX}" ]]; then
      PREFIX="${FN}/"
    elif [[ "${PREFIX}" != */ ]]; then
      PREFIX="${PREFIX}/"
    fi

    KEY="$(pick_zip_key "$REGION" "$BUCKET" "$PREFIX")"
    if [[ -z "$KEY" || "$KEY" == "None" ]]; then
      echo -e "   ${YELLOW}No .zip found under s3://$BUCKET/${PREFIX}${RESET}"
      continue
    fi
    if ! aws s3api head-object --region "$REGION" --bucket "$BUCKET" --key "$KEY" >/dev/null 2>&1; then
      echo -e "   ${YELLOW}File missing: s3://$BUCKET/$KEY — skipping.${RESET}"
      continue
    fi

    echo -e "   Using: s3://$BUCKET/$KEY"

    # fetch current lambda config (pre-update)
    read -r CUR_HASH _ <<<"$(aws lambda get-function-configuration \
      --region "$REGION" --function-name "$FN" \
      --query '[CodeSha256, Handler]' --output text)"

    # compute new hash
    TMP_ZIP="$(mktemp)"
    aws s3 cp --region "$REGION" "s3://$BUCKET/$KEY" "$TMP_ZIP" >/dev/null
    NEW_HASH=$(openssl dgst -binary -sha256 "$TMP_ZIP" | openssl base64)
    rm -f "$TMP_ZIP"

    # update function code only if hash changed
    if [[ "$CUR_HASH" != "$NEW_HASH" ]]; then
      aws lambda update-function-code \
        --region "$REGION" \
        --function-name "$FN" \
        --s3-bucket "$BUCKET" \
        --s3-key "$KEY" \
        --publish >/dev/null
      echo -e "   ${GREEN}Updated code${RESET}"
    else
      echo -e "   ${YELLOW}No code change — skipped code update.${RESET}"
    fi

    # Wait until Lambda finishes any update
    aws lambda wait function-updated --region "$REGION" --function-name "$FN" || true

    # Re-fetch handler AFTER wait
    CUR_HANDLER="$(aws lambda get-function-configuration \
      --region "$REGION" --function-name "$FN" \
      --query 'Handler' --output text)"

    # build handler from zip name + YAML export and update if needed
    if [[ -n "${HANDLER_EXPORT}" ]]; then
      ZIP_BASENAME="$(basename "$KEY")"   # e.g. firehose_handler_v2.zip
      MODULE_NAME="${ZIP_BASENAME%.zip}"  # -> firehose_handler_v2
      DESIRED_HANDLER="${MODULE_NAME}.${HANDLER_EXPORT}"

      if [[ "$CUR_HANDLER" != "$DESIRED_HANDLER" ]]; then
        aws lambda update-function-configuration \
          --region "$REGION" \
          --function-name "$FN" \
          --handler "$DESIRED_HANDLER" >/dev/null
        echo -e "   ${GREEN}Handler set to${RESET} ${CYAN}$DESIRED_HANDLER${RESET}"
      else
        echo -e "   Handler already ${CYAN}$DESIRED_HANDLER${RESET} — no change."
      fi
    fi
  done
done
