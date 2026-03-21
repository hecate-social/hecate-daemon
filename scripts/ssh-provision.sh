#!/usr/bin/env bash
# SSH provisioning wrapper for hecate-web terminal.
# Pipes all output to stdout/stderr for Tauri shell capture.
#
# Usage: ssh-provision.sh <user> <password> <host> <install-command>
set -uo pipefail

USER="$1"
PASS="$2"
HOST="$3"
shift 3
CMD="$*"

exec sshpass -p "$PASS" ssh \
    -o StrictHostKeyChecking=no \
    -o UserKnownHostsFile=/dev/null \
    -o LogLevel=ERROR \
    "$USER@$HOST" \
    "$CMD"
