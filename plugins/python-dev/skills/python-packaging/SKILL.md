---
name: python-packaging
description: >
  Modern Python packaging with uv: pyproject.toml, lockfile, dev
  dependencies, scripts, workspaces, publishing. Apply when setting up
  a new project, migrating from pip/poetry, or publishing to PyPI.
---

# Python packaging with uv

**uv** replaces pip, pip-tools, poetry, pyenv, virtualenv, and pipx.
~10-100x faster, correct by default. Do not use pip or poetry in new
projects.

## Install

uv is declared in `plugin.nix` -- available via devenv. For other
environments: https://docs.astral.sh/uv/getting-started/installation/

## Create a new project

```bash
uv init --package my-thing         # library (src layout)
uv init my-app                     # application
cd my-thing
uv add ruff --dev
uv add httpx
uv sync                            # create .venv, install everything
```

## `pyproject.toml` structure

```toml
[project]
name = "my-thing"
version = "0.1.0"
description = "Does the thing"
readme = "README.md"
requires-python = ">=3.12"
authors = [{ name = "Markus", email = "m@example.com" }]
license = "MIT"
dependencies = [
    "httpx>=0.27",
    "pydantic>=2.7",
]

[project.optional-dependencies]
cli = ["typer>=0.12"]

[project.scripts]
my-thing = "my_thing.__main__:main"

[build-system]
requires = ["hatchling"]
build-backend = "hatchling.build"

[dependency-groups]
dev = [
    "pytest>=8",
    "ruff>=0.6",
    "pyright>=1.1",
]
```

Use **`[dependency-groups]`** (PEP 735) for dev tools — not
`optional-dependencies`. Dev groups are not installed when users `pip
install` your package.

`build-backend`: **hatchling** (default), **setuptools** (legacy),
**maturin** (Rust extensions).

## Commands

```bash
uv add requests                       # add runtime dep
uv add --dev pytest                   # add dev dep
uv add --group docs mkdocs            # add to specific group
uv remove requests
uv sync                               # install from lockfile
uv sync --upgrade                     # update lockfile then install
uv sync --upgrade-package httpx       # update only httpx
uv lock                               # re-lock without installing
uv run pytest                         # run in the env
uv run python -m my_package
uv tree                               # dependency tree
uv pip list                           # list installed
```

## Lockfile

`uv.lock` — commit it for apps and binaries.

In CI, use `uv sync --frozen` to fail on lockfile drift.

## Running code

Do not activate the virtualenv. Use `uv run`:

```bash
uv run pytest
uv run ruff check
uv run python scripts/migrate.py
```

## Publishing to PyPI

```bash
uv build                              # sdist + wheel into dist/
uv publish --token pypi-...           # upload
```

For Rust extensions, use `maturin develop` / `maturin publish`.

## Workspaces (monorepo)

```toml
# root pyproject.toml
[tool.uv.workspace]
members = ["packages/*"]

[tool.uv.sources]
shared-lib = { workspace = true }
```

Each `packages/*/pyproject.toml` is a full project. One `uv.lock` at
the root.

## Python version management

```bash
uv python install 3.12
uv python pin 3.12
uv venv --python 3.12 .venv
```

Use `requires-python = ">=3.12"` in `pyproject.toml` as the version
floor.

## Migration from pip + requirements.txt

```bash
uv init --package .
uv add -r requirements.txt
rm requirements.txt requirements-dev.txt
```

Move dev dependencies to the `dev` dependency group.

## Migration from poetry

```bash
uvx migrate-to-uv
```

## Anti-patterns

- `pip install` inside a uv project — creates drift.
- Committing `.venv`.
- requirements.txt alongside `pyproject.toml` — pick one.
- `setup.py` in new projects.
- Forgetting `requires-python` — affects wheel resolution.

## Tool detection

```bash
for tool in python3 uv; do
  command -v "$tool" >/dev/null && echo "ok: $tool" || echo "MISSING: $tool"
done
```

## References

- uv docs: https://docs.astral.sh/uv/
- `pyproject.toml` guide: https://packaging.python.org/en/latest/guides/writing-pyproject-toml/
- PEP 735 (dependency groups): https://peps.python.org/pep-0735/
- hatchling: https://hatch.pypa.io/latest/
