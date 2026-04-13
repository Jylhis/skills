---
name: python-code-style
description: >
  Idiomatic Python 3.12+ style: PEP 8 baseline, modern syntax,
  comprehensions, f-strings, pathlib, structural pattern matching,
  walrus operator. Apply when writing or reviewing Python code.
---

# Python code style (3.12+)

Ruff enforces most of PEP 8 plus modern idioms; trust ruff and don't
argue with it.

## PEP 8 baseline

- **Indentation:** 4 spaces, never tabs.
- **Line length:** 88 columns (ruff default).
- **Blank lines:** 2 between top-level defs, 1 between methods.
- **Naming:**
  - `snake_case` for variables, functions, methods, modules.
  - `PascalCase` for classes and type aliases.
  - `UPPER_SNAKE_CASE` for module-level constants.
  - `_leading_underscore` for private, `__dunder__` reserved.
  - Avoid single-letter names except loop counters and math (`i`, `x`, `y`).
- **Imports:** one per line, grouped (stdlib, third-party, local), sorted
  within groups. Let ruff's `I` rules handle this.

## Modern Python features (3.10+)

- **Structural pattern matching** (`match`/`case`):
  ```python
  match response:
      case {"ok": True, "data": data}:
          return data
      case {"ok": False, "error": str(msg)}:
          raise ValueError(msg)
      case _:
          raise TypeError("unexpected response shape")
  ```
  Use for multi-branch logic on complex shapes. Avoid for simple
  equality — use `if`/`elif`.
- **f-strings over `.format()` or `%`**: `f"{user.name!r} at {now:%H:%M}"`.
  Python 3.12 allows arbitrary expressions including nested quotes.
- **Walrus operator** (`:=`) for "check and use":
  ```python
  while chunk := stream.read(4096):
      process(chunk)
  ```
- **`pathlib.Path` over `os.path`**:
  ```python
  from pathlib import Path
  config = Path("~/.config/app").expanduser()
  if config.exists():
      data = config.read_text()
  ```

## Comprehensions vs loops

- Prefer list/dict/set comprehensions for simple transforms:
  `[x * 2 for x in nums if x > 0]`
- Generator expressions for large pipelines to avoid materializing:
  `sum(x * x for x in nums)`
- **Don't nest** beyond two levels — convert to a loop.
- Don't abuse comprehensions for side effects; use a `for` loop.

## Iteration

- `enumerate(items)` instead of `range(len(items))`.
- `zip(a, b, strict=True)` — always use `strict=True` (3.10+).
- `itertools` for cycling, chaining, grouping — don't rebuild.
- `dict.items()`, `dict.values()` — don't iterate keys to look up values.

## Truthiness

- `if not xs:` for empty containers — don't compare `len(xs) == 0`.
- `if x is None:` — never `== None`.

## String formatting

- `"string".join(parts)` over repeated `+=`.
- `textwrap.dedent` for multi-line string literals in function bodies.
- Raw strings (`r"..."`) for regex patterns and Windows paths.

## Functions

- **Default arguments must not be mutable:**
  ```python
  # WRONG
  def append_to(item, target=[]):
      target.append(item)
      return target

  # RIGHT
  def append_to(item, target=None):
      if target is None:
          target = []
      target.append(item)
      return target
  ```
- **Keyword-only arguments** (`*, key1, key2`) force callers to be
  explicit for boolean flags and optional config.
- **Return early** — avoid deeply nested `if`/`else`.

## Classes

- Use `@dataclass` (or Pydantic for validated data) over hand-written
  `__init__`/`__repr__`/`__eq__`.
- Prefer composition over inheritance. ABC for true polymorphism, not
  code reuse.
- `@property` for simple computed attributes; method for anything that
  does work.
- `__slots__` only for performance-critical hot paths.

## Anti-patterns

- `type(x) == T` — use `isinstance(x, T)`.
- `except:` bare — always catch specific exceptions.
- `import *` — explicit imports only.
- `global` — pass values explicitly.
- `lambda` that just calls a function — pass the function directly.

## Tool detection

```bash
for tool in python3 uv ruff pyright pytest; do
  command -v "$tool" >/dev/null && echo "ok: $tool" || echo "MISSING: $tool"
done
```

## References

- PEP 8: https://peps.python.org/pep-0008/
- Ruff rules: https://docs.astral.sh/ruff/rules/
- Python 3.12 what's new: https://docs.python.org/3/whatsnew/3.12.html
