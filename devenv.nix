{ pkgs, ... }:
{
  packages = with pkgs; [
    nodePackages.markdownlint-cli2
    jq
    yq-go
    npins
  ];

  enterShell = ''
    echo "claude-config dev shell"
    echo "skills: $(ls skills | wc -l)  plugins: $(ls plugins | wc -l)"
  '';

  scripts.lint.exec = ''
    markdownlint-cli2 "skills/**/SKILL.md"
  '';

  scripts.validate-settings.exec = ''
    jq empty modules/settings.json && echo "settings.json ok"
  '';
}
