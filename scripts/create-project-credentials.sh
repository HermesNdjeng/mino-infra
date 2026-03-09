#!/usr/bin/env bash
set -euo pipefail

# ---------------------------------------------------------------------------
# create-project-credentials.sh
# Creates a dedicated MinIO user with scoped access for a pipeline stage.
#
# Usage:
#   ./scripts/create-project-credentials.sh <project> <stage> <policy-file>
#
# Example:
#   ./scripts/create-project-credentials.sh project-conv-rag ocr-output \
#       policies/project-conv-rag-ocr-output-policy.json
# ---------------------------------------------------------------------------

if [[ $# -lt 3 ]]; then
  echo "Usage: $0 <project-name> <stage> <policy-file>"
  echo ""
  echo "  <project-name>  e.g. project-conv-rag"
  echo "  <stage>         one of: raw-documents, ocr-output, readonly"
  echo "  <policy-file>   path to the IAM policy JSON"
  echo ""
  echo "Example:"
  echo "  $0 project-conv-rag ocr-output policies/project-conv-rag-ocr-output-policy.json"
  exit 1
fi

PROJECT="$1"
STAGE="$2"
POLICY_FILE="$3"

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(dirname "$SCRIPT_DIR")"

# Load environment
if [[ -f "$ROOT_DIR/.env" ]]; then
  # shellcheck source=/dev/null
  source "$ROOT_DIR/.env"
else
  echo "ERROR: .env file not found."
  exit 1
fi

MINIO_ALIAS="${MINIO_ALIAS:-local}"
MINIO_ENDPOINT="${MINIO_ENDPOINT:-localhost}"
MINIO_API_PORT="${MINIO_API_PORT:-9000}"
MINIO_ROOT_USER="${MINIO_ROOT_USER:?MINIO_ROOT_USER is required}"
MINIO_ROOT_PASSWORD="${MINIO_ROOT_PASSWORD:?MINIO_ROOT_PASSWORD is required}"

# Re-configure alias (idempotent)
mc alias set "${MINIO_ALIAS}" \
  "http://${MINIO_ENDPOINT}:${MINIO_API_PORT}" \
  "${MINIO_ROOT_USER}" \
  "${MINIO_ROOT_PASSWORD}" \
  --api S3v4 > /dev/null

# ---------------------------------------------------------------------------
# Generate credentials
# ---------------------------------------------------------------------------
USERNAME="${PROJECT}-${STAGE}"
ACCESS_KEY="${USERNAME}-$(openssl rand -hex 4)"
SECRET_KEY="$(openssl rand -hex 20)"
POLICY_NAME="$(basename "${POLICY_FILE}" .json)"

echo "Creating user '${USERNAME}'..."
mc admin user add "${MINIO_ALIAS}" "${ACCESS_KEY}" "${SECRET_KEY}"

echo "Registering policy '${POLICY_NAME}'..."
mc admin policy create "${MINIO_ALIAS}" "${POLICY_NAME}" "${POLICY_FILE}" 2>/dev/null || true

echo "Attaching policy to user..."
mc admin policy attach "${MINIO_ALIAS}" "${POLICY_NAME}" --user "${ACCESS_KEY}"

# ---------------------------------------------------------------------------
# Output credentials
# ---------------------------------------------------------------------------
echo ""
echo "========================================"
echo " Credentials for ${PROJECT} / ${STAGE}"
echo "========================================"
echo " MINIO_ENDPOINT  = http://${MINIO_ENDPOINT}:${MINIO_API_PORT}"
echo " MINIO_ACCESS_KEY = ${ACCESS_KEY}"
echo " MINIO_SECRET_KEY = ${SECRET_KEY}"
echo "========================================"
echo " Store these securely — they will not be shown again."
echo ""
