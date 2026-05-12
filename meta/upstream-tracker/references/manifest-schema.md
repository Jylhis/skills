# `upstream/sources.yaml` schema

Authoritative manifest for tracked upstream skill repositories. One file
per repo, hand-edited; helper scripts read it and update only the
`upstream-rev` and `last-fetched` fields automatically.

The format is a restricted YAML subset — only the shapes shown below
parse correctly. The helper scripts use the same parsing strategy as
`scripts/validate.py` (no PyYAML dependency).

## Top-level shape

```yaml
sources:
  - id: <string>
    repo: <string>
    branch: <string>
    subpath: <string>
    license: <string>
    upstream-rev: <string>
    reviewed-rev: <string>
    last-fetched: <string>
    skills:
      - upstream: <string>
        local: <string>
```

Top-level has exactly one key, `sources`, whose value is a list. Each
list entry is a mapping with the fields below.

## Field reference

| Field | Required | Type | Notes |
|---|---|---|---|
| `id` | yes | string | Unique within manifest. Lowercase letters, digits, hyphens. Used as filename for the decision log and the bare clone. |
| `repo` | yes | string | HTTPS clone URL (e.g. `https://github.com/grafana/skills`). SSH URLs work too if the user's git is configured for them. |
| `branch` | yes | string | Upstream branch to track (e.g. `main`, `master`). |
| `subpath` | yes | string | Repo-relative directory containing skills. Trailing slash optional. Use `.` if skills are at the repo root. |
| `license` | yes | string | SPDX identifier or short license name. Recorded for audit; not validated. |
| `upstream-rev` | auto | string | Last upstream HEAD sha seen by `fetch.py`. 40-char hex. Empty on the very first import; populated by `import.py`. |
| `reviewed-rev` | auto | string | Cursor sha — last upstream sha confirmed by §4 review. 40-char hex. Set to `upstream-rev` by `import.py`; advances only via `review.py`. Always `<= upstream-rev`. |
| `last-fetched` | auto | string | ISO-8601 timestamp of the last successful `fetch.py` run. |
| `skills` | yes | list | List of import mappings (see below). At least one entry. |

## `skills[]` entry shape

| Field | Required | Type | Notes |
|---|---|---|---|
| `upstream` | yes | string | Subdirectory inside `<subpath>` containing the upstream skill (e.g. `grafana-promql`). The path is relative to `subpath`, not the repo root. |
| `local` | yes | string | Local destination relative to `skills/`. Must follow the two-level convention: `<category>/<name>` (e.g. `observability/grafana-promql`). The `<name>` segment must equal the imported `SKILL.md`'s `name:` frontmatter. |

`local` paths must be unique across the entire manifest — multiple
upstreams cannot target the same local skill directory.

## Lifecycle of `upstream-rev` and `reviewed-rev`

```
                                          fetch.py
                                              │
                                              ▼
                          ┌────────── upstream-rev ─────────────┐
                          │           (HEAD now seen)           │
import.py sets both to ──►│                                     │
the import-time HEAD      │                                     │
                          │           reviewed-rev              │
                          └────── (cursor; advances via ────────┘
                                      review.py)
```

- `import.py` writes both fields to the same sha (the resolved upstream
  HEAD at import time) and appends an `accept` row to the decision log
  for that sha.
- `fetch.py` updates only `upstream-rev`. It is allowed to run forward
  to `origin/<branch>` HEAD without touching the cursor.
- `review.py` walks the decision log forward through contiguous
  resolved rows (`accept`, `skip`, finalized `cherry-picked:<sha>`)
  starting from the current `reviewed-rev`, and writes the new cursor
  back to the manifest. A `defer` row is the stop sign.

## Editing rules

- Top-level YAML keys other than `sources` are ignored (not allowed by
  the parser, but absent today). Don't add them.
- Hand-edits to `id`, `repo`, `branch`, `subpath`, `license`, `skills`
  are expected and supported.
- Hand-edits to `upstream-rev`, `reviewed-rev`, `last-fetched` are
  technically possible but discouraged — the helper scripts maintain
  them. If you must rewind `reviewed-rev` (e.g. to re-review an old
  commit), do it explicitly in a single commit so `git log` records
  the reason.

## Minimal example

```yaml
sources:
  - id: grafana-skills
    repo: https://github.com/grafana/skills
    branch: main
    subpath: skills
    license: AGPL-3.0
    upstream-rev: ""
    reviewed-rev: ""
    last-fetched: ""
    skills:
      - upstream: grafana-promql
        local: observability/grafana-promql
```

After running `python3 meta/upstream-tracker/scripts/import.py
grafana-skills`, the three auto-populated fields fill in and the
imported skill appears at `skills/observability/grafana-promql/SKILL.md`
with the `metadata.upstream-*` block injected.
