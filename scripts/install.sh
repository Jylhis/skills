#!/usr/bin/env bash
# Symlink this repo's skills/ and CLAUDE.md into ~/.claude/.
# Idempotent. Backs up any non-symlink contents it would overwrite.
#
# Usage: bash scripts/install.sh [--dry-run]
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
CLAUDE_DIR="${CLAUDE_HOME:-$HOME/.claude}"
TS="$(date -u +%Y%m%dT%H%M%SZ)"
BACKUP_DIR="$CLAUDE_DIR/.skills-backup-$TS"

DRY_RUN=0
[[ "${1:-}" == "--dry-run" ]] && DRY_RUN=1

run() { if [[ $DRY_RUN -eq 1 ]]; then echo "DRY: $*"; else "$@"; fi; }

link() {
  local src="$1" dst="$2"
  if [[ -L "$dst" ]] && [[ "$(readlink -f "$dst")" == "$src" ]]; then
    echo "skip $dst (already linked)"
    return
  fi
  if [[ -e "$dst" || -L "$dst" ]]; then
    run mkdir -p "$BACKUP_DIR"
    run mv "$dst" "$BACKUP_DIR/$(basename "$dst")"
  fi
  run ln -s "$src" "$dst"
  echo "link $dst -> $src"
}

run mkdir -p "$CLAUDE_DIR"
link "$REPO_ROOT/skills" "$CLAUDE_DIR/skills"
[[ -f "$REPO_ROOT/CLAUDE.md" ]] && link "$REPO_ROOT/CLAUDE.md" "$CLAUDE_DIR/CLAUDE.md"

if [[ -d "$BACKUP_DIR" ]]; then
  echo
  echo "Existing files were backed up to: $BACKUP_DIR"
fi
