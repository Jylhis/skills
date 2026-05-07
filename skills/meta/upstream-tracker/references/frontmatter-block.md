# `metadata.upstream-*` frontmatter block

Per-skill provenance for vendored content. The block lives inside the
existing optional `metadata:` map in the skill's frontmatter, which the
portable lint already accepts as a free-form string-valued mapping.

## Shape

```yaml
---
name: grafana-promql
description: ...
metadata:
  upstream-id: grafana-skills
  upstream-rev: 4f3c2e1a0b9d8c7e6f5a4b3c2d1e0f9a8b7c6d5e
  upstream-path: grafana-promql
  upstream-imported: 2026-05-07
---
```

| Key | Type | Notes |
|---|---|---|
| `upstream-id` | string | Must match a `sources[].id` in `upstream/sources.yaml`. The validator's `--strict-upstream` mode errors on unknown ids. |
| `upstream-rev` | string | 40-char upstream sha the file was vendored from. The **baseline** — does not track local edits. |
| `upstream-path` | string | The `skills[].upstream` value from the manifest entry. Lets a reader find the upstream original by combining `<repo>` + `<subpath>` + this. |
| `upstream-imported` | string | ISO date (`YYYY-MM-DD`) of the import. Local edits don't update it. |

All four are strings — the existing `validate.py` rejects non-string
values inside `metadata:` for portability. Hyphenated keys match the
existing `forked-from` / `forked-from-hash` convention from
`docs/skills-spec-v3.md` §8.

## Why a baseline pointer, not a current pointer

After `import.py` runs, `upstream-rev` equals the upstream HEAD that
was vendored. Local edits will diverge the file from that baseline —
that is the entire point of vendoring with local modifications.

If we instead stored the "current upstream sha" the file matches, we'd
have to either:
- recompute it after every edit (impossible to do reliably with a
  text-level diff against an upstream sha tree), or
- keep it stuck at baseline anyway (trivially wrong and misleading).

Storing the baseline is honest: "this file started here; everything
since is a local choice."

When a cherry-pick from a later upstream commit is **deliberately**
applied (`review.py ... --confirm`), the script offers to bump the
per-skill `upstream-rev` to the picked sha. That's the only path that
moves the baseline forward.

## Validator behaviour

`scripts/validate.py` accepts the keys with no schema change because
the existing `metadata:` whitelist already permits arbitrary string
fields. Two additional advisory checks run when
`upstream/sources.yaml` exists:

1. **Unknown `upstream-id`** — warn on stderr (exit code unchanged) if
   the id isn't present in the manifest. With `--strict-upstream`,
   this becomes an error.

2. **Stale baseline** — warn if a skill's `upstream-rev` is older than
   the manifest's `reviewed-rev` for that source, which means the
   skill was vendored before the most recent reviewed commit and may
   need re-syncing. Strict mode upgrades to error.

Both checks are no-ops when `upstream/sources.yaml` is absent, so the
default `just check` keeps passing for the catalogue's locally-authored
skills.

## Round-tripping

`import.py` injects the block by re-emitting the YAML frontmatter as a
restricted-shape mapping (top-level keys only, string values, double
quotes for descriptions). The implementation reuses
`scripts/validate.py`'s `parse_frontmatter` for reading and a small
`emit_frontmatter` for writing — no PyYAML dependency.

If you need to update the block by hand (e.g. correcting a typo in
`upstream-imported`), preserve indentation and the trailing `---` line.
The validator will catch any frontmatter shape it cannot parse.

## Worked example

After `import.py grafana-skills`, the imported file looks like:

```yaml
---
name: grafana-promql
description: |
  PromQL query construction and Grafana dashboard authoring patterns. Use
  when building or editing Grafana dashboards, debugging slow PromQL
  queries, or refactoring rate/histogram_quantile/by-clause usage.
metadata:
  upstream-id: grafana-skills
  upstream-rev: 4f3c2e1a0b9d8c7e6f5a4b3c2d1e0f9a8b7c6d5e
  upstream-path: grafana-promql
  upstream-imported: 2026-05-07
---

# PromQL & Grafana dashboards

...
```

A subsequent local edit fixes a typo in line 50 of the body. After
that edit:

- `git log -- skills/observability/grafana-promql/` shows the local
  commit. That's the local-edit history.
- `metadata.upstream-rev` still says `4f3c2e1a...` — the file's
  baseline. Unchanged.
- `upstream/sources.yaml`'s `reviewed-rev` for `grafana-skills` may
  have advanced past `4f3c2e1a` after later reviews. The validator's
  advisory check will flag this skill as having a stale baseline,
  signalling that backporting upstream work into it is a separate
  decision.
