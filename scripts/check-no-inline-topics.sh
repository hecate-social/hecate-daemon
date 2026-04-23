#!/usr/bin/env bash
#
# Fail the build if source code constructs mesh topics inline instead
# of going through hecate_topics (or macula_topic in the SDK).
#
# Why: the realm/daemon membership lifecycle was silently dead for
# months because one side built `io.macula.membership.revoked` (4
# dot-separated tokens) and the other built
# `io.macula/_realm/_realm/membership/revoked_v1` (5 slashes). With
# macula 2.1+ runtime validation, drift now fails loudly at the call
# site — but only AT runtime. This script catches it at PR time.
#
# Patterns flagged:
#   1. Dot-form: <<"realm.domain.event_v1">> in Erlang
#   2. Canonical hand-built: <<"realm/org/app/domain/event_v1">> in Erlang
#   3. Interpolated dot-form: "#{realm}.domain.event" in Elixir
#
# Exemptions:
#   - Lines under test/ or doc/ (test fixtures + examples are allowed)
#   - Lines that already call macula_topic: or hecate_topics: (the builder)
#   - System topics with leading underscore (_mesh.*, _dist.*, _dht.*)
#   - MRI strings (mri:type:realm/path — different namespace, not mesh topics)
#   - URLs (quic://, http://, https://)
#
# Usage:  scripts/check-no-inline-topics.sh
# Exit:   0 = clean, 1 = violations found
#
set -uo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"

# Paths to scan (production source only — tests/docs allowed inline).
SCAN_PATHS="apps/*/src"

# Forbidden patterns. Each ripgrep call returns matches; we collect
# them and exempt the safe lines afterwards.
TMPFILE="$(mktemp)"
trap 'rm -f "$TMPFILE"' EXIT

# Pattern 1: dot-form binary literal that looks like a versioned topic.
# Matches: <<"...word.word.word_v123">>
# Doesn't match: <<"io.macula">> (just a realm, no _v suffix)
rg --no-heading -n -t erlang \
   '<<"[a-z][a-z0-9._-]+\.[a-z][a-z0-9_]+_v[0-9]+">>' \
   $SCAN_PATHS 2>/dev/null >> "$TMPFILE" || true

# Pattern 2: canonical 5-segment slash form built by hand.
# Matches: <<"realm/org/app/domain/name_v1">> (hand-built — use macula_topic)
rg --no-heading -n -t erlang \
   '<<"[a-z][a-z0-9.-]+/[a-z_][a-z0-9_-]*/[a-z_][a-z0-9_-]*/[a-z_][a-z0-9_-]*/[a-z_][a-z0-9_-]*_v[0-9]+">>' \
   $SCAN_PATHS 2>/dev/null >> "$TMPFILE" || true

# Pattern 3: Erlang binary string interpolating a realm into a dot-form
# topic, e.g. by building it via list_to_binary / iolist.
# (Daemon is Erlang only; Elixir version of this lives in macula-realm.)
rg --no-heading -n -t erlang \
   'list_to_binary\(.*"[a-z][a-z0-9._]+\.[a-z][a-z0-9_]+_v[0-9]+"' \
   $SCAN_PATHS 2>/dev/null >> "$TMPFILE" || true

# Apply exemptions: drop lines that go through the builder, system
# topics, MRI strings, or URLs.
violations=$(
    grep -v -E 'macula_topic:|hecate_topics:|<<"_(mesh|dist|dht|scenario)\.|<<"mri:|<<"(quic|http|https)://' "$TMPFILE" || true
)

if [ -z "$violations" ]; then
    echo "OK: no inline mesh topic strings found in production source."
    exit 0
fi

echo "ERROR: found inline mesh topic string(s). Use hecate_topics or macula_topic instead."
echo
echo "$violations"
echo
echo "If a match is a false positive (an MRI string, a URL, or a"
echo "different protocol entirely), update scripts/check-no-inline-topics.sh"
echo "to add the exemption."
exit 1
