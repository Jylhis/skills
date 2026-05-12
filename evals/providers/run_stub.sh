#!/usr/bin/env bash
# Cassette replay provider for promptfoo. Replays a recorded SUT
# response keyed by sha256(provider + prompt + model + fixtures)[:16].
# A missing or stale cassette is a hard fail (exit 2) — Doc 3 §"VCR
# Cassettes" mismatch detection.

# shellcheck source=evals/providers/lib.sh
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
. "$SCRIPT_DIR/lib.sh"

emit_family_if_requested stub "${1:-}"

require_cmd python3 jq

# Import config.env from promptfoo's options JSON (argv[2]).
import_promptfoo_env "${2:-}"

PROMPT="${1:?prompt required as argv[1]}"
WORKDIR="${EVAL_WORKDIR:-$(mktemp -d -t eval-stub-XXXXXX)}"
mkdir -p "$WORKDIR"

# These are populated by the harness (run.py / justfile recipes) when
# scheduling a stub run; defaults make the wrapper still work for ad-hoc
# probing, falling back to "the most recently recorded golden in the
# named suite that was recorded against the named provider".
EVAL_SUITE="${EVAL_SUITE:?EVAL_SUITE env var required}"
EVAL_PROVIDER="${EVAL_PROVIDER:-claude}"
EVAL_MODEL_SNAPSHOT="${EVAL_MODEL_SNAPSHOT:-default}"
EVAL_FIXTURES_DIR="${EVAL_FIXTURES_DIR:-}"

REPO_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"

# Compute the cassette key via cassette.py.
KEY="$(python3 "$REPO_ROOT/evals/scripts/cassette.py" key \
  --provider "$EVAL_PROVIDER" \
  --prompt "$PROMPT" \
  --model "$EVAL_MODEL_SNAPSHOT" \
  ${EVAL_FIXTURES_DIR:+--fixtures "$EVAL_FIXTURES_DIR"})"

: "${EVAL_SUITE_DIR:?EVAL_SUITE_DIR must be set (expand.py sets this for stub providers)}"
CASSETTE="$REPO_ROOT/$EVAL_SUITE_DIR/golden/${KEY}.json"

if [[ ! -f "$CASSETTE" ]]; then
  printf 'cassette stale or missing for suite=%s provider=%s key=%s\n' \
    "$EVAL_SUITE" "$EVAL_PROVIDER" "$KEY" >&2
  printf 'expected: %s\n' "${CASSETTE#"$REPO_ROOT/"}" >&2
  printf 're-record with: just eval-record\n' >&2
  # Append to the missing-cassette report if the harness set a path.
  if [[ -n "${EVAL_MISSING_REPORT:-}" ]]; then
    {
      printf '%s %s %s\n' "$EVAL_SUITE" "$EVAL_PROVIDER" "$KEY"
    } >> "$EVAL_MISSING_REPORT"
  fi
  exit 2
fi

# Replay: stdout = recorded text, stderr = recorded trace (one line of JSON).
jq -r '.text' "$CASSETTE"

# Reconstruct the trace envelope on stderr in the same shape live wrappers emit.
jq -c '{triggered, elapsed_ms, family, provenance}' "$CASSETTE" 1>&2
