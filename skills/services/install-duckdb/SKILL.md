---
name: install-duckdb
description: "Install or update DuckDB extensions (not the DuckDB binary itself). Each requested extension is either a plain name (installed from core) or name@repo (e.g. magic@community). Use to install or update extensions, or to update the DuckDB CLI. If DuckDB itself is absent, this prints platform install instructions and stops."
metadata:
  upstream-id: duckdb-skills
  upstream-rev: 7feda8e01e22bc0886c86123f3884947e36d8c69
  upstream-path: install-duckdb
  upstream-imported: 2026-05-14
---

This skill installs or updates DuckDB **extensions** — it does not install the
DuckDB binary itself. If DuckDB is missing, it prints platform install
instructions (Step 1) and stops.

Work out which extensions the user wants. Each requested extension is named as
`name` or `name@repo`:
- `name` → `INSTALL name;`
- `name@repo` → `INSTALL name FROM repo;`

## Step 1 — Locate DuckDB

```bash
DUCKDB=$(command -v duckdb)
```

If not found, tell the user:

> **DuckDB is not installed.** Install it first with one of:
> - macOS:   `brew install duckdb`
> - Linux:   `curl -fsSL https://install.duckdb.org | sh`
> - Windows: `winget install DuckDB.cli`
>
> Then ask to run this skill again.

Stop if DuckDB is not found.

## Step 2 — Determine the mode

If the user asked to **update** extensions (or the DuckDB CLI), set mode to
**update**. Otherwise mode is **install**.

## Step 3 — Build and run statements

**Install mode:**

For each extension the user requested:
- If it contains `@`, split on `@` → `INSTALL <name> FROM <repo>;`
- Otherwise → `INSTALL <name>;`

Run all in a single DuckDB call:

```bash
"$DUCKDB" :memory: -c "INSTALL <ext1>; INSTALL <ext2> FROM <repo2>; ..."
```

**Update mode:**

First, check if the DuckDB CLI itself is up to date:

```bash
CURRENT=$(duckdb --version | grep -oE '[0-9]+\.[0-9]+\.[0-9]+')
LATEST=$(curl -fsSL https://duckdb.org/data/latest_stable_version.txt)
```

- If `CURRENT` == `LATEST` → report DuckDB CLI is up to date.
- If `CURRENT` != `LATEST` → ask the user:
  > **DuckDB CLI is outdated** (installed: `CURRENT`, latest: `LATEST`). Upgrade now?

  If the user agrees, detect the platform and run the appropriate upgrade command:
  - macOS (`brew` available): `brew upgrade duckdb`
  - Linux: `curl -fsSL https://install.duckdb.org | sh`
  - Windows: `winget upgrade DuckDB.cli`

Then update extensions:

- No extension names → update all: `UPDATE EXTENSIONS;`
- With extension names → update in a single call (ignore `@repo`):
  `UPDATE EXTENSIONS (<name1>, <name2>, ...);`

```bash
"$DUCKDB" :memory: -c "UPDATE EXTENSIONS;"
# or
"$DUCKDB" :memory: -c "UPDATE EXTENSIONS (<ext1>, <ext2>, ...);"
```

Report success or failure after the call completes.
