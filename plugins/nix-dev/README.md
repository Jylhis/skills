# nix-dev

Nix development intelligence for jstack: 10 skills covering the Nix
language, NixOS modules, flakes, npins, devenv, home-manager,
nix-debugging, nixpkgs, hybrid non-flake + flake architecture, and
linting — plus a `.mcp.json` that wires up the `mcp-nixos` MCP server
for NixOS option and package lookups.

## Contents

- `.claude-plugin/plugin.json` — plugin manifest
- `.mcp.json` — `mcp-nixos` server (`nix run github:utensils/mcp-nixos`)
- `skills/` — 10 skill directories with `SKILL.md`

This plugin is part of [jstack](../../) and is installed into
`~/.claude/plugins/nix-dev/` automatically by `scripts/install.bash`.
There is no separate install step.

## Skills

`devenv`, `flakes`, `home-manager`, `nix-debugging`, `nix-hybrid`,
`nix-language`, `nix-linting`, `nixos-modules`, `nixpkgs`, `npins`

See [`docs/plugins/nix-dev.mdx`](../../docs/plugins/nix-dev.mdx) for the
per-skill description table.

## MCP server

```json
{
  "mcpServers": {
    "mcp-nixos": {
      "type": "stdio",
      "command": "nix",
      "args": ["run", "github:utensils/mcp-nixos", "--"]
    }
  }
}
```

On first use, `nix run` fetches and builds
[`utensils/mcp-nixos`](https://github.com/utensils/mcp-nixos) from the
GitHub flake.

## LSP integration

The upstream plugin also shipped a non-standard `.lsp.json` file
declaring `nil` as an LSP server. Claude Code does not consume
`.lsp.json`, and `nil` is already provided by `runtime/default.nix`, so
the file was dropped on import.

## See also

- jstack docs: [`docs/plugins/nix-dev.mdx`](../../docs/plugins/nix-dev.mdx)
