#!/usr/bin/env bash
# Google Antigravity judge wrapper for promptfoo's g-eval `provider:`
# override. Antigravity is recommended as the cross-vendor judge for the
# Anthropic/OpenAI-routed SUTs because its family token ("google") differs
# from theirs, satisfying the same-family invariant in invariants.py.
#
# Binary name and flags mirror evals/providers/run_antigravity.sh; verify
# against https://antigravity.google docs before recording fresh goldens.

# shellcheck source=evals/providers/lib.sh
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
. "$SCRIPT_DIR/../providers/lib.sh"

emit_family_if_requested google "${1:-}"

require_cmd jq antigravity

PROMPT="${1:?prompt required as argv[1]}"
# argv[2+] is reserved for promptfoo's options JSON; ignore it.
WORKDIR="${EVAL_WORKDIR:-$(mktemp -d -t judge-antigravity-XXXXXX)}"
mkdir -p "$WORKDIR"

CLI_VERSION="$(antigravity --version 2>/dev/null | head -n1 || echo unknown)"
START="$(millis_now)"

TRACE="$WORKDIR/judge-trace.json"
(
  cd "$WORKDIR"
  antigravity -p "$PROMPT" --output-format stream-json \
    > "$TRACE" 2>"$WORKDIR/stderr.log"
) || {
  status=$?
  cat "$WORKDIR/stderr.log" >&2
  exit "$status"
}

ELAPSED=$(( $(millis_now) - START ))

# Final judge text comes from the canonical `response` event, falling
# back to the concatenation of streamed `text` events. Select the last
# matching event whole so multi-line responses are preserved, and guard
# JSON null so it does not stringify to "null".
TEXT="$(jq -rs '
  map(select(.type == "response")) | last | (.response // empty)
' "$TRACE" 2>/dev/null)"

if [[ -z "$TEXT" ]]; then
  TEXT="$(jq -r '
    select(.type == "text") | .text // empty
  ' "$TRACE" 2>/dev/null | tr -d '\n')"
fi

printf '%s' "$TEXT"

emit_trace 'null' "$ELAPSED" google antigravity "$CLI_VERSION" judge
