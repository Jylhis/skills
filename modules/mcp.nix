# MCP module — declares shared mcpServers options.
#
# MCP servers are configured once and deployed to each enabled tool
# in the tool's specific format (JSON, TOML, embedded).
# Tool modules read cfg.mcpServers and format them via lib/mcp-format.nix.
{
  lib,
  ...
}:
{
  options.programs.jstack.mcpServers = lib.mkOption {
    type = lib.types.attrsOf (
      lib.types.submodule {
        options = {
          command = lib.mkOption {
            type = lib.types.nullOr lib.types.str;
            default = null;
            description = "Command to start the MCP server.";
          };

          args = lib.mkOption {
            type = lib.types.listOf lib.types.str;
            default = [ ];
            description = "Arguments passed to the MCP server command.";
          };

          env = lib.mkOption {
            type = lib.types.attrsOf lib.types.str;
            default = { };
            description = "Environment variables for the MCP server.";
          };

          type = lib.mkOption {
            type = lib.types.enum [
              "stdio"
              "sse"
              "http"
            ];
            default = "stdio";
            description = "Transport type for the MCP server.";
          };

          url = lib.mkOption {
            type = lib.types.nullOr lib.types.str;
            default = null;
            description = "URL for sse/http transports.";
          };

          cwd = lib.mkOption {
            type = lib.types.nullOr lib.types.str;
            default = null;
            description = "Working directory for stdio MCP servers.";
          };

          experimental_environment = lib.mkOption {
            type = lib.types.nullOr lib.types.str;
            default = null;
            description = "Experimental Codex MCP environment selector.";
          };

          env_vars = lib.mkOption {
            type = lib.types.listOf lib.types.unspecified;
            default = [ ];
            description = "Environment variables Codex may forward to the MCP server.";
          };

          bearer_token_env_var = lib.mkOption {
            type = lib.types.nullOr lib.types.str;
            default = null;
            description = "Environment variable containing a bearer token for HTTP MCP servers.";
          };

          http_headers = lib.mkOption {
            type = lib.types.attrsOf lib.types.str;
            default = { };
            description = "Static HTTP headers for HTTP MCP servers.";
          };

          env_http_headers = lib.mkOption {
            type = lib.types.attrsOf lib.types.str;
            default = { };
            description = "HTTP headers whose values are read from environment variables.";
          };

          startup_timeout_sec = lib.mkOption {
            type = lib.types.nullOr lib.types.int;
            default = null;
            description = "MCP server startup timeout in seconds.";
          };

          tool_timeout_sec = lib.mkOption {
            type = lib.types.nullOr lib.types.int;
            default = null;
            description = "MCP tool execution timeout in seconds.";
          };

          enabled = lib.mkOption {
            type = lib.types.nullOr lib.types.bool;
            default = null;
            description = "Whether this MCP server is enabled.";
          };

          required = lib.mkOption {
            type = lib.types.nullOr lib.types.bool;
            default = null;
            description = "Whether Codex startup should fail if this server cannot initialize.";
          };

          enabled_tools = lib.mkOption {
            type = lib.types.listOf lib.types.str;
            default = [ ];
            description = "Codex MCP tool allow list.";
          };

          disabled_tools = lib.mkOption {
            type = lib.types.listOf lib.types.str;
            default = [ ];
            description = "Codex MCP tool deny list.";
          };
        };
      }
    );
    default = { };
    description = ''
      MCP servers shared across all enabled tools.
      Each tool module formats these into its specific config format.
    '';
    example = {
      github = {
        command = "github-mcp-server";
        args = [ "--stdio" ];
        env.GITHUB_TOKEN = "\${GITHUB_TOKEN}";
      };
    };
  };
}
