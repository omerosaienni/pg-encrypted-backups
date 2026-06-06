#!/bin/bash

set -euo pipefail

container_name="${1:?usage: run-restore.sh <container-name>}"
image_name="pg-encrypted-backups:latest"

# Must match the source's target so we restore from the same repo (local or GCS)
target="${TARGET:-local}"
repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
config="${repo_root}/docker/config/${target}"

if docker ps --format '{{.Names}}' | grep -q "^${container_name}$"; then
    echo "Container ${container_name} already running."
    exit 0
fi

echo "Starting ${container_name} (${target})..."
mkdir -p "${repo_root}/secrets"
# Shares pgbackrest-repo with the source so it can restore those backups. No
# pgdata volume - the restore writes into the container's own dir. Boots idle
# (tail -f) so you can restore into it, then start it to inspect.
docker run -d \
    -v pgbackrest-repo:/var/lib/pgbackrest \
    -v "${config}/pgbackrest.conf:/etc/pgbackrest/pgbackrest.conf:ro" \
    -v "${repo_root}/secrets:/home/myuser/.config:ro" \
    --name "${container_name}" \
    -p 127.0.0.1:25432:5432 \
    "${image_name}" tail -f /dev/null
