> **Archived 2026-05-05.** This roadmap targeted the v2 bundled-sources
> architecture, which has since been removed. Kept for historical
> reference only.

# Skills catalog roadmap

Living roadmap for reviewing, validating, organizing, and maintaining the skill
catalog. Supersedes the previous import-tracking TODO (resolved 2026-05-04 — the
11 listed upstreams are now pinned in `flake.nix`, re-exported from
`_sources.nix`, and registered in `bundled-sources.nix`; original table preserved
in [Appendix A](#appendix-a-resolved-import-history)).

## Why this exists

`bundled-sources.nix` (437 lines) wires ~50 source entries spanning Anthropic,
OpenAI, Microsoft, Cloudflare, HashiCorp, Trail of Bits (×38 plugins across two
upstreams), addyosmani, MiniMax, Leon×lnx, Orchestra-Research, github, grafana,
mattpocock, plus the 11 from the original TODO and 64 locally maintained skills
under `skills/`. Total catalog is several hundred skills, with no automated
quality gates beyond markdown formatting and a security scanner that runs only
against its own unit tests. This roadmap closes those gaps in four phases.

Gaps to close:

- No automated skill validation beyond `markdownlint-cli2` formatting.
- `scripts/scan_bundled_source.py` is wired only to `tests/test_scan_bundled_source.py`,
  never run against bundled trees in CI.
- No frontmatter schema check (name matches dir basename, description size
  bounds, required fields, no duplicates).
- No license/provenance audit trail. Upstream `LICENSE` files are not preserved
  alongside imports.
- No deduplication detection. `gh-cli`, `mcp-builder`, `security-best-practices`,
  `skill-creator` exist via multiple sources.
- `lib/default-skills.nix` is hand-maintained — drifts from disk.
- Documentation drift: `README.md` describes a `plugins/` layout that no longer
  exists; `docs/skill-groups/*.mdx` covers 6 of 14 declared groups.

---

## Phase 1 — Inventory and validation infrastructure

Goal: know what we have and prove every skill is shippable.

### 1.1 Generate full skill inventory as a checked-in artifact

- New: `scripts/build_skill_index.py` (or Nix derivation reusing
  `lib/list-catalog.nix`) producing `docs/skill-index.json` with one row per
  skill: `{id, name, namespace, source, upstream_url, license, path,
  description_len, frontmatter_ok, last_seen_rev}`.
- Wire as `devenv test` #16; fail if the index can't be regenerated cleanly.
- Replaces the need to manually grep across the catalog.

### 1.2 Frontmatter schema validation

- New: `scripts/validate_skill_frontmatter.py` — Python, mirroring style of
  `scripts/scan_bundled_source.py`.
- Per `SKILL.md`:
  - `name` present and matches dir basename.
  - `description` present, length 50–1024 chars.
  - No unknown top-level keys outside allow-list (`name`, `description`,
    `license`, `tools`, `allowed-tools`, `domain`, `role`).
  - UTF-8, no BOM, LF line endings.
- Run across local `skills/` and every resolved bundled-source path.
- Wire as `devenv test` #17. Existing failures captured in
  `docs/skill-quarantine.md` until fixed.

### 1.3 Wire `scan_bundled_source.py` into CI for real

- Currently only unit tests run via `devenv test` #14.
- Commit the in-flight uncommitted edits to `scripts/scan_bundled_source.py`
  and the untracked `tests/test_scan_bundled_source.py` first.
- New `just scan-bundled` target: walk every `inputs.<name>` resolved via
  `_sources.nix`, run the scanner with `--format json`.
- WARN findings → `docs/scan-warnings.md`. BLOCK findings → CI failure.

### 1.4 Deduplication detection

- Script identifies skills sharing a `name` across namespaces, writes
  `docs/skill-duplicates.md`.
- Resolution per duplicate (recorded in TODO):
  1. Suppress via `exclude` in `bundled-sources.nix`.
  2. Merge into a locally-maintained skill (pattern: `skills/skill-creator`).
  3. Accept as namespaced (`composio:gh-cli` vs `github:gh-cli`).

### 1.5 License and provenance index

- New: `docs/skill-provenance.md` — generated table, one row per source with
  license, upstream URL, locked rev, last-validated date.
- Validation rule: every source key in `bundled-sources.nix` must appear here.

---

## Phase 2 — Quality review of every skill

Goal: every skill is fit for purpose, or removed.

Process is per-source, per-skill. Tracked as a checklist (see below) with
columns: source, skill, frontmatter, scanner, license, dedup, manual-review,
notes.

Definition of done varies by source class:

- **Local skills** (64 under `skills/`): one-pass review of frontmatter clarity
  and content length. Goal: no `SKILL.md` exceeds 8 KB; longer content moves to
  `references/` per the skill-creator guidance.
- **Domain-critical bundled sources** (Anthropic, OpenAI, Microsoft, Cloudflare,
  HashiCorp, Trail of Bits, grafana): review every skill, exclude any that
  fails scanner / duplicate / quality gates.
- **Awesome-list sources** (composio, prat011, addyosmani, cc-toolkit, vibe,
  tech-leads-club, github-awesome-copilot): treat as candidate pool. Explicit
  `paths`/`include` only. Default-deny rather than default-include.
- **Language packs** (superpowers-zh): out-of-scope without a reviewer with
  appropriate language fluency. Mark as `quarantined-pending-reviewer`.

For each excluded skill, record reason in `docs/skill-exclusions.md` so future
upstream syncs don't silently re-include it.

### Source review checklist

| Source | Skills | Frontmatter | Scanner | License | Dedup | Manual review | Notes |
|---|--:|:--:|:--:|:--:|:--:|:--:|---|
| Local `skills/` | 64 | ☐ | ☐ | ☐ | ☐ | ☐ | Add `domain`/`role` to all |
| `cc-skills-golang` | 35 | ☐ | ☐ | ☐ | ☐ | ☐ | MIT, samber |
| `obsidian-skills` | 5 | ☐ | ☐ | ☐ | ☐ | ☐ | kepano |
| `rust-skills` | ~30 | ☐ | ☐ | ☐ | ☐ | ☐ | actionbook |
| `claude-plugins-official` | 1 + 10 agents | ☐ | ☐ | ☐ | ☐ | ☐ | Anthropic |
| `hashicorp-agent-skills` | 4 | ☐ | ☐ | ☐ | ☐ | ☐ | Terraform |
| `openai-skills` | 7 | ☐ | ☐ | ☐ | ☐ | ☐ | curated picks |
| `microsoft-skills` (ms) | 2 | ☐ | ☐ | ☐ | ☐ | ☐ | docs + cloud |
| `microsoft-azure-skills` | many | ☐ | ☐ | ☐ | ☐ | ☐ | full plugin |
| `cloudflare-skills` | 4 | ☐ | ☐ | ☐ | ☐ | ☐ | curated |
| `trailofbits-skills` ×24 | many | ☐ | ☐ | ☐ | ☐ | ☐ | review per plugin |
| `trailofbits-skills-curated` ×14 | many | ☐ | ☐ | ☐ | ☐ | ☐ | net-new only |
| `addyosmani-agent-skills` | many | ☐ | ☐ | ☐ | ☐ | ☐ | exclude `using-agent-skills` already |
| `minimax-skills` | 1 | ☐ | ☐ | ☐ | ☐ | ☐ | shader-dev |
| `taste-skill` | many | ☐ | ☐ | ☐ | ☐ | ☐ | UI design |
| `ai-research-skills` | many | ☐ | ☐ | ☐ | ☐ | ☐ | Orchestra-Research |
| `github-awesome-copilot` | 6 | ☐ | ☐ | ☐ | ☐ | ☐ | curated |
| `grafana-skills` | many | ☐ | ☐ | ☐ | ☐ | ☐ | recursive scan |
| `composio-awesome-codex-skills` | 45 | ☐ | ☐ | ☐ | ☐ | ☐ | curated picks |
| `superpowers-zh` | 20 | ☐ | ☐ | ☐ | ☐ | ☐ | needs zh reviewer |
| `prat011-awesome-llm-skills` | 31 | ☐ | ☐ | ☐ | ☐ | ☐ | awesome-list |
| `aboutsecurity` | 245 | ☐ | ☐ | ☐ | ☐ | ☐ | high volume |
| `finance-skills` | 22 | ☐ | ☐ | ☐ | ☐ | ☐ | excludes skill-creator |
| `claude-workflow-v2` | 14 | ☐ | ☐ | ☐ | ☐ | ☐ | workflow |
| `awesome-claude-code-toolkit` | 38 | ☐ | ☐ | ☐ | ☐ | ☐ | awesome-list |
| `vibe-skills` | 1 | ☐ | ☐ | ☐ | ☐ | ☐ | root only |
| `tech-leads-agent-skills` | 80 | ☐ | ☐ | ☐ | ☐ | ☐ | tlc namespace |
| `gitagent` | 1 | ☐ | ☐ | ☐ | ☐ | ☐ | gmail-email only |
| `waza` | 8 | ☐ | ☐ | ☐ | ☐ | ☐ | tw93 |
| `mattpocock-skills` | many | ☐ | ☐ | ☐ | ☐ | ☐ | with explicit excludes |

---

## Phase 3 — Organization scheme

Goal: readers and consumers find what they need without grepping the catalog.

Adopt a **two-axis taxonomy**:

- **Domain axis** (the *what*): `language/<lang>`, `infra/<area>`, `security`,
  `web`, `data-ml`, `productivity`, `editor`, `meta` (skill-about-skills),
  `ops/<topic>`. Each skill carries `domain:` in frontmatter.
- **Role axis** (the *when*): `supporting` (auto-loaded reference, e.g.
  `golang-error-handling`), `workflow` (user-invoked, e.g. `/review`,
  `/debug`), `meta` (skill-creator-style), `agent-only` (loaded by sub-agents).
  Already drafted in `README.md`. Each skill carries `role:` in frontmatter.

### 3.1 Replace `lib/default-skills.nix` with a generated attrset

- New: `lib/skill-groups.nix` derives groups from frontmatter `domain`/`role`
  tags from the `docs/skill-index.json` produced in Phase 1.1.
- Backwards-compatible: `lib.defaultSkills.nix`, `.golang`, etc. continue to
  expose the same group keys.
- `devenv test` #11 (currently at `devenv.nix:234`) gains a check that every
  local skill on disk has both `domain` and `role` set.

### 3.2 Update `docs/skill-groups/*.mdx` exhaustively

- One file per *role* (`workflow.mdx`, `supporting.mdx`, `meta.mdx`,
  `agent-only.mdx`) with skills grouped by `domain` inside each.
- Generated from `docs/skill-index.json`, not hand-edited.

### 3.3 Frontmatter migration

- Add `domain` + `role` to all 64 local `SKILL.md` files. Mostly mechanical;
  ambiguous cases reviewed individually.
- For bundled skills, supply `domain`/`role` via overrides in
  `bundled-sources.nix` (new optional fields per source) since we cannot edit
  upstream files.

---

## Phase 4 — Codebase restructure for maintainability

Goal: keep the 437-line `bundled-sources.nix` and growing skill set sustainable.

### 4.1 Split `bundled-sources.nix` by category

Move to a `bundled/` directory:

- `bundled/anthropic.nix` — Anthropic, OpenAI, Microsoft official sources
- `bundled/cloud.nix` — Cloudflare, HashiCorp, grafana, Microsoft Azure
- `bundled/security.nix` — Trail of Bits ×38 plugins (with `tobPlugin`/`tobcPlugin` helpers)
- `bundled/general.nix` — addyosmani, mattpocock, tech-leads-club
- `bundled/awesome-lists.nix` — composio, prat011, cc-toolkit, vibe, github-awesome-copilot
- `bundled/domain.nix` — finance, gitagent, claude-workflow-v2, aboutsecurity, ai-research, minimax, taste, waza
- `bundled/language-packs.nix` — superpowers-zh

Each per-category file under 150 lines. `tobPlugin`/`tobcPlugin` helpers move
to `lib/bundled-helpers.nix`. `bundled/default.nix` re-exports the merged
attrset. Root `bundled-sources.nix` becomes a one-liner re-export for
back-compat.

### 4.2 Eliminate single-source-of-truth drift

- `lib/default-skills.nix` becomes generated from `docs/skill-index.json`
  (per Phase 3.1).
- Add a `devenv test` assertion: every flake input prefix in `flake.nix` is
  referenced by exactly one `bundled/*.nix` entry.

### 4.3 Split the test driver

- `devenv.nix:141` currently inlines all 15 tests in a 130-line bash heredoc.
- Move each test to `tests/devenv/<n>-<name>.sh`. `enterTest` sources them.
- Easier to add tests #16/#17 from Phase 1.

### 4.4 Documentation cleanup

- Delete or rewrite the stale `plugins/` description in `README.md` (the
  `plugins/` directory no longer exists; current layout is flat `skills/`).
- Reconcile `PLAN.md` (jstack v2 design doc) with the as-built state, or
  archive to `docs/history/`.
- `CLAUDE.md` already in good shape — no change.

### 4.5 Repo top-level relocations

- `evals/` — appears scaffolded but mostly empty. Either populate with real
  evals (preferred) or move to `docs/history/` until ready.
- `templates/RESTORE.md` — clarify intent or remove.
- `research/` — keep as-is (referenced from `PLAN.md`).

---

## Execution order and dependencies

```
Phase 1.1  →  Phase 1.2  →  Phase 1.4  →  Phase 1.5
                ↓                ↓
              Phase 1.3       Phase 2 (per-source review)
                                 ↓
                            Phase 3.3 (frontmatter migration)
                                 ↓
                            Phase 3.1 → Phase 3.2
                                 ↓
                            Phase 4.1 → 4.2 → 4.3 → 4.4 → 4.5
```

Phase 1 unblocks everything else. Phase 2 can run in parallel with Phase 3 once
1.1+1.2 land. Phase 4 restructure happens last so the inventory is stable.

---

## Reusable infrastructure already in place

- `lib/discover.nix` — recursive `SKILL.md` scanner.
- `lib/list-catalog.nix` — merges local + bundled into one attrset.
- `scripts/scan_bundled_source.py` — security scanner ready to wire in.
- `tests/test_scan_bundled_source.py` — 8 unit tests.
- `devenv.nix` enterTest framework (15 tests) — extend rather than rewrite.
- `docs/skill-source-governance.md` — gate criteria already documented;
  Phase 1 enforces them programmatically.

---

## Verification at completion

- `devenv test` passes 17+ tests including the new index, frontmatter,
  and bundled-scanner checks.
- `nix build .#options-doc` succeeds.
- `docs/skill-index.json`, `docs/skill-provenance.md`, `docs/skill-duplicates.md`,
  `docs/skill-quarantine.md`, `docs/skill-exclusions.md` regenerate
  deterministically.
- `bundled-sources.nix` re-exports the merged tree from `bundled/*.nix`.
- `lib/default-skills.nix` is regenerated from disk metadata.
- Every local `SKILL.md` carries `domain` + `role` frontmatter.
- Every bundled source has license + provenance recorded.

---

## Appendix A: Resolved import history

Resolved on 2026-05-04. All listed upstreams pinned as non-flake inputs in
`flake.nix`, re-exported from `_sources.nix`, and registered in
`bundled-sources.nix`.

Gate markers: `license`, `provenance`, `layout`, `pinning`, `security`, `metadata`.

| Source | Category | Namespace | Imported skills | Gate status | Notes |
|---|---|---|--:|---|---|
| [ComposioHQ/awesome-codex-skills](https://github.com/ComposioHQ/awesome-codex-skills) | awesome-list | `composio` | 45 | license, provenance, layout, pinning, security, metadata | Curated top-level skills only. Excluded generated `composio-skills/` marketplace tree. |
| [jnMetaCode/superpowers-zh](https://github.com/jnMetaCode/superpowers-zh) | language pack | `superpowers-zh` | 20 | license, provenance, layout, pinning, security, metadata | Chinese-language skill pack under `skills/`. |
| [Prat011/awesome-llm-skills](https://github.com/Prat011/awesome-llm-skills) | awesome-list | `prat011` | 31 | license, provenance, layout, pinning, security, metadata | Verified in-repo `SKILL.md` directories, not only links. |
| [wgpsec/AboutSecurity](https://github.com/wgpsec/AboutSecurity) | domain-specific (security) | `aboutsecurity` | 245 | license, provenance, layout, pinning, security, metadata | Imported `skills/` only. Excluded `Dic/`, `Payload/`, `Vuln/`. |
| [himself65/finance-skills](https://github.com/himself65/finance-skills) | domain-specific (finance) | `finance` | 22 | license, provenance, layout, pinning, security, metadata | Imported plugin skills under `plugins/`; excluded duplicate `skill-creator`. |
| [CloudAI-X/claude-workflow-v2](https://github.com/CloudAI-X/claude-workflow-v2) | domain-specific (workflow) | `workflow` | 14 | license, provenance, layout, pinning, security, metadata | Imported skills only; agents/commands left out. |
| [rohitg00/awesome-claude-code-toolkit](https://github.com/rohitg00/awesome-claude-code-toolkit) | awesome-list | `cc-toolkit` | 38 | license, provenance, layout, pinning, security, metadata | Imported curated `skills/` tree. |
| [foryourhealth111-pixel/Vibe-Skills](https://github.com/foryourhealth111-pixel/Vibe-Skills) | general skills | `vibe` | 1 | license, provenance, layout, pinning, security, metadata | Root orchestration skill only. |
| [tech-leads-club/agent-skills](https://github.com/tech-leads-club/agent-skills) | general skills | `tlc` | 80 | license, provenance, layout, pinning, security, metadata | Imported `packages/skills-catalog/skills`. |
| [open-gitagent/gitagent](https://github.com/open-gitagent/gitagent) | domain-specific (git) | `gitagent` | 1 | license, provenance, layout, pinning, security, metadata | Imported concrete `gmail-email`; excluded `example-skill`. |
| [tw93/Waza](https://github.com/tw93/Waza) | general skills | `waza` | 8 | license, provenance, layout, pinning, security, metadata | Imported `skills/` tree. |
