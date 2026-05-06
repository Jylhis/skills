{ pkgs, ... }:
{
  packages = with pkgs; [
    git
    just
    jq
    markdownlint-cli2
    shellcheck
    python3
  ];

  enterShell = ''
    echo "skills dev shell — see 'just' for available recipes"
  '';

  enterTest = ''
    set -e
    markdownlint-cli2 '**/*.md' '#staging/**' '#docs/history/**' '#.devenv/**'
    shellcheck scripts/install.sh
    python3 scripts/validate.py
  '';
}
