# jstack v2 module entry point.
#
# Imports all submodules: core options, skill system, MCP/LSP config,
# and per-tool modules. A single import of this file provides the full
# programs.jstack option tree for NixOS, nix-darwin, and Home Manager.
{ ... }:
{
  imports = [
    ./core.nix
    ./skills.nix
    ./bundled.nix
    ./mcp.nix
    ./lsp.nix
    ./tools/claude-code.nix
    ./tools/codex.nix
    ./tools/gemini.nix
    ./tools/pi.nix
    ./tools/windsurf.nix
    ./tools/cursor.nix
    ./tools/opencode.nix
    ./tools/cline.nix
    ./tools/aider.nix
  ];
}
