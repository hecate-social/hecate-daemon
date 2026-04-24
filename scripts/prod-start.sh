#!/usr/bin/env bash
#
# Start hecate-daemon in prod-local devtime mode.
#
# Unlike dev-start.sh, prod-local:
#   - Connects to the REAL production relay mesh (no inproc backend).
#   - Uses ~/.hecate-prodlocal/ as data dir (distinct from ~/.hecate/
#     which belongs to a deployed daemon, and from ~/.hecate-dev/).
#   - Runs on port 4446 (api), 9445 (quic), 8182 (health) so it can
#     coexist with dev and prod on the same host.
#   - Node name hecate_prodlocal@<hostname> with its own cookie — no
#     accidental cluster joins.
#
# Usage:
#   ./scripts/prod-start.sh          # foreground (Ctrl+C to stop)
#   ./scripts/prod-start.sh console  # interactive shell
#
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"

cd "$PROJECT_DIR"

# Ensure prod-local data directory exists
mkdir -p ~/.hecate-prodlocal/hecate-daemon/{sqlite,reckon-db,sockets,run,connectors}
mkdir -p ~/.hecate-prodlocal/{config,gitops/system,searxng}

# Source prod-local environment if present (mirrors production
# EnvironmentFile pattern, but in the prodlocal namespace).
PROD_LOCAL_ENV="$HOME/.hecate-prodlocal/gitops/system/hecate-daemon.env"
REPO_ENV="$PROJECT_DIR/../hecate-gitops/quadlet/system/hecate-daemon.env"
if [ ! -f "$PROD_LOCAL_ENV" ] && [ -f "$REPO_ENV" ]; then
    cp "$REPO_ENV" "$PROD_LOCAL_ENV"
    echo "Seeded $PROD_LOCAL_ENV from hecate-gitops repo"
fi
if [ -f "$PROD_LOCAL_ENV" ]; then
    echo "Sourcing $PROD_LOCAL_ENV"
    set -a
    # shellcheck source=/dev/null
    . "$PROD_LOCAL_ENV"
    set +a
fi

# Override socket path for prod-local
export HECATE_SOCKET_PATH="$HOME/.hecate-prodlocal/hecate-daemon/sockets/api.sock"

# Client mode against the real relay fleet — this is the whole point
# of prod-local vs dev.
export MACULA_MODE=client

# Relay fleet — use the same BE virtual identities as the beam nodes
# (see macula-demo/infrastructure/beam0*/hecate-daemon.env.example).
# Sharing relay identities with the beams is required for the relay
# server's pubsub fanout — fanout doesn't cross identity boundaries
# even when two virtuals share a physical box. Override via
# MACULA_RELAYS env if testing an alt fleet.
export MACULA_RELAYS="${MACULA_RELAYS:-https://relay-be-leuven.macula.io:4433,https://relay-be-antwerp.macula.io:4433,https://relay-be-ghent.macula.io:4433}"

# BEAM cluster cookie + peers (lab topology: laptop <-> beam00..03).
# Settings live here (tracked, survives --clear) rather than in the
# ephemeral prod-local env file. They match
# macula-demo/infrastructure/beam0*/hecate-daemon.env.example so the
# attended laptop shares identity with the headless fleet and can
# pg-broadcast realm credentials to them.
export HECATE_ERLANG_COOKIE="${HECATE_ERLANG_COOKIE:-ZMFTAHTHAYKXRVMPPQIZ}"
export HECATE_CLUSTER_PEERS="${HECATE_CLUSTER_PEERS:-hecate@beam00.lab,hecate@beam01.lab,hecate@beam02.lab,hecate@beam03.lab}"

# Force real-mesh backend even if a stray env var tries to flip it.
# The inproc backend is strictly dev/test territory.
export HECATE_MESH_BACKEND=client

# MaxMind GeoIP: extract license key from GeoIP.conf if not already set
if [ -z "${MAXMIND_LICENSE_KEY:-}" ] && [ -f "$HOME/.config/maxmind/GeoIP.conf" ]; then
    MAXMIND_LICENSE_KEY="$(grep '^LicenseKey' "$HOME/.config/maxmind/GeoIP.conf" | awk '{print $2}')"
    export MAXMIND_LICENSE_KEY
    echo "Loaded MAXMIND_LICENSE_KEY from ~/.config/maxmind/GeoIP.conf"
fi

# Standard EPMD for node discovery
unset ERL_DIST_PORT

# Tell macula our LAN hostname for correct DHT advertising
export MACULA_HOSTNAME="$(/usr/bin/hostname -f 2>/dev/null || cat /etc/hostname)"

# Clean stale socket
rm -f "$HECATE_SOCKET_PATH"

# Kill stale BEAM holding the prod-local node name
if pgrep -f 'name hecate_prodlocal[@: ]' > /dev/null 2>&1; then
    echo "Killing stale hecate_prodlocal BEAM process..."
    pkill -f 'name hecate_prodlocal[@: ]' || true
    sleep 2
fi

# Build release from current sources
echo "Building prod-local release..."
rebar3 release

MODE="${1:-foreground}"

# Symlink prodlocal configs into the release dir so relx resolves
# them relative to RELEASE_ROOT_DIR.
REL_DIR="$PROJECT_DIR/_build/default/rel/hecate"
ln -sf "$PROJECT_DIR/config/prodlocal.sys.config" "$REL_DIR/prodlocal.sys.config"
ln -sf "$PROJECT_DIR/config/prodlocal.vm.args" "$REL_DIR/prodlocal.vm.args"
export RELX_CONFIG_PATH="$REL_DIR/prodlocal.sys.config"
export VMARGS_PATH="$REL_DIR/prodlocal.vm.args"

echo ""
echo "=== Hecate Prod-Local (real mesh) ==="
echo "  Data:      ~/.hecate-prodlocal/hecate-daemon/"
echo "  Socket:    ~/.hecate-prodlocal/hecate-daemon/sockets/api.sock"
echo "  API port:  4446 (dev: 4445, deployed prod: 4444)"
echo "  QUIC port: 9445 (dev: 9444, deployed prod: 9443)"
echo "  Mesh:      REAL (connects to production relay fleet)"
echo "  VMARGS:    $VMARGS_PATH"
echo "  SYSCONFIG: $RELX_CONFIG_PATH"
echo ""

exec _build/default/rel/hecate/bin/hecate "$MODE"
