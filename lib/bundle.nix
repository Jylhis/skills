# Bundle builder — creates store derivations with skill collections and injected package binaries.
#
# Two modes:
#   1. Third-party skills (from npins store paths): copies skill dirs, injects pkg binaries
#   2. Local plugin manifests: generates manifest files only (skills stay as live symlinks)
{ pkgs }:
let
  lib = pkgs.lib;
in
{
  # Build a skill bundle from a catalog of discovered skills.
  # catalog: attrset from discover.nix
  # selected: list of skill IDs to include, or null for all
  # packages: attrset of skill ID -> list of packages to inject
  mkSkillBundle =
    {
      catalog,
      selected ? null,
      packages ? { },
    }:
    let
      selectedCatalog =
        if selected == null then catalog else lib.filterAttrs (id: _: builtins.elem id selected) catalog;

      skillScripts = lib.mapAttrsToList (
        id: skill:
        let
          pkgList = packages.${id} or [ ];
          binInject = lib.concatMapStringsSep "\n" (pkg: ''
            if [ -d "${pkg}/bin" ]; then
              mkdir -p "$out/${skill.name}/bin"
              for bin in "${pkg}"/bin/*; do
                [ -f "$bin" ] && ln -s "$bin" "$out/${skill.name}/bin/"
              done
            fi
          '') pkgList;
        in
        ''
          # Skill: ${id}
          mkdir -p "$out/${skill.name}"
          cp -r "${skill.path}"/. "$out/${skill.name}/"
          chmod -R u+w "$out/${skill.name}"
          ${binInject}
        ''
      ) selectedCatalog;
    in
    pkgs.runCommand "jstack-skill-bundle" { } ''
      mkdir -p $out
      ${lib.concatStringsSep "\n" skillScripts}
    '';

  # Build a complete plugin bundle with manifests + skills for a target agent.
  # pluginDefs: attrset of name -> plugin.nix attrset
  # target: target name from targets.nix ("claude", "codex", "gemini")
  mkPluginBundle =
    {
      pluginDefs,
      target ? "claude",
    }:
    let
      manifest = import ./manifest.nix { inherit pkgs; };

      pluginManifests = lib.mapAttrs (
        name: def: manifest.mkPluginManifests { pluginDef = def; inherit target; }
      ) pluginDefs;

      pluginScripts = lib.mapAttrsToList (
        name: manifestDrv:
        ''
          mkdir -p "$out/${name}"
          cp -r ${manifestDrv}/. "$out/${name}/"
        ''
      ) pluginManifests;
    in
    pkgs.runCommand "jstack-plugin-bundle-${target}" { } ''
      mkdir -p $out
      ${lib.concatStringsSep "\n" pluginScripts}
    '';
}
