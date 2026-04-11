# jvm-dev

JVM development intelligence for jstack: 8 skills covering Java 21 LTS
and Kotlin 2.0+ under a single plugin. Uses Gradle with the Kotlin DSL
as the default build tool and wires up both LSPs plus the `gradle-mcp`
server.

## Contents

- `.claude-plugin/plugin.json` — plugin manifest
- `.lsp.json` — `jdtls` (Java) and `kotlin-language-server` (generated from `plugin.nix`)
- `.mcp.json` — `gradle-mcp` via JBang (generated from `plugin.nix`)
- `plugin.nix` — metadata, packages, LSP/MCP wiring (source of truth)
- `skills/` — 8 skill directories

This plugin is part of [jstack](../../) and is installed into
`~/.claude/plugins/jvm-dev/` automatically by `scripts/install.bash`.

## Skills

| Skill | Description |
|---|---|
| `java-code-style` | Google Java Style, modern Java features (records, sealed, pattern matching) |
| `kotlin-code-style` | Official Kotlin conventions, ktlint, data classes, idioms |
| `jvm-build-gradle` | Gradle Kotlin DSL, version catalogs, build scans |
| `jvm-testing` | JUnit 5 (Java), kotest (Kotlin), AssertJ, mockito |
| `java-concurrency` | Virtual threads, structured concurrency, CompletableFuture, locks |
| `kotlin-coroutines` | Structured concurrency, Flow, coroutine scopes, supervisor jobs |
| `jvm-packaging` | Gradle publish, Maven Central, JReleaser, JPMS modules |
| `jvm-security` | JNDI, deserialization, dep audit, OWASP top 10 for JVM |

## Opinionated picks

- **Build tool:** Gradle with Kotlin DSL (works for both Java and Kotlin)
- **Test runner:** JUnit 5 (Java primary), kotest (Kotlin primary)
- **Assertion library:** AssertJ (Java), kotest assertions (Kotlin)
- **Formatter:** google-java-format (Java), ktlint (Kotlin)
- **Logger:** SLF4J + Logback
- **DI:** not recommended at plugin level — framework choice (Spring,
  Dagger, Koin) is app-specific. See reference notes per skill.

## LSP integration

- **Java:** `jdtls` (Eclipse JDT Language Server), available as
  `pkgs.jdt-language-server`.
- **Kotlin:** `kotlin-language-server`, available as
  `pkgs.kotlin-language-server`.

Both are declared in `plugin.nix` and added to the runtime PATH.

## MCP integration

`gradle-mcp` (rnett) runs via `jbang run gradle-mcp@rnett`. JBang is
declared as a package and pulls the MCP server into its cache on first
use. Exposes project mapping, smart task execution, dependency search,
and a Kotlin REPL.

If JBang-based bootstrap proves flaky, fall back to `maven-tools-mcp`
(arvindand) for Maven projects.

## Sources

- `everything-claude-code` — Java / Kotlin code review skills as
  inspiration
- `gradle-mcp` by rnett — the MCP server wired into `plugin.nix`

## See also

- jstack docs: (TODO: `docs/plugins/jvm-dev.mdx`)
