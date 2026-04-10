{
  "$schema" = "https://json.schemastore.org/claude-code-settings.json";
  env.CLAUDE_CODE_EFFORT_LEVEL = "high";
  includeCoAuthoredBy = false;
  permissions.allow = [
    "Read"
    "Grep"
    "Glob"
    "WebSearch"
    "WebFetch"
    "mcp__fetch__fetch"
  ];
  model = "opus[1m]";
  statusLine = {
    type = "command";
    command = "wt list statusline --format=claude-code";
  };
  spinnerTipsEnabled = false;
  alwaysThinkingEnabled = true;
  effortLevel = "high";
  extraKnownMarketplaces = {
    jstack = {
      source = {
        source = "github";
        repo = "Jylhis/jstack";
      };
    };
  };
}
