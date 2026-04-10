{ pkgs }:
{
  name = "nix-dev";
  version = "0.2.0";
  description = "Nix development intelligence: Nix language, NixOS modules, flakes, npins, devenv, nixpkgs, home-manager, hybrid architecture, linting, plus nil LSP and mcp-nixos integration";
  author.name = "Markus Jylhänkangas";

  packages = [ pkgs.nil ];

  mcpServers = {
    mcp-nixos = {
      type = "stdio";
      command = "nix";
      args = [
        "run"
        "github:utensils/mcp-nixos"
        "--"
      ];
    };
  };

  lspServers = {
    nix = {
      command = "nil";
      args = [ ];
      extensionToLanguage = {
        ".nix" = "nix";
      };
    };
  };
}
