#!/usr/bin/env bash
# install.bash — link the jstack repo into agent config dirs, build runtime,
# update shell rc. Idempotent. Re-run safely.
#
# Flags:
#   --dry-run         Print actions, change nothing
#   --verbose         Print every action including skips
#   --seed-from-live  Seed repo/CLAUDE.md from ~/.claude/CLAUDE.md if both
#                     conditions hold: repo CLAUDE.md is empty AND live one
#                     is a still-resolvable nix-store symlink. Default off.
#   --target <agent>  Deploy to: claude (default), codex, gemini, or all
#
# Environment overrides:
#   CLAUDE_HOME       Override ~/.claude (useful for testing)
#   CODEX_HOME        Override ~/.codex
#   XDG_STATE_HOME    Override ~/.local/state

set -euo pipefail

# ------------------------------------------------------------------ paths --

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
CLAUDE_DIR="${CLAUDE_HOME:-$HOME/.claude}"
CODEX_DIR="${CODEX_HOME:-$HOME/.codex}"
GEMINI_DIR="$HOME/.gemini"
STATE_DIR="${XDG_STATE_HOME:-$HOME/.local/state}/jstack"
TS="$(date -u +%Y%m%dT%H%M%SZ)"
BACKUP_ROOT="$CLAUDE_DIR/.jstack-backups/$TS"

DRY_RUN=0
VERBOSE=0
SEED_FROM_LIVE=0
TARGET="claude"

# ------------------------------------------------------------------ flags --

while [[ $# -gt 0 ]]; do
  case "$1" in
    --dry-run)        DRY_RUN=1 ;;
    --verbose|-v)     VERBOSE=1 ;;
    --seed-from-live) SEED_FROM_LIVE=1 ;;
    --target)
      shift
      [[ $# -gt 0 ]] || { echo "--target needs a value (claude, codex, gemini, all)" >&2; exit 2; }
      TARGET="$1"
      ;;
    -h|--help)
      sed -n '2,18p' "$0" | sed 's/^# \{0,1\}//'
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
    || die "REPO_ROOT does not look like the jstack repo: $REPO_ROOT"
  for tool in git ln readlink awk jq nix; do
    command -v "$tool" >/dev/null 2>&1 || die "missing required tool: $tool"
  done
  if [[ $DRY_RUN -eq 0 ]]; then
    mkdir -p "$CLAUDE_DIR" "$STATE_DIR"
  fi
  log_action ok preflight "REPO_ROOT=$REPO_ROOT TARGET=$TARGET"
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

# ------------------------------------------------------------------ manifest generation --

build_manifests() {
  phase "generate manifests from plugin.nix"
  for plugin_dir_raw in "$REPO_ROOT"/plugins/*/; do
    local plugin_dir="${plugin_dir_raw%/}"
    local name; name="$(basename "$plugin_dir")"
    local plugin_nix="$plugin_dir/plugin.nix"
    [ -f "$plugin_nix" ] || continue

    # Generate .claude-plugin/plugin.json
    local manifest_json
    manifest_json=$(nix eval --impure --json --expr "
      let sources = import $REPO_ROOT/_sources.nix;
          pkgs = import sources.nixpkgs {};
          p = import $plugin_nix { inherit pkgs; };
      in { inherit (p) name description; }
        // (if p ? version then { inherit (p) version; } else {})
        // { author = p.author or {}; }
    ")
    if [[ $DRY_RUN -eq 0 ]]; then
      mkdir -p "$plugin_dir/.claude-plugin"
      echo "$manifest_json" | jq -S . > "$plugin_dir/.claude-plugin/plugin.json"
    fi

    # Generate .mcp.json if mcpServers defined
    local mcp_json
    mcp_json=$(nix eval --impure --json --expr "
      let sources = import $REPO_ROOT/_sources.nix;
          pkgs = import sources.nixpkgs {};
          p = import $plugin_nix { inherit pkgs; };
      in if p ? mcpServers && p.mcpServers != {} then { mcpServers = p.mcpServers; } else null
    ")
    if [[ "$mcp_json" != "null" && $DRY_RUN -eq 0 ]]; then
      echo "$mcp_json" | jq -S . > "$plugin_dir/.mcp.json"
    fi

    # Generate .lsp.json if lspServers defined
    local lsp_json
    lsp_json=$(nix eval --impure --json --expr "
      let sources = import $REPO_ROOT/_sources.nix;
          pkgs = import sources.nixpkgs {};
          p = import $plugin_nix { inherit pkgs; };
      in if p ? lspServers && p.lspServers != {} then p.lspServers else null
    ")
    if [[ "$lsp_json" != "null" && $DRY_RUN -eq 0 ]]; then
      echo "$lsp_json" | jq -S . > "$plugin_dir/.lsp.json"
    fi

    log_action GEN "$plugin_dir" "manifests from plugin.nix"
  done
}

# ------------------------------------------------------------------ claude target --

link_files() {
  phase "link files"
  for name in settings.json CLAUDE.md; do
    link_one_file "$REPO_ROOT/$name" "$CLAUDE_DIR/$name"
  done
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
  if nix_out="$(nix-build -E "import $REPO_ROOT/runtime {}" --no-out-link 2>&1)"; then
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
  block=$'# >>> jstack >>>\n'
  block+=$'# Managed by scripts/install.bash — do not edit between markers.\n'
  block+="export JSTACK_RUNTIME=\"\$HOME/.local/state/jstack/runtime\""$'\n'
  block+=$'case ":$PATH:" in *":$JSTACK_RUNTIME/bin:"*) ;; *) PATH="$JSTACK_RUNTIME/bin:$PATH" ;; esac\n'
  block+=$'# <<< jstack <<<'

  if [[ ! -e "$rc" ]]; then
    if [[ $DRY_RUN -eq 0 ]]; then
      printf '%s\n' "$block" > "$rc"
    fi
    log_action CREATE "$rc" "with marker block"
    return 0
  fi

  if [[ -L "$rc" && "$(readlink "$rc")" == /nix/store/* ]] || [[ ! -w "$rc" ]]; then
    warn "$rc is managed by Nix — skipping shell rc update"
    printf '\n  Use the home-manager module instead:\n\n'
    printf '    imports = [ %s/module.nix ];\n' "$REPO_ROOT"
    printf '    programs.jstack = {\n'
    printf '      enable = true;\n'
    printf '      repoPath = "%s";\n' "$REPO_ROOT"
    printf '    };\n\n'
    log_action skip "$rc" "managed by Nix"
    NEXT_STEPS+=("Add the jstack home-manager module to your configuration (see above)")
    return 0
  fi

  if grep -q '^# >>> jstack >>>$' "$rc" 2>/dev/null; then
    if [[ $DRY_RUN -eq 0 ]]; then
      awk -v block="$block" '
        /^# >>> jstack >>>$/ {skip=1; print block; next}
        /^# <<< jstack <<<$/ {skip=0; next}
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

deploy_claude() {
  build_manifests
  link_files
  link_dirs
  migrate_plugins
  build_runtime
  update_shell_rc
}

# ------------------------------------------------------------------ codex target --

deploy_codex() {
  phase "deploy codex"
  if [[ $DRY_RUN -eq 0 ]]; then
    mkdir -p "$CODEX_DIR"
  fi

  # Link skills directory
  link_one_dir "$REPO_ROOT/skills" "$CODEX_DIR/skills"

  # Link plugin skill directories as flat skill entries
  for plugin_dir in "$REPO_ROOT"/plugins/*/skills; do
    [ -d "$plugin_dir" ] || continue
    local plugin_name; plugin_name="$(basename "$(dirname "$plugin_dir")")"
    for skill_dir in "$plugin_dir"/*/; do
      [ -d "$skill_dir" ] || continue
      local skill_name; skill_name="$(basename "$skill_dir")"
      local dst="$CODEX_DIR/skills/$skill_name"
      if [[ ! -e "$dst" ]]; then
        run ln -s "$skill_dir" "$dst"
        log_action LINK "$dst" "-> $skill_dir"
      else
        log_action skip "$dst" "already exists"
      fi
    done
  done

  log_action ok "codex" "deployed to $CODEX_DIR"
}

# ------------------------------------------------------------------ gemini target --

deploy_gemini() {
  phase "deploy gemini"
  if [[ $DRY_RUN -eq 0 ]]; then
    mkdir -p "$GEMINI_DIR"
  fi

  # Link skills directory
  link_one_dir "$REPO_ROOT/skills" "$GEMINI_DIR/skills"

  # Link plugin skill directories as flat skill entries
  for plugin_dir in "$REPO_ROOT"/plugins/*/skills; do
    [ -d "$plugin_dir" ] || continue
    for skill_dir in "$plugin_dir"/*/; do
      [ -d "$skill_dir" ] || continue
      local skill_name; skill_name="$(basename "$skill_dir")"
      local dst="$GEMINI_DIR/skills/$skill_name"
      if [[ ! -e "$dst" ]]; then
        run ln -s "$skill_dir" "$dst"
        log_action LINK "$dst" "-> $skill_dir"
      else
        log_action skip "$dst" "already exists"
      fi
    done
  done

  log_action ok "gemini" "deployed to $GEMINI_DIR"
}

# ------------------------------------------------------------------ seed + cleanup --

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
  printf '  target:  %s\n' "$TARGET"
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
       - Disable programs.jstack.enable in your home-manager config
       - Run: home-manager switch
       - Re-run scripts/install.bash
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
  seed_claude_md

  case "$TARGET" in
    claude) deploy_claude ;;
    codex)  deploy_codex ;;
    gemini) deploy_gemini ;;
    all)
      deploy_claude
      deploy_codex
      deploy_gemini
      ;;
    *)
      die "unknown target: $TARGET (expected: claude, codex, gemini, all)"
      ;;
  esac

  cleanup_empty_backup
  summary
}

main "$@"
