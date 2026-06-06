#!/bin/bash
#
# Delta restore the latest backup from a stanza (the stanza decides local vs GCS).
# PostgreSQL must be stopped first - the viewer via stop-viewer.sh, the live
# source by stopping its container.
# Usage: restore.sh <stanza>

set -euo pipefail

stanza="${1:?usage: restore.sh <stanza>}"

echo "Restoring the latest backup from the ${stanza} stanza..."
pgbackrest --stanza="${stanza}" --log-level-console=info --repo=1 --delta restore