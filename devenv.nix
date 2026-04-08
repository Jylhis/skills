{ pkgs, config, ... }:
let
  settings = import ./settings.nix;
  runtimePkg = import ./runtime;
in
{
  packages = with pkgs; [
    markdownlint-cli2
    jq
    yq-go
    npins
    nodejs_20
    git
    fd
    ripgrep
    coreutils
    gnused
    shellcheck
    just
    runtimePkg
  ];

  env.JSTACK_RUNTIME = "${runtimePkg}";

  enterShell = ''
    echo "jstack dev shell"
    echo "skills: $(ls skills 2>/dev/null | wc -l)  agents: $(ls agents 2>/dev/null | wc -l)  commands: $(ls commands 2>/dev/null | wc -l)  plugins: $(ls plugins 2>/dev/null | wc -l)"

    # Symlink content dirs into .claude/ so Claude picks them up for this project.
    # Uses real paths (not nix store copies) to preserve live editing.
    for dir in plugins skills agents commands hooks; do
      ln -sfn "$DEVENV_ROOT/$dir" "$DEVENV_ROOT/.claude/$dir"
    done
  '';

  # https://devenv.sh/integrations/claude-code/
  claude.code.enable = true;

  # Merge settings.nix into the devenv-generated .claude/settings.json.
  # Must use the same key as the claude module (absolute path) so the
  # module system merges the two attrsets instead of creating two entries.
  files.${config.claude.code.settingsPath}.json = settings;

  # https://devenv.sh/integrations/treefmt/
  treefmt = {
    enable = true;
    config = {
      projectRootFile = "devenv.nix";
      programs = {
        nixfmt.enable = true;
        shfmt.enable = true;
        prettier = {
          enable = true;
          package = pkgs.nodePackages.prettier;
        };
      };
      # Only format files authored by this project. Plugin bundles,
      # scripts/, docs/, etc. are vendored/upstream-owned and left alone.
      settings.global.excludes = [
        "plugins/**"
        "docs/**"
        "scripts/**"
        "runtime/**"
        "npins/**"
        "evals/**"
        "hooks/**"
        "agents/**"
        "commands/**"
        "skills/**"
        "*.md"
        "devenv.lock"
        "settings.json"
        ".claude/**"
        ".mcp.json"
        ".github/**"
      ];
    };
  };

  scripts.lint.exec = ''
    treefmt --fail-on-change
    markdownlint-cli2 "skills/**/SKILL.md" "agents/*.md" "commands/*.md"
    jq empty settings.json && echo "settings.json ok"
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
  # Eight smoke tests validating the dev environment.
  # Run with: `devenv test`
  enterTest = ''
    set -euo pipefail
    fail() { echo "FAIL: $*" >&2; exit 1; }
    pass() { echo "PASS: $*"; }

    echo "==> devenv test suite (8 tests)"

    # 1. Required CLI tools resolve on PATH.
    echo "-- test 1/8: required tools on PATH"
    for bin in jq yq rg fd shellcheck markdownlint-cli2 treefmt git node npins just; do
      command -v "$bin" >/dev/null || fail "missing $bin"
    done
    pass "required tools available"

    # 2. settings.json is valid JSON.
    echo "-- test 2/8: settings.json parses as JSON"
    jq empty settings.json || fail "settings.json invalid"
    pass "settings.json valid"

    # 3. Project nix files exist and are non-empty.
    echo "-- test 3/8: project nix files present"
    for f in devenv.nix default.nix runtime/default.nix npins/default.nix; do
      [ -s "$f" ] || fail "missing or empty $f"
    done
    pass "nix files present"

    # 4. Project bash scripts pass `bash -n` syntax check.
    echo "-- test 4/8: bash -n on scripts"
    for f in scripts/install.bash scripts/eval.bash; do
      bash -n "$f" || fail "syntax error in $f"
    done
    pass "scripts parse"

    # 5. shellcheck on bundled scripts (errors only, not style/info).
    echo "-- test 5/8: shellcheck --severity=error"
    shellcheck --severity=error scripts/install.bash scripts/eval.bash \
      || fail "shellcheck reported errors"
    pass "shellcheck clean"

    # 6. treefmt is wired up and can resolve its generated config.
    echo "-- test 6/8: treefmt loads config"
    treefmt --version >/dev/null || fail "treefmt not runnable"
    pass "treefmt available"

    # 7. Any plugin manifests that exist are valid JSON.
    # Zero plugins is allowed (e.g. base configuration / fresh setup).
    echo "-- test 7/8: plugin .claude-plugin/plugin.json files valid"
    found=0
    for f in plugins/*/.claude-plugin/plugin.json; do
      [ -e "$f" ] || continue
      jq empty "$f" || fail "invalid JSON in $f"
      found=$((found + 1))
    done
    pass "$found plugin manifests valid"

    # 8. settings.json matches settings.nix (canonical source).
    echo "-- test 8/8: settings.json in sync with settings.nix"
    expected=$(nix eval --impure --json --expr 'import ./settings.nix' | jq -S .)
    actual=$(jq -S . settings.json)
    [ "$expected" = "$actual" ] || fail "settings.json out of sync with settings.nix — run: just generate-settings"
    pass "settings.json in sync"

    echo "==> all 8 tests passed"
  '';
}
