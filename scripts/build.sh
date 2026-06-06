#!/bin/bash

set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
image_name="pg-encrypted-backups:latest"

# pgbackrest.conf is bind-mounted at run time (see run-database.sh), not baked
# here, so one image serves both the local and GCS targets.

# Build from the docker/ directory (its Dockerfile COPYs config + scripts from there)
docker build \
    -t "${image_name}" \
    "${repo_root}/docker"
