{ pkgs, ... }:
{
  packages = with pkgs; [
    git
    just
    jq
    nixfmt-rfc-style
    statix
    deadnix
    markdownlint-cli2
    shellcheck
  ];

  enterShell = ''
    echo "skills dev shell — see 'just' for available recipes"
  '';

  enterTest = ''
    set -e
    nix-instantiate --eval default.nix > /dev/null
    nix flake check --no-build
    statix check . --ignore '.devenv/*' 'result/*'
    deadnix --fail --exclude .devenv result .
    shellcheck scripts/install.sh
  '';
}
