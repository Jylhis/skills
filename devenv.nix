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
  ];

  enterShell = ''
    echo "claude-config dev shell"
    echo "skills: $(ls skills 2>/dev/null | wc -l)  agents: $(ls agents 2>/dev/null | wc -l)  commands: $(ls commands 2>/dev/null | wc -l)  plugins: $(ls plugins 2>/dev/null | wc -l)"
  '';

  scripts.lint.exec = ''
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
}
