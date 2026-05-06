# CLAUDE.md

@AGENTS.md

## Claude Code

This file is consumed by Claude Code (claude.ai/code). The `@AGENTS.md`
import above pulls in the tool-agnostic project context; everything
below is Claude-specific.

- Prefer skills (`skills/<name>/SKILL.md`) over inline procedural
  prompts. Skills are loaded on-demand by the agent.
- Do not depend on plugin-root variables like `${CLAUDE_PLUGIN_ROOT}` or
  hidden subdirectory `CLAUDE.md` imports — keep skill content portable.
- Long API references and architecture descriptions belong in
  `references/` inside a skill, not in this file.
