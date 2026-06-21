{
  pkgs,
  lib,
  repoRoot,
}:
let
  myLib = import ./lib.nix { inherit lib; };
  inherit (myLib)
    mkSkill
    mkAgent
    mkCommand
    mkLsp
    mkPlugin
    packageNameFromArgs
    ;

  # IFD: extract YAML frontmatter from a Markdown file as JSON via yq-go.
  # The user explicitly preferred this over a committed catalogue.json.
  readFrontmatter =
    mdFile:
    let
      json = pkgs.runCommand "frontmatter.json" {
        nativeBuildInputs = [ pkgs.yq-go ];
      } "yq --front-matter=extract -o=json '.' ${mdFile} > $out";
    in
    builtins.fromJSON (builtins.readFile json);

  dirNames =
    path:
    lib.attrNames (lib.filterAttrs (_n: t: t == "directory") (builtins.readDir path));
  fileNames =
    path:
    lib.attrNames (lib.filterAttrs (_n: t: t == "regular") (builtins.readDir path));

  # --- Skills -----------------------------------------------------------------
  skillCategories = dirNames (repoRoot + "/skills");

  allSkills = lib.listToAttrs (
    lib.concatMap (
      category:
      let
        categoryPath = repoRoot + "/skills/${category}";
      in
      map (
        name:
        let
          skillPath = categoryPath + "/${name}";
          skillMd = skillPath + "/SKILL.md";
          fm = readFrontmatter skillMd;
        in
        {
          inherit name;
          value = mkSkill {
            inherit name category;
            path = skillPath;
            frontmatter = fm;
            scripts =
              if builtins.pathExists (skillPath + "/scripts") then
                fileNames (skillPath + "/scripts")
              else
                [ ];
            references =
              if builtins.pathExists (skillPath + "/references") then
                fileNames (skillPath + "/references")
              else
                [ ];
          };
        }
      ) (dirNames categoryPath)
    ) skillCategories
  );

  # --- Agents (only in jylhis-skills-core today) -----------------------------
  agentsDir = repoRoot + "/plugins/jylhis-skills-core/agents";
  agentFiles = lib.filter (f: lib.hasSuffix ".md" f) (fileNames agentsDir);

  allAgents = lib.listToAttrs (
    map (
      file:
      let
        name = lib.removeSuffix ".md" file;
        path = agentsDir + "/${file}";
      in
      {
        inherit name;
        value = mkAgent {
          inherit name path;
          frontmatter = readFrontmatter path;
        };
      }
    ) agentFiles
  );

  # --- Slash commands --------------------------------------------------------
  commandsDir = repoRoot + "/plugins/jylhis-skills-core/commands";
  commandFiles = lib.filter (f: lib.hasSuffix ".md" f) (fileNames commandsDir);

  allCommands = lib.listToAttrs (
    map (
      file:
      let
        name = lib.removeSuffix ".md" file;
        path = commandsDir + "/${file}";
      in
      {
        inherit name;
        value = mkCommand {
          inherit name path;
          frontmatter = readFrontmatter path;
        };
      }
    ) commandFiles
  );

  # --- LSP servers (per-plugin .lsp.json) ------------------------------------
  readLspsFromPlugin =
    pluginDir:
    let
      lspFile = pluginDir + "/.lsp.json";
    in
    if builtins.pathExists lspFile then
      let
        raw = lib.importJSON lspFile;
      in
      lib.mapAttrs (
        lang: cfg:
        mkLsp {
          language = lang;
          command = cfg.command;
          args = cfg.args;
          extensionToLanguage = cfg.extensionToLanguage or { };
          packageName = packageNameFromArgs cfg.args;
          path = lspFile;
        }
      ) raw
    else
      { };

  pluginNames = dirNames (repoRoot + "/plugins");
  allLspServers = lib.foldl' (
    acc: name: acc // readLspsFromPlugin (repoRoot + "/plugins/${name}")
  ) { } pluginNames;

  # --- MCP servers (slot reserved; no entries today) -------------------------
  allMcpServers = { };

  # --- Plugins (bundle the above by reference) -------------------------------
  defaultPluginName = "jylhis-skills-core";

  resolveSkillRef =
    ref:
    let
      base = lib.removePrefix "./skills/" ref;
    in
    allSkills.${base} or (throw "plugin references unknown skill: ${ref}");

  allPlugins = lib.listToAttrs (
    map (
      name:
      let
        pluginDir = repoRoot + "/plugins/${name}";
        claudeManifest = lib.importJSON (pluginDir + "/.claude-plugin/plugin.json");
        codexManifestFile = pluginDir + "/.codex-plugin/plugin.json";
        codexManifest =
          if builtins.pathExists codexManifestFile then lib.importJSON codexManifestFile else null;
        skillRefs = claudeManifest.skills or [ ];
        lspServers = readLspsFromPlugin pluginDir;
        isCore = name == defaultPluginName;
      in
      {
        inherit name;
        value = mkPlugin {
          inherit name;
          version = claudeManifest.version or "0.0.0";
          description = claudeManifest.description or "";
          default = isCore;
          path = pluginDir;
          inherit claudeManifest codexManifest;
          skills = map resolveSkillRef skillRefs;
          agents = if isCore then lib.attrValues allAgents else [ ];
          commands = if isCore then lib.attrValues allCommands else [ ];
          inherit lspServers;
          mcpServers = { };
        };
      }
    ) pluginNames
  );
in
{
  skills = allSkills;
  agents = allAgents;
  commands = allCommands;
  mcpServers = allMcpServers;
  lspServers = allLspServers;
  plugins = allPlugins;
}
