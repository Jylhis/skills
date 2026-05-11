# Generated skill template

The skill emitted by `skill-creator-lang` follows the
[agentskills.io](https://agentskills.io) open standard and the local
profile in `docs/skill-authoring-guide.md`.

## Frontmatter

Required:

- `name` — must equal the parent directory basename.
- `description` — 50–1024 chars; include trigger phrases for routing.

Optional:

- `license`
- `compatibility`
- `metadata` — free-form map; string values.

Never emit target-specific fields (`allowed-tools`, `argument-hint`,
`model`, `tools`, `hooks`, `permissionMode`, etc.) — `scripts/validate.py`
rejects them.

## Body order

Keep `SKILL.md` under ~8 KB. Push long material into
`references/<topic>.md`.

```markdown
---
name: <skill-name>
description: <50–1024 chars; include trigger phrases for routing>
---

# <Language or Stack Name> (<version>)

<one paragraph: paradigm, what this skill covers, when to load it>

## Toolchain

<the picked formatter, linter, type checker, REPL, test runner, package manager, build tool — one each>

## Tool detection

<bash block from step 10 of SKILL.md>

## Idiomatic style

<concrete dos and don'ts>

## Best practices

<the small expert ruleset>

## Footguns

<traps and safe alternatives>

## Gotchas

<!-- omit if not applicable -->
<project- or skill-specific traps the agent must see before triggering; keep here, not in references/>

## Templates

<!-- omit if not applicable -->
<canonical output format(s); inline if short, otherwise under assets/ with a pointer>

## Validation

<!-- omit if not applicable -->
<tested validation step (script or checklist) for plan-validate-execute workflows>

## Prefer built-ins

<which stdlib modules replace common third-party deps>

## Testing

<how to write, run one, run all>

## Build, lint, validate

<exact commands>

## Package & dependency management

<package manager, lockfile, virtualenv/equivalent, add and pin deps>

## Project layout

<directory structure for lib and app>

## Debugging & profiling

<commands>

## Security

<unsafe APIs, common CVE patterns>

## LSP server

<chosen language server, launch command, editor integration notes — or "none available">

## MCP servers

<chosen MCP server(s) and what they expose — or "none available">

## References

<links to references/*.md and official docs>
```
