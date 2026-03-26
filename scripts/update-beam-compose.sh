#!/usr/bin/env bash
#
# Add MACULA_MODE=client to beam node docker-compose.yml files.
# Run once to update the compose config on all beam nodes.
#
set -euo pipefail

NODES="beam00 beam01 beam02 beam03"
COMPOSE_PATH="\$HOME/.hecate/compose/docker-compose.yml"

for node in $NODES; do
    echo "=== ${node}.lab ==="

    # Check if MACULA_MODE already set
    if ssh "rl@${node}.lab" "grep -q MACULA_MODE ${COMPOSE_PATH} 2>/dev/null"; then
        echo "  MACULA_MODE already present, skipping"
        continue
    fi

    # Add MACULA_MODE=client after MACULA_HOSTNAME line
    ssh "rl@${node}.lab" "sed -i '/MACULA_HOSTNAME/a\\      - MACULA_MODE=client' ${COMPOSE_PATH}"
    echo "  Added MACULA_MODE=client"

    # Restart the container to pick up the new env
    ssh "rl@${node}.lab" "cd ~/.hecate/compose && docker compose up -d hecate-daemon"
    echo "  Restarted hecate-daemon"
done

echo ""
echo "Done. All beam nodes now run in client mode."
