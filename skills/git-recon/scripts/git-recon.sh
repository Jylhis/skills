#!/usr/bin/env bash
set -euo pipefail

SINCE="1 year ago"

while [[ $# -gt 0 ]]; do
  case $1 in
    --since) SINCE="$2"; shift 2 ;;
    *) echo "Usage: git-recon.sh [--since \"<time>\"]" >&2; exit 1 ;;
  esac
done

if ! git rev-parse --is-inside-work-tree &>/dev/null; then
  echo "ERROR: Not inside a git repository." >&2
  exit 1
fi

COMMIT_COUNT=$(git rev-list --count HEAD 2>/dev/null || echo 0)
if [[ "$COMMIT_COUNT" -lt 2 ]]; then
  echo "ERROR: Repository has insufficient history ($COMMIT_COUNT commits)." >&2
  exit 1
fi

run_pipeline() {
  local cmd_template="$1"
  local default_msg="$2"
  local output
  # Pass SINCE via environment to bash -c to avoid injection
  output=$(SINCE="$SINCE" bash -c "$cmd_template" 2>/dev/null) || true
  if [[ -n "$output" ]]; then
    echo "$output"
  else
    echo "$default_msg"
  fi
}

REPO_ROOT=$(basename "$(git rev-parse --show-toplevel)")
echo "=== GIT RECON: $REPO_ROOT (since: $SINCE) ==="
echo ""

echo "=== FILE CHURN (most changed files) ==="
run_pipeline \
  "git log --format=format: --name-only --since=\"$SINCE\" | grep -v '^$' | sort | uniq -c | sort -nr | head -20" \
  "(no file changes found in this period)"
echo ""

echo "=== BUS FACTOR (contributor ranking, all time) ==="
run_pipeline \
  "git shortlog -sn --no-merges HEAD" \
  "(no contributors found)"
echo ""
echo "--- Recent contributors (since: $SINCE) ---"
run_pipeline \
  "git shortlog -sn --no-merges --since=\"$SINCE\" HEAD" \
  "(no recent contributors found)"
echo ""

echo "=== BUG HOTSPOTS (files in bug-related commits) ==="
run_pipeline \
  "git log -i -E --grep='fix|bug|broken' --name-only --format='' --since=\"$SINCE\" | grep -v '^$' | sort | uniq -c | sort -nr | head -20" \
  "(no bug-related commits found in this period)"
echo ""

echo "=== FIREFIGHTING (reverts, hotfixes, emergencies) ==="
run_pipeline \
  "git log --oneline --since=\"$SINCE\" | grep -iE 'revert|hotfix|emergency|rollback'" \
  "(no firefighting commits found in this period)"
echo ""

echo "=== PROJECT VELOCITY (commits per month) ==="
run_pipeline \
  "git log --format='%ad' --date=format:'%Y-%m' HEAD | sort | uniq -c" \
  "(unable to compute velocity)"
echo ""
