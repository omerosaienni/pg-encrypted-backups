#!/bin/bash
#
# Open a shell in a container.

set -euo pipefail

container_name="${1:?usage: exec.sh <container-name>}"

docker exec -ti "${container_name}" bash
