#!/usr/bin/env bash
set -euo pipefail

# Migrate existing data from release CWD to ~/.hecate/
SRC="_build/default/rel/hecate/data"
DEST="${HOME}/.hecate"

if [ ! -d "${SRC}" ]; then
    echo "No existing data at ${SRC} — nothing to migrate."
    exit 0
fi

mkdir -p "${DEST}/reckon"

echo "Migrating data from ${SRC} to ${DEST}..."
cp -v "${SRC}"/*.db "${DEST}/" 2>/dev/null || true
cp -rv "${SRC}/reckon/"* "${DEST}/reckon/" 2>/dev/null || true
echo "Done. All data now in ${DEST}/"
