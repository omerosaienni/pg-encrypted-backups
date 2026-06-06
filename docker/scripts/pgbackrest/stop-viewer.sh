#!/bin/bash
#
# Stop PostgreSQL in the restore container (a restore needs it stopped).

set -euo pipefail

PGDATA="/var/lib/postgresql/data"
PGBIN="/usr/lib/postgresql/14/bin"

if "${PGBIN}/pg_isready" -q 2>/dev/null; then
    echo "Stopping PostgreSQL..."
    "${PGBIN}/pg_ctl" -D "${PGDATA}" -w -m fast stop
else
    echo "PostgreSQL is not running."
fi
