#!/usr/bin/env bash
# Install this repo (the jylhis-skills plugin) into supported agent tools.
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

enable_codex_plugin() {
  local config="$1"
  local plugin_id="jylhis-skills@jylhis-skills"
  local section="[plugins.\"$plugin_id\"]"
  local tmp

  if [[ $DRY_RUN -eq 1 ]]; then
    echo "DRY: enable Codex plugin $plugin_id in $config"
    return
  fi

  mkdir -p "$(dirname "$config")"
  touch "$config"

  if grep -qF "$section" "$config"; then
    tmp="$(mktemp "${config}.XXXXXX")"
    awk -v section="$section" '
      /^\[/ {
        if (in_section && !saw_enabled) {
          print "enabled = true"
        }
        in_section = ($0 == section)
        if (in_section) {
          saw_enabled = 0
        }
      }
      in_section && /^enabled[[:space:]]*=/ {
        print "enabled = true"
        saw_enabled = 1
        next
      }
      { print }
      END {
        if (in_section && !saw_enabled) {
          print "enabled = true"
        }
      }
    ' "$config" > "$tmp"
    mv "$tmp" "$config"
  else
    printf '\n[plugins."%s"]\nenabled = true\n' "$plugin_id" >> "$config"
  fi

  echo "enable Codex plugin $plugin_id in $config"
}

sync_codex_plugin_cache() {
  local cache_dir="$1/plugins/cache/jylhis-skills/jylhis-skills"
  local cache_root="$cache_dir/local"

  run mkdir -p "$cache_dir"
  if [[ -L "$cache_root" || ( -e "$cache_root" && ! -d "$cache_root" ) ]]; then
    run mkdir -p "$BACKUP_ROOT"
    run mv "$cache_root" "$BACKUP_ROOT/$(basename "$cache_root")"
  fi
  run mkdir -p "$cache_root"
  run rsync -a --delete --delete-excluded \
    --exclude .git \
    --exclude .devenv \
    --exclude .direnv \
    --exclude .cache \
    --exclude .claude \
    --exclude .codex \
    --exclude .gemini \
    --exclude result \
    --exclude 'result-*' \
    --exclude __pycache__ \
    --exclude '*.pyc' \
    "$REPO_ROOT/" "$cache_root/"
  echo "sync $cache_root <- $REPO_ROOT"
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
EXPECTED_MARKETPLACE_SOURCE="$REPO_ROOT"

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
  KNOWN_SOURCE="$(
    python3 - "$KNOWN" <<'PY'
import json, sys
path = sys.argv[1]
try:
    with open(path, "r", encoding="utf-8") as f:
        data = json.load(f)
except Exception:
    print("")
    raise SystemExit(0)

if isinstance(data, dict):
    entries = data.get("marketplaces", [])
else:
    entries = data

if not isinstance(entries, list):
    print("")
    raise SystemExit(0)

for entry in entries:
    if isinstance(entry, dict) and entry.get("name") == "jylhis-skills":
        print(entry.get("source", ""))
        raise SystemExit(0)

print("")
PY
  )"

  if [[ -z "$KNOWN_SOURCE" ]]; then
    run claude plugin marketplace add "$REPO_ROOT" --scope user
  elif [[ "$KNOWN_SOURCE" != "$EXPECTED_MARKETPLACE_SOURCE" ]]; then
    echo "error: marketplace jylhis-skills already exists with source: $KNOWN_SOURCE"
    echo "expected source: $EXPECTED_MARKETPLACE_SOURCE"
    echo "refusing to install from ambiguous marketplace entry"
    exit 1
  else
    echo "skip marketplace add (jylhis-skills already points to $EXPECTED_MARKETPLACE_SOURCE)"
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

# Migrate older installs: a raw symlink under ~/.codex/plugins is not a
# Codex marketplace install and can make Codex try to parse Claude metadata.
CODEX_LEGACY_LINK="$CODEX_DIR/plugins/jylhis-skills"
if [[ -e "$CODEX_LEGACY_LINK" || -L "$CODEX_LEGACY_LINK" ]]; then
  run mkdir -p "$BACKUP_ROOT"
  run mv "$CODEX_LEGACY_LINK" "$BACKUP_ROOT/$(basename "$CODEX_LEGACY_LINK")"
  echo "moved legacy Codex plugin path $CODEX_LEGACY_LINK -> $BACKUP_ROOT/"
fi

if command -v codex >/dev/null 2>&1; then
  run codex plugin marketplace add "$REPO_ROOT"
  sync_codex_plugin_cache "$CODEX_DIR"
  enable_codex_plugin "$CODEX_DIR/config.toml"
else
  cat <<EOF
codex CLI not found on PATH. To finish the Codex install, run:
  codex plugin marketplace add $REPO_ROOT
  mkdir -p ~/.codex/plugins/cache/jylhis-skills/jylhis-skills
  rsync -a --delete $REPO_ROOT/ ~/.codex/plugins/cache/jylhis-skills/jylhis-skills/local/

Then enable this plugin in ~/.codex/config.toml:
  [plugins."jylhis-skills@jylhis-skills"]
  enabled = true
EOF
fi

if [[ -d "$BACKUP_ROOT" ]]; then
  echo
  echo "Existing files were backed up to: $BACKUP_ROOT"
fi
