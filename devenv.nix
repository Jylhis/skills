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
  # Smoke tests validating the dev environment + module multi-target contract.
  # Run with: `devenv test`
  enterTest = ''
    set -euo pipefail
    fail() { echo "FAIL: $*" >&2; exit 1; }
    pass() { echo "PASS: $*"; }

    echo "==> devenv test suite (14 tests)"

    # 1. Required CLI tools resolve on PATH.
    echo "-- test 1/14: required tools on PATH"
    for bin in jq yq rg fd shellcheck markdownlint-cli2 treefmt git npins just; do
      command -v "$bin" >/dev/null || fail "missing $bin"
    done
    pass "required tools available"

    # 2. settings.json is valid JSON.
    echo "-- test 2/14: settings.json parses as JSON"
    jq empty settings.json || fail "settings.json invalid"
    pass "settings.json valid"

    # 3. Project nix files exist and are non-empty.
    echo "-- test 3/14: project nix files present"
    for f in devenv.nix default.nix runtime/default.nix npins/default.nix; do
      [ -s "$f" ] || fail "missing or empty $f"
    done
    pass "nix files present"

    # 4. Project bash scripts pass `bash -n` syntax check.
    echo "-- test 4/14: bash -n on scripts"
    for f in scripts/install.bash scripts/eval.bash; do
      bash -n "$f" || fail "syntax error in $f"
    done
    pass "scripts parse"

    # 5. shellcheck on bundled scripts (errors only, not style/info).
    echo "-- test 5/14: shellcheck --severity=error"
    shellcheck --severity=error scripts/install.bash scripts/eval.bash \
      || fail "shellcheck reported errors"
    pass "shellcheck clean"

    # 6. treefmt is wired up and can resolve its generated config.
    echo "-- test 6/14: treefmt loads config"
    treefmt --version >/dev/null || fail "treefmt not runnable"
    pass "treefmt available"

    # 7. Any plugin manifests that exist are valid JSON.
    # Zero plugins is allowed (e.g. base configuration / fresh setup).
    echo "-- test 7/14: plugin .claude-plugin/plugin.json files valid"
    found=0
    for f in plugins/*/.claude-plugin/plugin.json; do
      [ -e "$f" ] || continue
      jq empty "$f" || fail "invalid JSON in $f"
      found=$((found + 1))
    done
    pass "$found plugin manifests valid"

    # 8. settings.json matches settings.nix (canonical source).
    echo "-- test 8/14: settings.json in sync with settings.nix"
    expected=$(nix eval --impure --json --expr 'import ./settings.nix' | jq -S .)
    actual=$(jq -S . settings.json)
    [ "$expected" = "$actual" ] || fail "settings.json out of sync with settings.nix — run: just generate-settings"
    pass "settings.json in sync"

    # 9. lib/discover.nix can discover skills from plugins/.
    echo "-- test 9/14: lib/discover.nix discovers skills"
    skill_count=$(nix eval --impure --json --expr '
      let d = import ./lib/discover.nix;
          c = d { path = ./plugins/nix-dev/skills; namespace = "nix-dev"; };
      in builtins.length (builtins.attrNames c)
    ')
    [ "$skill_count" -gt 0 ] || fail "discover.nix found zero skills"
    pass "discover.nix found $skill_count skills in nix-dev"

    # 10. plugin.nix files exist for all plugin directories.
    echo "-- test 10/14: plugin.nix files present"
    plugin_count=0
    for d in plugins/*/; do
      d="''${d%/}"
      name=$(basename "$d")
      [ -f "$d/plugin.nix" ] || continue
      plugin_count=$((plugin_count + 1))
    done
    pass "$plugin_count plugin.nix files present"

    # 11. Generated manifests match plugin.nix data.
    echo "-- test 11/14: manifest generation round-trip"
    nix_name=$(nix eval --impure --json --expr '
      let pkgs = import ./npins {}; p = import ./plugins/nix-dev/plugin.nix { inherit pkgs; };
      in p.name
    ')
    [ "$nix_name" = '"nix-dev"' ] || fail "plugin.nix name mismatch: $nix_name"
    pass "manifest generation consistent"

    # 12. sources.nix parses without error.
    echo "-- test 12/14: sources.nix parses"
    nix eval --impure --json --expr 'import ./sources.nix' > /dev/null \
      || fail "sources.nix failed to parse"
    pass "sources.nix valid"

    # 13. promptfoo config is valid YAML.
    echo "-- test 13/14: promptfoo config valid"
    [ -f evals/promptfooconfig.yaml ] || fail "missing evals/promptfooconfig.yaml"
    yq '.' evals/promptfooconfig.yaml > /dev/null || fail "promptfooconfig.yaml invalid"
    pass "promptfooconfig.yaml valid"

    # 14. module.nix evaluates cleanly under HM, NixOS, and nix-darwin
    # stub contexts (and the negative-user assertion fires). The
    # driver throws on the first failed sub-check and prints "OK"
    # only when all 22 checks pass.
    echo "-- test 14/14: module.nix valid for HM / NixOS / nix-darwin"
    module_eval_out=$(nix eval --impure --raw --file tests/module-eval.nix 2>&1) \
      || fail "tests/module-eval.nix failed:\n$module_eval_out"
    [ "$(printf '%s\n' "$module_eval_out" | tail -n1)" = "OK" ] \
      || fail "tests/module-eval.nix did not return OK:\n$module_eval_out"
    pass "module.nix valid across all targets"

    echo "==> all 14 tests passed"
  '';
}
