#!/usr/bin/env bash
# install.sh — link the claude-config repo into ~/.claude/, build runtime,
# update shell rc. Idempotent. Re-run safely.
#
# Flags:
#   --dry-run         Print actions, change nothing
#   --verbose         Print every action including skips
#   --seed-from-live  Seed repo/CLAUDE.md from ~/.claude/CLAUDE.md if both
#                     conditions hold: repo CLAUDE.md is empty AND live one
#                     is a still-resolvable nix-store symlink. Default off.
#
# Environment overrides:
#   CLAUDE_HOME       Override ~/.claude (useful for testing)
#   XDG_STATE_HOME    Override ~/.local/state

set -euo pipefail

# ------------------------------------------------------------------ paths --

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
CLAUDE_DIR="${CLAUDE_HOME:-$HOME/.claude}"
STATE_DIR="${XDG_STATE_HOME:-$HOME/.local/state}/claude-config"
TS="$(date -u +%Y%m%dT%H%M%SZ)"
BACKUP_ROOT="$CLAUDE_DIR/.claude-config-backups/$TS"

DRY_RUN=0
VERBOSE=0
SEED_FROM_LIVE=0

# ------------------------------------------------------------------ flags --

while [[ $# -gt 0 ]]; do
  case "$1" in
    --dry-run)        DRY_RUN=1 ;;
    --verbose|-v)     VERBOSE=1 ;;
    --seed-from-live) SEED_FROM_LIVE=1 ;;
    -h|--help)
      sed -n '2,16p' "$0" | sed 's/^# \{0,1\}//'
      exit 0
      ;;
    *) echo "unknown flag: $1" >&2; exit 2 ;;
  esac
  shift
done

# ------------------------------------------------------------------ logging --

ACTIONS_TAKEN=0
ACTIONS_SKIPPED=0
LOG=()
NEXT_STEPS=()
BACKUP_USED=0

cyan()  { printf '\033[36m%s\033[0m' "$*"; }
yellow(){ printf '\033[33m%s\033[0m' "$*"; }
red()   { printf '\033[31m%s\033[0m' "$*"; }
green() { printf '\033[32m%s\033[0m' "$*"; }

log_action() {
  local kind="$1" target="$2" detail="${3:-}"
  LOG+=("${kind}|${target}|${detail}")
  if [[ $kind == skip ]]; then
    ACTIONS_SKIPPED=$((ACTIONS_SKIPPED + 1))
    [[ $VERBOSE -eq 1 ]] && printf '  %s %s %s\n' "$(cyan SKIP)" "$target" "$detail"
  else
    ACTIONS_TAKEN=$((ACTIONS_TAKEN + 1))
    printf '  %s %s %s\n' "$(green "$kind")" "$target" "$detail"
  fi
}

warn() { printf '%s %s\n' "$(yellow WARN)" "$*" >&2; }
die()  { printf '%s %s\n' "$(red ERR )" "$*" >&2; exit 1; }

# ------------------------------------------------------------------ dry-run wrappers --

run() {
  if [[ $DRY_RUN -eq 1 ]]; then
    printf '  %s %s\n' "$(cyan DRY)" "$*"
  else
    "$@"
  fi
}

ensure_backup_root() {
  if [[ $BACKUP_USED -eq 0 ]]; then
    BACKUP_USED=1
    if [[ $DRY_RUN -eq 0 ]]; then
      mkdir -p "$BACKUP_ROOT"
    fi
  fi
}

# ------------------------------------------------------------------ phases --

phase() { printf '\n%s %s\n' "$(cyan '==>')" "$*"; }

preflight() {
  phase "preflight"
  [[ $EUID -ne 0 ]] || die "do not run as root"
  [[ -f "$REPO_ROOT/settings.json" && -d "$REPO_ROOT/skills" ]] \
    || die "REPO_ROOT does not look like the claude-config repo: $REPO_ROOT"
  for tool in git ln readlink awk nix-build; do
    command -v "$tool" >/dev/null 2>&1 || die "missing required tool: $tool"
  done
  if [[ $DRY_RUN -eq 0 ]]; then
    mkdir -p "$CLAUDE_DIR" "$STATE_DIR"
  fi
  log_action ok preflight "REPO_ROOT=$REPO_ROOT CLAUDE_DIR=$CLAUDE_DIR"
}

init_submodules() {
  phase "init submodules"
  if [[ -f "$REPO_ROOT/.gitmodules" ]]; then
    run git -C "$REPO_ROOT" submodule update --init --recursive
    log_action ok submodules "initialized"
  else
    log_action skip submodules "no .gitmodules"
  fi
}

# link_one_file SRC DST
link_one_file() {
  local src="$1" dst="$2"
  local name; name="$(basename "$dst")"

  if [[ -L "$dst" ]]; then
    local target resolved
    target="$(readlink "$dst")"
    resolved="$(readlink -f "$dst" 2>/dev/null || true)"
    if [[ "$resolved" == "$src" ]]; then
      log_action skip "$dst" "already linked"
      return 0
    elif [[ "$target" == /nix/store/* ]]; then
      warn "NIX-STORE symlink at $dst -> $target"
      warn "  home-manager will recreate this on next 'home-manager switch'."
      ensure_backup_root
      if [[ $DRY_RUN -eq 0 ]]; then
        printf '%s -> %s\n' "$dst" "$target" >> "$BACKUP_ROOT/nix-origins.txt"
      fi
      run rm "$dst"
      NEXT_STEPS+=("Disable the home-manager module that owned $name (was: $target)")
    else
      ensure_backup_root
      run mv "$dst" "$BACKUP_ROOT/$name.symlink"
    fi
  elif [[ -e "$dst" ]]; then
    ensure_backup_root
    run cp -a "$dst" "$BACKUP_ROOT/$name"
    run rm "$dst"
  fi

  run ln -s "$src" "$dst"
  log_action LINK "$dst" "-> $src"
}

link_files() {
  phase "link files"
  for name in settings.json CLAUDE.md; do
    link_one_file "$REPO_ROOT/$name" "$CLAUDE_DIR/$name"
  done
}

# link_one_dir SRC DST
link_one_dir() {
  local src="$1" dst="$2"
  local name; name="$(basename "$dst")"

  if [[ ! -e "$src" ]]; then
    log_action skip "$dst" "src missing in repo: $src"
    return 0
  fi

  if [[ -L "$dst" ]]; then
    local resolved
    resolved="$(readlink -f "$dst" 2>/dev/null || true)"
    if [[ "$resolved" == "$src" ]]; then
      log_action skip "$dst" "already linked"
      return 0
    fi
    ensure_backup_root
    run mv "$dst" "$BACKUP_ROOT/$name.symlink"
  elif [[ -d "$dst" ]]; then
    if [[ -z "$(ls -A "$dst" 2>/dev/null)" ]]; then
      run rmdir "$dst"
    else
      ensure_backup_root
      run mv "$dst" "$BACKUP_ROOT/$name"
    fi
  elif [[ -e "$dst" ]]; then
    ensure_backup_root
    run mv "$dst" "$BACKUP_ROOT/$name.file"
  fi

  run ln -s "$src" "$dst"
  log_action LINK "$dst" "-> $src"
}

link_dirs() {
  phase "link directories"
  for name in skills agents commands hooks; do
    link_one_dir "$REPO_ROOT/$name" "$CLAUDE_DIR/$name"
  done
}

migrate_plugins() {
  phase "migrate plugins"
  local dst="$CLAUDE_DIR/plugins"
  local src="$REPO_ROOT/plugins"

  if [[ -L "$dst" ]]; then
    local resolved
    resolved="$(readlink -f "$dst" 2>/dev/null || true)"
    if [[ "$resolved" == "$src" ]]; then
      # Check if any unexpected dirs appeared (marketplace UI write-conflict warning)
      if [[ -f "$src/.marker" ]]; then
        local extras
        extras="$(find "$src" -mindepth 1 -maxdepth 1 -type d \
                  ! -name jstack-vendored 2>/dev/null || true)"
        if [[ -n "$extras" ]]; then
          warn "unexpected dirs under repo/plugins/ — marketplace UI may have written here:"
          while IFS= read -r line; do warn "  $line"; done <<< "$extras"
        fi
      fi
      log_action skip "$dst" "already linked"
      return 0
    fi
    ensure_backup_root
    run mv "$dst" "$BACKUP_ROOT/plugins.symlink"
  elif [[ -f "$dst/installed_plugins.json" ]]; then
    warn "marketplace plugins/ detected — backing up wholesale"
    ensure_backup_root
    run mv "$dst" "$BACKUP_ROOT/plugins"
    if [[ -f "$REPO_ROOT/templates/RESTORE.md" && $DRY_RUN -eq 0 ]]; then
      cp "$REPO_ROOT/templates/RESTORE.md" "$BACKUP_ROOT/plugins/RESTORE.md"
    fi
  elif [[ -e "$dst" ]]; then
    ensure_backup_root
    run mv "$dst" "$BACKUP_ROOT/plugins"
  fi

  run ln -s "$src" "$dst"
  log_action LINK "$dst" "-> $src"
}

build_runtime() {
  phase "build runtime"
  local nix_out
  if nix_out="$(nix-build "$REPO_ROOT/runtime/default.nix" --no-out-link 2>&1)"; then
    nix_out="$(printf '%s\n' "$nix_out" | tail -n1)"
    run ln -snf "$nix_out" "$STATE_DIR/runtime"
    log_action BUILD runtime "$nix_out"
  else
    warn "nix-build failed (continuing — runtime install is non-fatal)"
    warn "$nix_out"
    log_action skip runtime "nix-build failed"
    NEXT_STEPS+=("Re-run after fixing runtime/default.nix or restoring network")
  fi
}

update_shell_rc() {
  phase "shell rc"
  local rc
  case "${SHELL:-}" in
    *zsh*) rc="$HOME/.zshrc" ;;
    *bash*) rc="$HOME/.bashrc" ;;
    *) rc="$HOME/.zshrc" ;;
  esac

  local block
  block=$'# >>> claude-config >>>\n'
  block+=$'# Managed by scripts/install.sh — do not edit between markers.\n'
  block+="export CLAUDE_CONFIG_RUNTIME=\"\$HOME/.local/state/claude-config/runtime\""$'\n'
  block+=$'case ":$PATH:" in *":$CLAUDE_CONFIG_RUNTIME/bin:"*) ;; *) PATH="$CLAUDE_CONFIG_RUNTIME/bin:$PATH" ;; esac\n'
  block+=$'# <<< claude-config <<<'

  if [[ ! -e "$rc" ]]; then
    if [[ $DRY_RUN -eq 0 ]]; then
      printf '%s\n' "$block" > "$rc"
    fi
    log_action CREATE "$rc" "with marker block"
    return 0
  fi

  if [[ ! -w "$rc" ]]; then
    warn "$rc not writable — skipping shell rc update"
    log_action skip "$rc" "not writable"
    return 0
  fi

  if grep -q '^# >>> claude-config >>>$' "$rc" 2>/dev/null; then
    # Already present — replace block atomically
    if [[ $DRY_RUN -eq 0 ]]; then
      awk -v block="$block" '
        /^# >>> claude-config >>>$/ {skip=1; print block; next}
        /^# <<< claude-config <<<$/ {skip=0; next}
        !skip {print}
      ' "$rc" > "$rc.tmp" && mv "$rc.tmp" "$rc"
    fi
    log_action UPDATE "$rc" "marker block"
  else
    if [[ $DRY_RUN -eq 0 ]]; then
      printf '\n%s\n' "$block" >> "$rc"
    fi
    log_action APPEND "$rc" "marker block"
  fi
}

seed_claude_md() {
  [[ $SEED_FROM_LIVE -eq 1 ]] || return 0
  phase "seed CLAUDE.md (--seed-from-live)"
  local repo_md="$REPO_ROOT/CLAUDE.md"
  local live_md="$CLAUDE_DIR/CLAUDE.md"
  if [[ -s "$repo_md" ]]; then
    log_action skip "$repo_md" "not empty"
    return 0
  fi
  if [[ ! -L "$live_md" ]]; then
    log_action skip "$repo_md" "live CLAUDE.md is not a symlink"
    return 0
  fi
  local target
  target="$(readlink "$live_md")"
  if [[ "$target" != /nix/store/* ]]; then
    log_action skip "$repo_md" "live CLAUDE.md does not point into nix store"
    return 0
  fi
  local resolved
  resolved="$(readlink -f "$live_md" 2>/dev/null || true)"
  if [[ -z "$resolved" || ! -r "$resolved" ]]; then
    log_action skip "$repo_md" "live target unreadable: $target"
    return 0
  fi
  if [[ $DRY_RUN -eq 0 ]]; then
    cat "$resolved" > "$repo_md"
  fi
  log_action SEED "$repo_md" "from $resolved"
  NEXT_STEPS+=("Review and commit the seeded CLAUDE.md")
}

cleanup_empty_backup() {
  if [[ $BACKUP_USED -eq 1 && $DRY_RUN -eq 0 ]]; then
    rmdir "$BACKUP_ROOT" 2>/dev/null || true
  fi
}

summary() {
  phase "summary"
  printf '  taken:   %d\n' "$ACTIONS_TAKEN"
  printf '  skipped: %d\n' "$ACTIONS_SKIPPED"
  if [[ $BACKUP_USED -eq 1 && -d "$BACKUP_ROOT" ]]; then
    printf '  backup:  %s\n' "$BACKUP_ROOT"
  fi
  if [[ $DRY_RUN -eq 1 ]]; then
    printf '\n  %s\n' "$(yellow 'DRY RUN — no changes made')"
  fi

  printf '\n%s\n' "$(cyan 'NEXT STEPS:')"
  cat <<'EOF'
  1. If any "NIX-STORE symlink" warnings appeared above:
       - Disable programs.claude-config.enable in your home-manager config
       - Run: home-manager switch
       - Re-run scripts/install.sh
  2. exec zsh    (or open a new shell to pick up the PATH change)
EOF
  if [[ ${#NEXT_STEPS[@]} -gt 0 ]]; then
    printf '\n  Additional follow-ups from this run:\n'
    for step in "${NEXT_STEPS[@]}"; do
      printf '    - %s\n' "$step"
    done
  fi
}

# ------------------------------------------------------------------ run --

main() {
  preflight
  init_submodules
  seed_claude_md
  link_files
  link_dirs
  migrate_plugins
  build_runtime
  update_shell_rc
  cleanup_empty_backup
  summary
}

main "$@"
