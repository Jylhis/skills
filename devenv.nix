{ pkgs, ... }:
{
  packages = with pkgs; [
    git
    just
    jq
    shellcheck
    python3
  ];

  enterShell = ''
    echo "skills dev shell — see 'just' for available recipes"
  '';

  languages = {
    nix.enable = true;
    shell.enable = true;
    python.enable = true;
  };

  enterTest = ''
    set -e
    shellcheck scripts/install.sh
    python3 scripts/validate.py
  '';
}
