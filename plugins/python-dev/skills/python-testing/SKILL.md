---
name: python-testing
description: >
  pytest testing patterns for Python: fixtures, parametrize, async tests,
  mocks, coverage, running a single test. Apply when writing or debugging
  Python tests.
---

# Python testing with pytest

pytest is the standard test runner. Do not use `unittest` in new
projects.

## Install (via uv)

```bash
uv add --dev pytest pytest-asyncio pytest-cov
```

## Project layout

```
my_package/
├── src/
│   └── my_package/
│       └── __init__.py
└── tests/
    ├── conftest.py      # shared fixtures
    ├── test_users.py
    └── integration/
        └── test_api.py
```

## `pyproject.toml` config

```toml
[tool.pytest.ini_options]
testpaths = ["tests"]
pythonpath = ["src"]
addopts = "-ra --strict-markers --strict-config"
markers = [
    "slow: deselect with -m 'not slow'",
    "integration: integration tests that hit external services",
]
asyncio_mode = "auto"
```

- `-ra` — short summary of failures.
- `--strict-markers` — fail on unknown `@pytest.mark.*` usage.
- `asyncio_mode = "auto"` — picks up `async def` tests without decorators.

## Minimal test

```python
def test_normalize_email_lowercases() -> None:
    assert normalize_email("Foo@Bar.com") == "foo@bar.com"

def test_normalize_email_strips_whitespace() -> None:
    assert normalize_email(" foo@bar.com ") == "foo@bar.com"
```

Test names describe the behaviour: `test_<what>_<condition>`.

## Fixtures

```python
# tests/conftest.py
import pytest
from my_package.db import Database

@pytest.fixture
def db() -> Database:
    db = Database(":memory:")
    db.migrate()
    yield db
    db.close()

@pytest.fixture
def user(db: Database) -> User:
    return db.create_user(name="alice")
```

- `conftest.py` holds fixtures shared across a directory.
- Scope: `function` (default), `class`, `module`, `session`. Use the
  smallest scope that works.
- Fixtures can depend on other fixtures.
- `yield` runs teardown after the test.

## Parametrize

```python
@pytest.mark.parametrize(
    ("raw", "expected"),
    [
        ("Foo@Bar.com", "foo@bar.com"),
        (" foo@bar.com ", "foo@bar.com"),
        ("FOO+tag@BAR.com", "foo+tag@bar.com"),
    ],
    ids=["case", "whitespace", "plus-tag"],
)
def test_normalize_email(raw: str, expected: str) -> None:
    assert normalize_email(raw) == expected
```

Always include `ids=` for readable failure messages.

## Async tests

With `asyncio_mode = "auto"`:

```python
async def test_fetches_user(client: httpx.AsyncClient) -> None:
    user = await client.get_user("42")
    assert user.id == "42"
```

## Mocks

Prefer dependency injection over `unittest.mock`. Pass fakes as fixtures:

```python
@pytest.fixture
def fake_http() -> FakeHttpClient:
    return FakeHttpClient(responses={"/users/42": {"id": "42"}})
```

When you must patch:

```python
def test_fetch_retries_on_500(monkeypatch) -> None:
    calls = []
    def fake_get(url: str) -> Response:
        calls.append(url)
        return Response(status=500 if len(calls) == 1 else 200)
    monkeypatch.setattr("my_package.http.get", fake_get)
    fetch_with_retry("/users/42")
    assert len(calls) == 2
```

- Prefer `monkeypatch` over `unittest.mock.patch`.
- Patch the **import site**, not the source.

## Assertions

pytest rewrites `assert` for detailed diffs. Use plain `assert`:

```python
assert user.name == "alice"
assert sorted(ids) == [1, 2, 3]
```

For exceptions:

```python
with pytest.raises(ValueError, match="invalid email"):
    normalize_email("not-an-email")
```

## Running

```bash
uv run pytest                              # all tests
uv run pytest tests/test_users.py          # one file
uv run pytest tests/test_users.py::test_normalize_email_lowercases
uv run pytest -k "normalize"               # filter by name
uv run pytest -m "not slow"                # marker filter
uv run pytest --cov=my_package --cov-report=term-missing
uv run pytest -x                           # stop on first failure
uv run pytest --lf                         # rerun last failures
```

## Anti-patterns

- Mocking the thing you're testing.
- `if` statements inside tests — parametrize instead.
- Tests that depend on execution order.
- Sleeping with `time.sleep()` — use fake clocks or events.
- `assert True` as a placeholder.
- Shared mutable state across tests via module-level variables.

## Tool detection

```bash
for tool in python3 pytest uv; do
  command -v "$tool" >/dev/null && echo "ok: $tool" || echo "MISSING: $tool"
done
```

## References

- pytest docs: https://docs.pytest.org
- pytest fixtures: https://docs.pytest.org/en/stable/explanation/fixtures.html
- pytest-asyncio: https://pytest-asyncio.readthedocs.io
- Coverage.py: https://coverage.readthedocs.io
