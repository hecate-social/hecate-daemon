#!/usr/bin/env bash
#
# Fix /etc/hosts on beam nodes: host00.lab must resolve to 192.168.1.100
# (workstation's beam-facing NIC), not 192.168.129.9 (router subnet).
#
# Run from workstation: ./scripts/fix-beam-hosts.sh
# Requires: sudo access on beam nodes (password: rl)
#
set -euo pipefail

HOSTS=(beam00.lab beam01.lab beam02.lab beam03.lab)
OLD_IP="192.168.129.9"
NEW_IP="192.168.1.100"
HOSTNAME="host00.lab"

for host in "${HOSTS[@]}"; do
    echo -n "$host: "
    ssh -o ConnectTimeout=3 "rl@$host" "
        if grep -q '$OLD_IP.*$HOSTNAME' /etc/hosts 2>/dev/null; then
            echo '$NEW_IP $HOSTNAME' | sudo tee /etc/hosts.d/host00.conf >/dev/null 2>&1 || \
            sudo sed -i 's|$OLD_IP.*$HOSTNAME|$NEW_IP\t$HOSTNAME|' /etc/hosts
            echo 'fixed ($OLD_IP → $NEW_IP)'
        elif grep -q '$NEW_IP.*$HOSTNAME' /etc/hosts 2>/dev/null; then
            echo 'already correct'
        else
            echo '$NEW_IP $HOSTNAME' | sudo tee -a /etc/hosts >/dev/null
            echo 'added'
        fi
    " 2>/dev/null || echo "FAILED"
done

echo ""
echo "Verify:"
for host in "${HOSTS[@]}"; do
    echo -n "$host: "
    ssh -o ConnectTimeout=3 "rl@$host" "getent hosts host00.lab" 2>/dev/null || echo "FAILED"
done
