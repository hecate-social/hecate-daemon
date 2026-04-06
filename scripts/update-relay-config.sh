#!/bin/bash
# Update MACULA_RELAYS on all beam nodes for multi-homing.
# Uses actual relay identities (not box hostnames) from two different
# physical hosts for connection diversity.
#
# relay-de-munich   → Nuremberg host (closest to beam cluster)
# relay-de-berlin   → Nuremberg host (backup)
# relay-pl-warsaw   → Helsinki host  (diversity — different physical host)

set -euo pipefail

NODES="beam00.lab beam01.lab beam02.lab beam03.lab"
ENV_FILE=".hecate/gitops/system/hecate-daemon.env"

NEW_RELAYS="MACULA_RELAYS=https://relay-de-munich.macula.io:4433,https://relay-de-berlin.macula.io:4433,https://relay-pl-warsaw.macula.io:4433"

for NODE in ${NODES}; do
    echo "=== ${NODE} ==="

    # Replace MACULA_RELAYS line (whatever the old value is)
    ssh "rl@${NODE}" "sed -i 's|^MACULA_RELAYS=.*|${NEW_RELAYS}|' ~/${ENV_FILE}"
    echo "  Updated MACULA_RELAYS"

    # Add MACULA_CONNECTIONS if not present
    if ssh "rl@${NODE}" "grep -q MACULA_CONNECTIONS ~/${ENV_FILE}"; then
        echo "  MACULA_CONNECTIONS already set"
    else
        ssh "rl@${NODE}" "printf '\n# Multi-homing: concurrent relay connections\nMACULA_CONNECTIONS=2\n' >> ~/${ENV_FILE}"
        echo "  Added MACULA_CONNECTIONS=2"
    fi

    # Verify
    echo "  Config:"
    ssh "rl@${NODE}" "grep -E 'MACULA_RELAYS|MACULA_CONNECTIONS' ~/${ENV_FILE}" | sed 's/^/    /'
    echo ""
done

echo "Done. Restart daemons for changes to take effect:"
echo "  for n in beam00 beam01 beam02 beam03; do"
echo "    ssh rl@\${n}.lab 'cd ~/.hecate/compose && docker compose restart hecate-daemon'"
echo "  done"
