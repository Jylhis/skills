#!/usr/bin/env bash
# Claude Code provider for promptfoo's `exec:` lane.
#
# Wrapper contract (see evals/providers/lib.sh): argv[1] is the rendered
# prompt. argv[2+] is RESERVED for promptfoo (it passes provider options
# JSON there) and is ignored. The workdir override is via the
# `EVAL_WORKDIR` env var; otherwise a fresh mktemp dir is used. The CLI
# runs with the workdir as CWD so the host's real skills/CLAUDE.md/
# AGENTS.md cannot leak into the session.
#
# Stdout: the assistant's final text. Stderr: a single line of JSON
# trace consumed by promptfoo + invariants.py.

# shellcheck source=evals/providers/lib.sh
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
. "$SCRIPT_DIR/lib.sh"

emit_family_if_requested anthropic "${1:-}"

require_cmd jq python3 claude

PROMPT="${1:?prompt required as argv[1]}"
WORKDIR="${EVAL_WORKDIR:-$(mktemp -d -t eval-claude-XXXXXX)}"
mkdir -p "$WORKDIR"

CLI_VERSION="$(claude --version 2>/dev/null | head -n1 || echo unknown)"
MODEL_SNAPSHOT="${EVAL_CLAUDE_MODEL:-default}"

START="$(millis_now)"

# Capture the full stream-json trace; promptfoo only sees the assistant
# text on stdout and our compact trace on stderr.
TRACE_FILE="$WORKDIR/claude-trace.jsonl"
(
  cd "$WORKDIR"
  claude -p "$PROMPT" \
    --output-format stream-json \
    --verbose \
    --max-turns 1 \
    < /dev/null > "$TRACE_FILE" 2>"$WORKDIR/claude-stderr.log"
) || {
  status=$?
  cat "$WORKDIR/claude-stderr.log" >&2
  exit "$status"
}

ELAPSED=$(( $(millis_now) - START ))

# Final assistant text comes from the last `result` event, falling back
# to concatenated `assistant.content[].text` if `result` is absent.
TEXT="$(jq -r '
  select(.type == "result") | .result
' "$TRACE_FILE" | tail -n1)"

if [[ -z "$TEXT" ]]; then
  TEXT="$(jq -r '
    select(.type == "assistant") | .message.content[]?
    | select(.type == "text") | .text
  ' "$TRACE_FILE" | paste -sd '\n' -)"
fi

# Triggered skill: any `tool_use` with name=="Skill" exposes the skill
# name in its `input.skill` field.
TRIGGERED_RAW="$(jq -r '
  select(.type == "assistant") | .message.content[]?
  | select(.type == "tool_use" and .name == "Skill") | .input.skill
' "$TRACE_FILE" | head -n1)"

if [[ -n "$TRIGGERED_RAW" ]]; then
  TRIGGERED_JSON="$(jq -nc --arg s "$TRIGGERED_RAW" '$s')"
else
  TRIGGERED_JSON='null'
fi

printf '%s' "$TEXT"

emit_trace "$TRIGGERED_JSON" "$ELAPSED" anthropic claude "$CLI_VERSION" "$MODEL_SNAPSHOT"
