#!/bin/bash
#
# Tell the whole migration story end to end, for a given stanza pair:
#   1. Archive to the <plain> stanza and take a backup.
#   2. More orders, migrate to the <encrypted> stanza (live), back up full + incr.
#   3. Inspect the latest backup in the viewer (look without touching production).
#   4. Roll the LIVE SOURCE back to either backup - the real recovery story.
#
# Usage: demo.sh [local|gcp]   (default: local)

set -euo pipefail

target="${1:-local}"
repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
case "${target}" in
    local)
        PLAIN=demo
        ENC=demo-encrypted
        ;;
    gcp)
        PLAIN=demo-gcp
        ENC=demo-gcp-encrypted
        # The GCS config only exists once Terraform has provisioned the bucket
        if [ ! -f "${repo_root}/docker/config/gcp/pgbackrest.conf" ]; then
            echo "No GCS config - run 'make build-gcs' first." >&2
            exit 1
        fi
        ;;
    *)
        echo "usage: demo.sh [local|gcp]" >&2
        exit 1
        ;;
esac

SRC=postgres-db
DST=postgres-restore-db

# Source helpers
psql_src()       { docker exec "${SRC}" psql -U myuser -d myuserdb "$@"; }
psql_src_super() { docker exec "${SRC}" psql -U postgres "$@"; }
backup_src()     { docker exec "${SRC}" "$@"; }

# Restore-container helpers
psql_dst()       { docker exec "${DST}" psql -U myuser -d myuserdb "$@"; }
restore_dst()    { docker exec "${DST}" "$@"; }

note()           { printf '\n=== %s ===\n' "$1"; }

# Wait for the database to be fully initialised - pg_isready alone can pass
# against the temporary server the base image runs during initdb, so poll for
# the seeded orders table (proof init-user-db.sh finished) instead.
wait_for_source_ready() {
    echo "Waiting for the source database to be ready..."
    for _ in $(seq 1 60); do
        if psql_src -tAc 'SELECT 1 FROM orders LIMIT 1' >/dev/null 2>&1; then
            return 0
        fi
        sleep 2
    done
    echo "Source database did not become ready in time." >&2
    exit 1
}

# Settle WAL archiving before the first backup. On a cold boot the archiver
# fails the first WAL (no stanza yet) and backs off; the first backup's check
# can then race that retry and time out. Create the stanza and wait for one
# successful archive so the round-trip is proven before we start.
wait_for_wal_archiving() {
    backup_src pgbackrest --stanza="${PLAIN}" stanza-create >/dev/null 2>&1 || true
    for _ in $(seq 1 30); do
        psql_src_super -q -c "SELECT pg_switch_wal();" >/dev/null 2>&1 || true
        if [ -n "$(psql_src_super -tAc 'SELECT last_archived_wal FROM pg_stat_archiver;' | tr -d '[:space:]')" ]; then
            return 0
        fi
        sleep 2
    done
    echo "WAL archiving did not start in time." >&2
    exit 1
}

# Restore a stanza back onto the LIVE SOURCE (the real "roll production back").
# The source runs postgres as PID 1, so we take the container down, restore into
# its pgdata from a throwaway container, then bring it back up - it boots on the
# restored data and promotes to a writable primary.
restore_onto_source() {
    stanza="$1"
    docker stop "${SRC}" >/dev/null
    docker run --rm \
        -v pgdata:/var/lib/postgresql/data \
        -v pgbackrest-repo:/var/lib/pgbackrest \
        -v "${repo_root}/docker/config/${target}/pgbackrest.conf:/etc/pgbackrest/pgbackrest.conf:ro" \
        -v "${repo_root}/secrets:/home/myuser/.config:ro" \
        pg-encrypted-backups:latest restore.sh "${stanza}"
    docker start "${SRC}" >/dev/null
    for _ in $(seq 1 30); do
        psql_src -tAc 'SELECT 1 FROM orders LIMIT 1' >/dev/null 2>&1 && break
        sleep 2
    done
}

wait_for_source_ready
wait_for_wal_archiving

note "Starting orders on the live database (archiving to the ${PLAIN} stanza)"
psql_src -c 'SELECT id, customer, amount FROM orders ORDER BY id;'

note "1. Backup to the ${PLAIN} (UNENCRYPTED) stanza"
backup_src backup.sh "${PLAIN}" full

note "2. More orders arrive after the unencrypted backup"
psql_src -c "INSERT INTO orders (customer, amount) VALUES ('Umbrella', 310.00), ('Soylent', 99.99);"
psql_src -c 'SELECT id, customer, amount FROM orders ORDER BY id;'

note "3. Migrate: point archiving at the ${ENC} stanza (live, no restart)"
psql_src_super -c "ALTER SYSTEM SET archive_command = 'pgbackrest --stanza=${ENC} archive-push %p';"
psql_src_super -c "SELECT pg_reload_conf();"
echo "   (the same switch can be made in the config file + a container restart)"

note "4. More orders, then a FULL encrypted backup to the ${ENC} stanza"
psql_src -c "INSERT INTO orders (customer, amount) VALUES ('Stark Industries', 1500.00);"
psql_src -c 'SELECT id, customer, amount FROM orders ORDER BY id;'
backup_src backup.sh "${ENC}" full

note "5. More orders, then an INCREMENTAL backup (only the changes since the full)"
psql_src -c "INSERT INTO orders (customer, amount) VALUES ('Cyberdyne', 640.00);"
psql_src -c 'SELECT id, customer, amount FROM orders ORDER BY id;'
backup_src backup.sh "${ENC}" incr

# --- Investigate a backup in the viewer (look without touching production) ---

note "6. Inspect the latest backup in the restore container (without touching the source)"
echo "   the viewer lets you see what a backup holds before you ever restore it"
restore_dst stop-viewer.sh
restore_dst restore.sh "${ENC}"
restore_dst start-viewer.sh
echo "   contents of the latest encrypted backup (full + incremental):"
psql_dst -c 'SELECT id, customer, amount FROM orders ORDER BY id;'
restore_dst stop-viewer.sh

# --- Recover: restore a backup onto the LIVE SOURCE - the real DR story ---

note "7. Roll the SOURCE back to the ${PLAIN} (UNENCRYPTED) backup"
echo "   the live source right now:"
psql_src -c 'SELECT count(*) AS orders FROM orders;'
echo "   taking the source down, restoring ${PLAIN} onto it, bringing it back..."
restore_onto_source "${PLAIN}"
echo "   the same source database, rolled back to the pre-migration backup:"
psql_src -c 'SELECT id, customer, amount FROM orders ORDER BY id;'

note "8. Roll the SOURCE back to the ${ENC} (ENCRYPTED) backup instead"
echo "   taking the source down, restoring ${ENC} onto it, bringing it back..."
restore_onto_source "${ENC}"
echo "   the same source database, now holding the latest encrypted backup:"
psql_src -c 'SELECT id, customer, amount FROM orders ORDER BY id;'

note "Done: investigated a backup in the viewer, then rolled the live source back to either stanza"
