---
name: python-security
description: >
  Python security footguns and safe alternatives: subprocess injection,
  pickle deserialization, yaml.load, SSRF, SQL injection, secrets
  management, path traversal. Apply when handling untrusted input or
  external services.
---

# Python security

Unsafe API and safe alternative pairs for review.

## Command injection: `subprocess`

```python
# WRONG
subprocess.run(f"grep {user_input} file.log", shell=True)
```

```python
# RIGHT
subprocess.run(["grep", user_input, "file.log"], check=True)
```

- `shell=False` is the default; do not override.
- `check=True` raises on non-zero exit.
- For shell pipelines, chain two `subprocess.run` calls explicitly.

If you must use `shell=True`, use `shlex.quote`:

```python
safe = shlex.quote(user_input)
subprocess.run(f"grep {safe} file.log", shell=True)
```

## Deserialization: `pickle`

**Never unpickle untrusted data.** `pickle.loads` executes arbitrary code.

Alternatives: **JSON**, **Pydantic `model_validate_json`**, **`msgpack`**.

Pickle is for trusted data only (local cache, RPC between trusted
processes).

## `yaml.load` pitfall

```python
# WRONG
config = yaml.load(text)          # RCE risk

# RIGHT
config = yaml.safe_load(text)
```

`yaml.load(text, Loader=yaml.FullLoader)` is still unsafe. Always
`safe_load`.

## SQL injection

```python
# WRONG
cursor.execute(f"SELECT * FROM users WHERE id = '{user_id}'")
```

```python
# RIGHT — parameterized
cursor.execute("SELECT * FROM users WHERE id = %s", (user_id,))
```

- Use your driver's parameter binding (`%s`, `?`, `:name`).
- Never trust column or table names from user input — validate against
  an allowlist.

## SSRF (Server-Side Request Forgery)

```python
import httpx
from urllib.parse import urlparse
import ipaddress
import socket

def is_safe_url(url: str) -> bool:
    parsed = urlparse(url)
    if parsed.scheme not in {"http", "https"}:
        return False
    host = parsed.hostname
    if host is None:
        return False
    try:
        ip = ipaddress.ip_address(socket.gethostbyname(host))
    except (OSError, ValueError):
        return False
    return not (ip.is_private or ip.is_loopback or ip.is_link_local or ip.is_multicast)
```

- Parse and validate **before** fetching.
- Resolve hostname once, then fetch by IP to prevent DNS rebinding.
- Block cloud metadata endpoints (`169.254.169.254`).

## Path traversal

```python
# WRONG — accepts ../../etc/passwd
def read_file(name: str) -> str:
    return (Path("/var/data") / name).read_text()
```

```python
# RIGHT
def read_file(name: str) -> str:
    base = Path("/var/data").resolve()
    target = (base / name).resolve()
    if not target.is_relative_to(base):
        raise ValueError("path outside base directory")
    return target.read_text()
```

## Secrets

- Never commit secrets. `.env` in dev, secrets manager in production.
- Never log secrets. Filter `password`, `token`, `authorization`, `cookie`.
- Use `secrets` module for cryptographic random, not `random`:
  ```python
  import secrets
  token = secrets.token_urlsafe(32)
  api_key = secrets.token_hex(16)
  ```
- `hmac.compare_digest` for constant-time token comparison — never `==`.

## Password hashing

**`argon2-cffi`** (preferred) or **`passlib[bcrypt]`**. Never SHA-256
a password. Never roll your own.

## Dependency audit

```bash
uv run pip-audit                  # audit installed deps
uv run safety check               # alternative
```

## JWT pitfalls

- Use **`PyJWT`** with explicit `algorithms=["HS256"]` — never
  `algorithms=["none"]`.
- Short expiry + refresh tokens.
- Verify `exp` and `nbf`.

## `eval` and `exec`

Never on user input. Use `ast.literal_eval` for literals or a
purpose-built DSL parser.

## Anti-patterns

- `requests` without a timeout — blocks indefinitely. Always `timeout=30`.
- Catching `Exception` and returning `None` — hides security errors.
- Logging the full request body on error — leaks PII and secrets.
- Returning stack traces to users in HTTP responses.
- Loading YAML/pickle from user uploads.
- `tempfile.mktemp()` (race condition) — use `tempfile.NamedTemporaryFile`.

## Tool detection

```bash
for tool in python3 uv pip-audit; do
  command -v "$tool" >/dev/null && echo "ok: $tool" || echo "MISSING: $tool"
done
```

## References

- OWASP Python cheat sheet: https://cheatsheetseries.owasp.org/cheatsheets/Python_Security_Cheat_Sheet.html
- `subprocess` security: https://docs.python.org/3/library/subprocess.html#security-considerations
- `secrets` module: https://docs.python.org/3/library/secrets.html
- PyCQA `bandit`: https://bandit.readthedocs.io
