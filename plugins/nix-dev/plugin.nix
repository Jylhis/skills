{ pkgs }:
{
  name = "nix-dev";
  version = "0.3.0";
  description = "Nix development intelligence: 14 skills covering Nix language, NixOS modules, flakes, npins, devenv, nixpkgs, home-manager, nix-darwin, hybrid architecture, linting, performance, containers, testing, and debugging — plus nil LSP and mcp-nixos integration";
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
