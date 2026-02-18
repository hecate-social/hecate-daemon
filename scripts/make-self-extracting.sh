#!/bin/bash
#
# Creates a self-extracting executable from a release tarball
#
# Usage: ./make-self-extracting.sh <tarball> <output>
#
set -euo pipefail

TARBALL="${1:-}"
OUTPUT="${2:-}"

if [[ -z "$TARBALL" || -z "$OUTPUT" ]]; then
    echo "Usage: $0 <tarball> <output>"
    exit 1
fi

if [[ ! -f "$TARBALL" ]]; then
    echo "Error: Tarball not found: $TARBALL"
    exit 1
fi

# Create the self-extracting script
cat > "$OUTPUT" << 'WRAPPER_HEAD'
#!/bin/bash
#
# Hecate Daemon - Self-extracting executable
#
set -euo pipefail

HECATE_HOME="${HECATE_HOME:-$HOME/.hecate/hecate-daemon}"
HECATE_CACHE="$HECATE_HOME/runtime"
MARKER="$HECATE_CACHE/.extracted"
VERSION="0.1.0"

# Extract on first run or version mismatch
extract_if_needed() {
    if [[ -f "$MARKER" ]] && grep -q "$VERSION" "$MARKER" 2>/dev/null; then
        return 0
    fi

    echo "Extracting Hecate daemon v$VERSION..." >&2
    mkdir -p "$HECATE_CACHE"

    # Find the archive marker and extract
    ARCHIVE_LINE=$(awk '/^__ARCHIVE__$/{print NR + 1; exit 0}' "$0")
    tail -n +"$ARCHIVE_LINE" "$0" | tar -xzf - -C "$HECATE_CACHE"

    echo "$VERSION" > "$MARKER"
    echo "Extraction complete." >&2
}

extract_if_needed

# Run the actual hecate binary
exec "$HECATE_CACHE/bin/hecate" "$@"

__ARCHIVE__
WRAPPER_HEAD

# Append the tarball
cat "$TARBALL" >> "$OUTPUT"

# Make executable
chmod +x "$OUTPUT"

echo "Created self-extracting executable: $OUTPUT"
echo "Size: $(du -h "$OUTPUT" | cut -f1)"
