#!/usr/bin/env bash
# Install the jylhis-skills marketplace + the default plugin into supported
# agent tools. Targets: Claude Code (CLI + Claude Code on the web, same plugin
# marketplace mechanism) and Pi (pi-coding-agent). Per-language and per-tool
# plugins remain opt-in — the script prints the commands to install them at the
# end. claude.ai Skills are a separate, upload-based channel (see `just package`
# / docs/install.md), not wired here.
#
# Links AGENTS.md for Pi project context. (~/.claude/CLAUDE.md and AGENTS.md are
# Home-Manager-managed, so this installer no longer touches them.) Idempotent.
# Backs up any existing files it would overwrite.
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
  jylhis-systemd
  jylhis-gitlab
  jylhis-terraform
  jylhis-azure
  jylhis-obsidian
  jylhis-pkm
  jylhis-grafana
  jylhis-taste
  jylhis-duckdb
)
LEGACY_PLUGIN="jylhis-skills"   # the pre-split monolith

# Opt-in plugins that are nevertheless mirrored into Pi on every run, in
# addition to the default plugin. These are the commonly-useful language and
# tool plugins the user wants available without a manual opt-in step. Claude
# Code still installs them via the normal /plugin opt-in flow.
PI_ALWAYS_PLUGINS=(
  jylhis-python
  jylhis-typescript
  jylhis-go
  jylhis-jvm
  jylhis-emacs
  jylhis-nix
  jylhis-filesystems
  jylhis-systemd
  jylhis-obsidian
  jylhis-pkm
)

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
    # Name the backup after the full destination path (slashes → underscores)
    # so distinct files that share a basename — e.g. ~/.claude/AGENTS.md and
    # ~/.pi/agent/AGENTS.md — don't clobber each other's backup.
    local rel="${dst#/}"
    run mv "$dst" "$BACKUP_ROOT/${rel//\//_}"
  fi
  run ln -s "$src" "$dst"
  echo "link $dst -> $src"
}

# Pi (pi-coding-agent) discovers skills by recursively scanning its skills
# directories for SKILL.md. Mirror a plugin's skills/ symlink farm into
# ~/.pi/agent/skills/<plugin>/ as real files (rsync -L resolves the symlinks to
# the canonical skills/<category>/<name>/ tree). evals/ are recording fixtures,
# not skill content, so they are excluded.
sync_pi_plugin_skills() {
  local pi_dir="$1" plugin="$2"
  local dest="$pi_dir/skills/$plugin"

  # Back up any existing symlink / non-directory before creating the dir, so a
  # broken symlink at $dest can't make `mkdir -p` fail.
  if [[ -L "$dest" || ( -e "$dest" && ! -d "$dest" ) ]]; then
    run mkdir -p "$BACKUP_ROOT"
    run mv "$dest" "$BACKUP_ROOT/pi-skills-$(basename "$dest")"
  fi
  run mkdir -p "$dest"
  run rsync -aL --delete --delete-excluded \
    --exclude .git \
    --exclude .devenv \
    --exclude .direnv \
    --exclude .cache \
    --exclude .claude \
    --exclude evals \
    --exclude result \
    --exclude 'result-*' \
    --exclude __pycache__ \
    --exclude '*.pyc' \
    "$REPO_ROOT/plugins/$plugin/skills/" "$dest/"
  echo "sync $dest <- $REPO_ROOT/plugins/$plugin/skills"
}

# True if $1 is a plugin that should always be mirrored into Pi (a member of
# PI_ALWAYS_PLUGINS). Used to skip it in the refresh loop, since it is already
# synced unconditionally above.
is_pi_always_plugin() {
  local needle="$1"
  local p
  for p in "${PI_ALWAYS_PLUGINS[@]}"; do
    [[ "$p" == "$needle" ]] && return 0
  done
  return 1
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

# ~/.claude/CLAUDE.md is Home-Manager-managed (programs.claude-code.context),
# so this installer no longer links CLAUDE.md or AGENTS.md into ~/.claude/ --
# doing so collided with HM's managed file. Global output-style conventions
# now live in the HM-managed CLAUDE.md; repo-specific guidance loads via this
# repo's own CLAUDE.md when working here. Pi still gets its AGENTS.md below.

# ── Pi (pi-coding-agent) ──────────────────────────────────────────────────────
# Pi reads ~/.pi/agent/AGENTS.md for project context and auto-discovers SKILL.md
# under ~/.pi/agent/skills/. We mirror the default plugin's skills there and link
# AGENTS.md. Override the agent dir with PI_AGENT_DIR (Pi honours
# PI_CODING_AGENT_DIR at runtime).
PI_DIR="${PI_AGENT_DIR:-${PI_CODING_AGENT_DIR:-$HOME/.pi/agent}}"
run mkdir -p "$PI_DIR/skills"

if command -v pi >/dev/null 2>&1; then
  sync_pi_plugin_skills "$PI_DIR" "$DEFAULT_PLUGIN"
  echo "pi: synced ${DEFAULT_PLUGIN} skills into $PI_DIR/skills"

  # Always-install plugins: mirror these into Pi on every run, not just when
  # the user has previously opted in.
  for plugin_name in "${PI_ALWAYS_PLUGINS[@]}"; do
    echo "sync pi:$plugin_name (always)"
    sync_pi_plugin_skills "$PI_DIR" "$plugin_name"
  done

  # Refresh any remaining opt-in plugins already mirrored into Pi so they pick
  # up structural changes. A plugin is "installed for Pi" if its skills dir
  # exists. Skip PI_ALWAYS_PLUGINS (already synced above).
  for plugin_name in "${OPTIN_PLUGINS[@]}"; do
    [[ -d "$PI_DIR/skills/$plugin_name" ]] || continue
    is_pi_always_plugin "$plugin_name" && continue
    echo "refresh pi:$plugin_name"
    sync_pi_plugin_skills "$PI_DIR" "$plugin_name"
  done
else
  cat <<EOF
pi (pi-coding-agent) not found on PATH. Install it with:
  npm install -g @earendil-works/pi-coding-agent
  # or: curl -fsSL https://pi.dev/install.sh | sh
Then re-run this script to sync the default and always-on plugins, or sync the
default plugin manually:
  mkdir -p "$PI_DIR/skills/${DEFAULT_PLUGIN}"
  rsync -aL --delete "$REPO_ROOT/plugins/${DEFAULT_PLUGIN}/skills/" "$PI_DIR/skills/${DEFAULT_PLUGIN}/"
EOF
fi

# Pi project context (it reads AGENTS.md / CLAUDE.md from its agent dir).
[[ -f "$REPO_ROOT/AGENTS.md" ]] && link "$REPO_ROOT/AGENTS.md" "$PI_DIR/AGENTS.md"

# ── Opt-in install hints ────────────────────────────────────────────────────
PI_ALWAYS_STR="${PI_ALWAYS_PLUGINS[*]}"
PI_OPTIN_REMAINING=""
for p in "${OPTIN_PLUGINS[@]}"; do
  if ! is_pi_always_plugin "$p"; then
    PI_OPTIN_REMAINING="${PI_OPTIN_REMAINING:+$PI_OPTIN_REMAINING }$p"
  fi
done

cat <<EOF

Default plugin installed: ${DEFAULT_PLUGIN}
Always installed for Pi (in addition to default): ${PI_ALWAYS_STR}
Available opt-in plugins (Claude Code): ${OPTIN_PLUGINS[*]}
Remaining opt-in for Pi: ${PI_OPTIN_REMAINING}

To install a remaining opt-in (example: jylhis-gitlab):
  Claude Code:  /plugin install jylhis-gitlab@jylhis-skills
  Pi:           rsync -aL --delete "$REPO_ROOT/plugins/jylhis-gitlab/skills/" "$PI_DIR/skills/jylhis-gitlab/"
                # then re-run scripts/install.sh to keep it refreshed

claude.ai Skills (upload channel): run \`just package\` and upload
dist/skills/<name>.zip via claude.ai → Settings → Capabilities → Skills.
EOF

if [[ -d "$BACKUP_ROOT" ]]; then
  echo
  echo "Existing files were backed up to: $BACKUP_ROOT"
fi
