#!/bin/bash

set -euo pipefail

container_name="${1:?usage: run-database.sh <container-name>}"
image_name="pg-encrypted-backups:latest"

# Backup target: local or gcp - picks which config dir to mount (gcp/ is
# Terraform-generated, so it only exists after `make build-gcs`)
target="${TARGET:-local}"
repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
config="${repo_root}/docker/config/${target}"

if docker ps --format '{{.Names}}' | grep -q "^${container_name}$"; then
    echo "Container ${container_name} already running."
    exit 0
fi

echo "Starting ${container_name} (${target})..."
mkdir -p "${repo_root}/secrets"
# Mount the per-target config instead of baking it, so one image serves both modes.
# archive.conf is a conf.d drop-in, not -c, so the demo's ALTER SYSTEM can override it.
docker run -d \
    -e POSTGRES_PASSWORD=mysecretpassword \
    -v pgdata:/var/lib/postgresql/data \
    -v pgbackrest-repo:/var/lib/pgbackrest \
    -v "${config}/pgbackrest.conf:/etc/pgbackrest/pgbackrest.conf:ro" \
    -v "${config}/archive.conf:/etc/postgresql/conf.d/archive.conf:ro" \
    -v "${repo_root}/secrets:/home/myuser/.config:ro" \
    --name "${container_name}" \
    -p 127.0.0.1:15432:5432 \
    "${image_name}"
