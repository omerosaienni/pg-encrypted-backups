#!/bin/bash
#
# Reset to a clean slate: drop the local volumes and, if we provisioned a GCS
# bucket, empty its workspace too (stale stanzas there would clash next run).

set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

echo "Removing local volumes (this deletes all local backups)..."
docker volume rm -f pgdata pgbackrest-repo 2>/dev/null || true

# Only ever touch the bucket Terraform manages - never one the user pointed us
# at. terraform output is authoritative; skip quietly if there's no state/gcloud.
gcp_conf="${repo_root}/docker/config/gcp/pgbackrest.conf"
if [ -f "${gcp_conf}" ] && command -v gcloud >/dev/null; then
    bucket="$(cd "${repo_root}/terraform" && terraform output -raw bucket_name 2>/dev/null || true)"
    if [ -n "${bucket}" ]; then
        echo "Emptying gs://${bucket}/demo-workspace..."
        gcloud storage rm -r "gs://${bucket}/demo-workspace" 2>/dev/null || true
    fi
fi
