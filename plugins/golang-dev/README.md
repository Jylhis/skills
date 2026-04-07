# golang-dev

Go development intelligence for jstack: 36 skills covering idiomatic Go,
concurrency, testing, performance, security, observability, and the
`samber/*` library family.

## Contents

- `.claude-plugin/plugin.json` — plugin manifest
- `skills/` — 36 skill directories, many with `references/`, `evals/`, and `assets/` subdirs

This plugin is part of [jstack](../../) and is installed into
`~/.claude/plugins/golang-dev/` automatically by `scripts/install.bash`.
There is no separate install step.

## Skills

`golang-benchmark`, `golang-cli`, `golang-code-style`,
`golang-concurrency`, `golang-context`, `golang-continuous-integration`,
`golang-data-structures`, `golang-database`,
`golang-dependency-injection`, `golang-dependency-management`,
`golang-design-patterns`, `golang-documentation`, `golang-error-handling`,
`golang-grpc`, `golang-linter`, `golang-modern-syntax`,
`golang-modernize`, `golang-naming`, `golang-observability`,
`golang-performance`, `golang-popular-libraries`, `golang-project-layout`,
`golang-safety`, `golang-samber-do`, `golang-samber-hot`,
`golang-samber-lo`, `golang-samber-mo`, `golang-samber-oops`,
`golang-samber-ro`, `golang-samber-slog`, `golang-security`,
`golang-stay-updated`, `golang-stretchr-testify`,
`golang-structs-interfaces`, `golang-testing`, `golang-troubleshooting`

See [`docs/plugins/golang-dev.mdx`](../../docs/plugins/golang-dev.mdx)
for the per-skill description table.

## LSP integration

This plugin's documentation references `gopls` via
`nix run nixpkgs#gopls`, but no `.mcp.json` exists and `gopls` is not
currently in `runtime/default.nix`. To make `gopls` available to Claude
Code, add it to the runtime.

## Sources

- [`samber/cc-skills-golang`](https://github.com/samber/cc-skills-golang) — 35 skills by Samuel Berthe (MIT)
- [`JetBrains/go-modern-guidelines`](https://github.com/JetBrains/go-modern-guidelines) — `golang-modern-syntax` (Apache-2.0)

Skills retain the licenses of their original sources.

## See also

- jstack docs: [`docs/plugins/golang-dev.mdx`](../../docs/plugins/golang-dev.mdx)
