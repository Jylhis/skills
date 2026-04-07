{ pkgs, ... }:
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
    # https://devenv.sh/integrations/treefmt/
    # treefmt + the formatters it drives, configured via ./treefmt.toml.
    treefmt
    nixfmt-rfc-style
    shfmt
    nodePackages.prettier
  ];

  enterShell = ''
    echo "jstack dev shell"
    echo "skills: $(ls skills 2>/dev/null | wc -l)  agents: $(ls agents 2>/dev/null | wc -l)  commands: $(ls commands 2>/dev/null | wc -l)  plugins: $(ls plugins 2>/dev/null | wc -l)"
  '';

  # https://devenv.sh/integrations/claude-code/
  claude.code.enable = true;

  scripts.lint.exec = ''
    treefmt --fail-on-change
    markdownlint-cli2 "skills/**/SKILL.md" "agents/*.md" "commands/*.md" || true
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
  # Seven smoke tests validating the dev environment.
  # Run with: `devenv test`
  enterTest = ''
    set -euo pipefail
    fail() { echo "FAIL: $*" >&2; exit 1; }
    pass() { echo "PASS: $*"; }

    echo "==> devenv test suite (7 tests)"

    # 1. Required CLI tools resolve on PATH.
    echo "-- test 1/7: required tools on PATH"
    for bin in jq yq rg fd shellcheck markdownlint-cli2 treefmt git node npins; do
      command -v "$bin" >/dev/null || fail "missing $bin"
    done
    pass "required tools available"

    # 2. settings.json is valid JSON.
    echo "-- test 2/7: settings.json parses as JSON"
    jq empty settings.json || fail "settings.json invalid"
    pass "settings.json valid"

    # 3. Project nix files exist and are non-empty.
    echo "-- test 3/7: project nix files present"
    for f in devenv.nix default.nix runtime/default.nix npins/default.nix; do
      [ -s "$f" ] || fail "missing or empty $f"
    done
    pass "nix files present"

    # 4. Project bash scripts pass `bash -n` syntax check.
    echo "-- test 4/7: bash -n on scripts"
    for f in scripts/install.bash scripts/eval.bash; do
      bash -n "$f" || fail "syntax error in $f"
    done
    pass "scripts parse"

    # 5. shellcheck on bundled scripts (errors only, not style/info).
    echo "-- test 5/7: shellcheck --severity=error"
    shellcheck --severity=error scripts/install.bash scripts/eval.bash \
      || fail "shellcheck reported errors"
    pass "shellcheck clean"

    # 6. treefmt is wired up and can read its config.
    echo "-- test 6/7: treefmt loads config"
    treefmt --version >/dev/null || fail "treefmt not runnable"
    [ -f treefmt.toml ] || fail "treefmt.toml missing"
    pass "treefmt available"

    # 7. Any plugin manifests that exist are valid JSON.
    # Zero plugins is allowed (e.g. base configuration / fresh setup).
    echo "-- test 7/7: plugin .claude-plugin/plugin.json files valid"
    found=0
    for f in plugins/*/.claude-plugin/plugin.json; do
      [ -e "$f" ] || continue
      jq empty "$f" || fail "invalid JSON in $f"
      found=$((found + 1))
    done
    pass "$found plugin manifests valid"

    echo "==> all 7 tests passed"
  '';
}
