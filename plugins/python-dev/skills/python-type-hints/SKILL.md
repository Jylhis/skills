---
name: python-type-hints
description: >
  Modern Python type hints: PEP 695 generics, TypedDict, Protocol,
  Literal, Final, overloads, pyright strict mode, runtime validation
  boundary. Apply when adding or reviewing type annotations.
---

# Python type hints (3.12+)

Python's type system is gradual: annotations are optional and erased at
runtime. Enable pyright strict mode on new code; keep legacy code untyped
rather than lying about its types.

## Baseline

```python
def greet(name: str, times: int = 1) -> str:
    return ", ".join([f"Hello, {name}"] * times)
```

- All public functions should have parameter and return types.
- `None` is the return type for functions with no `return`.

## PEP 695 syntax (Python 3.12+)

```python
# Generic function
def first[T](items: list[T]) -> T:
    return items[0]

# Generic class
class Stack[T]:
    def __init__(self) -> None:
        self._items: list[T] = []

    def push(self, item: T) -> None:
        self._items.append(item)

# Type alias
type UserId = str
type Response[T] = dict[str, T | None]
```

Do not use the legacy `TypeVar` / `Generic` syntax in new code.

## Container types

- `list[int]`, `dict[str, int]`, `tuple[int, str]`, `set[str]` — native
  generics since 3.9.
- `Sequence`, `Mapping`, `Iterable`, `Iterator` — import from
  `collections.abc`, not `typing`.
- Prefer abstract types in parameters, concrete in return values:
  ```python
  def process(items: Iterable[int]) -> list[int]:
      return sorted(items)
  ```

## Union, Optional, Literal

- **Use `|`**: `int | str`, `str | None`.
- **`Literal`** constrains to specific values:
  ```python
  def fetch(method: Literal["GET", "POST"]) -> bytes: ...
  ```

## TypedDict

```python
from typing import TypedDict, NotRequired

class User(TypedDict):
    id: str
    name: str
    email: NotRequired[str]  # PEP 655
```

- `NotRequired[X]` for optional keys.
- `total=False` for "all keys optional".
- For **runtime validation**, use Pydantic. TypedDict is erased at runtime.

## Protocol (structural typing)

```python
from typing import Protocol

class SupportsClose(Protocol):
    def close(self) -> None: ...

def cleanup(resource: SupportsClose) -> None:
    resource.close()
```

Protocols match by shape, not inheritance. `@runtime_checkable` enables
`isinstance()` checks but slows things down; skip unless needed.

## Overloads

```python
from typing import overload

@overload
def get(key: str, default: None = None) -> str | None: ...
@overload
def get(key: str, default: str) -> str: ...
def get(key: str, default: str | None = None) -> str | None:
    return store.get(key, default)
```

## `Final` and `ClassVar`

```python
from typing import Final, ClassVar

MAX_RETRIES: Final = 3

class Config:
    version: ClassVar[str] = "1.0"
```

## Type narrowing

```python
def process(value: str | int) -> str:
    if isinstance(value, str):
        return value.upper()   # narrowed to str
    return str(value)          # narrowed to int
```

Custom type guards with `TypeIs` (PEP 742):

```python
from typing import TypeIs

def is_user(obj: object) -> TypeIs[User]:
    return isinstance(obj, dict) and "id" in obj and "name" in obj
```

## pyright strict mode

```toml
[tool.pyright]
typeCheckingMode = "strict"
pythonVersion = "3.12"
exclude = ["build", "dist", ".venv"]
```

Strict flags missing annotations, implicit `Any`, unknown types. Adopt
on new code; leave legacy in `basic` mode via per-file overrides.

## Runtime validation boundary

Types are erased at runtime. For data from **outside** your process
(HTTP, DB, config, user input), validate with **Pydantic v2** or
**`dataclass` + manual checks**.

## Anti-patterns

- `Any` without a comment — use `object` instead.
- `# type: ignore` without a reason — use
  `# pyright: ignore[rule-name]  reason`.
- `typing.List`, `typing.Dict`, `typing.Tuple` in new code (3.9+
  supports `list`, `dict`, `tuple`).
- Relying on runtime types to enforce contracts — that's Pydantic's job.

## Tool detection

```bash
for tool in python3 pyright; do
  command -v "$tool" >/dev/null && echo "ok: $tool" || echo "MISSING: $tool"
done
```

## References

- Python typing docs: https://docs.python.org/3/library/typing.html
- PEP 695 (type parameter syntax): https://peps.python.org/pep-0695/
- PEP 742 (TypeIs): https://peps.python.org/pep-0742/
- pyright config: https://microsoft.github.io/pyright/#/configuration
