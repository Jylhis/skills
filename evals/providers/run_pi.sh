#!/usr/bin/env bash
# pi-coding-agent provider for promptfoo's `exec:` lane.
# (NOT Inflection's pi.ai — that has no CLI.)

# shellcheck source=evals/providers/lib.sh
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
. "$SCRIPT_DIR/lib.sh"

# Pi is provider-agnostic — it can route to any backend — so the family
# token is "unknown" and same-family judging is decided by configuration,
# not by name.
emit_family_if_requested unknown "${1:-}"

require_cmd jq python3 pi

PROMPT="${1:?prompt required as argv[1]}"
# argv[2+] is reserved for promptfoo's options JSON; ignore it.
WORKDIR="${EVAL_WORKDIR:-$(mktemp -d -t eval-pi-XXXXXX)}"
mkdir -p "$WORKDIR"

CLI_VERSION="$(pi --version 2>/dev/null | head -n1 || echo unknown)"
MODEL_SNAPSHOT="${EVAL_PI_MODEL:-default}"

# Sentinel marker: any skill amended in the workdir writes its name
# here when invoked. The patch is applied by the harness's expand step
# when `cases[].providers` includes `pi`.
SENTINEL="$WORKDIR/.skill_marks"
: > "$SENTINEL"

START="$(millis_now)"

TRACE_FILE="$WORKDIR/pi-trace.jsonl"
(
  cd "$WORKDIR"
  pi -p "$PROMPT" --output-format rpc \
    > "$TRACE_FILE" 2>"$WORKDIR/pi-stderr.log"
) || {
  status=$?
  cat "$WORKDIR/pi-stderr.log" >&2
  exit "$status"
}

ELAPSED=$(( $(millis_now) - START ))

# Pi's RPC stream uses event-typed records; the last assistant message
# is the canonical text.
TEXT="$(jq -rs '
  map(select(.type == "assistant_message")) | last | (.text // empty)
' "$TRACE_FILE" 2>/dev/null)"

if [[ -z "$TEXT" ]]; then
  TEXT="$(jq -rs 'map(select(.type == "result")) | last | (.text // empty)' "$TRACE_FILE" 2>/dev/null)"
fi

# Sentinel-marker fallback (the default for Pi because telemetry is
# sparse): any line `skill=<name>` in the sentinel file counts as a
# trigger. We take the first match.
TRIGGERED_RAW=""
if [[ -s "$SENTINEL" ]]; then
  TRIGGERED_RAW="$(grep -E '^skill=' "$SENTINEL" | head -n1 | sed 's/^skill=//')"
fi

if [[ -z "$TRIGGERED_RAW" ]]; then
  # Telemetry path: a `tool_call` event named `Skill` or `activate_skill`.
  TRIGGERED_RAW="$(jq -r '
    select(.type == "tool_call" and (.name == "Skill" or .name == "activate_skill"))
    | (.input.skill // .args.skill // empty)
  ' "$TRACE_FILE" 2>/dev/null | head -n1)"
fi

if [[ -n "$TRIGGERED_RAW" ]]; then
  TRIGGERED_JSON="$(jq -nc --arg s "$TRIGGERED_RAW" '$s')"
else
  TRIGGERED_JSON='null'
fi

printf '%s' "$TEXT"

emit_trace "$TRIGGERED_JSON" "$ELAPSED" unknown pi "$CLI_VERSION" "$MODEL_SNAPSHOT"
