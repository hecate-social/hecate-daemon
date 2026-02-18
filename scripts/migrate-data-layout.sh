#!/usr/bin/env bash
set -euo pipefail

# Migrate hecate-daemon data from flat ~/.hecate/ layout to namespaced
# ~/.hecate/hecate-daemon/ layout.
#
# MUST be run with the daemon STOPPED.
# Idempotent — safe to run multiple times.
#
# Old layout (flat):
#   ~/.hecate/daemon.sock, daemon.pid, daemon.state
#   ~/.hecate/hecate.db, query_*.db (+ WAL/SHM files)
#   ~/.hecate/reckon/{hecate, dev_studio}
#
# New layout (namespaced):
#   ~/.hecate/hecate-daemon/sockets/api.sock
#   ~/.hecate/hecate-daemon/run/daemon.pid, daemon.state
#   ~/.hecate/hecate-daemon/sqlite/hecate.db, query_*.db
#   ~/.hecate/hecate-daemon/reckon-db/{hecate, dev_studio}
#   ~/.hecate/hecate-daemon/connectors/

HECATE_ROOT="${HOME}/.hecate"
TARGET="${HECATE_ROOT}/hecate-daemon"

echo "=== Hecate Data Layout Migration ==="
echo "Source: ${HECATE_ROOT}/ (flat)"
echo "Target: ${TARGET}/ (namespaced)"
echo ""

# Preflight: daemon must be stopped
if [ -f "${HECATE_ROOT}/daemon.pid" ]; then
    PID=$(cat "${HECATE_ROOT}/daemon.pid" 2>/dev/null || echo "")
    if [ -n "${PID}" ] && kill -0 "${PID}" 2>/dev/null; then
        echo "ERROR: Daemon is running (PID ${PID}). Stop it first."
        echo "  ./scripts/stop-daemon.sh"
        exit 1
    fi
fi

# Also check new location
if [ -f "${TARGET}/run/daemon.pid" ]; then
    PID=$(cat "${TARGET}/run/daemon.pid" 2>/dev/null || echo "")
    if [ -n "${PID}" ] && kill -0 "${PID}" 2>/dev/null; then
        echo "ERROR: Daemon is running (PID ${PID}). Stop it first."
        exit 1
    fi
fi

# Create target directories
echo "[1/6] Creating directory layout..."
mkdir -p "${TARGET}/sqlite"
mkdir -p "${TARGET}/reckon-db"
mkdir -p "${TARGET}/sockets"
mkdir -p "${TARGET}/run"
mkdir -p "${TARGET}/connectors"
echo "  Done."

# Move SQLite databases
echo "[2/6] Migrating SQLite databases..."
MOVED_SQLITE=0
for db in "${HECATE_ROOT}"/*.db; do
    [ -f "${db}" ] || continue
    base=$(basename "${db}")
    if [ ! -f "${TARGET}/sqlite/${base}" ]; then
        mv "${db}" "${TARGET}/sqlite/${base}"
        echo "  Moved: ${base}"
        MOVED_SQLITE=$((MOVED_SQLITE + 1))
        # Move WAL and SHM files if they exist
        [ -f "${db}-wal" ] && mv "${db}-wal" "${TARGET}/sqlite/${base}-wal"
        [ -f "${db}-shm" ] && mv "${db}-shm" "${TARGET}/sqlite/${base}-shm"
    else
        echo "  Skip (exists): ${base}"
    fi
done
[ ${MOVED_SQLITE} -eq 0 ] && echo "  No SQLite files to migrate."

# Move ReckonDB data
echo "[3/6] Migrating ReckonDB data..."
if [ -d "${HECATE_ROOT}/reckon" ]; then
    for store in "${HECATE_ROOT}/reckon"/*/; do
        [ -d "${store}" ] || continue
        name=$(basename "${store}")
        if [ ! -d "${TARGET}/reckon-db/${name}" ]; then
            mv "${store}" "${TARGET}/reckon-db/${name}"
            echo "  Moved: reckon/${name} -> reckon-db/${name}"
        else
            echo "  Skip (exists): reckon-db/${name}"
        fi
    done
    # Remove empty reckon dir
    rmdir "${HECATE_ROOT}/reckon" 2>/dev/null || true
else
    echo "  No ReckonDB data to migrate."
fi

# Move runtime files
echo "[4/6] Migrating runtime files..."
for f in daemon.pid daemon.state; do
    if [ -f "${HECATE_ROOT}/${f}" ]; then
        mv "${HECATE_ROOT}/${f}" "${TARGET}/run/${f}"
        echo "  Moved: ${f} -> run/${f}"
    fi
done

# Clean up old socket (sockets are recreated on start)
echo "[5/6] Cleaning stale socket..."
if [ -S "${HECATE_ROOT}/daemon.sock" ]; then
    rm -f "${HECATE_ROOT}/daemon.sock"
    echo "  Removed: daemon.sock (will be recreated as sockets/api.sock)"
else
    echo "  No stale socket."
fi

# Migrate old connectors dir
echo "[6/6] Migrating connectors..."
OLD_CONNECTORS="${HOME}/.config/hecate/connectors"
if [ -d "${OLD_CONNECTORS}" ]; then
    for sock in "${OLD_CONNECTORS}"/*.sock; do
        [ -f "${sock}" ] || continue
        base=$(basename "${sock}")
        if [ ! -f "${TARGET}/connectors/${base}" ]; then
            cp "${sock}" "${TARGET}/connectors/${base}"
            echo "  Copied: ${base}"
        fi
    done
    echo "  Old connectors dir preserved at: ${OLD_CONNECTORS}"
else
    echo "  No old connectors directory."
fi

echo ""
echo "=== Migration complete ==="
echo ""
echo "New layout:"
find "${TARGET}" -maxdepth 2 -type f -o -type d | sort | head -30
echo ""
echo "Start the daemon with: ./scripts/restart-local.sh"
