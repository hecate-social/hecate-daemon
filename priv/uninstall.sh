#!/bin/bash
set -e

# macula-hecate uninstaller

INSTALL_DIR="${INSTALL_DIR:-$HOME/.local/bin}"
DATA_DIR="${DATA_DIR:-$HOME/.hecate/hecate-daemon}"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

echo "========================================"
echo "macula-hecate uninstaller"
echo "========================================"
echo ""

# Check if hecate is running
check_running() {
    if pgrep -f "hecate" > /dev/null; then
        echo -e "${YELLOW}Warning: hecate is running${NC}"
        echo ""
        read -p "Stop hecate before uninstalling? (y/N) " -n 1 -r
        echo ""
        if [[ $REPLY =~ ^[Yy]$ ]]; then
            echo "Stopping hecate..."
            "$INSTALL_DIR/hecate" stop || true
            sleep 2
        else
            echo -e "${RED}Aborted: Please stop hecate manually first${NC}"
            exit 1
        fi
    fi
}

# Confirm uninstall
confirm_uninstall() {
    echo -e "${YELLOW}This will remove:${NC}"
    echo "  - Binary: $INSTALL_DIR/hecate"
    echo "  - Data:   $DATA_DIR"
    echo ""
    read -p "Are you sure? (y/N) " -n 1 -r
    echo ""
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        echo "Aborted."
        exit 0
    fi
}

# Backup data
backup_data() {
    if [ -d "$DATA_DIR" ]; then
        BACKUP_DIR="$HOME/hecate-backup-$(date +%Y%m%d_%H%M%S)"
        echo ""
        read -p "Backup data to $BACKUP_DIR? (Y/n) " -n 1 -r
        echo ""
        if [[ ! $REPLY =~ ^[Nn]$ ]]; then
            echo "Creating backup..."
            cp -r "$DATA_DIR" "$BACKUP_DIR"
            echo -e "${GREEN}✓ Backup created at $BACKUP_DIR${NC}"
        fi
    fi
}

# Uninstall hecate
uninstall() {
    echo ""
    echo "Uninstalling..."

    # Remove binary
    if [ -f "$INSTALL_DIR/hecate" ]; then
        rm -f "$INSTALL_DIR/hecate"
        echo -e "${GREEN}✓ Removed binary${NC}"
    else
        echo -e "${YELLOW}! Binary not found (already removed?)${NC}"
    fi

    # Remove data directory
    if [ -d "$DATA_DIR" ]; then
        rm -rf "$DATA_DIR"
        echo -e "${GREEN}✓ Removed data directory${NC}"
    else
        echo -e "${YELLOW}! Data directory not found (already removed?)${NC}"
    fi

    echo ""
    echo -e "${GREEN}✓ Uninstall complete${NC}"
    echo ""
}

# Print cleanup notes
print_notes() {
    echo "========================================"
    echo "Notes:"
    echo "========================================"
    echo ""
    echo "If you added hecate to PATH manually, you may want to remove it from:"
    echo "  - ~/.bashrc"
    echo "  - ~/.zshrc"
    echo ""
    echo "Look for lines like:"
    echo "  export PATH=\"\$HOME/.local/bin:\$PATH\""
    echo ""
}

# Main uninstall flow
main() {
    check_running
    confirm_uninstall
    backup_data
    uninstall
    print_notes
}

main
