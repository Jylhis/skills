{ pkgs, ... }:
{
  packages = with pkgs; [
    git
    just
    jq
    shellcheck
    (python3.withPackages (ps: with ps; [ pyyaml jsonschema ]))
    promptfoo
  ];

  enterShell = ''
    echo "skills dev shell — see 'just' for available recipes"
  '';

  languages = {
    nix.enable = true;
    shell.enable = true;
    python.enable = true;
    go.enable = true;
    typescript.enable = true;
    javascript = {
      enable = true;
      bun.enable = true;
    };
  };

  enterTest = ''
    set -e
    just check
    just test-go
    just eval-smoke
  '';
}
