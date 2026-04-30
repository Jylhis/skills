# MCP config formatters — convert a shared mcpServers attrset to per-tool format.
#
# Each tool stores MCP server configuration differently:
#   - Claude Code, Cursor, Windsurf, Pi: standalone JSON file
#   - Codex CLI: TOML [mcp_servers] section in config.toml
#   - Gemini CLI, OpenCode: embedded in settings JSON under mcpServers/mcp key
#   - Cline: JSON in VS Code extension dir (not auto-managed)
#   - Aider: no MCP support
#
# Usage:
#   formatMcpJson servers   => JSON string for Claude/Cursor/Windsurf/Pi
#   formatMcpToml pkgs servers => store path to TOML file (Codex)
#   formatMcpAttrs servers  => attrset for embedding in parent JSON (Gemini/OpenCode)
{ lib }:
let
  optionalNonNull = name: value: lib.optionalAttrs (value != null) { ${name} = value; };
  optionalNonEmpty =
    name: value: lib.optionalAttrs (value != [ ] && value != { }) { ${name} = value; };

  formatCommonServer =
    srv:
    {
    }
    // optionalNonNull "command" (srv.command or null)
    // optionalNonEmpty "args" (srv.args or [ ])
    // optionalNonEmpty "env" (srv.env or { })
    // lib.optionalAttrs ((srv.type or "stdio") != "stdio") { inherit (srv) type; }
    // optionalNonNull "url" (srv.url or null);

  formatCodexServer =
    srv:
    formatCommonServer srv
    // optionalNonNull "cwd" (srv.cwd or null)
    // optionalNonNull "experimental_environment" (srv.experimental_environment or null)
    // optionalNonEmpty "env_vars" (srv.env_vars or [ ])
    // optionalNonNull "bearer_token_env_var" (srv.bearer_token_env_var or null)
    // optionalNonEmpty "http_headers" (srv.http_headers or { })
    // optionalNonEmpty "env_http_headers" (srv.env_http_headers or { })
    // optionalNonNull "startup_timeout_sec" (srv.startup_timeout_sec or null)
    // optionalNonNull "tool_timeout_sec" (srv.tool_timeout_sec or null)
    // optionalNonNull "enabled" (srv.enabled or null)
    // optionalNonNull "required" (srv.required or null)
    // optionalNonEmpty "enabled_tools" (srv.enabled_tools or [ ])
    // optionalNonEmpty "disabled_tools" (srv.disabled_tools or [ ]);
in
{
  # Format MCP servers as a JSON string with { mcpServers: { ... } } wrapper.
  # Used by: Claude Code (.mcp.json), Cursor (.cursor/mcp.json),
  #          Windsurf (~/.codeium/windsurf/mcp_config.json), Pi (.pi/mcp.json)
  formatMcpJson =
    servers:
    builtins.toJSON {
      mcpServers = lib.mapAttrs (_: formatCommonServer) servers;
    };

  formatCodexMcpAttrs = servers: lib.mapAttrs (_: formatCodexServer) servers;

  formatToml =
    pkgs: name: attrs:
    (pkgs.formats.toml { }).generate name attrs;

  # Format MCP servers as a TOML config file via JSON -> remarshal conversion.
  # Returns a store derivation (path), not a string.
  # Used by: Codex CLI (config.toml)
  formatMcpToml =
    pkgs: servers:
    (pkgs.formats.toml { }).generate "codex-mcp.toml" {
      mcp_servers = lib.mapAttrs (_: formatCodexServer) servers;
    };

  # Format MCP servers as a plain attrset for embedding in a parent JSON config.
  # The caller merges this into the tool's settings.json before serializing.
  # Used by: Gemini CLI (settings.json mcpServers key),
  #          OpenCode (opencode.json mcp key)
  formatMcpAttrs = servers: lib.mapAttrs (_: formatCommonServer) servers;
}
