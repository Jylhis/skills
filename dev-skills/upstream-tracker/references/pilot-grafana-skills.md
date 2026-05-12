# Pilot: vendoring `grafana/skills`

Worked example for the first adoption. Concrete enough to copy-paste,
but the same flow applies to any other upstream. Treat this as the
test fixture for a future eval.

## Why this source

- Single namespace (`grafana`) — no ambiguity.
- Single `subpath` (`skills/`) at upstream root — no nested layouts.
- Permissive license (AGPL-3.0 — recorded for audit; not a problem for a
  catalogue link of skill markdown).
- Fills an empty `skills/observability/` slot in this catalogue, so no
  collisions and a clear category.
- Reasonable size (a handful of skills) — small enough to review
  end-to-end manually as a sanity check on the helper scripts.

## Step 1 — manifest entry

Edit `upstream/sources.yaml` to add (or, for a brand-new manifest,
create the file with):

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
      - upstream: grafana-observability
        local: observability/grafana-observability
      - upstream: grafana-promql
        local: observability/grafana-promql
```

The `skills[]` list above is illustrative — confirm the actual
upstream subdirectory names by browsing the repo or reading
`docs/upstream-sources.md` for the historical bundle layout.

## Step 2 — import

```bash
python3 dev-skills/upstream-tracker/scripts/import.py grafana-skills
```

The script:

1. Creates `.cache/upstream/grafana-skills.git` as a bare partial
   clone if it doesn't exist; runs `git fetch` if it does.
2. Resolves `origin/main` to a sha — call it `4f3c2e1a...`.
3. For each `skills[]` entry:
   - Reads `<cache>/skills/grafana-promql/SKILL.md` at the resolved
     sha (and the `references/`, `scripts/`, `assets/` subdirs if
     present).
   - Writes them to `skills/observability/grafana-promql/`.
   - Re-emits the imported `SKILL.md` frontmatter with a fresh
     `metadata.upstream-*` block:
     ```yaml
     metadata:
       upstream-id: grafana-skills
       upstream-rev: 4f3c2e1a...
       upstream-path: grafana-promql
       upstream-imported: 2026-05-07
     ```
4. Sets the manifest's `upstream-rev` and `reviewed-rev` to
   `4f3c2e1a...`, fills `last-fetched`.
5. Appends one `accept` row per imported sha to
   `upstream/decisions/grafana-skills.log`.
6. Re-runs `python3 scripts/validate.py` — exit 0 expected.
7. Prints the lines to add to `.claude-plugin/plugin.json`:
   ```
   "./skills/observability/grafana-observability",
   "./skills/observability/grafana-promql",
   ```

## Step 3 — register and verify

Add the printed lines to the `skills` array in
`.claude-plugin/plugin.json` (alphabetical inside the new
`observability/` block — alphabetical between `nix/` and `python/` in
the existing list).

Then:

```bash
just check
```

Expect: `markdownlint`, `shellcheck`, and `validate.py` all clean.

## Step 4 — commit

```bash
git add upstream/sources.yaml \
        upstream/decisions/grafana-skills.log \
        skills/observability/ \
        .claude-plugin/plugin.json
git commit -m "Vendor grafana-skills @ <short-sha>"
```

One commit per source keeps `git log -- upstream/` and
`git log -- skills/observability/` readable for future audits.

## Step 5 — first sync (optional, demonstrates §3)

A week later:

```bash
python3 dev-skills/upstream-tracker/scripts/fetch.py
```

Sample output if upstream has had 3 commits touching `skills/`:

```markdown
# Upstream pending review

## grafana-skills (3 pending)

last-fetched: 2026-05-14T10:23:11Z
reviewed-rev: 4f3c2e1a
upstream-rev: 9b8a7c6d

- 9b8a7c6d · alice@grafana · 2026-05-13 · "Improve PromQL examples in grafana-promql"
  - skills/grafana-promql/SKILL.md
- 5a4b3c2d · bob@grafana   · 2026-05-12 · "Add new alerting playbook"
  - skills/grafana-alerting/SKILL.md
- 1f2e3d4c · alice@grafana · 2026-05-11 · "Fix typo in grafana-observability"
  - skills/grafana-observability/SKILL.md

# (other sources omitted)
```

The middle commit touches a new upstream skill (`grafana-alerting`) we
haven't imported. That's fine — `review.py skip` is the correct
decision for it (we'll re-adopt with a manifest update if/when we want
that skill).

## Step 6 — review (demonstrates §4)

```bash
python3 dev-skills/upstream-tracker/scripts/review.py grafana-skills
```

The script walks the pending list oldest-first. For each commit it
prints metadata + path-filtered diff and prompts:

```
[a]ccept / [s]kip / [d]efer / [c]herry-pick / [q]uit >
```

For `1f2e3d4c` (typo fix) — it touches a skill we have, but the typo
isn't in our local copy after our import-time edits. Either `accept`
(no-op for us) or `cherry-pick` (apply just to be sure). Pick `accept`.

For `5a4b3c2d` (new alerting playbook) — we don't carry it. Pick `skip`.

For `9b8a7c6d` (improved examples) — we want it. Pick `cherry-pick`.
The script applies the patch to the working tree:

```
git apply -p2 --directory=skills/observability/grafana-promql \
    /tmp/upstream-tracker-9b8a7c6d.patch
```

Review the working-tree diff, edit if needed, then commit:

```bash
git add skills/observability/grafana-promql/
git commit -m "Backport grafana-skills@9b8a7c6d: improve PromQL examples"
```

Confirm the cherry-pick to advance the cursor:

```bash
python3 dev-skills/upstream-tracker/scripts/review.py grafana-skills \
    --confirm 9b8a7c6d <local-commit-sha>
```

After confirm, the decision log row becomes
`9b8a7c6d\tcherry-picked:<local-sha>\t...`, the cursor advances past
all three commits, and `fetch.py` reports zero pending.
