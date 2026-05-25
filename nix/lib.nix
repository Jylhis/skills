{ lib }:
rec {
  mkSkill =
    {
      name,
      category,
      path,
      frontmatter,
      scripts ? [ ],
      references ? [ ],
    }:
    {
      type = "skill";
      inherit
        name
        category
        path
        frontmatter
        scripts
        references
        ;
      description = frontmatter.description or "";
    };

  mkAgent =
    {
      name,
      path,
      frontmatter,
    }:
    {
      type = "agent";
      inherit name path frontmatter;
      description = frontmatter.description or "";
    };

  mkCommand =
    {
      name,
      path,
      frontmatter,
    }:
    {
      type = "command";
      inherit name path frontmatter;
      description = frontmatter.description or "";
      argumentHint = frontmatter."argument-hint" or null;
      allowedTools = frontmatter."allowed-tools" or [ ];
    };

  mkLsp =
    {
      language,
      command,
      args,
      extensionToLanguage ? { },
      packageName ? null,
      path,
    }:
    {
      type = "lsp";
      inherit
        language
        command
        args
        extensionToLanguage
        packageName
        path
        ;
    };

  # Reserved slot — no MCP servers ship today, but the constructor exists so
  # the first one to land does not require a flake change.
  mkMcp =
    {
      name,
      transport ? "stdio",
      command,
      args ? [ ],
      env ? { },
      packageName ? null,
    }:
    {
      type = "mcp";
      inherit
        name
        transport
        command
        args
        env
        packageName
        ;
    };

  mkPlugin =
    {
      name,
      version,
      description,
      default ? false,
      path,
      claudeManifest,
      codexManifest,
      skills ? [ ],
      agents ? [ ],
      commands ? [ ],
      lspServers ? { },
      mcpServers ? { },
    }:
    {
      type = "plugin";
      inherit
        name
        version
        description
        default
        path
        skills
        agents
        commands
        lspServers
        mcpServers
        ;
      manifests = {
        claude = claudeManifest;
        codex = codexManifest;
        antigravity = null;
      };
    };

  # Pull the `nixpkgs#<name>` token out of an LSP args list (if any). The four
  # language plugins all follow the convention `nix shell nixpkgs#<server> -c ...`.
  packageNameFromArgs =
    args:
    let
      hit = lib.lists.findFirst (a: lib.hasPrefix "nixpkgs#" a) null args;
    in
    if hit == null then null else lib.removePrefix "nixpkgs#" hit;
}
