# Skill bundle builder — creates store derivations with skill collections,
# build-time tool-name substitution, user transforms, and injected package binaries.
#
# Usage:
#   mkSkillBundle {
#     inherit pkgs lib;
#     skills = { my-skill = { src = ./skills/my-skill; packages = []; transform = null; }; };
#     toolName = "claude-code";  # for tool-name substitution
#   }
#   => /nix/store/...-jstack-skills-claude-code/
#       my-skill/
#         SKILL.md          (with {{tools.read}} -> "Read")
#         scripts/
#         bin/              (symlinks to package binaries)
{ pkgs, lib }:
let
  toolMappings = import ./tool-mappings.nix;

  # Build sed expressions for tool-name substitution.
  # Replaces {{tools.<op>}} with the concrete name for the given tool,
  # or "(not available)" if the tool does not support that operation.
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

  # Build the shell script to copy a single skill into the output.
  mkSkillScript =
    {
      name,
      src,
      packages ? [ ],
      transform ? null,
      toolName,
    }:
    let
      sedExpr = mkSedExpr toolName;

      # If transform is set, it's a Nix function (string -> string) applied
      # at eval time via builtins.readFile. This is opt-in and rare.
      transformedContent =
        if transform != null then
          let
            original = builtins.readFile (src + "/SKILL.md");
          in
          transform original
        else
          null;

      # Write transformed content to a temp file for copying
      transformedFile =
        if transformedContent != null then pkgs.writeText "${name}-SKILL.md" transformedContent else null;

      binInject = lib.concatMapStringsSep "\n" (pkg: ''
        if [ -d "${pkg}/bin" ]; then
          mkdir -p "$out/${name}/bin"
          for bin in "${pkg}"/bin/*; do
            [ -f "$bin" ] && ln -s "$bin" "$out/${name}/bin/"
          done
        fi
      '') packages;
    in
    ''
      # Skill: ${name}
      mkdir -p "$out/${name}"
      cp -r "${src}"/. "$out/${name}/"
      chmod -R u+w "$out/${name}"

      ${
        if transformedFile != null then
          # Replace SKILL.md with pre-transformed version
          ''
            cp "${transformedFile}" "$out/${name}/SKILL.md"
            chmod u+w "$out/${name}/SKILL.md"
          ''
        else
          ""
      }

      # Tool-name substitution (build-time sed)
      if [ -f "$out/${name}/SKILL.md" ]; then
        sed -i ${sedExpr} "$out/${name}/SKILL.md"
      fi

      ${binInject}
    '';
  # Build a skill bundle for a specific tool target.
  #
  # skills: attrset of name -> { src, packages?, transform? }
  # toolName: target tool name (e.g., "claude-code", "codex", "gemini")
  #
  # Returns a store derivation containing all skills with tool-specific
  # SKILL.md content and injected package binaries.
  mkSkillBundle =
    {
      skills,
      toolName,
    }:
    let
      skillScripts = lib.mapAttrsToList (
        name: skill:
        mkSkillScript {
          inherit name toolName;
          inherit (skill) src;
          packages = skill.packages or [ ];
          transform = skill.transform or null;
        }
      ) skills;
    in
    pkgs.runCommand "jstack-skills-${toolName}" { } ''
      mkdir -p $out
      ${lib.concatStringsSep "\n" skillScripts}
    '';

  # Build a skill bundle from a discovered catalog (from discover.nix).
  # Adapts the catalog format to the skills format expected by mkSkillBundle.
  #
  # catalog: attrset from discover.nix (keyed by "namespace:skill-name")
  # selected: list of skill IDs to include, or null for all
  # packages: attrset of skill ID -> list of packages
  # toolName: target tool name
  mkSkillBundleFromCatalog =
    {
      catalog,
      selected ? null,
      packages ? { },
      toolName,
    }:
    let
      filteredCatalog =
        if selected == null then catalog else lib.filterAttrs (id: _: builtins.elem id selected) catalog;

      skills = lib.mapAttrs' (
        id: skill:
        lib.nameValuePair skill.name {
          src = skill.path;
          packages = packages.${id} or [ ];
        }
      ) filteredCatalog;
    in
    mkSkillBundle { inherit skills toolName; };
in
{
  inherit mkSkillBundle mkSkillBundleFromCatalog;
}
