#!/usr/bin/env bash
# Shared boilerplate for the harness/ scripts. Source it, don't run it:
#   . "$(dirname "$0")/_common.sh"
#
# Provides:
#   $HARNESS_DIR $REPO_DIR $BUILD_DIR        — paths
#   harness_ensure_built                      — rebar3 compile if the umbrella isn't built
#   harness_compile <module.erl>...           — erlc the given helper module(s) into harness/ebin
#   harness_run_erl <eval-expr>               — bare erl: no distribution (no epmd), no -heart, no
#                                               disk writes, throwaway cwd, full umbrella code path
#   colour helpers: c_bold c_dim c_red c_green c_yellow c_cyan c_reset  (empty when not a TTY)
#   hr [char]                                 — a horizontal rule the width of the terminal
#   say <fmt...>                              — printf to stderr (so it doesn't get captured in $(...))
set -euo pipefail

HARNESS_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_DIR="$(cd "$HARNESS_DIR/.." && pwd)"
BUILD_DIR="$REPO_DIR/_build/default/lib"

# --- colours (only when stdout is a terminal and not NO_COLOR) ---
if [ -t 1 ] && [ -z "${NO_COLOR:-}" ]; then
  c_reset=$'\033[0m'; c_bold=$'\033[1m'; c_dim=$'\033[2m'
  c_red=$'\033[31m'; c_green=$'\033[32m'; c_yellow=$'\033[33m'
  c_blue=$'\033[34m'; c_magenta=$'\033[35m'; c_cyan=$'\033[36m'
else
  c_reset='' c_bold='' c_dim='' c_red='' c_green='' c_yellow='' c_blue='' c_magenta='' c_cyan=''
fi

_term_cols() { tput cols 2>/dev/null || echo 80; }
hr() { local ch="${1:-─}" w; w=$(_term_cols); printf '%s' "${c_dim}"; for ((i=0;i<w;i++)); do printf '%s' "$ch"; done; printf '%s\n' "${c_reset}"; }

say() { printf '%s\n' "$*" >&2; }

harness_ensure_built() {
  if [ ! -d "$BUILD_DIR/macula/ebin" ] || [ ! -d "$BUILD_DIR/resolve_mesh_names/ebin" ]; then
    say "${c_dim}==> building (rebar3 compile) ...${c_reset}"
    ( cd "$REPO_DIR" && rebar3 compile >/dev/null )
  fi
}

harness_compile() {
  mkdir -p "$HARNESS_DIR/ebin"
  local incs=()
  [ -d "$BUILD_DIR/macula/include" ] && incs+=( -I "$BUILD_DIR/macula/include" )
  say "${c_dim}==> compiling $* ...${c_reset}"
  ( cd "$HARNESS_DIR/src" && erlc -o "$HARNESS_DIR/ebin" "${incs[@]}" \
      -pa "$BUILD_DIR/macula/ebin" -pa "$BUILD_DIR/resolve_mesh_names/ebin" \
      -pa "$BUILD_DIR/serve_dns_over_mesh/ebin" -pa "$HARNESS_DIR/ebin" \
      "$@" )
}

harness_run_erl() {
  local eval_expr="$1"
  local pa=() d
  for d in "$BUILD_DIR"/*/ebin; do [ -d "$d" ] && pa+=( -pa "$d" ); done
  pa+=( -pa "$HARNESS_DIR/ebin" )
  local work; work="$(mktemp -d "${TMPDIR:-/tmp}/hcv-harness.XXXXXX")"
  # bake the path into the trap so it survives this function returning
  trap "rm -rf -- '$work'" EXIT
  ( cd "$work" && exec erl -noshell "${pa[@]}" -eval "$eval_expr" )
}

# A default Belgian station fleet (the be-* relays the beam daemons use). Override
# with HARNESS_RELAYS=url,url,...
: "${HARNESS_RELAYS:=https://station-be-brussels.macula.io:4433,https://station-be-antwerp.macula.io:4433,https://station-be-hasselt.macula.io:4433}"
export HARNESS_RELAYS
