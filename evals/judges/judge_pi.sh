#!/usr/bin/env bash
# pi-coding-agent judge wrapper for promptfoo's g-eval `provider:`
# override. Pi is provider-agnostic so the family token is "unknown";
# `invariants.py` will conservatively reject Pi as a judge whenever the
# SUT family is also unknown to avoid the Claude-via-Pi self-bias case.

# shellcheck source=evals/providers/lib.sh
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
. "$SCRIPT_DIR/../providers/lib.sh"

emit_family_if_requested unknown "${1:-}"

require_cmd jq pi

PROMPT="${1:?prompt required as argv[1]}"
# argv[2+] is reserved for promptfoo's options JSON; ignore it.
WORKDIR="${EVAL_WORKDIR:-$(mktemp -d -t judge-pi-XXXXXX)}"
mkdir -p "$WORKDIR"

CLI_VERSION="$(pi --version 2>/dev/null | head -n1 || echo unknown)"
START="$(millis_now)"

TRACE="$WORKDIR/judge-trace.jsonl"
(
  cd "$WORKDIR"
  pi -p "$PROMPT" --output-format rpc \
    > "$TRACE" 2>"$WORKDIR/stderr.log"
) || {
  status=$?
  cat "$WORKDIR/stderr.log" >&2
  exit "$status"
}

ELAPSED=$(( $(millis_now) - START ))

TEXT="$(jq -rs 'map(select(.type == "assistant_message")) | last | (.text // empty)' "$TRACE" 2>/dev/null)"
if [[ -z "$TEXT" ]]; then
  TEXT="$(jq -rs 'map(select(.type == "result")) | last | (.text // empty)' "$TRACE" 2>/dev/null)"
fi

printf '%s' "$TEXT"

emit_trace 'null' "$ELAPSED" unknown pi "$CLI_VERSION" judge
