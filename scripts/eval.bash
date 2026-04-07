#!/usr/bin/env bash
# eval.bash — wrap promptfoo eval with sensible defaults.
#
# Flags:
#   --fast            Run only routing-tagged tests
#   --filter <name>   Pass through to promptfoo --filter-pattern
#
# Requires: npx (provided by devenv.nix nodejs_20)

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
CONFIG="$REPO_ROOT/evals/promptfooconfig.yaml"

[[ -f "$CONFIG" ]] || { echo "missing $CONFIG" >&2; exit 1; }
command -v npx >/dev/null 2>&1 || { echo "npx not on PATH (enter devenv shell)" >&2; exit 1; }

args=(eval --config "$CONFIG")
filter_set=0

while [[ $# -gt 0 ]]; do
  case "$1" in
    --fast)
      args+=(--filter-pattern '@routing')
      filter_set=1
      ;;
    --filter)
      shift
      [[ $# -gt 0 ]] || { echo "--filter needs a value" >&2; exit 2; }
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
exec npx --yes promptfoo@latest "${args[@]}"
