#!/usr/bin/env bash
# Symlink this repo (the jylhis-skills plugin) into each tool's plugin directory.
# Also links AGENTS.md and CLAUDE.md directly for Claude Code project context.
# Idempotent. Backs up any existing files it would overwrite.
#
# Usage: bash scripts/install.sh [--dry-run]
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
TS="$(date -u +%Y%m%dT%H%M%SZ)"

DRY_RUN=0
[[ "${1:-}" == "--dry-run" ]] && DRY_RUN=1

run() { if [[ $DRY_RUN -eq 1 ]]; then echo "DRY: $*"; else "$@"; fi; }

BACKUP_ROOT="$HOME/.skills-backup-$TS"

link() {
  local src="$1" dst="$2"
  # Always create absolute-path symlinks. Plain `readlink` avoids
  # `readlink -f` which is GNU-only and not on stock macOS.
  if [[ -L "$dst" ]] && [[ "$(readlink "$dst")" == "$src" ]]; then
    echo "skip $dst (already linked)"
    return
  fi
  if [[ -e "$dst" || -L "$dst" ]]; then
    run mkdir -p "$BACKUP_ROOT"
    run mv "$dst" "$BACKUP_ROOT/$(basename "$dst")"
  fi
  run ln -s "$src" "$dst"
  echo "link $dst -> $src"
}

# ── Claude Code ──────────────────────────────────────────────────────────────
CLAUDE_DIR="${CLAUDE_HOME:-$HOME/.claude}"
run mkdir -p "$CLAUDE_DIR/plugins"
link "$REPO_ROOT" "$CLAUDE_DIR/plugins/jylhis-skills"

# Direct context links so @AGENTS.md and CLAUDE.md resolve inside ~/.claude/
[[ -f "$REPO_ROOT/AGENTS.md" ]] && link "$REPO_ROOT/AGENTS.md" "$CLAUDE_DIR/AGENTS.md"
[[ -f "$REPO_ROOT/CLAUDE.md" ]] && link "$REPO_ROOT/CLAUDE.md" "$CLAUDE_DIR/CLAUDE.md"

# ── Gemini CLI ────────────────────────────────────────────────────────────────
GEMINI_DIR="$HOME/.gemini"
run mkdir -p "$GEMINI_DIR/extensions"
link "$REPO_ROOT" "$GEMINI_DIR/extensions/jylhis-skills"

# ── Codex ─────────────────────────────────────────────────────────────────────
CODEX_DIR="$HOME/.codex"
run mkdir -p "$CODEX_DIR/plugins"
link "$REPO_ROOT" "$CODEX_DIR/plugins/jylhis-skills"

if [[ -d "$BACKUP_ROOT" ]]; then
  echo
  echo "Existing files were backed up to: $BACKUP_ROOT"
fi
