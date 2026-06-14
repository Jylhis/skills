#!/usr/bin/env bash
# Claude judge wrapper for promptfoo's g-eval `provider:` override.
#
# promptfoo's g-eval owns the rubric prompt construction; this wrapper
# just needs to behave like a chat completion: take prompt on argv[1],
# return assistant text on stdout. Schema-validation of the response is
# promptfoo's job; we never retry on bad output (Doc 3 reviewer S2).

# shellcheck source=evals/providers/lib.sh
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
. "$SCRIPT_DIR/../providers/lib.sh"

emit_family_if_requested anthropic "${1:-}"

require_cmd jq claude

PROMPT="${1:?prompt required as argv[1]}"
# argv[2+] is reserved for promptfoo's options JSON; ignore it.
WORKDIR="${EVAL_WORKDIR:-$(mktemp -d -t judge-claude-XXXXXX)}"
mkdir -p "$WORKDIR"

CLI_VERSION="$(claude --version 2>/dev/null | head -n1 || echo unknown)"
START="$(millis_now)"

# Judge runs headless, single-turn, no tools. The system instruction
# steers it toward JSON-only output for callers that ask for it; for
# promptfoo's g-eval the prompt itself is already structured.
TRACE="$WORKDIR/judge-trace.jsonl"
(
  cd "$WORKDIR"
  claude -p "$PROMPT" \
    --output-format stream-json \
    --verbose \
    --max-turns 1 \
    < /dev/null > "$TRACE" 2>"$WORKDIR/stderr.log"
) || {
  status=$?
  cat "$WORKDIR/stderr.log" >&2
  exit "$status"
}

ELAPSED=$(( $(millis_now) - START ))

TEXT="$(jq -r 'select(.type == "result") | .result' "$TRACE" | tail -n1)"
if [[ -z "$TEXT" ]]; then
  TEXT="$(jq -r 'select(.type == "assistant") | .message.content[]? | select(.type=="text") | .text' "$TRACE" | paste -sd '\n' -)"
fi

printf '%s' "$TEXT"

emit_trace 'null' "$ELAPSED" anthropic claude "$CLI_VERSION" judge
