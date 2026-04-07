#!/usr/bin/env bash
# bump-vendor.bash — fast-forward each git submodule under vendor/, run the
# eval suite, and commit the bumped submodule pointers if evals pass.
#
# On eval failure: prints what would have been committed and exits non-zero
# WITHOUT touching the working tree.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

cd "$REPO_ROOT"

if [[ ! -f .gitmodules ]]; then
  echo "no .gitmodules — nothing to bump"
  exit 0
fi

echo "==> fetching and fast-forwarding submodules under vendor/"
# shellcheck disable=SC2016  # $displaypath is set by `git submodule foreach`, not the parent shell
git submodule foreach --recursive '
  set -e
  case "$displaypath" in
    vendor/*) ;;
    *) echo "  skipping $displaypath (not under vendor/)"; exit 0 ;;
  esac
  git fetch --quiet origin
  default="$(git remote show origin | sed -n "/HEAD branch/s/.*: //p")"
  git checkout --quiet "$default"
  git pull --quiet --ff-only
'

echo "==> running full eval suite"
if bash "$SCRIPT_DIR/eval.bash"; then
  git add -- vendor
  if git diff --cached --quiet; then
    echo "==> no submodule changes to commit"
    exit 0
  fi
  status_lines="$(git submodule status -- vendor | awk '{printf "  %s -> %s\n", $2, substr($1,2,12)}')"
  git commit -m "$(printf 'vendor: bump submodules\n\n%s\n' "$status_lines")"
  echo "==> committed"
else
  echo "==> evals FAILED — would have committed:"
  git diff -- vendor || true
  git submodule status -- vendor || true
  echo "  working tree left unchanged for inspection"
  exit 1
fi
