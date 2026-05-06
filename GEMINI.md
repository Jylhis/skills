# GEMINI.md

@AGENTS.md

## Gemini CLI

This file is consumed by Gemini CLI. The `@AGENTS.md` import above pulls
in the tool-agnostic project context; everything below is Gemini-
specific.

- Prefer skills over always-loaded context: `skills/<name>/SKILL.md`.
- Use `/memory show` and `/memory reload` to inspect/refresh the loaded
  context.
- Do not encode Gemini-only behaviors (commands, hooks, extensions) in
  portable SKILL.md files. Put those under target-native config.
