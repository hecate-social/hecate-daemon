#!/usr/bin/env bash
# purge-local.sh — Remove ALL hecate artifacts from this machine
#
# This allows a clean reinstall. Run as your normal user (not root).
#
# What gets removed:
#   - systemd services (hecate-daemon, hecate-reconciler)
#   - Quadlet container symlinks
#   - podman containers and images
#   - ~/.hecate/ (all data, gitops, secrets, config)
#   - ~/.local/bin/hecate* (CLI, reconciler, tui, web symlinks)
#   - epmd registrations and stale BEAM processes

set -euo pipefail

RED='\033[31m'
GREEN='\033[32m'
YELLOW='\033[33m'
BOLD='\033[1m'
RESET='\033[0m'

info()  { echo -e "${GREEN}>>>${RESET} $*"; }
warn()  { echo -e "${YELLOW}>>>${RESET} $*"; }
err()   { echo -e "${RED}>>>${RESET} $*" >&2; }

echo -e "${BOLD}Hecate Purge — Remove all artifacts${RESET}"
echo ""

# --- 1. Stop systemd services ---
info "Stopping systemd services..."
systemctl --user stop hecate-daemon.service 2>/dev/null && info "  stopped hecate-daemon" || true
systemctl --user stop hecate-reconciler.service 2>/dev/null && info "  stopped hecate-reconciler" || true

# --- 2. Disable services ---
info "Disabling systemd services..."
systemctl --user disable hecate-daemon.service 2>/dev/null && info "  disabled hecate-daemon" || true
systemctl --user disable hecate-reconciler.service 2>/dev/null && info "  disabled hecate-reconciler" || true

# --- 3. Remove Quadlet symlink ---
info "Removing Quadlet container symlinks..."
rm -f "${HOME}/.config/containers/systemd/hecate-daemon.container" && info "  removed Quadlet symlink" || true
rmdir "${HOME}/.config/containers/systemd" 2>/dev/null || true
rmdir "${HOME}/.config/containers" 2>/dev/null || true

# --- 4. Remove reconciler service file ---
info "Removing systemd unit files..."
rm -f "${HOME}/.config/systemd/user/hecate-reconciler.service"
rm -f "${HOME}/.config/systemd/user/default.target.wants/hecate-reconciler.service"
systemctl --user daemon-reload 2>/dev/null || true
info "  daemon-reloaded"

# --- 5. Kill stale processes ---
info "Killing stale hecate processes..."
# Kill heart first (it respawns beam)
pkill -f 'heart.*hecate' 2>/dev/null && info "  killed heart" || true
sleep 0.5
# Kill beam/hecate processes (both containerized and local dev releases)
pkill -9 -f 'beam.*hecate' 2>/dev/null && info "  killed beam" || true
pkill -f 'run_erl.*hecate' 2>/dev/null && info "  killed run_erl" || true
pkill -f 'epmd' 2>/dev/null && info "  killed epmd" || true

# --- 6. Stop and remove podman container + image ---
info "Removing podman container and image..."
podman stop hecate-daemon 2>/dev/null && info "  stopped container" || true
podman rm hecate-daemon 2>/dev/null && info "  removed container" || true
podman rmi codeberg.org/hecate-social/hecate-daemon:latest 2>/dev/null && info "  removed image" || true
# Also try with systemd-generated name
podman rm systemd-hecate-daemon 2>/dev/null || true

# --- 7. Remove data directory ---
info "Removing ~/.hecate/..."
rm -rf "${HOME}/.hecate"
info "  removed"

# --- 8. Remove binaries ---
info "Removing binaries from ~/.local/bin/..."
rm -f "${HOME}/.local/bin/hecate"
rm -f "${HOME}/.local/bin/hecate-reconciler"
rm -f "${HOME}/.local/bin/hecate-tui"
rm -f "${HOME}/.local/bin/hecate-web"
info "  removed"

# --- 9. Final verification ---
echo ""
echo -e "${BOLD}Verification:${RESET}"
echo -n "  ~/.hecate/           "
[[ -d "${HOME}/.hecate" ]] && echo -e "${RED}STILL EXISTS${RESET}" || echo -e "${GREEN}gone${RESET}"
echo -n "  hecate binary        "
command -v hecate &>/dev/null && echo -e "${RED}STILL IN PATH${RESET}" || echo -e "${GREEN}gone${RESET}"
echo -n "  systemd units        "
systemctl --user list-units --all 'hecate*' --no-legend 2>/dev/null | grep -q hecate && echo -e "${RED}STILL LOADED${RESET}" || echo -e "${GREEN}gone${RESET}"
echo -n "  podman container     "
podman ps -a --filter name=hecate --format '{{.Names}}' 2>/dev/null | grep -q hecate && echo -e "${RED}STILL EXISTS${RESET}" || echo -e "${GREEN}gone${RESET}"
echo -n "  beam processes       "
pgrep -f 'beam.*hecate' &>/dev/null && echo -e "${RED}STILL RUNNING${RESET}" || echo -e "${GREEN}gone${RESET}"

echo ""
echo -e "${GREEN}Purge complete.${RESET} Machine is clean for a fresh install."
