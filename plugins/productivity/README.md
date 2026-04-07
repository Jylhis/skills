# productivity

General productivity and workflow skills for jstack. Currently ships a
single skill: `session-log`.

## Contents

- `.claude-plugin/plugin.json` — plugin manifest
- `skills/session-log/SKILL.md` — weekly conversation log appender

This plugin is part of [jstack](../../) and is installed into
`~/.claude/plugins/productivity/` automatically by
`scripts/install.bash`. There is no separate install step.

## Skills

| Skill | Description |
|---|---|
| `session-log` | Summarize the current conversation and append to the weekly agent-log file (`YYYY-wWW agent-log.md`) |

**Trigger phrases:** "log this", "session log", "summarize this session",
or any request to write results to the agent-log.

See [`docs/plugins/productivity.mdx`](../../docs/plugins/productivity.mdx)
for the full format and workflow rules.

## Sources

- [`michalparkola/tapestry-skills`](https://github.com/michalparkola/tapestry-skills) — 1 skill (MIT)

Skills retain the licenses of their original sources.

## See also

- jstack docs: [`docs/plugins/productivity.mdx`](../../docs/plugins/productivity.mdx)
