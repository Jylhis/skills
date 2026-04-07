let
  sources = import ../npins;
  pkgs = import sources.nixpkgs { };
in
pkgs.buildEnv {
  name = "claude-runtime";
  paths = with pkgs; [
    # LSPs
    pyright
    nil
    typescript-language-server

    # MCP servers — populate as needs surface

    # eval harness — promptfoo via npm in devenv shell for now
  ];
}
