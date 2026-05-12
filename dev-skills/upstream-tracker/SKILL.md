---
name: upstream-tracker
description: >
  Track external upstream skill repositories: import a skill from upstream
  into this catalogue, modify it locally without losing the baseline,
  monitor the upstream for new commits since the last review, and review
  each upstream commit one-by-one to accept, skip, defer, or cherry-pick
  it into the local copy. Use when the user says "import skill from
  <repo>", "vendor <repo>", "monitor upstream for new commits", "what's
  changed upstream", "check upstream for updates", "review upstream
  commit", "backport <sha>", or "follow <repo> for new skills". Operates
  on `upstream/sources.yaml` (manifest), `upstream/decisions/<id>.log`
  (per-source review cursor), and `.cache/upstream/<id>.git` (local bare
  partial clone). Helper scripts under this skill's `scripts/` do the
  deterministic git work; the agent following this SKILL.md drives the
  decisions.
---

# Upstream skill tracker

Vendor and follow upstream skill repositories with a clear baseline,
local edits, a review queue for new commits, and durable per-commit
decisions. Use this skill whenever the task involves bringing skill
content from another repo into `skills/<category>/<name>/` — or keeping
already-vendored content in sync.

This is a meta-skill. Its body documents the workflow; its scripts are
deterministic helpers; its references hold long-form documentation
(manifest schema, frontmatter shape, pilot example).

## When to invoke

Match the request to one of four operations:

| Request shape | Operation |
|---|---|
| "Import / vendor / pull in skill X from `<repo>`" | §1 Adopt a new upstream |
| "I'm editing this imported skill" | §2 Local modifications |
| "What's changed upstream?" / "Any new upstream commits?" | §3 Monitor for new commits |
| "Review upstream commit `<sha>`" / "Backport `<sha>`" | §4 Review a single commit |

If the user is registering a brand-new local skill not from any upstream,
this is **not** the right skill — point at `dev-skills/skill-creator-lang`
instead.

## Tool detection

```bash
for tool in git python3 jq; do
  command -v "$tool" >/dev/null && echo "ok: $tool" || echo "MISSING: $tool"
done
```

`jq` is optional (only used to format JSON output). `git` and `python3`
are required.

## State files

This skill operates on three repo-root paths. None of them ships
populated; they are created when the user adopts the first upstream.

- `upstream/sources.yaml` — manifest. Authoritative for source state.
  See `references/manifest-schema.md` for the field reference.
- `upstream/decisions/<id>.log` — append-only TSV. One row per reviewed
  upstream commit. Format: `<sha>\t<decision>\t<iso-date>\t<note>`,
  where `decision ∈ {accept, skip, defer, cherry-picked:<local-sha>}`.
- `.cache/upstream/<id>.git` — bare partial clone (`--filter=blob:none`).
  Gitignored. Recreated on demand by `scripts/fetch.py`.

The per-skill `metadata.upstream-*` block in vendored `SKILL.md` files
is **advisory** (self-describing attribution). The manifest is the source
of truth for tooling. See `references/frontmatter-block.md`.

## §1 — Adopt a new upstream

Use when the user wants to vendor one or more skills from a not-yet-tracked
repo, or to add more skills from an already-tracked repo.

Procedure:

1. **Confirm the source.** Get the user to provide:
   - upstream URL (e.g. `https://github.com/grafana/skills`)
   - branch (default `main`)
   - subpath inside the repo where skills live (e.g. `skills/`)
   - the upstream-relative paths of each skill to import
   - the local destination path inside `skills/<category>/<name>/`
   - the upstream's license (so it can be recorded; not validated)

2. **Pick or confirm the source `id`.** Lowercase, hyphenated, unique
   within the manifest. Often `<org>-<repo>` (e.g. `grafana-skills`).

3. **Edit `upstream/sources.yaml`.** Add a new `sources[]` entry per
   `references/manifest-schema.md`. Set `upstream-rev` to the empty
   string and `reviewed-rev` to the empty string — the import script
   fills both. Save.

4. **Run the import:**
   ```bash
   python3 dev-skills/upstream-tracker/scripts/import.py <id>
   ```
   The script:
   - Ensures the bare partial clone under `.cache/upstream/<id>.git`.
   - Resolves the upstream HEAD sha for `branch`.
   - Copies each `skills[]` entry's `<subpath>/<upstream>` directory
     into `skills/<local>/`.
   - Injects `metadata.upstream-id / upstream-rev / upstream-path /
     upstream-imported` into each imported `SKILL.md`.
   - Sets manifest `upstream-rev` and `reviewed-rev` to the resolved sha.
   - Appends an `accept` row to `upstream/decisions/<id>.log` for the
     resolved sha.
   - Refuses to overwrite an existing local skill without `--force`.
   - Re-runs `scripts/validate.py` afterwards.

5. **Register imported paths.** Add each `skills/<local>/` to the
   `skills` array in `.claude-plugin/plugin.json` (alphabetical inside
   the category). The import script prints the exact lines to paste.

6. **Verify.** From the repo root:
   ```bash
   just check
   ```
   Investigate any failures before committing.

7. **Commit** the manifest entry, the decision log line, the imported
   skill directories, and the `plugin.json` update together. One commit
   per adoption keeps `git log` readable.

## §2 — Local modifications

Use when editing an already-vendored skill.

Rules:

1. **Edit freely.** Treat the imported `SKILL.md` as repo-owned content;
   refactor, reword, fix bugs.

2. **Do not touch `metadata.upstream-rev`.** It records the upstream sha
   the file was vendored from — the **baseline**, not the current state.
   Local edits drift from this baseline by design; that's the whole
   point. The validator only flags drift if the manifest has reviewed
   *past* the baseline.

3. **Do not touch the decision log.** Local edits are recorded in
   `git log -- skills/<path>/`, which already gives full provenance.

4. **If the local edit is a backport from an upstream commit not yet
   reviewed**, switch to §4 first — drive the change through the review
   loop so the cursor advances.

## §3 — Monitor for new commits

Use when the user wants to see what has changed upstream since the last
review (e.g. "what's pending", "any new commits to backport").

Procedure:

1. **Run the fetch helper:**
   ```bash
   python3 dev-skills/upstream-tracker/scripts/fetch.py
   ```
   For each source in the manifest, this script:
   - Ensures the bare partial clone under `.cache/upstream/<id>.git`.
   - Runs `git fetch origin <branch>`.
   - Computes commits in `reviewed-rev..origin/<branch>` whose
     `--name-only` output intersects the source's `subpath`.
   - Updates the manifest's `upstream-rev` (HEAD now seen) and
     `last-fetched`. Does **not** touch `reviewed-rev`.
   - Prints a Markdown report grouped by source.

2. **Read the report.** Per-source sections list pending commits with
   `sha · author · date · subject · paths-touched-within-subpath`. An
   empty section is the steady state (no review needed).

3. **Decide what to review.** Tell the user what's pending and ask which
   commits (if any) to review now. Default to oldest-first to keep
   `reviewed-rev` advancing monotonically.

The fetch script is idempotent: re-running shows the same pending list
until commits are decided in §4.

## §4 — Review a single commit

Use when the user names a specific upstream commit, or when §3 surfaced
a pending list and the user wants to walk through it.

Procedure:

1. **Run the review helper:**
   ```bash
   python3 dev-skills/upstream-tracker/scripts/review.py <id> [--sha <sha>]
   ```
   With no `--sha`, it walks the pending list oldest-first. With
   `--sha`, it operates on just that commit.

2. **For each commit, the script prints:**
   - Commit metadata (author, date, subject, body).
   - `git show <sha> -- <subpath>` — the diff restricted to the source's
     `subpath` so cross-cutting upstream changes don't drown the signal.
   - The current `reviewed-rev` and the cursor position.

3. **Choose a decision:**
   - **`accept`** — the commit's effect is already absorbed (or trivial).
     Append `accept` to the decision log; advance the cursor.
   - **`skip`** — the commit doesn't apply to this fork (e.g. upstream
     scaffolding, removed tests we don't carry). Append `skip`; advance
     the cursor.
   - **`defer`** — needs more thought; not deciding now. Append `defer`;
     **do not** advance the cursor. The commit will reappear in §3.
   - **`cherry-pick`** — the change should land locally. The script
     extracts the patch with `git -C cache show <sha> -- <subpath>` and
     applies it to the working tree via `git apply -p<n>
     --directory=skills/<local>/`. The user reviews the working-tree
     diff, edits as needed, and commits separately. The decision log
     records `cherry-picked:<pending>`; once the user runs:
     ```bash
     python3 dev-skills/upstream-tracker/scripts/review.py <id> \
         --confirm <upstream-sha> <local-sha>
     ```
     the row is finalized to `cherry-picked:<local-sha>` and the
     cursor advances.

4. **Cursor advance rule.** After every decision write, the script
   walks the decision log forward from the current `reviewed-rev` and
   advances through **contiguous** rows whose decision is one of
   `accept`, `skip`, or finalized `cherry-picked:<sha>`. A `defer` row
   blocks advance — fix it (re-review with a different decision) or
   live with the cursor stalled until the user resumes.

5. **Bump per-skill metadata when needed.** Cherry-picking new content
   into a vendored skill should also bump that skill's
   `metadata.upstream-rev` to the picked sha (the script offers to do
   this when the cherry-pick is confirmed). For `accept` / `skip` the
   per-skill metadata stays at its baseline — those decisions don't
   change local content.

## Common operations

### "Adopt grafana-skills as the pilot"

See `references/pilot-grafana-skills.md` for the worked example.

### "Retire a source"

Remove the `sources[]` entry from `upstream/sources.yaml`. The decision
log under `upstream/decisions/<id>.log` stays as historical record.
`.cache/upstream/<id>.git` is local-only and can be deleted at will.
Imported skills remain in `skills/`; their `metadata.upstream-id` will
trigger advisory warnings from `validate.py --strict-upstream`, which
is the intended signal that the source is no longer tracked.

### "Multiple upstreams ship the same skill name"

The manifest `local` paths must be unique across all sources — that's
the only enforcement. Pick distinct local names if the upstreams collide.

## Footguns

- **Don't `git fetch` upstream from outside the helper.** The script
  uses a bare partial clone; manual fetches into the user's main
  worktree pollute it.
- **Don't edit `metadata.upstream-rev` manually after import.** It's
  the baseline pointer; tooling assumes it matches a real upstream sha.
- **Don't `--force` import unless the local skill was originally vendored
  from the same source and you want to overwrite local edits.** Use the
  cherry-pick flow (§4) for incremental upstream changes.
- **`defer` is sticky.** A deferred commit blocks the cursor until
  re-decided — that's the design, not a bug. If many commits pile up
  behind a defer, re-review the defer first.

## References

- `references/manifest-schema.md` — `upstream/sources.yaml` field reference.
- `references/frontmatter-block.md` — `metadata.upstream-*` shape and
  validator behaviour.
- `references/pilot-grafana-skills.md` — worked example: vendoring
  `github:grafana/skills`.
