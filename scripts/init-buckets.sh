#!/usr/bin/env bash
set -euo pipefail

# ---------------------------------------------------------------------------
# init-buckets.sh
# Initializes MinIO buckets and access policies for all projects.
# Run from the repo root after MinIO is up:
#   ./scripts/init-buckets.sh
# ---------------------------------------------------------------------------

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(dirname "$SCRIPT_DIR")"

# Load environment
if [[ -f "$ROOT_DIR/.env" ]]; then
  # shellcheck source=/dev/null
  source "$ROOT_DIR/.env"
else
  echo "ERROR: .env file not found. Copy .env.example to .env and fill in credentials."
  exit 1
fi

MINIO_ALIAS="${MINIO_ALIAS:-local}"
MINIO_ENDPOINT="${MINIO_ENDPOINT:-localhost}"
MINIO_API_PORT="${MINIO_API_PORT:-9000}"
MINIO_ROOT_USER="${MINIO_ROOT_USER:?MINIO_ROOT_USER is required}"
MINIO_ROOT_PASSWORD="${MINIO_ROOT_PASSWORD:?MINIO_ROOT_PASSWORD is required}"

# ---------------------------------------------------------------------------
# Configure mc alias
# ---------------------------------------------------------------------------
echo "Configuring mc alias '${MINIO_ALIAS}'..."
mc alias set "${MINIO_ALIAS}" \
  "http://${MINIO_ENDPOINT}:${MINIO_API_PORT}" \
  "${MINIO_ROOT_USER}" \
  "${MINIO_ROOT_PASSWORD}" \
  --api S3v4

# ---------------------------------------------------------------------------
# Helper: create bucket if it doesn't exist
# ---------------------------------------------------------------------------
create_bucket() {
  local bucket="$1"
  if mc ls "${MINIO_ALIAS}/${bucket}" &>/dev/null; then
    echo "  [skip] bucket '${bucket}' already exists"
  else
    mc mb "${MINIO_ALIAS}/${bucket}"
    echo "  [ok]   created bucket '${bucket}'"
  fi
}

# ---------------------------------------------------------------------------
# Helper: apply a policy to a bucket
# ---------------------------------------------------------------------------
apply_policy() {
  local policy_name="$1"
  local policy_file="$2"
  mc admin policy create "${MINIO_ALIAS}" "${policy_name}" "${policy_file}"
  echo "  [ok]   applied policy '${policy_name}'"
}

# ---------------------------------------------------------------------------
# RAG Pipeline data flow:
#   raw-documents → ocr-output → chunks
# ---------------------------------------------------------------------------

echo ""
echo "=== project-conv-rag ==="
create_bucket "project-conv-rag-raw-documents"
create_bucket "project-conv-rag-ocr-output"
create_bucket "project-conv-rag-chunks"

# Enable versioning on raw-documents to protect source files
mc version enable "${MINIO_ALIAS}/project-conv-rag-raw-documents"
echo "  [ok]   versioning enabled on 'project-conv-rag-raw-documents'"

echo ""
echo "=== shared ==="
create_bucket "shared"

# ---------------------------------------------------------------------------
# Apply access policies
# ---------------------------------------------------------------------------
echo ""
echo "=== Applying policies ==="
POLICIES_DIR="$ROOT_DIR/policies"

for policy_file in "$POLICIES_DIR"/*.json; do
  policy_name="$(basename "${policy_file}" .json)"
  apply_policy "${policy_name}" "${policy_file}"
done

echo ""
echo "Bucket initialization complete."
mc ls "${MINIO_ALIAS}"
