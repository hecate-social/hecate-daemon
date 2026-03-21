#!/usr/bin/env bash
# Generate dev node vm.args files with -name and Site A cookie.
# All dev nodes cluster together on host00.lab.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
CONFIG_DIR="$(dirname "$SCRIPT_DIR")/config"
COOKIE="ZMFTAHTHAYKXRVMPPQIZ"
HOST="host00.lab"

for i in $(seq 0 6); do
    cat > "${CONFIG_DIR}/dev${i}.vm.args" <<EOF
## Dev node ${i} — Site A (clusters with hecate_dev on host00.lab)
-name hecate_dev${i}@${HOST}
-setcookie ${COOKIE}
-mode interactive
-smp auto
+A 16
+P 262144
+Q 16384
EOF
    echo "Generated dev${i}.vm.args"
done

echo "All dev node vm.args updated (cookie: ${COOKIE}, host: ${HOST})"
