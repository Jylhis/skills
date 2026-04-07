# rust-dev

Rust development intelligence for jstack: 29 skills covering ownership,
lifetimes, error handling, concurrency, design patterns, domain packs,
and LSP-driven analyzers.

## Contents

- `.claude-plugin/plugin.json` — plugin manifest
- `skills/` — 29 skill directories, each with a `SKILL.md`

This plugin is part of [jstack](../../) and is installed into
`~/.claude/plugins/rust-dev/` automatically by `scripts/install.bash`.
There is no separate install step.

## Skills

### Language mechanics
`m01-ownership`, `m02-resource`, `m03-mutability`, `m04-zero-cost`,
`m05-type-driven`, `m06-error-handling`, `m07-concurrency`

### Design and architecture
`m09-domain`, `m10-performance`, `m11-ecosystem`, `m12-lifecycle`,
`m13-domain-error`, `m14-mental-model`, `m15-anti-pattern`

### Domain packs
`domain-cli`, `domain-cloud-native`, `domain-embedded`,
`domain-fintech`, `domain-iot`, `domain-ml`, `domain-web`

### LSP-driven analyzers
`rust-code-navigator`, `rust-refactor-helper`, `rust-trait-explorer`,
`rust-symbol-analyzer`, `rust-call-graph`, `rust-deps-visualizer`

### Core
`coding-guidelines`, `unsafe-checker`

## LSP integration

The upstream plugin shipped a `.mcp.json` declaring `rust-analyzer` as an
MCP server with an `extensionToLanguage` field. That layout mixes LSP and
MCP semantics and was not adopted in jstack — `.mcp.json` was dropped on
import. To make `rust-analyzer` available on `PATH`, add it to
`runtime/default.nix`.

## Sources

- [`actionbook/rust-skills`](https://github.com/actionbook/rust-skills) — 29 skills by ZhangHanDong (MIT)

Skills retain the license of their original source.

## See also

- jstack docs: [`docs/plugins/rust-dev.mdx`](../../docs/plugins/rust-dev.mdx)
