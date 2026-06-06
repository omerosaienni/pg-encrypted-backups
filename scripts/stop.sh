#!/bin/bash
#
# Stop and remove a container.

set -euo pipefail

container_name="${1:?usage: stop.sh <container-name>}"

if [ -n "$(docker ps -a -q -f "name=${container_name}")" ]; then
    echo "Removing container ${container_name}..."
    docker rm -f "${container_name}"
else
    echo "Container ${container_name} does not exist."
fi
