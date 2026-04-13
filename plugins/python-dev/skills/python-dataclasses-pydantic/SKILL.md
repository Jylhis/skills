---
name: python-dataclasses-pydantic
description: >
  When to use dataclass vs Pydantic v2 vs TypedDict vs attrs, and the
  migration paths between them. Covers validation, serialization,
  config, and model design. Apply when designing any value object or
  data model in Python.
---

# dataclass vs Pydantic vs TypedDict

Pick one per module and stick with it; mixing creates conversion
boilerplate.

| Tool | Use when |
|---|---|
| **`@dataclass`** | Internal value objects; no runtime validation needed; you own all the data |
| **Pydantic v2** | External data (HTTP, config, DB rows); need validation + serialization; want JSON schema |
| **TypedDict** | Legacy APIs that return `dict`; third-party library interop; types only, no runtime check |
| **`attrs`** | Legacy projects that already use it |

## `@dataclass`

```python
from dataclasses import dataclass, field
from datetime import datetime

@dataclass(frozen=True, slots=True)
class CacheEntry:
    key: str
    value: bytes
    created_at: datetime
    ttl_seconds: int = 3600
    tags: list[str] = field(default_factory=list)
```

- **`frozen=True`** — immutable, hashable, usable as dict keys. Default
  for value objects.
- **`slots=True`** (3.10+) — less memory, faster attribute access, blocks
  accidental attribute typos.
- **`field(default_factory=list)`** for mutable defaults — never use a
  bare `tags: list[str] = []`.
- **No validation** — `CacheEntry(key=123, value=None, ...)` silently
  succeeds. Use Pydantic for untrusted data.

## Pydantic v2

```python
from pydantic import BaseModel, Field, EmailStr, field_validator

class User(BaseModel):
    id: str
    email: EmailStr
    name: str = Field(..., min_length=1, max_length=200)
    age: int = Field(..., ge=0, lt=150)
    tags: list[str] = Field(default_factory=list)

    @field_validator("name")
    @classmethod
    def strip_name(cls, v: str) -> str:
        return v.strip()
```

- **Validate at the boundary**: HTTP handlers, config load, DB row parse.
  Don't scatter Pydantic throughout internal code.
- **`model_validate(data)`** parses a dict; raises `ValidationError` on
  bad input.
- **`model_dump(mode='json')`** serializes to a JSON-safe dict.
- Use type-level constraints (`min_length`, `ge`, `lt`, `pattern`)
  instead of custom validators when possible.
- **v2 is not v1.** `@field_validator`, `@model_validator(mode='after')`,
  `model_config = ConfigDict(...)`.

### Pydantic settings

```python
from pydantic_settings import BaseSettings, SettingsConfigDict

class Settings(BaseSettings):
    model_config = SettingsConfigDict(env_file=".env", env_prefix="APP_")

    database_url: str
    log_level: str = "INFO"
    debug: bool = False

settings = Settings()  # reads env vars automatically
```

## TypedDict

Use only when you must interop with `dict`-returning APIs:

```python
from typing import TypedDict, NotRequired

class StripeEvent(TypedDict):
    id: str
    type: str
    data: NotRequired[dict[str, object]]
```

- **Runtime-erased** — just hints, no validation.
- **`NotRequired`** for optional keys.
- Convert to a dataclass/Pydantic model at the boundary for better
  downstream code.

## dataclass -> Pydantic migration

```python
# Before
from dataclasses import dataclass

@dataclass
class User:
    id: str
    name: str

# After
from pydantic import BaseModel

class User(BaseModel):
    id: str
    name: str
```

Fields are identical. Migrate when you start adding validators; don't
migrate speculatively.

## Serialization

- **dataclass -> dict:** `dataclasses.asdict(instance)`.
- **dataclass -> JSON:** `json.dumps(asdict(instance), default=str)`.
  Beware datetimes, Decimals, UUIDs.
- **Pydantic -> dict:** `instance.model_dump()`.
- **Pydantic -> JSON string:** `instance.model_dump_json()`.
- **Pydantic -> JSON-safe dict:**
  `instance.model_dump(mode='json')` — converts datetimes, UUIDs to
  strings.

## Inheritance

- Dataclass inheritance: fields with defaults must come after fields
  without — gets annoying fast. Prefer composition.
- Pydantic inheritance works cleanly for sharing fields across
  request/response models.

## Anti-patterns

- Pydantic for every internal dataclass — overhead adds up, most
  internal data is already valid.
- `@dataclass` for HTTP request payloads — no validation.
- Mixing Pydantic v1 and v2 in the same project.
- `BaseModel.model_config = {'arbitrary_types_allowed': True}` — disables
  validation; usually means you should use a dataclass.
- Custom `__init__` on a dataclass — use `__post_init__` instead.
- `json.dumps(asdict(x))` with datetimes — fails at runtime.

## Tool detection

```bash
for tool in python3 uv pyright; do
  command -v "$tool" >/dev/null && echo "ok: $tool" || echo "MISSING: $tool"
done
```

## References

- dataclasses: https://docs.python.org/3/library/dataclasses.html
- Pydantic v2: https://docs.pydantic.dev/latest/
- Pydantic migration guide: https://docs.pydantic.dev/latest/migration/
- pydantic-settings: https://docs.pydantic.dev/latest/concepts/pydantic_settings/
