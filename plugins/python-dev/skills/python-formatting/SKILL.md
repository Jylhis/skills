---
name: python-formatting
description: >
  Ruff format as the Python formatter: config, per-file settings, line
  length, pre-commit hooks. Apply when setting up formatting for a new
  project or migrating from black.
---

# Python formatting with ruff format

Ruff ships its own formatter (`ruff format`) that is **drop-in
compatible with black**, ~30x faster, and part of the same binary as
ruff's linter. Do not use black, autopep8, or yapf.

## Config (`pyproject.toml`)

```toml
[tool.ruff]
target-version = "py312"
line-length = 88
src = ["src", "tests"]

[tool.ruff.format]
quote-style = "double"          # match black's default
indent-style = "space"
skip-magic-trailing-comma = false
docstring-code-format = true    # format code blocks inside docstrings
```

- `line-length = 88` — black's default, community standard.
- `quote-style = "double"` — use single if migrating a single-quote
  codebase and you want to avoid a massive diff.
- `docstring-code-format = true` — formats code examples inside
  docstrings.

## Running

```bash
uv run ruff format .               # format in place
uv run ruff format --check .       # CI: fail if anything is unformatted
uv run ruff format --diff .        # show what would change
uv run ruff format path/to/file.py
```

## Pre-commit / lefthook

`lefthook.yml`:

```yaml
pre-commit:
  commands:
    format:
      glob: "*.py"
      run: uv run ruff format --check {staged_files}
    lint:
      glob: "*.py"
      run: uv run ruff check {staged_files}
```

Keep `--check` in pre-commit — forcing a reformat on commit surprises
developers. Format-on-save in the editor is better UX.

## Format-on-save

- **VS Code:** `"editor.defaultFormatter": "charliermarsh.ruff"` +
  `"editor.formatOnSave": true` for Python files.
- **Neovim:** `conform.nvim` with `formatters_by_ft = { python = { "ruff_format" } }`.
- **PyCharm:** Ruff plugin, "Reformat on save".

## Integration with lint

Ruff's linter and formatter can collide on a few style rules. Disable
the conflicting lint rules (`COM`, `E501`, some quote rules) — add
them to `ignore` under `[tool.ruff.lint]`.

## Migration from black

```bash
uv remove black
uv add --dev ruff
```

```toml
[tool.ruff]
line-length = 88   # match your existing black line-length

[tool.ruff.format]
quote-style = "double"
```

Run `uv run ruff format .` once, commit as a single "switch to ruff
format" commit so `git blame` stays useful.

## Anti-patterns

- Running both black **and** ruff format — they will fight.
- Formatting generated files (e.g. `_pb2.py`).
- `# fmt: off` / `# fmt: on` without a reason comment.
- Running format in CI as a separate job from lint — run them together:
  `ruff check && ruff format --check`.

## Tool detection

```bash
for tool in python3 uv ruff; do
  command -v "$tool" >/dev/null && echo "ok: $tool" || echo "MISSING: $tool"
done
```

## References

- Ruff formatter: https://docs.astral.sh/ruff/formatter/
- Black compatibility: https://docs.astral.sh/ruff/formatter/black/
- docstring-code-format: https://docs.astral.sh/ruff/settings/#format_docstring-code-format
