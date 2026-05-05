# skill-creator (merged)

This `skill-creator` skill is a merged, opinionated distillation of four
upstream skill-creator skills maintained by different vendors. It is
regenerated periodically from the upstream sources; the `SKILL.md` in
this folder is the agent-facing output.

This README is for humans browsing the repository — it is **not** loaded
by the agent at skill-trigger time.

## Upstream sources

| Upstream | URL |
|---|---|
| `anthropics/skills` | <https://github.com/anthropics/skills/blob/main/skills/skill-creator/SKILL.md> |
| `anthropics/claude-plugins-official` | <https://github.com/anthropics/claude-plugins-official/blob/main/plugins/skill-creator/skills/skill-creator/SKILL.md> |
| `openai/skills` | <https://github.com/openai/skills/blob/main/skills/.system/skill-creator/SKILL.md> |
| `microsoft/skills` | <https://github.com/microsoft/skills/blob/main/.github/skills/skill-creator/SKILL.md> |

Verify each upstream's license before redistributing.

## What each upstream contributed

- **`anthropics/skills`** (canonical base) — the full evaluation loop:
  drafting test cases, spawning with-skill + baseline subagents in the
  same turn, grading, aggregation, the eval viewer, feedback.json
  handling, iteration between `iteration-<N>/` workspaces, blind
  comparison, the description-optimization `run_loop.py`, and the
  Claude.ai / Cowork harness-specific notes. Also the "pushy
  descriptions," theory-of-mind writing style, and the guidance to
  bundle repeatedly-rewritten code into `scripts/`.
- **`anthropics/claude-plugins-official`** — near-identical to
  `anthropics/skills`. Minor wording refinements pulled in where they
  were strictly better.
- **`openai/skills`** — the **Degrees of Freedom** framework
  (high/medium/low), strict naming rules (lowercase-hyphen, <64 chars,
  verb-led, namespace-by-tool), the explicit "don't include README.md /
  CHANGELOG.md / QUICK_REFERENCE.md" list, `init_skill.py` /
  `quick_validate.py` tooling references, and the avoid-duplication
  principle.
- **`microsoft/skills`** — the **Fresh Documentation First** principle
  (verify current docs before coding — generalized here from its
  Azure-specific phrasing), the degrees-of-freedom and anti-patterns
  presented as **tables**, the pre-flight checklist, and the
  scenario-based test pattern with `expected_patterns` /
  `forbidden_patterns` / `mock_response`.

## What was dropped

- Vendor-specific branding (Codex, Azure Foundry, `DefaultAzureCredential`).
- Symlink-based skill categorization (Microsoft-specific deployment).
- Microsoft-specific README-catalog updates and Astro docs-site rebuild steps.
- UI-metadata (`agents/openai.yaml`) details unless a harness needs it.

## Last refreshed

**2026-04-20**

To refresh: re-fetch the four upstream `SKILL.md` files, diff against
the versions used at last refresh, merge net-new guidance into
`SKILL.md`, and update this date. Keep the merged skill under ~600
lines; push deep material into `references/` rather than growing
SKILL.md.
