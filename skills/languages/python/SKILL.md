---
name: python
description: Use for Python 3.12+ work — modern code style (PEP 8, match, pathlib, f-strings), asyncio (TaskGroup, gather, cancellation), error handling (Exception design, ExceptionGroup), type hints (PEP 695 generics, TypedDict, Protocol, pyright), dataclasses vs Pydantic, Ruff (format & lint), packaging with uv, and pytest testing (fixtures, parametrize, asyncio, mocking, coverage). Read the matching reference before acting.
---

# Python skill index

Pick the topic and read its reference before writing or reviewing
Python code. Each reference is the focused, opinionated guidance for
that sub-topic.

| Topic | When to read | Reference |
|---|---|---|
| Code style | PEP 8, comprehensions, f-strings, match/case, walrus, pathlib, dataclasses, modern union syntax | `references/code-style.md` |
| Async / asyncio | async/await, TaskGroup, gather, cancellation, timeout, Semaphore, Queue, to_thread, debug mode | `references/async.md` |
| Error handling | exception hierarchy design, narrow try/except, raise X from Y, ExceptionGroup / except*, contextlib.suppress | `references/error-handling.md` |
| Type hints | PEP 695 generics, TypedDict, Protocol, Literal, Final, overload, X \| None, pyright/mypy strict mode | `references/type-hints.md` |
| Dataclasses / Pydantic | choosing between @dataclass, Pydantic v2 BaseModel, TypedDict, attrs, frozen=True | `references/dataclasses-pydantic.md` |
| Formatting (Ruff) | ruff format config, line-length, pre-commit, CI, migrating from black | `references/formatting.md` |
| Linting (Ruff) | rule selection (E/F/I/B/UP/PL/RUF), per-file-ignores, --fix, replacing flake8/pylint/isort | `references/linting.md` |
| Packaging (uv) | uv init / sync / add / build / publish, pyproject [project], workspaces, [project.scripts], migrating from pip/poetry/pdm | `references/packaging.md` |
| Testing (pytest) | fixtures, @parametrize, pytest-asyncio, mocking, monkeypatch, tmp_path, capsys/caplog, coverage | `references/testing.md` |

For Python **security** topics (subprocess, pickle, yaml, SSRF, SQLi,
secrets, crypto), use the `security` skill instead.

After reading the reference, follow its guidance for the task.
