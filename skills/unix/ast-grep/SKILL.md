---
name: ast-grep
description: "Use for polyglot structural code search, lint, and rewrite with ast-grep (alias `sg`) across JavaScript / TypeScript / TSX, Python, Go, Rust, Java, Kotlin, C / C++, C#, Ruby, PHP, Swift, Bash, HTML, CSS, JSON, YAML, and more. Reach for it instead of grep / sed when a regex would over- or under-match because of formatting, comments, or nested structures. Covers `ast-grep run -p` one-shot patterns, `ast-grep scan` with YAML rules, `ast-grep new project` scaffolding, `ast-grep test` for rule snapshots, meta-variable syntax (`$VAR`, `$_`, `$$$`), composite rules (`all`, `any`, `not`, `inside`, `has`, `precedes`, `follows`), `constraints` regex filters, `fix` rewrites, `sgconfig.yml`, JSON output for tooling, and CI usage."
---

# ast-grep

`ast-grep` (CLI binary `ast-grep`, also aliased `sg`) is a polyglot
tree-sitter-backed tool for structural code search, lint, and rewrite.
Use it whenever a `grep` / `sed` regex would be brittle: it matches on
the parsed AST, so formatting, whitespace, and comments don't matter.

Default to `ast-grep` over regex for: API migrations, codemods,
deprecating a function, finding insecure patterns, enforcing in-house
lint rules across multiple languages.

## Install

```bash
brew install ast-grep             # macOS / Linux
npm i -g @ast-grep/cli            # Node ecosystem
cargo install ast-grep --locked   # Rust
pip install ast-grep-cli          # Python ecosystem
```

The binary is `ast-grep`. `sg` is an alias on most distributions; on
some systems `sg` collides with `/usr/bin/sg` (setgid) — use
`ast-grep` in scripts.

## Quick search and rewrite (`ast-grep run`)

`run` is the default subcommand; `ast-grep -p ...` and
`ast-grep run -p ...` are equivalent.

```bash
ast-grep -p 'console.log($A)' -l ts src/
ast-grep -p 'console.log($A)' -r 'logger.debug($A)' -l ts src/
ast-grep -p 'foo($$$)' -l js --json=stream | jq .
```

Key flags:

- `-p, --pattern` — pattern source.
- `-l, --lang` — explicit language (`js`, `ts`, `tsx`, `py`, `go`,
  `rust`, `java`, `kotlin`, `c`, `cpp`, `csharp`, `ruby`, `php`,
  `swift`, `bash`, `html`, `css`, `json`, `yaml`, …). Inferred from
  file extension if omitted.
- `-r, --rewrite` — replacement template.
- `-i, --interactive` / `-U, --update-all` — confirm or apply rewrites.
- `--stdin` — read code from stdin.
- `--json=pretty|stream|compact` — machine-readable output.
- `-A`, `-B`, `-C` — context lines (like `grep`).
- `--globs` — include / exclude paths.
- `--debug-query -l <lang>` — print the tree-sitter parse of the
  pattern; the first thing to reach for when a pattern doesn't match.

## Pattern syntax

Patterns are real source code in the target language. Meta-variables
introduce holes:

| Token       | Matches                                                         |
| ----------- | --------------------------------------------------------------- |
| `$VAR`      | Exactly one named AST node; the same name must match identically.|
| `$_`        | Exactly one anonymous node (don't capture).                      |
| `$$VAR`     | Zero or more nodes captured as a sequence (advanced).            |
| `$$$`       | Ellipsis: any number of sibling nodes (args, statements, items). |
| `$$$VAR`    | Named ellipsis: capture the sequence for use in `--rewrite`.     |

Examples:

```bash
# Any console method
ast-grep -p 'console.$METHOD($$$)' -l ts

# Promise.then with arrow callback
ast-grep -p '$P.then($X => $$$)' -l js

# Empty catch block
ast-grep -p 'try { $$$ } catch ($_) { }' -l ts
```

## YAML rules and `ast-grep scan`

Use `scan` for repeatable rules with messages, fixes, and severity.

```bash
ast-grep new project          # scaffolds sgconfig.yml + rules/ + rule-tests/ + utils/
ast-grep new rule no-eval -l js
ast-grep scan                 # uses sgconfig.yml
ast-grep scan -r rule.yml     # one-off rule file
ast-grep scan --inline-rules '{id: x, language: js, rule: {pattern: eval($A)}}'
ast-grep scan --filter '^security-' --json=stream
ast-grep scan -U              # apply all fixes without prompting
```

Rule file shape (`rules/no-eval.yml`):

```yaml
id: no-eval
language: JavaScript
severity: error
message: Avoid eval; it executes arbitrary code.
note: Use JSON.parse or a real parser.
rule:
  pattern: eval($CODE)
fix: JSON.parse($CODE)
```

### Rule operators

- **Atomic**: `pattern`, `kind` (tree-sitter node kind), `regex`,
  `nthChild`, `range`.
- **Relational**: `inside`, `has`, `precedes`, `follows`. Each takes a
  sub-rule plus optional `stopBy: end | neighbor | <rule>` and
  `field: <name>` (e.g. `field: parameter`).
- **Composite**: `all: [...]`, `any: [...]`, `not: <rule>`, `matches: <util-id>`.
- **`constraints`** — per-meta-variable filters:

  ```yaml
  rule:
    pattern: fetch($URL)
  constraints:
    URL:
      regex: '^["'']http://'   # only flag plain http
  ```

- **`utils`** in `sgconfig.yml` or per-rule — named sub-rules reused
  via `matches: <id>`. Promote any rule that appears in two places.
- **`rewriters`** — multiple fix templates selected by sub-rule, useful
  for one rule that produces different rewrites by case.

### Project layout (`sgconfig.yml`)

```yaml
ruleDirs:
  - rules
testConfigs:
  - testDir: rule-tests
utilDirs:
  - utils
```

`ast-grep` walks up from CWD to find `sgconfig.yml`, so `scan` works
from any subdirectory of the project.

## Testing rules (`ast-grep test`)

Each rule gets a sibling YAML in `rule-tests/<id>-test.yml` with
`valid` and `invalid` snippets. `ast-grep test` runs them, supports
`--snapshots` for golden fixes, and `-U` to update snapshots.

```bash
ast-grep test                 # run all
ast-grep test -f no-eval      # filter by id regex
ast-grep test -U              # accept new snapshots
```

## Common idioms

- **Match-only, no fix**: omit `fix`. The rule still reports.
- **Lint codebase in CI**:

  ```bash
  ast-grep scan --error      # exits non-zero on any error-severity match
  ```

- **Codemod with review**: `ast-grep scan -i` (interactive) or
  `... -U` after a dry run.
- **Pipe into jq / ripgrep**: `ast-grep --json=stream` emits one JSON
  object per match per line.
- **Hybrid lint with another tool**: run `ast-grep scan` alongside
  Ruff / ESLint / Clippy — ast-grep handles cross-language and
  project-specific rules they can't express.

## Footguns

- **A pattern that looks right but doesn't match** — almost always a
  tree-sitter parse mismatch. Run with `--debug-query -l <lang>` to
  see how ast-grep parsed the pattern; adjust until the AST matches
  what's in the source files.
- **`-l` is required when piping from stdin** or when the file
  extension is ambiguous (`.h`, `.ts` for TypeScript vs Typoscript,
  etc.).
- **Tree-sitter grammar drift** — rules tied to a specific node `kind`
  can break when ast-grep upgrades a grammar. Prefer `pattern` over
  raw `kind:` when both work; keep snapshot tests so drift is caught
  by `ast-grep test`.
- **`fix` strings are templates, not code** — `$VAR` is substituted
  textually. Wrap in parentheses if precedence matters
  (`fix: '($A)?.foo'`).
- **Don't reach for ast-grep for plain string search.** `rg` is faster
  and clearer for non-structural matches.

## Editor / LSP integration

`ast-grep lsp` runs a Language Server that surfaces `scan` diagnostics
and quick-fixes in any LSP-aware editor. It uses the same
`sgconfig.yml`, so editor warnings stay in sync with CI.

```bash
ast-grep lsp                  # invoke from your editor's LSP config
```

The official VS Code extension is `ast-grep.ast-grep-vscode`.
Neovim users: configure `ast-grep` via `nvim-lspconfig` (server name
`ast_grep`).

## Tool detection

```bash
for tool in ast-grep jq rg; do
  command -v "$tool" >/dev/null && echo "ok: $tool" || echo "MISSING: $tool"
done
```

`jq` and `rg` are not required, but most workflows that consume
`--json` output or pre-filter files for ast-grep use them.

## References

- Docs: <https://ast-grep.github.io/>
- Pattern reference: <https://ast-grep.github.io/guide/pattern-syntax.html>
- Rule reference: <https://ast-grep.github.io/reference/rule.html>
- CLI reference: <https://ast-grep.github.io/reference/cli.html>
- Rule catalog (copy-paste examples): <https://ast-grep.github.io/catalog/>
- Playground (paste code, iterate on patterns): <https://ast-grep.github.io/playground.html>
