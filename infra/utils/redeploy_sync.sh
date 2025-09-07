#!/usr/bin/env bash
set -euo pipefail

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

mapfile -t MANIFESTS < <(find "$MANIFEST_DIR" -type f -name '*-lambda-manifest.yaml' | sort)

for MF in "${MANIFESTS[@]}"; do
  base="$(basename "$MF")"
  prefix="${base%%-*}"
  REGION="$(map_region "$prefix" || true)"

  echo -e "\n${MAGENTA}================================"
  echo -e " Manifest: ${CYAN}$MF${RESET}"
  echo -e " Region:   ${YELLOW}$REGION${RESET}"
  echo -e "================================${RESET}\n"

  # function_name, bucket, key/prefix, optional filename (ignored if empty), optional handler (export only)
  yq -r '.[] | [.function_name, .bucket, (.key // .prefix // ""), (.filename // ""), (.handler // "")] | @tsv' "$MF" |
  while IFS=$'\t' read -r FN BUCKET PREFIX FILENAME HANDLER_EXPORT; do
    [[ -z "${FN:-}" ]] && continue
    echo -e "→ ${CYAN}$FN${RESET}"

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

    # choose artifact:
    # - if YAML gave .filename, use it
    # - else pick most recent .zip under prefix
    if [[ -n "${FILENAME}" ]]; then
      KEY="${PREFIX}${FILENAME}"
    else
      KEY=$(aws s3api list-objects-v2 \
              --region "$REGION" \
              --bucket "$BUCKET" \
              --prefix "$PREFIX" \
              --query 'reverse(sort_by(Contents[?ends_with(Key, `.zip`)==`true`], &LastModified))[:1].Key' \
              --output text 2>/dev/null || true)
    fi

    if [[ -z "$KEY" || "$KEY" == "None" ]] || ! aws s3api head-object --region "$REGION" --bucket "$BUCKET" --key "$KEY" >/dev/null 2>&1; then
      echo -e "   ${YELLOW}No usable .zip at s3://$BUCKET/${PREFIX} (or file missing) — skipping.${RESET}"
      continue
    fi

    echo -e "   Using: s3://$BUCKET/$KEY"

    # current config
    read -r CUR_HASH CUR_HANDLER <<<"$(aws lambda get-function-configuration \
      --region "$REGION" --function-name "$FN" \
      --query '[CodeSha256, Handler]' --output text)"

    # compute new hash
    TMP_ZIP="$(mktemp)"
    aws s3 cp --region "$REGION" "s3://$BUCKET/$KEY" "$TMP_ZIP" >/dev/null
    NEW_HASH=$(openssl dgst -binary -sha256 "$TMP_ZIP" | openssl base64)
    rm -f "$TMP_ZIP"

    # update code if changed
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

    # if YAML has handler export, compose "<module>.<export>" from the chosen zip and set it
    if [[ -n "${HANDLER_EXPORT}" ]]; then
      ZIP_BASENAME="$(basename "$KEY")"          # e.g., firehose_handler_v2.zip
      MODULE_NAME="${ZIP_BASENAME%.zip}"         # -> firehose_handler_v2
      DESIRED_HANDLER="${MODULE_NAME}.${HANDLER_EXPORT}"  # -> firehose_handler_v2.send_to_firehose
      if [[ "$CUR_HANDLER" != "$DESIRED_HANDLER" ]]; then
        aws lambda update-function-configuration \
          --region "$REGION" \
          --function-name "$FN" \
          --handler "$DESIRED_HANDLER" >/dev/null
        echo -e "   ${GREEN}Handler set to${RESET} ${CYAN}$DESIRED_HANDLER${RESET}"
      else
        echo -e "   Handler already ${CYAN}$DESIRED_HANDLER${RESET} — no change."
      fi
    else
      echo -e "   No 'handler' in YAML — leaving handler unchanged."
    fi
  done
done



##!/usr/bin/env bash
#set -euo pipefail
#
## Colors
#RED="\033[1;31m"
#GREEN="\033[1;32m"
#YELLOW="\033[1;33m"
#MAGENTA="\033[1;35m"
#CYAN="\033[1;36m"
#RESET="\033[0m"
#
#MANIFEST_DIR="infra/utils/lambda_config/redeploy_manifest"
#
#map_region() {
#  case "$1" in
#    us) echo "us-east-1" ;;
#    eu) echo "eu-central-1" ;;
#    ap) echo "ap-northeast-1" ;;
#    *)  echo ""; return 1 ;;
#  esac
#}
#
#mapfile -t MANIFESTS < <(find "$MANIFEST_DIR" -type f -name '*-lambda-manifest.yaml' | sort)
#
#for MF in "${MANIFESTS[@]}"; do
#  base="$(basename "$MF")"
#  prefix="${base%%-*}"
#  REGION="$(map_region "$prefix" || true)"
#
#  echo -e "\n${MAGENTA}================================"
#  echo -e " Manifest: ${CYAN}$MF${RESET}"
#  echo -e " Region:   ${YELLOW}$REGION${RESET}"
#  echo -e "================================${RESET}\n"
#
#  # read function_name + bucket (+ optional prefix)
#  # read: function_name, bucket, prefix(from key), optional filename
#  yq -r '.[] | [.function_name, .bucket, (.key // .prefix // ""), (.filename // "")] | @tsv' "$MF" |
#  while IFS=$'\t' read -r FN BUCKET PREFIX FILENAME; do
#    [[ -z "${FN:-}" ]] && continue
#    echo -e "→ ${CYAN}$FN${RESET}"
#
#    # ensure function exists
#    if ! aws lambda get-function --region "$REGION" --function-name "$FN" >/dev/null 2>&1; then
#      echo -e "   ${RED}[$FN] not found in $REGION — skipping.${RESET}"
#      continue
#    fi
#
#    # normalize prefix (allow empty -> default to "<function_name>/")
#    if [[ -z "${PREFIX}" ]]; then
#      PREFIX="${FN}/"
#    elif [[ "${PREFIX}" != */ ]]; then
#      PREFIX="${PREFIX}/"
#    fi
#
#    if [[ -n "${FILENAME}" ]]; then
#      # exact file requested
#      KEY="${PREFIX}${FILENAME}"
#      if ! aws s3api head-object --region "$REGION" --bucket "$BUCKET" --key "$KEY" >/dev/null 2>&1; then
#        echo -e "   ${YELLOW}File not found: s3://$BUCKET/$KEY — skipping.${RESET}"
#        continue
#      fi
#    else
#      # pick most recent .zip under the prefix
#      KEY=$(aws s3api list-objects-v2 \
#              --region "$REGION" \
#              --bucket "$BUCKET" \
#              --prefix "$PREFIX" \
#              --query 'reverse(sort_by(Contents[?ends_with(Key, `.zip`)==`true`], &LastModified))[:1].Key' \
#              --output text 2>/dev/null || true)
#      if [[ -z "$KEY" || "$KEY" == "None" ]]; then
#        echo -e "   ${YELLOW}No .zip found under s3://$BUCKET/${PREFIX} — skipping.${RESET}"
#        continue
#      fi
#    fi
#
#    echo -e "   Using: s3://$BUCKET/$KEY"
#
#    # fetch current lambda hash
#    CUR_HASH=$(aws lambda get-function-configuration \
#      --region "$REGION" --function-name "$FN" \
#      --query 'CodeSha256' --output text)
#
#    # hash chosen artifact
#    TMP_ZIP="$(mktemp)"
#    aws s3 cp --region "$REGION" "s3://$BUCKET/$KEY" "$TMP_ZIP" >/dev/null
#    NEW_HASH=$(openssl dgst -binary -sha256 "$TMP_ZIP" | openssl base64)
#    rm -f "$TMP_ZIP"
#
#    if [[ "$CUR_HASH" == "$NEW_HASH" ]]; then
#      echo -e "   ${YELLOW}No code change — skipped.${RESET}"
#      continue
#    fi
#
#    aws lambda update-function-code \
#      --region "$REGION" \
#      --function-name "$FN" \
#      --s3-bucket "$BUCKET" \
#      --s3-key "$KEY" \
#      --publish >/dev/null
#
#    echo -e "   ${GREEN}Updated${RESET} from s3://$BUCKET/$KEY"
#  done
#done