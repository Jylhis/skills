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
- Plugin-local skills (Claude-only, real directories under
  `plugins/jylhis-skills-core/skills/`): `explore`, `lsp-status`,
  `remember-correction`, invoked as `/jylhis-skills-core:<name>`.
- LSP wiring is per-language-plugin via `plugins/jylhis-<lang>/.lsp.json`;
  `/jylhis-skills-core:lsp-status` reports only what the user has opted
  into.

## Output style

This file is symlinked to `~/.claude/CLAUDE.md`, so these conventions apply
to text Claude generates (chat replies, code, shell scripts) in every
project, not just this repo. They govern new output, not a rewrite of
existing committed prose.

- Do not use em dashes (the "—" character) in generated output. Prefer a
  comma, a colon, parentheses, a sentence break, or "and" / "but".
  Exceptions: quoting source text verbatim, or literal `--` CLI flags.
- Do not use a run of `=` characters as a section divider in shell output,
  here-docs, or chat. Use blank lines, a single `#` heading line, or a short
  `[label]` marker instead.
