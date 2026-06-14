# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

@AGENTS.md

## Claude Code

The `@AGENTS.md` import above is the source of truth for project context
(layout, commands, conventions, script-language preference, upstream
workflow). Do not duplicate it here. Everything below is Claude-specific.

- Skills live at `skills/<category>/<name>/SKILL.md` (two levels deep).
  Prefer authoring or extending a skill over inline procedural prompts —
  skills are loaded on-demand.
- Skill content must stay portable: no `${CLAUDE_PLUGIN_ROOT}`, no
  `` !`...` `` bash interpolation, no hidden subdirectory `CLAUDE.md`
  imports. `just validate` enforces this.
- Long API references and architecture deep dives belong in
  `references/` inside a skill, not in this file.

### Claude runtime entry points shipped by this repo

When `jylhis-skills-core` is installed, these are available in addition
to the skills listed by the runtime:

- Subagents (read-only): `@reviewer`, `@explorer`, `@debugger` —
  `plugins/jylhis-skills-core/agents/`.
- Slash commands: `/explore`, `/lsp-status`, `/remember-correction` —
  `plugins/jylhis-skills-core/commands/`.
- LSP wiring is per-language-plugin via `plugins/jylhis-<lang>/.lsp.json`;
  `/lsp-status` reports only what the user has opted into.
