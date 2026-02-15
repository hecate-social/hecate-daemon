#!/usr/bin/env bash
set -euo pipefail

# Clean restart hecate-daemon: stop, wipe all data, rebuild, start
# Usage: ./scripts/clean-restart.sh

DAEMON_DIR="$(cd "$(dirname "$0")/.." && pwd)"
REL_DIR="${DAEMON_DIR}/_build/default/rel/hecate"
REL_DATA="${REL_DIR}/data"
REL_HECATE_HOME="${REL_DIR}/.hecate"  # relative ~ expansion quirk
OLD_DATA="${DAEMON_DIR}/data"
USER_HECATE="${HOME}/.hecate"

echo "=== Hecate Daemon Clean Restart ==="
echo "Daemon dir: ${DAEMON_DIR}"
echo ""

# 1. Stop running daemon (handle heart auto-restart storms)
echo "[1/5] Stopping daemon..."
"${REL_DIR}/bin/hecate" stop 2>/dev/null || true
sleep 1

# Kill order: heart FIRST (it respawns beam), then run_erl, then beam.
# When daemon crash-loops, heart spawns many beam instances. Each heart
# respawns beam on death. We must kill ALL hearts before touching beam,
# then sweep up orphans until nothing remains.
kill_hecate_procs() {
    killall -9 heart 2>/dev/null || true
    pkill -9 -f "heart.*hecate" 2>/dev/null || true
    pkill -9 -f "run_erl.*hecate" 2>/dev/null || true
    pkill -9 -f "hecate/bin/hecate" 2>/dev/null || true
    pkill -9 -f "beam.*hecate" 2>/dev/null || true
    killall -9 beam.smp 2>/dev/null || true
    killall -9 run_erl 2>/dev/null || true
}

hecate_procs_alive() {
    pgrep -f "beam.*hecate" > /dev/null 2>&1 ||
    pgrep -f "heart.*hecate" > /dev/null 2>&1 ||
    pgrep -f "run_erl.*hecate" > /dev/null 2>&1
}

MAX_ATTEMPTS=10
for attempt in $(seq 1 "${MAX_ATTEMPTS}"); do
    if ! hecate_procs_alive; then
        break
    fi
    kill_hecate_procs
    sleep 1
    if [ "${attempt}" -gt 1 ]; then
        echo "  Attempt ${attempt}/${MAX_ATTEMPTS}: sweeping orphan processes..."
    fi
done

if hecate_procs_alive; then
    echo "  ERROR: Could not kill all hecate processes after ${MAX_ATTEMPTS} attempts."
    echo "  Remaining:"
    pgrep -af "beam.*hecate" 2>/dev/null || true
    pgrep -af "heart.*hecate" 2>/dev/null || true
    exit 1
else
    echo "  Daemon stopped."
fi

# Clean up socket and stale pipes
rm -f /run/hecate/daemon.sock
rm -rf /tmp/erl_pipes/hecate@*

# 2. Wipe data
echo "[2/5] Wiping data..."

# Release data dir (SQLite DBs + ReckonDB Raft logs)
if [ -d "${REL_DATA}" ]; then
    echo "  Removing: ${REL_DATA}/"
    rm -rf "${REL_DATA}"
fi

# Release ~/.hecate (node lifecycle DB)
if [ -d "${REL_HECATE_HOME}" ]; then
    echo "  Removing: ${REL_HECATE_HOME}/"
    rm -rf "${REL_HECATE_HOME}"
fi

# Old data dir (pre-rename DBs)
if [ -d "${OLD_DATA}" ]; then
    echo "  Removing: ${OLD_DATA}/"
    rm -rf "${OLD_DATA}"
fi

# User ~/.hecate (old hecate.db)
if [ -d "${USER_HECATE}" ]; then
    echo "  Removing: ${USER_HECATE}/"
    rm -rf "${USER_HECATE}"
fi

echo "  All data wiped."

# 3. Compile
echo "[3/5] Compiling..."
cd "${DAEMON_DIR}"
rebar3 compile

# 4. Build release
echo "[4/5] Building release..."
rebar3 release

# 5. Start daemon
echo "[5/5] Starting daemon..."
"${REL_DIR}/bin/hecate" daemon

# Wait for socket
echo "  Waiting for socket..."
for i in $(seq 1 15); do
    if [ -S /run/hecate/daemon.sock ]; then
        break
    fi
    sleep 1
done

if [ -S /run/hecate/daemon.sock ]; then
    echo ""
    echo "=== Daemon started ==="
    curl -s --unix-socket /run/hecate/daemon.sock http://localhost/health | python3 -m json.tool 2>/dev/null || \
    curl -s --unix-socket /run/hecate/daemon.sock http://localhost/health
    echo ""
else
    echo "  WARNING: Socket not found after 15s. Check logs:"
    echo "  ${REL_DIR}/log/erlang.log.1"
fi
