# jstack library — skill discovery, manifest generation, and bundle building.
{ pkgs }:
let
  inherit (pkgs) lib;

  # v1 (legacy)
  targets = import ./targets.nix;
  discoverSkills = import ./discover.nix;
  mkManifest = import ./manifest.nix { inherit pkgs; };
  mkBundle = import ./bundle.nix { inherit pkgs; };

  # v2
  toolDefs = import ./tool-defs.nix;
  toolMappings = import ./tool-mappings.nix;
  mcpFormat = import ./mcp-format.nix { inherit lib; };
  instructionGen = import ./instruction-gen.nix { inherit lib; };
  skillBundle = import ./skill-bundle.nix { inherit pkgs lib; };
  defaultSkills = import ./default-skills.nix;
in
{
  inherit
    # v1
    targets
    discoverSkills
    mkManifest
    mkBundle
    # v2
    toolDefs
    toolMappings
    mcpFormat
    instructionGen
    skillBundle
    defaultSkills
    ;
}
