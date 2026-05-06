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
# Register this repo as a local marketplace and install the plugin from it.
# That makes the plugin appear in `/plugin` (raw symlinks under
# ~/.claude/plugins/ load at runtime but never show in the marketplace UI).
CLAUDE_DIR="${CLAUDE_HOME:-$HOME/.claude}"
run mkdir -p "$CLAUDE_DIR/plugins"

# Migrate older installs: a raw symlink at ~/.claude/plugins/jylhis-skills
# would cause the plugin to load twice once we also install via marketplace.
LEGACY_LINK="$CLAUDE_DIR/plugins/jylhis-skills"
if [[ -L "$LEGACY_LINK" ]]; then
  run mkdir -p "$BACKUP_ROOT"
  run mv "$LEGACY_LINK" "$BACKUP_ROOT/$(basename "$LEGACY_LINK")"
  echo "moved legacy symlink $LEGACY_LINK -> $BACKUP_ROOT/"
fi

KNOWN="$CLAUDE_DIR/plugins/known_marketplaces.json"
INSTALLED="$CLAUDE_DIR/plugins/installed_plugins.json"

# --scope user writes enabledPlugins to ~/.claude/settings.json. If that
# file is owned by home-manager / read-only, fall back to --scope project,
# which writes to <repo>/.claude/settings.json instead.
SCOPE="${CLAUDE_PLUGIN_SCOPE:-}"
if [[ -z "$SCOPE" ]]; then
  if [[ -e "$CLAUDE_DIR/settings.json" && ! -w "$CLAUDE_DIR/settings.json" ]]; then
    echo "note: $CLAUDE_DIR/settings.json is not writable (home-manager?); using --scope project"
    SCOPE=project
  else
    SCOPE=user
  fi
fi

if command -v claude >/dev/null 2>&1; then
  if ! grep -q '"jylhis-skills"' "$KNOWN" 2>/dev/null; then
    run claude plugin marketplace add "$REPO_ROOT" --scope user
  else
    echo "skip marketplace add (jylhis-skills already in $KNOWN)"
  fi
  if ! grep -q '"jylhis-skills@jylhis-skills"' "$INSTALLED" 2>/dev/null; then
    run claude plugin install jylhis-skills@jylhis-skills --scope "$SCOPE"
  else
    echo "skip plugin install (jylhis-skills@jylhis-skills already in $INSTALLED)"
  fi
else
  cat <<EOF
claude CLI not found on PATH. To finish the Claude Code install, run inside
Claude Code:
  /plugin marketplace add $REPO_ROOT
  /plugin install jylhis-skills@jylhis-skills
EOF
fi

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
