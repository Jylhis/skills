# `upstream/sources.yaml` schema

Authoritative manifest for tracked upstream skill repositories. One file
per repo, hand-edited; helper scripts read it and update only the
`upstream-rev`, `reviewed-rev`, and `last-fetched` fields
automatically.

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
        category: <string>
        name: <string>
        target-plugin: <string>
        merge-strategy: <string>   # optional; default "standalone"
        umbrella: <string>         # required for umbrella-references
        topic: <string>            # required for umbrella-references
```

Top-level has exactly one key, `sources`, whose value is a list. Each
list entry is a mapping with the fields below.

## Source field reference

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
| `category` | yes | string | One of `engineering`, `languages`, `domains`, `services`, `stack`, `productivity`, `personal`, `misc`. Sets the destination category folder. |
| `name` | yes | string | Local skill name. Must match the destination directory basename and the imported `SKILL.md`'s `name:` frontmatter. |
| `target-plugin` | yes (for standalone) | string | The `plugins/<name>/` directory that should expose this skill (e.g. `jylhis-skills-core`). The importer creates the `plugins/<plugin>/skills/<name>` symlink and adds `./skills/<name>` to that plugin's `.claude-plugin/plugin.json`. The plugin directory itself must already exist. |
| `merge-strategy` | no | string | `standalone` (default): write a new SKILL.md at `skills/<category>/<name>/`. `umbrella-references`: drop the upstream SKILL.md body into `skills/<category>/<umbrella>/references/<topic>.md` instead of writing a new skill — requires `umbrella:` and `topic:`. `replace`: like `standalone` but overwrites silently. |
| `umbrella` | yes (for umbrella-references) | string | Existing umbrella skill name under the same `category:` whose `references/` will receive the upstream content. |
| `topic` | yes (for umbrella-references) | string | Filename stem (without `.md`) under `<umbrella>/references/`. |

### Legacy `local:` field

The pre-v8-category schema used a single `local: <category>/<name>`
field instead of separate `category:` and `name:` keys. The importer
still accepts `local:` for backwards compat, but new entries should
use `category:` + `name:`. The category must be one of the eight
canonical values.

`name` segments must be unique across the entire manifest — multiple
upstreams cannot target the same local skill directory under
`standalone`. Multiple `umbrella-references` entries can target
different `topic:` files under the same `umbrella:`.

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

## Minimal example — standalone skill

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
        category: services
        name: grafana
        target-plugin: jylhis-grafana
        merge-strategy: standalone
```

After running `python3 meta/upstream-tracker/scripts/import.py
grafana-skills`, the three auto-populated fields fill in and the
imported skill appears at `skills/services/grafana/SKILL.md` with the
`metadata.upstream-*` block injected. The importer also creates
`plugins/jylhis-grafana/skills/grafana` (symlink) and adds
`./skills/grafana` to `plugins/jylhis-grafana/.claude-plugin/plugin.json`.

## Minimal example — umbrella-references merge

```yaml
sources:
  - id: openai-skills
    repo: https://github.com/openai/skills
    branch: main
    subpath: skills/.curated
    license: MIT
    upstream-rev: ""
    reviewed-rev: ""
    last-fetched: ""
    skills:
      - upstream: security-best-practices
        category: domains
        name: security-best-practices
        target-plugin: jylhis-skills-core
        merge-strategy: umbrella-references
        umbrella: security
        topic: best-practices
```

This drops the upstream `SKILL.md` body into
`skills/domains/security/references/best-practices.md` rather than
creating a new top-level skill. No plugin wiring is performed for
`umbrella-references` entries — the existing umbrella's plugin
membership already covers the new reference.
