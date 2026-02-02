#!/bin/bash
set -e

# macula-hecate installer
# Usage: curl https://macula.io/install/hecate-install.sh | sh

REPO="macula-io/macula-hecate"
INSTALL_DIR="${INSTALL_DIR:-$HOME/.local/bin}"
DATA_DIR="${DATA_DIR:-$HOME/.hecate}"
VERSION="${VERSION:-latest}"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

echo "========================================"
echo "macula-hecate installer"
echo "========================================"
echo ""

# Detect OS
detect_os() {
    case "$(uname -s)" in
        Linux*)     OS="linux";;
        Darwin*)    OS="darwin";;
        *)
            echo -e "${RED}Error: Unsupported OS${NC}"
            echo "Supported: Linux, macOS"
            exit 1
            ;;
    esac
}

# Detect architecture
detect_arch() {
    ARCH="$(uname -m)"
    case "$ARCH" in
        x86_64)     ARCH="amd64";;
        aarch64)    ARCH="arm64";;
        arm64)      ARCH="arm64";;
        *)
            echo -e "${RED}Error: Unsupported architecture: $ARCH${NC}"
            echo "Supported: x86_64 (amd64), aarch64/arm64"
            exit 1
            ;;
    esac
}

# Get latest version from GitHub
get_latest_version() {
    if [ "$VERSION" = "latest" ]; then
        VERSION=$(curl -s "https://api.github.com/repos/${REPO}/releases/latest" | grep '"tag_name":' | sed -E 's/.*"([^"]+)".*/\1/')
        if [ -z "$VERSION" ]; then
            echo -e "${YELLOW}Warning: Could not fetch latest version, using v0.1.0${NC}"
            VERSION="v0.1.0"
        fi
    fi
}

# Download and install
install_hecate() {
    TARBALL="hecate-${OS}-${ARCH}.tar.gz"
    URL="https://github.com/${REPO}/releases/download/${VERSION}/${TARBALL}"

    echo "Detected: $OS $ARCH"
    echo "Version: $VERSION"
    echo "Download URL: $URL"
    echo ""

    # Create directories
    echo "Creating directories..."
    mkdir -p "$INSTALL_DIR"
    mkdir -p "$DATA_DIR"

    # Download
    echo "Downloading hecate..."
    TEMP_DIR="$(mktemp -d)"
    cd "$TEMP_DIR"

    if command -v curl &> /dev/null; then
        curl -L -o "$TARBALL" "$URL" || {
            echo -e "${RED}Error: Download failed${NC}"
            echo "URL: $URL"
            rm -rf "$TEMP_DIR"
            exit 1
        }
    elif command -v wget &> /dev/null; then
        wget -O "$TARBALL" "$URL" || {
            echo -e "${RED}Error: Download failed${NC}"
            echo "URL: $URL"
            rm -rf "$TEMP_DIR"
            exit 1
        }
    else
        echo -e "${RED}Error: curl or wget required${NC}"
        rm -rf "$TEMP_DIR"
        exit 1
    fi

    # Extract
    echo "Extracting..."
    tar -xzf "$TARBALL" || {
        echo -e "${RED}Error: Extraction failed${NC}"
        rm -rf "$TEMP_DIR"
        exit 1
    }

    # Install binary
    echo "Installing to $INSTALL_DIR..."
    if [ -d "bin" ]; then
        cp bin/hecate "$INSTALL_DIR/hecate"
        chmod +x "$INSTALL_DIR/hecate"
    else
        echo -e "${RED}Error: bin/hecate not found in tarball${NC}"
        rm -rf "$TEMP_DIR"
        exit 1
    fi

    # Copy release files (lib, erts, etc.)
    RELEASE_DIR="$DATA_DIR/release"
    mkdir -p "$RELEASE_DIR"
    cp -r * "$RELEASE_DIR/" 2>/dev/null || true

    # Cleanup
    cd -
    rm -rf "$TEMP_DIR"

    echo ""
    echo -e "${GREEN}✓ Installation complete!${NC}"
    echo ""
}

# Check if already in PATH
check_path() {
    case ":$PATH:" in
        *":$INSTALL_DIR:"*)
            echo -e "${GREEN}✓ $INSTALL_DIR is already in PATH${NC}"
            ;;
        *)
            echo -e "${YELLOW}! $INSTALL_DIR is not in PATH${NC}"
            echo ""
            echo "Add to PATH by running:"
            echo ""
            if [ -f "$HOME/.bashrc" ]; then
                echo "  echo 'export PATH=\"\$HOME/.local/bin:\$PATH\"' >> ~/.bashrc"
                echo "  source ~/.bashrc"
            elif [ -f "$HOME/.zshrc" ]; then
                echo "  echo 'export PATH=\"\$HOME/.local/bin:\$PATH\"' >> ~/.zshrc"
                echo "  source ~/.zshrc"
            else
                echo "  export PATH=\"\$HOME/.local/bin:\$PATH\""
            fi
            echo ""
            ;;
    esac
}

# Print next steps
print_next_steps() {
    echo "========================================"
    echo "Next steps:"
    echo "========================================"
    echo ""
    echo "1. Initialize hecate:"
    echo "   hecate init"
    echo ""
    echo "2. Start hecate daemon:"
    echo "   hecate start"
    echo ""
    echo "3. Check health:"
    echo "   curl http://localhost:4444/health"
    echo ""
    echo "4. View logs:"
    echo "   tail -f ~/.hecate/logs/hecate.log"
    echo ""
    echo "Documentation: https://github.com/${REPO}"
    echo ""
}

# Main installation flow
main() {
    detect_os
    detect_arch
    get_latest_version
    install_hecate
    check_path
    print_next_steps
}

main
