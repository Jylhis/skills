#!/usr/bin/env bash
# OpenAI Codex judge wrapper for promptfoo's g-eval `provider:` override.

# shellcheck source=evals/providers/lib.sh
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
. "$SCRIPT_DIR/../providers/lib.sh"

emit_family_if_requested openai "${1:-}"

require_cmd jq codex

PROMPT="${1:?prompt required as argv[1]}"
# argv[2+] is reserved for promptfoo's options JSON; ignore it.
WORKDIR="${EVAL_WORKDIR:-$(mktemp -d -t judge-codex-XXXXXX)}"
mkdir -p "$WORKDIR"

CLI_VERSION="$(codex --version 2>/dev/null | head -n1 || echo unknown)"
START="$(millis_now)"

TRACE="$WORKDIR/judge-trace.jsonl"
(
  cd "$WORKDIR"
  codex exec --json --skip-git-repo-check "$PROMPT" \
    > "$TRACE" 2>"$WORKDIR/stderr.log"
) || {
  status=$?
  cat "$WORKDIR/stderr.log" >&2
  exit "$status"
}

ELAPSED=$(( $(millis_now) - START ))

TEXT="$(jq -rs '
  map(select(.type == "item" and .item.kind == "agent_message"))
  | last | (.item.text // empty)
' "$TRACE")"

printf '%s' "$TEXT"

emit_trace 'null' "$ELAPSED" openai codex "$CLI_VERSION" judge
