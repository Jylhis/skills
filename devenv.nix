{ pkgs, config, ... }:
let
  settings = import ./settings.nix;
  settingsFile = (pkgs.formats.json { }).generate "claude-settings.json" settings;
  runtimePkg = import ./runtime { };
  sources = import ./_sources.nix;
in
{
  packages = with pkgs; [
    markdownlint-cli2
    secretspec
    jq
    yq-go
    promptfoo
    git
    fd
    ripgrep
    coreutils
    gnused
    shellcheck
    just
    statix
    deadnix
    nixfmt-rfc-style
    runtimePkg
  ];
  env = {
    JSTACK_RUNTIME = "${runtimePkg}";
    ANTHROPIC_API_KEY = config.secretspec.secrets.ANTHROPIC_API_KEY or "";
    OPENAI_API_KEY = config.secretspec.secrets.OPENAI_API_KEY or "";
    PROMPTFOO_DISABLE_TELEMETRY = 1;
    PROMPTFOO_DISABLE_UPDATE = 1;
  };
  enterShell = ''
    echo "jstack dev shell"
    echo "skills: $(ls skills 2>/dev/null | wc -l)  agents: $(ls agents 2>/dev/null | wc -l)  commands: $(ls commands 2>/dev/null | wc -l)"

    # Symlink content dirs into .claude/ so Claude picks them up for this project.
    for dir in agents commands; do
      ln -sfn "$DEVENV_ROOT/$dir" "$DEVENV_ROOT/.claude/$dir"
    done

    # Replace the devenv-written settings.json with a symlink to the
    # nix-store derivation built from settings.nix — same content, no
    # tracked artifact, and Claude reads through the symlink.
    ln -sfn "${settingsFile}" "$DEVENV_ROOT/.claude/settings.json"

    # Skills dir is a real directory so local and third-party skills coexist.
    # If a previous run left a symlink (e.g. from an earlier repo layout), drop it.
    [ -L "$DEVENV_ROOT/.claude/skills" ] && rm "$DEVENV_ROOT/.claude/skills"
    mkdir -p "$DEVENV_ROOT/.claude/skills"
    for skill in "$DEVENV_ROOT/skills"/*/; do
      [ -d "$skill" ] && ln -sfn "$skill" "$DEVENV_ROOT/.claude/skills/$(basename "$skill")"
    done
  '';

  # https://devenv.sh/integrations/claude-code/
  claude.code.enable = true;
  claude.code.skills = {
    promptfoo = {
      source = sources.promptfoo;
      skillsRoot = ".claude/skills";
      namespace = "promptfoo";
    };
  };
  claude.code.mcpServers = {
    devenv = {
      type = "stdio";
      command = "devenv";
      args = [ "mcp" ];
      env = {
        DEVENV_ROOT = config.devenv.root;
      };
    };
    promptfoo = {
      type = "stdio";
      command = "promptfoo";
      args = [
        "mcp"
        "--transport"
        "stdio"
      ];

    };
  };

  # Merge settings.nix into devenv's claude.code-managed settings.json.
  # devenv writes a regular file here; enterShell then replaces it with
  # a symlink to the same content built into the nix store.
  files.${config.claude.code.settingsPath}.json = settings;

  # https://devenv.sh/integrations/treefmt/
  treefmt = {
    enable = true;
    config = {
      projectRootFile = "devenv.nix";
      programs = {
        nixfmt.enable = true;
        shfmt.enable = true;
      };
      # Only format files authored by this project. Plugin bundles,
      # scripts/, docs/, etc. are vendored/upstream-owned and left alone.
      settings.global.excludes = [
        "docs/**"
        "scripts/**"
        "runtime/**"
        "evals/**"
        "agents/**"
        "commands/**"
        "skills/**"
        "*.md"
        "devenv.lock"
        ".claude/**"
        ".mcp.json"
        ".lsp.json"
        ".github/**"
      ];
    };
  };

  scripts.lint.exec = ''
    treefmt --fail-on-change
    markdownlint-cli2 "skills/**/SKILL.md" "agents/*.md" "commands/*.md"
    jq empty .claude/settings.json && echo ".claude/settings.json ok"
  '';

  scripts.install.exec = ''
    bash scripts/install.bash "$@"
  '';

  scripts.eval.exec = ''
    bash scripts/eval.bash "$@"
  '';

  scripts.eval-fast.exec = ''
    bash scripts/eval.bash --fast "$@"
  '';

  # https://devenv.sh/tests/
  # Smoke tests validating the dev environment + module multi-target contract.
  # Run with: `devenv test`
  enterTest = ''
    set -euo pipefail
    fail() { echo "FAIL: $*" >&2; exit 1; }
    pass() { echo "PASS: $*"; }

    echo "==> devenv test suite (15 tests)"

    # 1. Required CLI tools resolve on PATH.
    echo "-- test 1/15: required tools on PATH"
    for bin in jq yq rg fd shellcheck markdownlint-cli2 treefmt git just; do
      command -v "$bin" >/dev/null || fail "missing $bin"
    done
    pass "required tools available"

    # 2. .claude/settings.json is valid JSON (symlinked from nix store).
    echo "-- test 2/15: .claude/settings.json parses as JSON"
    jq empty .claude/settings.json || fail ".claude/settings.json invalid"
    pass ".claude/settings.json valid"

    # 3. Project nix files exist and are non-empty.
    echo "-- test 3/15: project nix files present"
    for f in devenv.nix default.nix runtime/default.nix _sources.nix overlay.nix; do
      [ -s "$f" ] || fail "missing or empty $f"
    done
    pass "nix files present"

    # 4. Project bash scripts pass `bash -n` syntax check.
    echo "-- test 4/15: bash -n on scripts"
    for f in scripts/install.bash scripts/eval.bash; do
      bash -n "$f" || fail "syntax error in $f"
    done
    pass "scripts parse"

    # 5. shellcheck on bundled scripts (errors only, not style/info).
    echo "-- test 5/15: shellcheck --severity=error"
    shellcheck --severity=error scripts/install.bash scripts/eval.bash \
      || fail "shellcheck reported errors"
    pass "shellcheck clean"

    # 6. treefmt is wired up and can resolve its generated config.
    echo "-- test 6/15: treefmt loads config"
    treefmt --version >/dev/null || fail "treefmt not runnable"
    pass "treefmt available"

    # 7. Generated server config files are valid JSON.
    echo "-- test 7/15: .mcp.json and .lsp.json valid"
    if [ -f .mcp.json ]; then
      jq empty .mcp.json || fail ".mcp.json invalid"
    fi
    if [ -f .lsp.json ]; then
      jq empty .lsp.json || fail ".lsp.json invalid"
    fi
    pass "server config files valid"

    # 8. .claude/settings.json is a symlink into the nix store built from settings.nix.
    echo "-- test 8/15: .claude/settings.json links to nix store"
    [ -L .claude/settings.json ] || fail ".claude/settings.json is not a symlink"
    target=$(readlink -f .claude/settings.json)
    case "$target" in
      /nix/store/*) : ;;
      *) fail ".claude/settings.json target $target is not under /nix/store" ;;
    esac
    expected=$(nix eval --impure --json --expr 'import ./settings.nix' | jq -S .)
    actual=$(jq -S . .claude/settings.json)
    [ "$expected" = "$actual" ] || fail ".claude/settings.json content does not match settings.nix"
    pass ".claude/settings.json -> $target"

    # 9. lib/discover.nix can discover skills from skills/.
    echo "-- test 9/15: lib/discover.nix discovers skills"
    skill_count=$(nix eval --impure --json --expr '
      let d = import ./lib/discover.nix;
          c = d { path = ./skills; namespace = "jstack"; };
      in builtins.length (builtins.attrNames c)
    ')
    [ "$skill_count" -gt 0 ] || fail "discover.nix found zero skills"
    pass "discover.nix found $skill_count skills"

    # 10. lib/servers.nix evaluates and has expected keys.
    echo "-- test 10/15: lib/servers.nix evaluates"
    server_keys=$(nix eval --impure --json --expr '
      let sources = import ./_sources.nix; pkgs = import sources.nixpkgs {};
          s = import ./lib/servers.nix { inherit pkgs; };
      in { mcp = builtins.attrNames s.mcpServers; lsp = builtins.attrNames s.lspServers; pkgCount = builtins.length s.packages; }
    ')
    [ -n "$server_keys" ] || fail "lib/servers.nix eval failed"
    pass "lib/servers.nix valid: $server_keys"

    # 11. lib/default-skills.nix lists skills that exist on disk.
    echo "-- test 11/15: default-skills.nix consistency"
    nix eval --impure --json --expr '
      let ds = import ./lib/default-skills.nix;
      in builtins.length (builtins.attrNames ds.all)
    ' > /dev/null || fail "default-skills.nix eval failed"
    pass "default-skills.nix consistent"

    # 12. bundled-sources.nix parses without error.
    # (bundled-sources.nix is a function of flake inputs, so we apply it to the
    # inputs attrset from _sources.nix before evaluating.)
    echo "-- test 12/15: bundled-sources.nix parses"
    nix eval --impure --json --expr 'builtins.attrNames ((import ./bundled-sources.nix) (import ./_sources.nix))' > /dev/null \
      || fail "bundled-sources.nix failed to parse"
    pass "bundled-sources.nix valid"

    # 13. promptfoo config is valid YAML.
    echo "-- test 13/15: promptfoo config valid"
    [ -f promptfooconfig.yaml ] || fail "missing promptfooconfig.yaml"
    yq '.' promptfooconfig.yaml > /dev/null || fail "promptfooconfig.yaml invalid"
    pass "promptfooconfig.yaml valid"

    # 14. module evaluates cleanly under HM, NixOS, and nix-darwin
    # stub contexts (and the negative-user assertion fires). The driver
    # throws on the first failed sub-check and prints "OK" only when
    # all checks pass.
    echo "-- test 14/15: modules/ valid for HM / NixOS / nix-darwin"
    module_eval_out=$(nix eval --impure --raw --apply 'f: f {}' --file tests/module-eval.nix 2>&1) \
      || fail "tests/module-eval.nix failed:\n$module_eval_out"
    [ "$(printf '%s\n' "$module_eval_out" | tail -n1)" = "OK" ] \
      || fail "tests/module-eval.nix did not return OK:\n$module_eval_out"
    pass "modules/ valid across all targets"

    # 15. nixpkgs revision parity across devenv.lock and flake.lock
    echo "-- test 15/15: nixpkgs revision parity"
    devenv_rev=$(jq -r '.nodes.nixpkgs.locked.rev' devenv.lock)
    flake_rev=$(jq -r '.nodes.nixpkgs.locked.rev' flake.lock)
    [ "$devenv_rev" = "$flake_rev" ] || fail "nixpkgs rev mismatch: devenv=$devenv_rev flake=$flake_rev"
    pass "nixpkgs revision $flake_rev matches across devenv and flake"

    echo "==> all 15 tests passed"
  '';
}
