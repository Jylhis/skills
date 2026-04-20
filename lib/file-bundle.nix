# Flat-file bundle builder — used for agents (*.md) and slash commands
# (*.md). Each entry is a single markdown file copied into the bundle
# directory with tool-name substitution applied ({{tools.<op>}} ->
# concrete name for the target tool).
{ pkgs, lib }:
let
  toolMappings = import ./tool-mappings.nix;

  mkSedExpr =
    toolName:
    let
      ops = builtins.attrNames toolMappings;
      sedParts = map (
        op:
        let
          concrete = toolMappings.${op}.${toolName} or null;
          replacement = if concrete != null then concrete else "(not available)";
        in
        "-e 's|{{tools.${op}}}|${replacement}|g'"
      ) ops;
    in
    lib.concatStringsSep " " sedParts;

  # entries: attrset of name -> { src = path; tools = nullOr listOf str }
  # toolName: target tool for substitution + filtering.
  # kind: human-readable label (e.g., "agents", "commands") used in deriv name.
  mkFileBundle =
    {
      entries,
      toolName,
      kind,
    }:
    let
      applicable = lib.filterAttrs (
        _: e: (e.tools or null) == null || builtins.elem toolName e.tools
      ) entries;

      sedExpr = mkSedExpr toolName;

      copyScripts = lib.mapAttrsToList (name: entry: ''
        cp "${entry.src}" "$out/${name}.md"
        chmod u+w "$out/${name}.md"
        sed -i ${sedExpr} "$out/${name}.md"
      '') applicable;
    in
    if applicable == { } then
      null
    else
      pkgs.runCommand "jstack-${kind}-${toolName}" { } ''
        mkdir -p $out
        ${lib.concatStringsSep "\n" copyScripts}
      '';
in
{
  inherit mkFileBundle;
}
