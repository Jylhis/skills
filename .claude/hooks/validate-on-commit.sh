#!/usr/bin/env bash
# PreToolUse hook (matcher: Bash): run the portable skill lint before any
# `git commit`. Non-commit commands pass through untouched.
set -u
cd "${CLAUDE_PROJECT_DIR:-.}" || exit 0
input=$(cat)
case "$input" in *commit*) ;; *) exit 0 ;; esac
if command -v jq >/dev/null 2>&1; then
  cmd=$(printf '%s' "$input" | jq -r '.tool_input.command // empty')
else
  cmd=$(printf '%s' "$input" | python3 -c 'import json,sys; print(json.load(sys.stdin).get("tool_input", {}).get("command", ""))')
fi
printf '%s' "$cmd" | grep -qE '(^|[^[:alnum:]_-])git[[:space:]]([^;|&]*[[:space:]])?commit([^[:alnum:]_-]|$)' || exit 0
if ! out=$(python3 scripts/validate.py 2>&1); then
  printf '%s\n' "$out" >&2
  echo "Blocked: scripts/validate.py failed. Fix skill lint errors before committing." >&2
  exit 2
fi
exit 0
