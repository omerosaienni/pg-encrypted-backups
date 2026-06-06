#!/bin/bash
#
# Backup to a stanza (the stanza name decides local vs GCS).
# Usage: backup.sh <stanza> [full|incr]   (default: full)

set -euo pipefail

stanza="${1:?usage: backup.sh <stanza> [full|incr]}"
type="${2:-full}"

# Wait for the real database (up to 60s). Querying the seeded orders table (not
# just pg_isready) proves init-user-db.sh finished - it avoids both the
# temporary init server (no myuserdb) and a half-initialised cluster (myuserdb
# exists but the seed has not run yet).
ready=
for _ in $(seq 1 30); do
    if psql -U postgres -d myuserdb -tAc 'SELECT 1 FROM orders LIMIT 1' >/dev/null 2>&1; then ready=1; break; fi
    echo "Waiting for PostgreSQL to be ready..."
    sleep 2
done
if [ -z "${ready}" ]; then
    echo "PostgreSQL did not become ready in time" >&2
    exit 1
fi

pgbackrest --stanza="${stanza}" --log-level-console=info stanza-create
pgbackrest --stanza="${stanza}" --log-level-console=info check
pgbackrest --stanza="${stanza}" --log-level-console=info --repo=1 --type="${type}" backup