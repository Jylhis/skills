#!/usr/bin/env bash
# Cassette replay for the judge layer. Used by CI so g-eval assertions
# do not require live model access. Replays
# skills/<category>/<name>/evals/golden/<key>.judge.json keyed on the
# judge prompt (which promptfoo constructs deterministically from the
# rubric + response).

# shellcheck source=evals/providers/lib.sh
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
. "$SCRIPT_DIR/../providers/lib.sh"

emit_family_if_requested stub "${1:-}"

require_cmd python3 jq

# Import config.env from promptfoo's options JSON (argv[2]).
import_promptfoo_env "${2:-}"

PROMPT="${1:?prompt required as argv[1]}"
WORKDIR="${EVAL_WORKDIR:-$(mktemp -d -t judge-stub-XXXXXX)}"
mkdir -p "$WORKDIR"

EVAL_SUITE="${EVAL_SUITE:?EVAL_SUITE env var required}"
EVAL_JUDGE_PROVIDER="${EVAL_JUDGE_PROVIDER:-stub}"
EVAL_MODEL_SNAPSHOT="${EVAL_MODEL_SNAPSHOT:-default}"

REPO_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"

KEY="$(python3 "$REPO_ROOT/evals/scripts/cassette.py" key \
  --provider "judge-${EVAL_JUDGE_PROVIDER}" \
  --prompt "$PROMPT" \
  --model "$EVAL_MODEL_SNAPSHOT")"

: "${EVAL_SUITE_DIR:?EVAL_SUITE_DIR must be set (expand.py sets this for stub judges)}"
CASSETTE="$REPO_ROOT/$EVAL_SUITE_DIR/golden/${KEY}.judge.json"

if [[ ! -f "$CASSETTE" ]]; then
  printf 'judge cassette stale or missing for suite=%s judge=%s key=%s\n' \
    "$EVAL_SUITE" "$EVAL_JUDGE_PROVIDER" "$KEY" >&2
  printf 'expected: %s\n' "${CASSETTE#"$REPO_ROOT/"}" >&2
  printf 're-record with: just eval-record\n' >&2
  if [[ -n "${EVAL_MISSING_REPORT:-}" ]]; then
    printf '%s judge-%s %s\n' "$EVAL_SUITE" "$EVAL_JUDGE_PROVIDER" "$KEY" \
      >> "$EVAL_MISSING_REPORT"
  fi
  exit 2
fi

# The recorded judge envelope stores the judge's raw text response
# under .text; promptfoo's g-eval will re-parse that into a score.
jq -r '.text' "$CASSETTE"
jq -c '{triggered, elapsed_ms, family, provenance}' "$CASSETTE" 1>&2
