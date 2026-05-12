# `ast-grep` skill rubric

This file is the per-suite rubric input for promptfoo's g-eval judge.
The judge concatenates `evals/judges/rubric_template.md` with this
file and the per-case rubric criteria, then asks the configured judge
CLI to score the SUT output.

Score each rubric criterion 1–5; `overall_pass` is true iff every
criterion is ≥4. The harness records the full dimensional output for
human review even when the case fails — that audit trail matters more
than the binary pass.

## Skill under test

`skills/unix/ast-grep/SKILL.md` — polyglot structural code search,
lint, and rewrite via the `ast-grep` CLI. Triggers on keywords like
"structural", "AST", "codemod", "meta-variable", and on tasks where a
`grep`/`sed` regex would be brittle because of formatting or nesting.

## What "good" looks like

A high-scoring response:

- Uses `ast-grep run -p '<pattern>'` (or the equivalent
  `ast-grep -p '<pattern>'`) for one-shot searches; `ast-grep scan`
  for repository-wide rule application; or a YAML rule when the user
  asks for a reusable check.
- Names a meta-variable correctly: `$VAR` (single node), `$_`
  (anonymous single node), `$$$` (variadic / list of nodes).
- Provides the language flag (`-l ts`, `-l js`, etc.) when the prompt
  hints at a specific language.
- For YAML rules: a top-level `id`, `language`, and `rule.pattern`
  (optionally `rule.kind` / `rule.regex` / composite `all`/`any`/`not`).
- Avoids regex-only suggestions when the user explicitly asked for
  structural matching.
- Avoids apologetic filler ("I apologize", "As an AI", "Sure, here").

## What "bad" looks like

- Suggesting `grep -E` / `sed` / `awk` for a structural matching task.
- Inventing flags (`--structural`, `--ast`, `--match`) that ast-grep
  does not have.
- Using a wrong meta-variable form (`$$VAR`, `$X$$`, `:VAR:`).
- Returning a YAML rule missing `id` or `language`, or using a key
  like `pattern:` at the top level instead of nested under `rule:`.
- Hallucinating `ast-grep replace` (the rewrite flag is `-r`, not a
  subcommand).
