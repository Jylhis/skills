#!/usr/bin/env bash
# eval.bash — wrap promptfoo eval with sensible defaults.
#
# Flags:
#   --fast            Run only routing-tagged tests
#   --quality         Run only quality-tagged tests (llm-rubric)
#   --skill <name>    Filter by skill name (matches test description)
#   --filter <name>   Pass through to promptfoo --filter-pattern
#
# Requires: promptfoo (provided by devenv.nix)

set -euo pipefail

export PROMPTFOO_REQUEST_BACKOFF_MS="${PROMPTFOO_REQUEST_BACKOFF_MS:-5000}"
export PROMPTFOO_RETRY_5XX="${PROMPTFOO_RETRY_5XX:-true}"

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

args=(eval)
filter_set=0

while [[ $# -gt 0 ]]; do
  case "$1" in
    --fast)
      args+=(--filter-metadata 'tags=@routing')
      filter_set=1
      ;;
    --compare)
      args=(eval --config promptfooconfig.compare.yaml)
      ;;
    --redteam)
      args=(eval --config promptfooconfig.redteam.yaml)
      ;;
    --quality)
      args+=(--filter-metadata 'tags=@quality')
      filter_set=1
      ;;
    --filter)
      shift
      [[ $# -gt 0 ]] || { echo "--filter needs a value" >&2; exit 2; }
      args+=(--filter-pattern "$1")
      filter_set=1
      ;;
    --plugin)
      shift
      [[ $# -gt 0 ]] || { echo "--plugin needs a value" >&2; exit 2; }
      args+=(--filter-metadata "tags=@$1")
      filter_set=1
      ;;
    --skill)
      shift
      [[ $# -gt 0 ]] || { echo "--skill needs a value" >&2; exit 2; }
      args+=(--filter-pattern "$1")
      filter_set=1
      ;;
    *)
      args+=("$1")
      ;;
  esac
  shift
done

[[ $filter_set -eq 1 ]] || true   # acknowledge unused for clarity

cd "$REPO_ROOT"
exec promptfoo "${args[@]}"
