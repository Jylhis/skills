---
name: python-error-handling
description: >
  Python error handling: exception hierarchies, try/except audit, custom
  exceptions, contextlib, exception chaining, ExceptionGroup. Apply when
  reviewing error paths or designing an exception API.
---

# Python error handling

Catch specific exception types, re-raise with context, and treat
exceptions as part of the API.

## Specific exceptions only

```python
# WRONG
try:
    result = risky()
except Exception:
    return None
```

```python
# RIGHT
try:
    result = risky()
except (ValueError, TypeError) as err:
    log.warning("risky() rejected input", exc_info=err)
    raise
```

- **Catch the narrowest exception** that applies.
- **Never use bare `except:`** — catches `KeyboardInterrupt` and
  `SystemExit`.
- **Catch `Exception`** only as a last-resort logging boundary at the
  top of a request handler or task runner, and always re-raise or log
  with stack trace.

## Custom exceptions

```python
class AppError(Exception):
    """Base for all application errors."""

class NotFoundError(AppError):
    def __init__(self, resource: str, id: str) -> None:
        super().__init__(f"{resource} with id {id} not found")
        self.resource = resource
        self.id = id

class ValidationError(AppError):
    def __init__(self, field: str, reason: str) -> None:
        super().__init__(f"{field}: {reason}")
        self.field = field
        self.reason = reason
```

- Inherit from `Exception` (not `BaseException`).
- Pass structured data (ids, field names) as attributes, not just a
  stringified message.
- Small, flat hierarchy rooted in one `AppError`.

## Exception chaining

```python
try:
    response = httpx.get(url)
except httpx.HTTPError as err:
    raise NetworkError(f"failed to fetch {url}") from err
```

- `raise X from err` — preserves the cause chain.
- `raise X from None` — suppresses the previous exception (e.g.
  KeyError -> NotFoundError conversion).
- Don't stringify the cause into the new message — the traceback shows it.

## EAFP vs LBYL

```python
# EAFP — Pythonic
try:
    return cache[key]
except KeyError:
    value = expensive_compute()
    cache[key] = value
    return value
```

```python
# LBYL — acceptable when the check is cheap
if path.exists():
    return path.read_text()
return default
```

Use EAFP for dict/attribute access where the "check" doubles the cost.
Use LBYL when the check is free (file existence, None check).

## contextlib

```python
from contextlib import contextmanager, suppress

@contextmanager
def temp_file(suffix: str = ""):
    f = tempfile.NamedTemporaryFile(suffix=suffix, delete=False)
    try:
        yield Path(f.name)
    finally:
        f.close()
        Path(f.name).unlink(missing_ok=True)

with temp_file(".json") as path:
    path.write_text(json.dumps(data))
```

- `contextmanager` for simple setup/teardown.
- `ExitStack` for dynamic cleanup (unknown number of context managers).
- `suppress(SomeError)` reads better than `try: ... except SomeError: pass`.

## ExceptionGroup (Python 3.11+)

```python
try:
    async with asyncio.TaskGroup() as tg:
        tg.create_task(fetch_user())
        tg.create_task(fetch_orders())
except* NetworkError as eg:
    for err in eg.exceptions:
        log.warning("network failed", exc_info=err)
except* ValidationError as eg:
    for err in eg.exceptions:
        log.error("validation failed", exc_info=err)
```

- `except*` filters an ExceptionGroup by type.
- Re-raises the subset that didn't match.
- TaskGroup aggregates child errors into an ExceptionGroup automatically.

## Logging errors

```python
log.error("failed to load user", exc_info=True)
# or with explicit exception
log.error("failed to load user", exc_info=err)
```

- Always pass `exc_info=True` or `exc_info=err` inside `except` blocks.
- `log.exception(msg)` is shorthand for `log.error(msg, exc_info=True)`.
- For structlog: `log.error("load failed", error=repr(err))`.

## try/except audit checklist

1. Is this `except` catching something specific?
2. Is the handler doing more than logging + re-raise?
3. Is the re-raise using `from err` to preserve context?
4. Does the code after the `try` still make sense if the `try` was
   skipped (for `pass` handlers)?
5. Is there a retry loop with no backoff or limit?
6. Is there a `finally` that could re-raise in cleanup?

## Anti-patterns

- `except Exception: pass` — silently swallows everything.
- `except Exception as err: raise err` — loses traceback (use `raise`).
- Returning `None` instead of raising — errors "sneak" through.
- Catching `Exception` at function boundaries "just in case".
- Using exceptions for control flow in hot loops.
- Validating errors by `str(err)` parsing.

## Tool detection

```bash
for tool in python3 uv pyright; do
  command -v "$tool" >/dev/null && echo "ok: $tool" || echo "MISSING: $tool"
done
```

## References

- Exception hierarchy: https://docs.python.org/3/library/exceptions.html
- PEP 654 (ExceptionGroup): https://peps.python.org/pep-0654/
- contextlib: https://docs.python.org/3/library/contextlib.html
