#!/usr/bin/env bash
# Google Antigravity CLI provider for promptfoo's `exec:` lane.
# Antigravity 2.0 (announced 2026-05-19) replaced Gemini CLI as
# Google's flagship agentic developer surface. Binary name and flags
# below are derived from the original Gemini CLI ergonomics that
# Antigravity inherits; verify against https://antigravity.google docs
# before recording fresh goldens.

# shellcheck source=evals/providers/lib.sh
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
. "$SCRIPT_DIR/lib.sh"

emit_family_if_requested google "${1:-}"

require_cmd jq python3 antigravity

PROMPT="${1:?prompt required as argv[1]}"
# argv[2+] is reserved for promptfoo's options JSON; ignore it.
WORKDIR="${EVAL_WORKDIR:-$(mktemp -d -t eval-antigravity-XXXXXX)}"
mkdir -p "$WORKDIR"

CLI_VERSION="$(antigravity --version 2>/dev/null | head -n1 || echo unknown)"
MODEL_SNAPSHOT="${EVAL_ANTIGRAVITY_MODEL:-default}"

START="$(millis_now)"

TRACE_FILE="$WORKDIR/antigravity-trace.json"
(
  cd "$WORKDIR"
  antigravity -p "$PROMPT" --output-format stream-json \
    > "$TRACE_FILE" 2>"$WORKDIR/antigravity-stderr.log"
) || {
  status=$?
  cat "$WORKDIR/antigravity-stderr.log" >&2
  exit "$status"
}

ELAPSED=$(( $(millis_now) - START ))

# Antigravity's stream-json output is NDJSON; the final assistant text
# is the concatenation of `text` events, with a non-stream-final
# `response` event as the canonical fallback. (Inherited from the
# Gemini CLI format.)
TEXT="$(jq -rs '
  map(select(.type == "response")) | last | (.response // empty)
' "$TRACE_FILE" 2>/dev/null)"

if [[ -z "$TEXT" ]]; then
  # Streamed `text` chunks concatenate with nothing between them.
  # `tr -d '\n'` is the portable equivalent of `paste -sd '' -`
  # (GNU paste rejects an empty delimiter list).
  TEXT="$(jq -r '
    select(.type == "text") | .text // empty
  ' "$TRACE_FILE" 2>/dev/null | tr -d '\n')"
fi

# `activate_skill` is the explicit skill-load tool event Antigravity
# inherited from Gemini CLI; its `args.skill` (or `input.skill`)
# carries the activated skill name. We also look at the aggregate
# `stats.tools.byName.activate_skill` form as a fallback.
TRIGGERED_RAW="$(jq -r '
  select(.type == "tool_use" and .name == "activate_skill")
  | (.input.skill // .args.skill // empty)
' "$TRACE_FILE" 2>/dev/null | head -n1)"

if [[ -z "$TRIGGERED_RAW" ]]; then
  TRIGGERED_RAW="$(jq -r '
    select(.stats != null) | .stats.tools.byName.activate_skill.lastSkill // empty
  ' "$TRACE_FILE" 2>/dev/null | head -n1)"
fi

if [[ -n "$TRIGGERED_RAW" ]]; then
  TRIGGERED_JSON="$(jq -nc --arg s "$TRIGGERED_RAW" '$s')"
else
  TRIGGERED_JSON='null'
fi

printf '%s' "$TEXT"

emit_trace "$TRIGGERED_JSON" "$ELAPSED" google antigravity "$CLI_VERSION" "$MODEL_SNAPSHOT"
