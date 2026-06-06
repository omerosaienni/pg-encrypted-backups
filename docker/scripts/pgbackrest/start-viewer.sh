#!/bin/bash
#
# Start the viewer: PostgreSQL on a just-restored data dir, for inspection only.

set -euo pipefail

PGDATA="/var/lib/postgresql/data"
PGBIN="/usr/lib/postgresql/14/bin"

if [ ! -s "${PGDATA}/PG_VERSION" ]; then
    echo "No restored database found in ${PGDATA}." >&2
    echo "Run restore.sh first, then start-viewer.sh." >&2
    exit 1
fi

if "${PGBIN}/pg_isready" -q 2>/dev/null; then
    echo "PostgreSQL is already running."
    exit 0
fi

echo "Starting PostgreSQL on the restored data directory..."
# archive_mode=off: this is a throwaway viewer. The restored copy inherits the
# source's archive_command and shares its repo, so without this it would push its
# own (forked-timeline) WAL into the source's stanza and contaminate it.
"${PGBIN}/pg_ctl" -D "${PGDATA}" -w -l "${PGDATA}/startup.log" \
    -o "-c archive_mode=off" start

# After a restore the server replays WAL before it accepts connections - wait
# until it is actually ready
for _ in $(seq 1 30); do
    "${PGBIN}/pg_isready" -q && break
    sleep 1
done
if ! "${PGBIN}/pg_isready" -q; then
    echo "PostgreSQL did not become ready in time. Last startup log lines:" >&2
    tail -n 15 "${PGDATA}/startup.log" >&2 2>/dev/null || true
    exit 1
fi
