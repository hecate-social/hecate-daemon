#!/usr/bin/env bash
# Provision beam nodes for Hecate site clustering (podman containers).
#
# Site A: beam00 + beam01 (shares cookie with host00.lab)
# Site B: beam02 (standalone)
# Site C: beam03 (standalone)
#
# Each node runs hecate-daemon as a podman container (Quadlet).
# Network=host means Erlang distribution works across container/native boundaries.
#
# Usage:
#   ./scripts/provision-beam-nodes.sh           # all 4 nodes
#   ./scripts/provision-beam-nodes.sh beam00    # single node

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"

SITE_A_COOKIE="ZMFTAHTHAYKXRVMPPQIZ"

# Generate stable cookies for B and C (or reuse if already generated)
COOKIE_FILE="${SCRIPT_DIR}/../.beam-cookies"
if [ -f "$COOKIE_FILE" ]; then
    source "$COOKIE_FILE"
fi
SITE_B_COOKIE="${SITE_B_COOKIE:-$(openssl rand -base64 20 | tr -dc 'A-Za-z' | head -c20)}"
SITE_C_COOKIE="${SITE_C_COOKIE:-$(openssl rand -base64 20 | tr -dc 'A-Za-z' | head -c20)}"

declare -A NODE_COOKIE
declare -A NODE_PEERS

NODE_COOKIE[beam00]="$SITE_A_COOKIE"
NODE_COOKIE[beam01]="$SITE_A_COOKIE"
NODE_COOKIE[beam02]="$SITE_B_COOKIE"
NODE_COOKIE[beam03]="$SITE_C_COOKIE"

# Site A: beam00, beam01, host00 cluster together
NODE_PEERS[beam00]="beam01.lab,host00.lab"
NODE_PEERS[beam01]="beam00.lab,host00.lab"
NODE_PEERS[beam02]=""
NODE_PEERS[beam03]=""

DAEMON_IMAGE="ghcr.io/hecate-social/hecate-daemon:latest"

ALL_NODES=(beam00 beam01 beam02 beam03)

if [ $# -gt 0 ]; then
    NODES=("$@")
else
    NODES=("${ALL_NODES[@]}")
fi

provision_node() {
    local node="$1"
    local cookie="${NODE_COOKIE[$node]}"
    local peers="${NODE_PEERS[$node]}"
    local fqdn="${node}.lab"

    echo ""
    echo "──────────────────────────────────────────────"
    echo "Provisioning: ${fqdn} (podman container)"
    echo "  Cookie: ${cookie:0:4}...${cookie: -4}"
    echo "  Peers:  ${peers:-none}"
    echo "──────────────────────────────────────────────"

    if ! ssh -o ConnectTimeout=5 "rl@${fqdn}" true 2>/dev/null; then
        echo "ERROR: Cannot SSH to rl@${fqdn} — skipping"
        return 1
    fi

    ssh "rl@${fqdn}" bash -s -- "$cookie" "$fqdn" "$peers" "$DAEMON_IMAGE" <<'REMOTE_SCRIPT'
set -euo pipefail
COOKIE="$1"
FQDN="$2"
PEERS="$3"
IMAGE="$4"
HECATE_DIR="$HOME/.hecate"

echo "  [1/7] Creating directory structure..."
mkdir -p "$HECATE_DIR/hecate-daemon"/{sqlite,reckon-db,sockets,run,connectors}
mkdir -p "$HECATE_DIR"/{config,secrets,gitops/system,gitops/apps}

echo "  [2/7] Setting cookie..."
chmod 600 ~/.erlang.cookie 2>/dev/null || true
echo -n "$COOKIE" > ~/.erlang.cookie
chmod 400 ~/.erlang.cookie

echo "  [3/7] Writing daemon env + vm.args..."

# vm.args mounted into container via VMARGS_PATH
cat > "$HECATE_DIR/hecate-daemon/vm.args" <<EOF
## Provisioned $(date -I) — managed by provision-beam-nodes.sh
-name hecate@${FQDN}
-setcookie ${COOKIE}
-heart
-mode interactive
-smp auto
+A 64
+P 1048576
+Q 65536
+sbt db
+SDio 32
EOF

cat > "$HECATE_DIR/gitops/system/hecate-daemon.env" <<EOF
# Hecate Daemon Configuration
# Provisioned $(date -I)

# Override vm.args inside container
VMARGS_PATH=$HECATE_DIR/hecate-daemon/vm.args

# Mesh
HECATE_REALM=io.macula
HECATE_BOOTSTRAP=https://boot.macula.io:443

# API (Unix socket)
HECATE_SOCKET_PATH=$HECATE_DIR/hecate-daemon/sockets/api.sock

# LLM
OLLAMA_HOST=http://localhost:11434

# BEAM Clustering
HECATE_ERLANG_COOKIE=${COOKIE}
HECATE_NODE_NAME=hecate@${FQDN}
HECATE_CLUSTER_PEERS=${PEERS}
EOF

echo "  [4/7] Writing Quadlet container file..."
cat > "$HECATE_DIR/gitops/system/hecate-daemon.container" <<EOF
[Unit]
Description=Hecate Daemon (core)
After=network-online.target
Wants=network-online.target

[Container]
Image=${IMAGE}
ContainerName=hecate-daemon
AutoUpdate=registry
Network=host

# HOME=%h so convention paths resolve correctly inside container
Environment=HOME=%h
Environment=XDG_RUNTIME_DIR=%t
Environment=DBUS_SESSION_BUS_ADDRESS=unix:path=%t/bus

# Volume mounts — paths identical inside/outside container
Volume=%h/.hecate/hecate-daemon:%h/.hecate/hecate-daemon:Z
Volume=%h/.hecate/gitops:%h/.hecate/gitops:Z

# Systemd/D-Bus access for plugin management
Volume=%t/systemd:%t/systemd:ro
Volume=%t/bus:%t/bus:ro

# Environment from files
EnvironmentFile=%h/.hecate/gitops/system/hecate-daemon.env
EnvironmentFile=-%h/.hecate/secrets/llm-providers.env

# Health check
HealthCmd=test -S %h/.hecate/hecate-daemon/sockets/api.sock
HealthInterval=30s
HealthRetries=3
HealthTimeout=5s
HealthStartPeriod=15s

[Service]
Restart=always
RestartSec=10s
TimeoutStartSec=120s

[Install]
WantedBy=default.target
EOF

echo "  [5/7] Stopping old daemon..."
systemctl --user stop hecate-daemon 2>/dev/null || true
# Also stop any native daemon that might be running
"$HOME/hecate/bin/hecate" stop 2>/dev/null || true
sleep 2

echo "  [6/7] Wiping stale reckon-db data..."
rm -rf "$HECATE_DIR/hecate-daemon/reckon-db"/*

echo "  [7/7] Installing Quadlet and starting daemon..."
# Ensure secrets file exists (even if empty)
touch "$HECATE_DIR/secrets/llm-providers.env"

# Symlink Quadlet files to systemd user config
mkdir -p ~/.config/containers/systemd
ln -sf "$HECATE_DIR/gitops/system/hecate-daemon.container" ~/.config/containers/systemd/hecate-daemon.container

# Reload systemd to pick up new Quadlet
systemctl --user daemon-reload

# Pull latest image
podman pull "$IMAGE" 2>&1 | tail -1 || echo "  (pull failed, using cached image)"

# Start
systemctl --user start hecate-daemon 2>/dev/null || true

# Wait for socket
echo -n "  Waiting for daemon"
for i in $(seq 1 20); do
    if [ -S "$HECATE_DIR/hecate-daemon/sockets/api.sock" ]; then
        echo " ready!"
        exit 0
    fi
    echo -n "."
    sleep 3
done
echo " (still starting — check: ssh rl@$FQDN 'journalctl --user -u hecate-daemon -f')"
REMOTE_SCRIPT
}

echo "=== Beam Node Provisioning (podman) ==="
echo "Image:  ${DAEMON_IMAGE}"
echo "Site A: beam00 + beam01 + host00 (cookie: ${SITE_A_COOKIE:0:4}...)"
echo "Site B: beam02 (standalone)"
echo "Site C: beam03 (standalone)"

for node in "${NODES[@]}"; do
    provision_node "$node" || true
done

# Save cookies
cat > "$COOKIE_FILE" <<EOF
# Beam node cookies (generated $(date -I))
SITE_A_COOKIE=${SITE_A_COOKIE}
SITE_B_COOKIE=${SITE_B_COOKIE}
SITE_C_COOKIE=${SITE_C_COOKIE}
EOF
chmod 600 "$COOKIE_FILE"

echo ""
echo "=== Provisioning complete ==="
echo "Cookies saved to: ${COOKIE_FILE}"
echo ""
echo "Verify Site A clustering from host00:"
echo "  erl -name probe@host00.lab -setcookie $SITE_A_COOKIE -noshell \\"
echo "    -eval \"net_adm:ping('hecate@beam00.lab'), net_adm:ping('hecate@beam01.lab'), io:format(\\\"~p~n\\\", [nodes()]), halt().\""
