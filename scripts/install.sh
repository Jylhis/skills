#!/usr/bin/env bash
# Install the jylhis-skills marketplace + the default plugin into supported
# agent tools. Per-language and per-tool plugins remain opt-in — the script
# prints the commands to install them at the end.
#
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

# Plugin set published by the marketplace.
DEFAULT_PLUGIN="jylhis-skills-core"
OPTIN_PLUGINS=(
  jylhis-python
  jylhis-typescript
  jylhis-go
  jylhis-jvm
  jylhis-emacs
  jylhis-nix
  jylhis-filesystems
  jylhis-gitlab
  jylhis-terraform
  jylhis-azure
  jylhis-obsidian
  jylhis-grafana
  jylhis-taste
)
LEGACY_PLUGIN="jylhis-skills"   # the pre-split monolith

ALL_PLUGINS=("$DEFAULT_PLUGIN" "${OPTIN_PLUGINS[@]}")

# Iterate $INSTALLED (Claude) for jylhis-* plugins currently installed in this scope.
# Used to refresh all installed plugins, not just the default, after a structural
# repo change (e.g. skill layout migration).
list_installed_claude_plugins() {
  local installed="$1"
  [[ -f "$installed" ]] || return 0
  python3 - "$installed" <<'PY' 2>/dev/null || true
import json, sys
try:
    with open(sys.argv[1]) as f:
        data = json.load(f)
except (OSError, ValueError):
    sys.exit(0)
keys = data.get("installedPlugins", data) if isinstance(data, dict) else {}
if isinstance(keys, dict):
    for k in keys:
        if k.endswith("@jylhis-skills"):
            print(k)
PY
}

# Iterate ~/.codex/config.toml [plugins."<name>@jylhis-skills"] sections currently
# enabled. Same purpose as the Claude variant — find opt-ins to refresh.
list_enabled_codex_plugins() {
  local config="$1"
  [[ -f "$config" ]] || return 0
  python3 - "$config" <<'PY'
import re
import sys

section_re = re.compile(r'^\[plugins\."([^"]+@jylhis-skills)"\]\s*$')
enabled_re = re.compile(r"^enabled\s*=\s*true\s*$")

current = ""
try:
    with open(sys.argv[1], encoding="utf-8") as f:
        for raw_line in f:
            line = raw_line.strip()
            match = section_re.match(line)
            if match:
                current = match.group(1)
                continue
            if line.startswith("["):
                current = ""
                continue
            if current and enabled_re.match(line):
                print(current)
                current = ""
except OSError:
    pass
PY
}

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
  local plugin_id="$2"
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

remove_codex_plugin_config_section() {
  local config="$1"
  local plugin_id="$2"
  local section="[plugins.\"$plugin_id\"]"

  [[ -f "$config" ]] || return 0
  grep -qF "$section" "$config" || return 0

  if [[ $DRY_RUN -eq 1 ]]; then
    echo "DRY: remove legacy Codex plugin section $plugin_id from $config"
    return
  fi

  python3 - "$config" "$section" <<'PY'
import sys

path, section = sys.argv[1], sys.argv[2]

try:
    with open(path, encoding="utf-8") as f:
        lines = f.readlines()
except OSError:
    sys.exit(0)

out = []
skipping = False
changed = False

for line in lines:
    stripped = line.strip()
    if stripped == section:
        skipping = True
        changed = True
        continue
    if skipping and stripped.startswith("["):
        skipping = False
    if not skipping:
        out.append(line)

if changed:
    with open(path, "w", encoding="utf-8") as f:
        f.writelines(out)
PY

  echo "removed legacy Codex plugin section $plugin_id from $config"
}

sync_codex_plugin_cache() {
  local cache_dir="$1/plugins/cache/jylhis-skills/$2"
  local cache_root="$cache_dir/local"

  run mkdir -p "$cache_dir"
  if [[ -L "$cache_root" || ( -e "$cache_root" && ! -d "$cache_root" ) ]]; then
    run mkdir -p "$BACKUP_ROOT"
    run mv "$cache_root" "$BACKUP_ROOT/$(basename "$cache_root")"
  fi
  run mkdir -p "$cache_root"
  # Codex plugin cache mirrors the per-plugin directory under plugins/<name>/.
  # Use rsync -L so the per-plugin skills/ symlinks resolve to the canonical
  # SKILL.md tree under the repo's skills/ root.
  run rsync -aL --delete --delete-excluded \
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
    "$REPO_ROOT/plugins/$2/" "$cache_root/"
  echo "sync $cache_root <- $REPO_ROOT/plugins/$2"
}

# ── Claude Code ──────────────────────────────────────────────────────────────
# Register this repo as a local marketplace and install only the default plugin.
# Other plugins appear in `/plugin` UI as opt-in and require explicit install.
CLAUDE_DIR="${CLAUDE_HOME:-$HOME/.claude}"
run mkdir -p "$CLAUDE_DIR/plugins"

# Migrate older installs:
#  - a raw symlink at ~/.claude/plugins/jylhis-skills predates the marketplace flow;
#  - the pre-split single plugin was installed as `jylhis-skills@jylhis-skills`.
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

# Read the recorded marketplace source. An older install may point at a
# stale GitHub mirror instead of this repo (`Jylhis/skills`), which causes
# Claude to keep serving an outdated skill list. Returns empty if the entry
# is missing or unreadable.
claude_marketplace_source() {
  python3 - "$KNOWN" <<'PY' 2>/dev/null || true
import json, sys
try:
    with open(sys.argv[1]) as f:
        data = json.load(f)
except (OSError, ValueError):
    sys.exit(0)
src = data.get("jylhis-skills", {}).get("source", {})
if src.get("source") == "local":
    print(src.get("path") or src.get("location") or "")
elif src.get("path"):
    print(src["path"])
else:
    parts = [src.get(k, "") for k in ("source", "repo", "url")]
    print("|".join(p for p in parts if p))
PY
}

if command -v claude >/dev/null 2>&1; then
  current_src="$(claude_marketplace_source)"
  if [[ -n "$current_src" && "$current_src" != "$REPO_ROOT" ]]; then
    echo "claude marketplace source ($current_src) differs from $REPO_ROOT; resetting"
    if grep -q "\"${LEGACY_PLUGIN}@jylhis-skills\"" "$INSTALLED" 2>/dev/null; then
      run claude plugin uninstall "${LEGACY_PLUGIN}@jylhis-skills" --scope user --keep-data || true
    fi
    run claude plugin marketplace remove jylhis-skills || true
  fi

  # Drop the pre-split monolithic install if present — its skill set is now
  # fanned out across the per-language plugins, so leaving it installed would
  # double-load every skill once we install jylhis-skills-core.
  if grep -q "\"${LEGACY_PLUGIN}@jylhis-skills\"" "$INSTALLED" 2>/dev/null; then
    echo "removing legacy single-plugin install ${LEGACY_PLUGIN}@jylhis-skills"
    run claude plugin uninstall "${LEGACY_PLUGIN}@jylhis-skills" --scope user --keep-data || true
  fi

  if ! grep -q '"jylhis-skills"' "$KNOWN" 2>/dev/null; then
    run claude plugin marketplace add "$REPO_ROOT" --scope user
  else
    echo "skip marketplace add (jylhis-skills already in $KNOWN)"
  fi

  # Refresh the marketplace's snapshot of $REPO_ROOT, then install or
  # update the default plugin only. Other plugins remain opt-in.
  run claude plugin marketplace update jylhis-skills || true

  if grep -q "\"${DEFAULT_PLUGIN}@jylhis-skills\"" "$INSTALLED" 2>/dev/null; then
    run claude plugin update "${DEFAULT_PLUGIN}@jylhis-skills" --scope "$SCOPE" || true
  else
    run claude plugin install "${DEFAULT_PLUGIN}@jylhis-skills" --scope "$SCOPE"
  fi

  # Refresh any opt-in plugins the user has previously installed so they pick
  # up structural changes (e.g. the skills/<category>/<name> layout migration).
  while IFS= read -r installed_id; do
    case "$installed_id" in
      "${DEFAULT_PLUGIN}@jylhis-skills"|"") continue ;;
    esac
    echo "refresh $installed_id"
    run claude plugin update "$installed_id" --scope "$SCOPE" || true
  done < <(list_installed_claude_plugins "$INSTALLED")
else
  cat <<EOF
claude CLI not found on PATH. To finish the Claude Code install, run inside
Claude Code:
  /plugin marketplace add $REPO_ROOT
  /plugin install ${DEFAULT_PLUGIN}@jylhis-skills
EOF
fi

# Direct context links so @AGENTS.md and CLAUDE.md resolve inside ~/.claude/
[[ -f "$REPO_ROOT/AGENTS.md" ]] && link "$REPO_ROOT/AGENTS.md" "$CLAUDE_DIR/AGENTS.md"
[[ -f "$REPO_ROOT/CLAUDE.md" ]] && link "$REPO_ROOT/CLAUDE.md" "$CLAUDE_DIR/CLAUDE.md"

# ── Google Antigravity ───────────────────────────────────────────────────────
# Antigravity discovers skills directly from ~/.gemini/antigravity/skills/<name>/.
# Each plugin's skills/ directory contains symlinks into the canonical
# skills/<category>/<name>/ tree; we resolve those and create one symlink per
# skill in Antigravity's global skills dir.
ANTIGRAVITY_DIR="$HOME/.gemini/antigravity"
run mkdir -p "$ANTIGRAVITY_DIR/skills"

# Migrate legacy Gemini CLI installs: the old flow symlinked plugins into
# ~/.gemini/extensions/. Antigravity does not consume that directory.
GEMINI_EXT_DIR="$HOME/.gemini/extensions"
if [[ -d "$GEMINI_EXT_DIR" ]]; then
  for legacy in "$GEMINI_EXT_DIR"/jylhis-*; do
    [[ -e "$legacy" || -L "$legacy" ]] || continue
    run mkdir -p "$BACKUP_ROOT"
    run mv "$legacy" "$BACKUP_ROOT/gemini-ext-$(basename "$legacy")"
    echo "moved legacy Gemini extension $legacy -> $BACKUP_ROOT/"
  done
fi

# Install Antigravity skills from the plugin's validated Claude manifest.
# This avoids trusting a flat scan of plugins/<plugin>/skills, which could
# include unmanifested local directories.
install_antigravity_skills_from_plugin() {
  local plugin="$1"
  local plugin_dir="$REPO_ROOT/plugins/$plugin"
  local manifest="$plugin_dir/.claude-plugin/plugin.json"
  [[ -f "$manifest" ]] || return 0

  local name target
  while IFS=$'\t' read -r name target; do
    [[ -n "$name" && -n "$target" ]] || continue
    link "$target" "$ANTIGRAVITY_DIR/skills/$name"
  done < <(
    python3 - "$REPO_ROOT" "$manifest" <<'PY'
import json
import pathlib
import sys

repo = pathlib.Path(sys.argv[1]).resolve()
manifest = pathlib.Path(sys.argv[2]).resolve()
plugin_dir = manifest.parent.parent
skills_root = (repo / "skills").resolve()

data = json.loads(manifest.read_text(encoding="utf-8"))
for raw in data.get("skills", []):
    path = (manifest.parent / raw).resolve()
    try:
        path.relative_to(skills_root)
    except ValueError:
        continue
    if not (path.is_dir() and (path / "SKILL.md").is_file()):
        continue
    print(f"{path.name}\t{path}")
PY
  )
}

install_antigravity_skills_from_plugin "$DEFAULT_PLUGIN"

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

# Drop the pre-split monolithic Codex cache if present.
CODEX_LEGACY_CACHE="$CODEX_DIR/plugins/cache/jylhis-skills/${LEGACY_PLUGIN}"
if [[ -d "$CODEX_LEGACY_CACHE" ]]; then
  run mkdir -p "$BACKUP_ROOT"
  run mv "$CODEX_LEGACY_CACHE" "$BACKUP_ROOT/codex-cache-$(basename "$CODEX_LEGACY_CACHE")"
  echo "moved legacy Codex cache $CODEX_LEGACY_CACHE -> $BACKUP_ROOT/"
fi

remove_codex_plugin_config_section "$CODEX_DIR/config.toml" "${LEGACY_PLUGIN}@jylhis-skills"

# Read the `source = "..."` line under `[marketplaces.jylhis-skills]` in
# Codex config.toml. Same intent as claude_marketplace_source: detect when
# an older add pointed at a remote mirror so we can reset before re-adding.
codex_marketplace_source() {
  local config="$1"
  [[ -f "$config" ]] || return 0
  awk '
    /^\[marketplaces\.jylhis-skills\]/ { in_section = 1; next }
    /^\[/                              { in_section = 0 }
    in_section && /^source[[:space:]]*=/ {
      sub(/^source[[:space:]]*=[[:space:]]*/, "")
      gsub(/^"|"$/, "")
      print
      exit
    }
  ' "$config"
}

if command -v codex >/dev/null 2>&1; then
  current_codex_src="$(codex_marketplace_source "$CODEX_DIR/config.toml")"
  if [[ -n "$current_codex_src" && "$current_codex_src" != "$REPO_ROOT" ]]; then
    echo "codex marketplace source ($current_codex_src) differs from $REPO_ROOT; resetting"
    run codex plugin marketplace remove jylhis-skills || true
  fi
  run codex plugin marketplace add "$REPO_ROOT"
  sync_codex_plugin_cache "$CODEX_DIR" "$DEFAULT_PLUGIN"
  enable_codex_plugin "$CODEX_DIR/config.toml" "${DEFAULT_PLUGIN}@jylhis-skills"

  # Refresh any opt-in Codex plugins the user has previously enabled so they
  # pick up structural changes (skills/<category>/<name> layout migration).
  while IFS= read -r enabled_id; do
    plugin_name="${enabled_id%@jylhis-skills}"
    case "$plugin_name" in
      "$DEFAULT_PLUGIN"|"") continue ;;
    esac
    is_known=0
    for known in "${ALL_PLUGINS[@]}"; do
      [[ "$known" == "$plugin_name" ]] && is_known=1 && break
    done
    [[ "$is_known" -eq 1 ]] || continue
    echo "refresh $enabled_id"
    sync_codex_plugin_cache "$CODEX_DIR" "$plugin_name"
  done < <(list_enabled_codex_plugins "$CODEX_DIR/config.toml")
else
  cat <<EOF
codex CLI not found on PATH. To finish the Codex install, run:
  codex plugin marketplace add $REPO_ROOT
  mkdir -p ~/.codex/plugins/cache/jylhis-skills/${DEFAULT_PLUGIN}
  rsync -aL --delete $REPO_ROOT/plugins/${DEFAULT_PLUGIN}/ ~/.codex/plugins/cache/jylhis-skills/${DEFAULT_PLUGIN}/local/

Then enable the default plugin in ~/.codex/config.toml:
  [plugins."${DEFAULT_PLUGIN}@jylhis-skills"]
  enabled = true
EOF
fi

# ── Opt-in install hints ────────────────────────────────────────────────────
cat <<EOF

Default plugin installed: ${DEFAULT_PLUGIN}
Available opt-in plugins: ${OPTIN_PLUGINS[*]}

To install one in each tool (example: jylhis-python):
  Claude Code:  /plugin install jylhis-python@jylhis-skills
  Codex:        codex plugin install jylhis-python@jylhis-skills
                # then set [plugins."jylhis-python@jylhis-skills"] enabled=true in ~/.codex/config.toml
  Antigravity:  for s in $REPO_ROOT/plugins/jylhis-python/skills/*; do
                  ln -s "\$s" "\$HOME/.gemini/antigravity/skills/\$(basename "\$s")"
                done
EOF

if [[ -d "$BACKUP_ROOT" ]]; then
  echo
  echo "Existing files were backed up to: $BACKUP_ROOT"
fi
