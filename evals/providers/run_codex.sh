#!/usr/bin/env bash
# OpenAI Codex CLI provider for promptfoo's `exec:` lane.

# shellcheck source=evals/providers/lib.sh
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
. "$SCRIPT_DIR/lib.sh"

emit_family_if_requested openai "${1:-}"

require_cmd jq python3 codex

PROMPT="${1:?prompt required as argv[1]}"
# argv[2+] is reserved for promptfoo's options JSON; ignore it.
WORKDIR="${EVAL_WORKDIR:-$(mktemp -d -t eval-codex-XXXXXX)}"
mkdir -p "$WORKDIR"

CLI_VERSION="$(codex --version 2>/dev/null | head -n1 || echo unknown)"
MODEL_SNAPSHOT="${EVAL_CODEX_MODEL:-default}"

START="$(millis_now)"

TRACE_FILE="$WORKDIR/codex-trace.jsonl"
(
  cd "$WORKDIR"
  codex exec --json --skip-git-repo-check "$PROMPT" \
    > "$TRACE_FILE" 2>"$WORKDIR/codex-stderr.log"
) || {
  status=$?
  cat "$WORKDIR/codex-stderr.log" >&2
  exit "$status"
}

ELAPSED=$(( $(millis_now) - START ))

# Codex's JSON event stream uses `item.kind` to mark assistant text
# items; the final assistant message is the latest one.
TEXT="$(jq -rs '
  map(select(.type == "item" and .item.kind == "agent_message"))
  | last | (.item.text // empty)
' "$TRACE_FILE")"

if [[ -z "$TEXT" ]]; then
  TEXT="$(jq -rs 'map(select(.type == "result")) | last | (.text // empty)' "$TRACE_FILE")"
fi

# Best-effort heuristic skill detection: a `command_execution` item
# whose `command` reads any path matching `*/skills/*/*/SKILL.md` is
# treated as the agent loading that skill.
TRIGGERED_RAW="$(jq -r '
  select(.type == "item" and .item.kind == "command_execution")
  | .item.command // empty
  | tostring
  | capture("[/\\\\]skills[/\\\\][^/\\\\]+[/\\\\](?<n>[^/\\\\]+)[/\\\\]SKILL\\.md")? | .n
' "$TRACE_FILE" | head -n1)"

if [[ -n "$TRIGGERED_RAW" ]]; then
  TRIGGERED_JSON="$(jq -nc --arg s "$TRIGGERED_RAW" '$s')"
else
  TRIGGERED_JSON='null'
fi

printf '%s' "$TEXT"

emit_trace "$TRIGGERED_JSON" "$ELAPSED" openai codex "$CLI_VERSION" "$MODEL_SNAPSHOT"
