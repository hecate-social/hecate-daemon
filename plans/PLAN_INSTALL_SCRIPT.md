# PLAN: Install Script

**Status:** Planning
**Created:** 2026-01-31
**Priority:** High
**Depends On:** PLAN_AGENT_ONBOARDING.md

---

## Mission

Enable one-command installation: `curl -sSL https://macula.io/hecate.sh | sh`

This installer must:
- Work on Linux, macOS, Windows (WSL2)
- Detect OS and architecture automatically
- Download appropriate binary from GitHub releases
- Install to standard location
- Initialize identity
- Optionally start pairing flow
- Show clear next steps

---

## Success Metrics

| Metric | Target |
|--------|--------|
| **Installation success rate** | > 99% |
| **Time to install** | < 2 minutes |
| **Platforms supported** | Linux (amd64/arm64), macOS (amd64/arm64), Windows WSL2 |
| **Automatic updates** | Check for new version on each run |
| **Error messages** | Clear, actionable |

---

## Architecture

```
curl https://macula.io/hecate.sh | sh
    ↓
┌─────────────────────────────────────────┐
│ install.sh (Bash script)                │
│                                         │
│ 1. Detect OS/arch                       │
│ 2. Check dependencies (curl, tar)       │
│ 3. Download from GitHub releases        │
│ 4. Extract and install                  │
│ 5. Run hecate init                      │
│ 6. Optionally pair                      │
│ 7. Show next steps                      │
└─────────────────────────────────────────┘
    ↓
Installed to: ~/.local/bin/hecate
Identity: ~/.hecate/identity.json
Config: ~/.hecate/config.json
```

---

## Script Location

### Development

`macula-hecate/priv/install.sh` - Tracked in repo

### Production

Hosted at `https://macula.io/hecate.sh` via macula-realm:

```
macula-realm/
└── priv/
    └── static/
        └── install/
            └── hecate.sh  # Symlink or copy from macula-hecate
```

Served by Phoenix at `/install/hecate.sh` → redirects to `https://macula.io/hecate.sh`

---

## Script Implementation

### priv/install.sh

```bash
#!/usr/bin/env bash
set -euo pipefail

#═══════════════════════════════════════════════════════════════
# Hecate Installer
# Install hecate daemon to your machine in one command.
#
# Usage:
#   curl -sSL https://macula.io/hecate.sh | sh
#
# Options (via environment variables):
#   HECATE_VERSION=0.1.0  # Install specific version (default: latest)
#   HECATE_DIR=/custom/path  # Install directory (default: ~/.local/bin)
#   SKIP_INIT=1  # Skip hecate init step
#   SKIP_PAIR=1  # Skip pairing prompt
#═══════════════════════════════════════════════════════════════

readonly REPO="macula-io/macula-hecate"
readonly INSTALL_DIR="${HECATE_DIR:-${HOME}/.local/bin}"
readonly DATA_DIR="${HOME}/.hecate"
readonly SKIP_INIT="${SKIP_INIT:-0}"
readonly SKIP_PAIR="${SKIP_PAIR:-0}"

# Colors
readonly RED='\033[0;31m'
readonly GREEN='\033[0;32m'
readonly YELLOW='\033[1;33m'
readonly BLUE='\033[0;34m'
readonly NC='\033[0m' # No Color

# Detect OS and architecture
detect_platform() {
    local os arch

    # Detect OS
    case "$(uname -s)" in
        Linux*)     os="linux" ;;
        Darwin*)    os="darwin" ;;
        MINGW*|MSYS*|CYGWIN*) os="windows" ;;
        *)
            echo -e "${RED}Error: Unsupported OS: $(uname -s)${NC}" >&2
            echo "Supported: Linux, macOS, Windows (WSL2)" >&2
            exit 1
            ;;
    esac

    # Detect architecture
    case "$(uname -m)" in
        x86_64|amd64)   arch="amd64" ;;
        aarch64|arm64)  arch="arm64" ;;
        armv7l)         arch="armv7" ;;
        *)
            echo -e "${RED}Error: Unsupported architecture: $(uname -m)${NC}" >&2
            echo "Supported: x86_64 (amd64), aarch64 (arm64), armv7l" >&2
            exit 1
            ;;
    esac

    echo "${os}-${arch}"
}

# Get latest version from GitHub
get_latest_version() {
    local version
    version=$(curl -sSf "https://api.github.com/repos/${REPO}/releases/latest" \
        | grep '"tag_name"' \
        | sed -E 's/.*"tag_name": "v?([^"]+)".*/\1/')

    if [ -z "$version" ]; then
        echo -e "${RED}Error: Could not determine latest version${NC}" >&2
        exit 1
    fi

    echo "$version"
}

# Download and install
install_hecate() {
    local platform=$1
    local version=${HECATE_VERSION:-$(get_latest_version)}
    local filename="hecate-${platform}.tar.gz"
    local url="https://github.com/${REPO}/releases/download/v${version}/${filename}"
    local tmp_dir=$(mktemp -d)

    echo -e "${BLUE}Installing hecate ${version} for ${platform}...${NC}"

    # Download
    echo -e "${BLUE}Downloading from ${url}...${NC}"
    if ! curl -sSfL "$url" -o "${tmp_dir}/${filename}"; then
        echo -e "${RED}Error: Failed to download hecate${NC}" >&2
        echo "URL: $url" >&2
        rm -rf "$tmp_dir"
        exit 1
    fi

    # Extract
    echo -e "${BLUE}Extracting...${NC}"
    if ! tar -xzf "${tmp_dir}/${filename}" -C "$tmp_dir"; then
        echo -e "${RED}Error: Failed to extract archive${NC}" >&2
        rm -rf "$tmp_dir"
        exit 1
    fi

    # Install
    mkdir -p "$INSTALL_DIR"
    mv "${tmp_dir}/hecate" "${INSTALL_DIR}/hecate"
    chmod +x "${INSTALL_DIR}/hecate"

    # Cleanup
    rm -rf "$tmp_dir"

    echo -e "${GREEN}✓ Installed to ${INSTALL_DIR}/hecate${NC}"
}

# Initialize identity
init_identity() {
    if [ "$SKIP_INIT" = "1" ]; then
        echo -e "${YELLOW}Skipping initialization (SKIP_INIT=1)${NC}"
        return
    fi

    if [ -f "${DATA_DIR}/identity.json" ]; then
        echo -e "${YELLOW}Identity already exists at ${DATA_DIR}/identity.json${NC}"
        return
    fi

    echo -e "${BLUE}Initializing identity...${NC}"
    if "${INSTALL_DIR}/hecate" init; then
        echo -e "${GREEN}✓ Identity created${NC}"
    else
        echo -e "${RED}Error: Failed to initialize identity${NC}" >&2
        exit 1
    fi
}

# Add to PATH
add_to_path() {
    # Check if already in PATH
    if echo "$PATH" | grep -q "${INSTALL_DIR}"; then
        return
    fi

    local shell_rc
    case "$SHELL" in
        */bash)
            shell_rc="${HOME}/.bashrc"
            ;;
        */zsh)
            shell_rc="${HOME}/.zshrc"
            ;;
        */fish)
            shell_rc="${HOME}/.config/fish/config.fish"
            echo -e "${YELLOW}Note: Please add ${INSTALL_DIR} to your PATH manually${NC}"
            return
            ;;
        *)
            echo -e "${YELLOW}Note: Please add ${INSTALL_DIR} to your PATH manually${NC}"
            return
            ;;
    esac

    if [ ! -f "$shell_rc" ]; then
        touch "$shell_rc"
    fi

    if ! grep -q "${INSTALL_DIR}" "$shell_rc"; then
        echo "" >> "$shell_rc"
        echo "# Hecate" >> "$shell_rc"
        echo "export PATH=\"${INSTALL_DIR}:\$PATH\"" >> "$shell_rc"
        echo -e "${GREEN}✓ Added ${INSTALL_DIR} to PATH in ${shell_rc}${NC}"
        echo -e "${YELLOW}Run: source ${shell_rc}${NC}"
    fi
}

# Prompt for pairing
prompt_pair() {
    if [ "$SKIP_PAIR" = "1" ]; then
        return
    fi

    echo ""
    echo -e "${BLUE}═══════════════════════════════════════════${NC}"
    echo -e "${GREEN}Hecate installed successfully!${NC}"
    echo -e "${BLUE}═══════════════════════════════════════════${NC}"
    echo ""
    echo -e "Next step: ${YELLOW}Pair with a realm${NC}"
    echo ""
    read -p "Start pairing now? (y/N) " -n 1 -r
    echo ""

    if [[ $REPLY =~ ^[Yy]$ ]]; then
        echo ""
        echo -e "${BLUE}Starting hecate daemon...${NC}"
        "${INSTALL_DIR}/hecate" start || true

        echo ""
        echo -e "${BLUE}Initiating pairing...${NC}"
        "${INSTALL_DIR}/hecate" pair || true
    else
        show_next_steps
    fi
}

# Show next steps
show_next_steps() {
    echo ""
    echo -e "${BLUE}═══════════════════════════════════════════${NC}"
    echo -e "${GREEN}Next Steps${NC}"
    echo -e "${BLUE}═══════════════════════════════════════════${NC}"
    echo ""
    echo "1. Add hecate to your PATH:"
    echo -e "   ${YELLOW}source ~/.bashrc${NC}  # or ~/.zshrc"
    echo ""
    echo "2. Start the daemon:"
    echo -e "   ${YELLOW}hecate start${NC}"
    echo ""
    echo "3. Pair with a realm:"
    echo -e "   ${YELLOW}hecate pair${NC}"
    echo ""
    echo "4. Announce a capability:"
    echo -e "   ${YELLOW}hecate capabilities announce ...${NC}"
    echo ""
    echo "Documentation: https://macula.io/docs/hecate/"
    echo "Support: https://discord.gg/macula"
    echo ""
}

# Check dependencies
check_dependencies() {
    local missing=()

    if ! command -v curl &> /dev/null; then
        missing+=("curl")
    fi

    if ! command -v tar &> /dev/null; then
        missing+=("tar")
    fi

    if [ ${#missing[@]} -gt 0 ]; then
        echo -e "${RED}Error: Missing required dependencies: ${missing[*]}${NC}" >&2
        echo "Install them with your package manager (apt, brew, etc.)" >&2
        exit 1
    fi
}

# Main
main() {
    echo ""
    echo -e "${BLUE}╔══════════════════════════════════════════════════════╗${NC}"
    echo -e "${BLUE}║                                                      ║${NC}"
    echo -e "${BLUE}║       ${GREEN}Hecate Installer${BLUE}                             ║${NC}"
    echo -e "${BLUE}║       Gateway to the Macula Mesh                     ║${NC}"
    echo -e "${BLUE}║                                                      ║${NC}"
    echo -e "${BLUE}╚══════════════════════════════════════════════════════╝${NC}"
    echo ""

    check_dependencies

    local platform=$(detect_platform)
    echo -e "Platform: ${GREEN}${platform}${NC}"
    echo ""

    install_hecate "$platform"
    init_identity
    add_to_path

    prompt_pair
}

main "$@"
```

---

## Hosting on macula.io

### Option 1: Static File (Simple)

Copy script to macula-realm static directory:

```bash
# In macula-hecate repo
cp priv/install.sh /path/to/macula-realm/priv/static/hecate.sh
```

Served at: `https://macula.io/hecate.sh`

### Option 2: Controller (Dynamic)

Create a controller in macula-realm that:
- Fetches latest version from GitHub API
- Renders script with version injected
- Caches for 1 hour

```elixir
# macula_realm_web/controllers/install_controller.ex
defmodule MaculaRealmWeb.InstallController do
  use MaculaRealmWeb, :controller

  def hecate(conn, _params) do
    script = File.read!("priv/static/install/hecate.sh")

    conn
    |> put_resp_content_type("text/x-shellscript")
    |> put_resp_header("cache-control", "public, max-age=3600")
    |> send_resp(200, script)
  end
end
```

Route:
```elixir
get "/hecate.sh", InstallController, :hecate
```

---

## GitHub Actions Release Workflow

### .github/workflows/release.yml

```yaml
name: Release

on:
  push:
    tags:
      - 'v*'

jobs:
  build:
    strategy:
      matrix:
        include:
          - os: ubuntu-latest
            target: linux-amd64
            arch: x86_64
          - os: ubuntu-latest
            target: linux-arm64
            arch: aarch64
          - os: macos-latest
            target: darwin-amd64
            arch: x86_64
          - os: macos-latest
            target: darwin-arm64
            arch: arm64

    runs-on: ${{ matrix.os }}

    steps:
      - uses: actions/checkout@v4

      - uses: erlef/setup-beam@v1
        with:
          otp-version: '26'
          rebar3-version: '3.22'

      - name: Build release
        run: rebar3 as prod tar

      - name: Rename tarball
        run: |
          mkdir -p dist
          tar -xzf _build/prod/rel/hecate/*.tar.gz -C dist
          tar -czf hecate-${{ matrix.target }}.tar.gz -C dist .

      - uses: softprops/action-gh-release@v1
        with:
          files: hecate-*.tar.gz
        env:
          GITHUB_TOKEN: ${{ secrets.GITHUB_TOKEN }}
```

---

## CLI Support

Add `hecate pair` command for convenience:

### src/hecate_cli.erl

```erlang
%% hecate pair - Start pairing flow
main(["pair"]) ->
    case hecate_api_client:post("/pairing/start", #{}) of
        {ok, #{<<"qr_code">> := QrData}} ->
            io:format("~s~n", [maps:get(<<"terminal_instructions">>, QrData)]),
            poll_pairing_status(maps:get(<<"session_id">>, QrData));
        {error, Reason} ->
            io:format("Error: ~p~n", [Reason]),
            halt(1)
    end;

poll_pairing_status(SessionId) ->
    timer:sleep(2000),
    case hecate_api_client:get("/pairing/status") of
        {ok, #{<<"status">> := <<"paired">>}} ->
            io:format("~n✓ Pairing successful!~n"),
            halt(0);
        {ok, #{<<"status">> := <<"pairing">>}} ->
            poll_pairing_status(SessionId);
        {ok, #{<<"status">> := <<"failed">>}} ->
            io:format("~nPairing failed~n"),
            halt(1);
        {error, _} ->
            poll_pairing_status(SessionId)
    end.
```

Usage:
```bash
hecate pair
# Shows QR code, polls until paired
```

---

## Testing

### Manual Test

```bash
# Test installer locally
bash priv/install.sh

# Test with version override
HECATE_VERSION=0.1.0 bash priv/install.sh

# Test skip flags
SKIP_INIT=1 SKIP_PAIR=1 bash priv/install.sh
```

### Automated Test (CI)

```yaml
# .github/workflows/test-install.yml
name: Test Install Script

on: [push, pull_request]

jobs:
  test:
    strategy:
      matrix:
        os: [ubuntu-latest, macos-latest]
    runs-on: ${{ matrix.os }}

    steps:
      - uses: actions/checkout@v4

      - name: Test install script
        run: |
          SKIP_PAIR=1 bash priv/install.sh
          ~/.local/bin/hecate --version
```

---

## Success Criteria Checklist

- [ ] Script detects OS and architecture correctly
- [ ] Downloads appropriate binary from GitHub releases
- [ ] Installs to `~/.local/bin/hecate`
- [ ] Runs `hecate init` automatically
- [ ] Adds to PATH in shell config
- [ ] Prompts for pairing
- [ ] Shows clear next steps
- [ ] Works on Linux (amd64, arm64)
- [ ] Works on macOS (amd64, arm64)
- [ ] Works on Windows WSL2
- [ ] Error messages are clear and actionable
- [ ] Script hosted at `https://macula.io/hecate.sh`
- [ ] GitHub Actions builds releases for all platforms
- [ ] Documentation updated with install instructions

---

## Next Steps

1. Implement `priv/install.sh`
2. Add GitHub Actions release workflow
3. Test on all platforms
4. Host script on macula.io
5. Update documentation to reference install script
6. Announce `curl | sh` installer

---

**Related Plans:**
- [PLAN_AGENT_ONBOARDING.md](PLAN_AGENT_ONBOARDING.md)
- [PLAN_CQRS_ARCHITECTURE.md](PLAN_CQRS_ARCHITECTURE.md)
