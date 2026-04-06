# MinIO Infrastructure

My Shared MinIO object storage service used across multiple projects.

## Architecture

```
MinIO Instance
├── project-conv-rag-raw-documents/   ← raw uploaded documents (PDF, DOCX, images)
├── project-conv-rag-ocr-output/      ← OCR results (structured text, JSON)
├── project-agent-b-raw-documents/
├── project-agent-b-ocr-output/
└── shared/                           ← cross-project shared assets
```

### RAG Pipeline Data Flow

```
[Ingestion] → raw-documents → [OCR Service] → ocr-output → [Chunking/Embedding → Vector Store]
```

Each pipeline stage has its own bucket and dedicated credentials with least-privilege access.

## Quick Start (Docker)

```bash
# Copy and configure environment, replace with your actual value
cp .env.example .env

# Start MinIO
cd deploy/docker
docker compose up -d

# Initialize buckets and policies (if mc not installed, do it first [text](https://github.com/minio/mc))
cd ../../
./scripts/init-buckets.sh
```

## Deployment

| Environment | Method | Directory |
|------------|--------|-----------|
| Local/Dev | Docker Compose | `deploy/docker/` |
| Staging/Prod | Kubernetes + ArgoCD | `deploy/kubernetes/` |

## Project Onboarding

To add a new project:

1. Add bucket definitions in `scripts/init-buckets.sh`
2. Create access policies in `policies/` (one per pipeline stage)
3. Create dedicated credentials via `scripts/create-project-credentials.sh`
4. Share the endpoint + credentials with the project team

```bash
# Example: create credentials for the OCR service of project-conv-rag
./scripts/create-project-credentials.sh project-conv-rag ocr-output policies/project-conv-rag-ocr-output-policy.json
```

## Access Policies

Each project has 3 policies (in `policies/`):

| Policy | Service | Permissions |
|--------|---------|-------------|
| `*-raw-documents-policy.json` | Ingestion | Write to `raw-documents` |
| `*-ocr-output-policy.json` | OCR | Read `raw-documents`, write `ocr-output` |
| `*-readonly-policy.json` | Retrieval | Read `raw-documents` and `ocr-output` |

## Known Gotchas

### `s3:GetBucketLocation` required for SDK clients

The MinIO Python SDK (and other S3-compatible SDKs) calls `s3:GetBucketLocation` internally when using `bucket_exists()`. This operation is not obvious and is missing from most policy examples.

**Symptom:** `AccessDenied` error when connecting with scoped credentials, but works fine with root credentials.

**Fix:** Add `s3:GetBucketLocation` to the policy for every bucket the service calls `bucket_exists()` on:

```json
{
  "Effect": "Allow",
  "Action": ["s3:ListBucket", "s3:GetBucketLocation"],
  "Resource": ["arn:aws:s3:::your-bucket-name"]
}
```

## Monitoring

- MinIO Console: `http://localhost:9001`
- Prometheus metrics: `http://localhost:9000/minio/v2/metrics/cluster`
- Grafana dashboard: see `monitoring/grafana/`
