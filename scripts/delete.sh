#!/bin/bash
#
# Delete the image.

set -euo pipefail

image_name="pg-encrypted-backups:latest"

if docker images --format '{{.Repository}}:{{.Tag}}' | grep -q "^${image_name}$"; then
    echo "Deleting image ${image_name}..."
    docker rmi "${image_name}"
else
    echo "Image ${image_name} does not exist."
fi
