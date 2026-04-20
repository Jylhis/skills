# jstack module options

Reference for the `programs.jstack` option tree. The module is usable
from Home Manager, NixOS, and nix-darwin — each context is detected at
evaluation time and the appropriate deployment strategy is selected.

- **Skills** are declared either individually via
  `programs.jstack.skills.<name>` or in bulk via
  `programs.jstack.skillSources.<name>`. Skill sources pull from flake
  inputs and support per-skill `include` / `exclude` filters.
- **Agents** and **commands** are markdown files deployed to each tool's
  config dir (`.claude/agents`, `.claude/commands`). Consumer config is
  merged additively with repo-shipped defaults.
- **Tools** under `programs.jstack.tools.<name>` enable per-tool
  integrations (Claude Code, Codex, Gemini, Pi, Windsurf, Cursor,
  OpenCode, Cline, Aider). Each tool accepts `enable`, extra settings,
  permissions, and hooks.

Source: <https://github.com/jylhis/jstack>.

---

