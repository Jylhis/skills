---
name: python-linting
description: >
  Ruff linting for Python: rule selection, per-file ignores, noqa
  comments, CI integration. Apply when setting up lint for a new project
  or tightening rules.
---

# Python linting with ruff

Ruff: 10-100x faster than flake8, replaces flake8 + isort + pydocstyle
+ pylint + most plugins. Do not use pylint, flake8, or pyflakes in new
projects.

## Install

```bash
uv add --dev ruff
```

## Minimal config (`pyproject.toml`)

```toml
[tool.ruff]
target-version = "py312"
line-length = 88
src = ["src", "tests"]

[tool.ruff.lint]
select = [
    "E",    # pycodestyle errors
    "W",    # pycodestyle warnings
    "F",    # pyflakes
    "I",    # isort
    "N",    # pep8-naming
    "UP",   # pyupgrade
    "B",    # flake8-bugbear
    "A",    # flake8-builtins
    "C4",   # flake8-comprehensions
    "PT",   # flake8-pytest-style
    "SIM",  # flake8-simplify
    "RUF",  # ruff-specific
]
ignore = [
    "E501",   # line too long — handled by formatter
]

[tool.ruff.lint.per-file-ignores]
"tests/**/*.py" = [
    "S101",   # assert is fine in tests
    "PLR2004", # magic values fine in tests
]
```

## Rule groups

**Always enable:** `F`, `E`/`W`, `I`, `UP`, `B`.

**Consider:** `PT` (pytest-style), `SIM` (simplify), `C4`
(comprehensions), `N` (naming), `RUF`, `ANN` (strict projects only).

**Usually disable:** `D` (pydocstyle, high-noise), `COM` (conflicts with
formatter), `T20` (print — scripts use print legitimately), `TRY`
(opinionated, often wrong).

## `noqa` comments

```python
value = eval(user_input)  # noqa: S307  reason: REPL tool, trusted input
```

- Always specify the rule: `# noqa: E501`, not bare `# noqa`.
- Always include a reason.
- Bare `# noqa` is caught by `RUF100`.

## Running

```bash
uv run ruff check .                    # lint
uv run ruff check . --fix              # auto-fix safe violations
uv run ruff check . --fix --unsafe-fixes  # include risky fixes
uv run ruff check . --watch            # watch mode
uv run ruff check --statistics         # counts per rule
```

## Per-file and per-directory ignores

```toml
[tool.ruff.lint.per-file-ignores]
"__init__.py" = ["F401"]   # allow re-exports
"migrations/*.py" = ["E501", "N806"]
```

## CI integration

```yaml
- name: Lint
  run: uv run ruff check .
```

Do not add `--fix` in CI.

## Integration with pyright

Run both: `ruff check . && pyright`. Ruff catches style and micro-bugs,
pyright catches types.

## Anti-patterns

- Using ruff **and** black **and** isort — ruff replaces them both.
- Mixing pylint with ruff — 80% duplication.
- Disabling whole rule groups because of one violation — use per-file
  ignores.
- `# noqa` on every other line — disable the rule in config instead.

## Tool detection

```bash
for tool in python3 uv ruff; do
  command -v "$tool" >/dev/null && echo "ok: $tool" || echo "MISSING: $tool"
done
```

## References

- Ruff docs: https://docs.astral.sh/ruff/
- Rules: https://docs.astral.sh/ruff/rules/
- Configuration: https://docs.astral.sh/ruff/configuration/
