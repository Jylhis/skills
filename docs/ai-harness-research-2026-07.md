# AI Harness Best Practices for Claude Code: Research Report and Gap Analysis

Date: 2026-07-11. Status: research deliverable, no code changes applied.

Scope: (1) CLAUDE.md / AGENTS.md memory-file design, (2) skills and plugins
architecture, (3) hooks, settings and permissions, (4) subagents, slash
commands, MCP curation, LSP integration and orchestration. Targets: Claude
Code (CLI and web) primarily, with Pi (`pi-coding-agent`) portability.

Method: a fan-out deep-research pipeline (5 search angles, 21 sources
fetched, 105 candidate claims extracted, 25 adversarially verified with
3-vote refutation panels: 24 confirmed unanimously, 1 refuted) merged with
a full local audit of this repository (memory files, all 65 SKILL.md files
(60 published under `skills/` plus 5 repo-only under `meta/`), 16 plugin
manifests, agents, commands, validation, CI, evals, upstream tracking).
Line counts throughout are `wc -l`.

## Part 1: Verified best practices

### 1. Memory files (CLAUDE.md / AGENTS.md)

All findings in this section confirmed 3-0 against primary sources
([memory docs](https://code.claude.com/docs/en/memory),
[best practices](https://code.claude.com/docs/en/best-practices),
[context engineering blog](https://www.anthropic.com/engineering/effective-context-engineering-for-ai-agents)).

- **Target under 200 lines of always-loaded context.** The docs are
  explicit: "target under 200 lines per CLAUDE.md file. Longer files
  consume more context and reduce adherence" and "Bloated CLAUDE.md files
  cause Claude to ignore your actual instructions!" The framing is the
  minimal set of information that fully specifies expected behavior,
  organized into distinct sections.
- **The `@AGENTS.md` import shim is the officially sanctioned pattern.**
  Claude Code reads CLAUDE.md, not AGENTS.md; the documented approach is a
  CLAUDE.md that imports AGENTS.md and appends Claude-specific
  instructions. This repo's CLAUDE.md is structurally identical to the
  docs' own example.
- **Imports organize but do not save context.** `@path` imports (max four
  hops) are expanded at launch. Splitting content across imported files
  changes nothing about the token footprint. Only moving content into
  skills or path-scoped rules actually reduces the always-loaded cost.
- **The decision rule for what stays always-loaded:** facts needed in
  every session (build commands, conventions, layout, always-do-X rules)
  stay; multi-step procedures or content relevant to only part of the
  codebase move to a skill or a path-scoped rule, because skill bodies
  load only when used.
- **Memory files are context, not enforcement.** CLAUDE.md content is
  advisory. Anything that must happen deterministically (blocking an
  action, running a check before every commit) belongs in a lifecycle
  hook: PreToolUse to block a tool call, Stop to gate turn completion
  (overridden after 8 consecutive blocks).

### 2. Skills and plugins

Confirmed 3-0 against
[skills docs](https://code.claude.com/docs/en/skills),
[platform Agent Skills overview](https://platform.claude.com/docs/en/agents-and-tools/agent-skills/overview),
and the
[Agent Skills engineering blog](https://www.anthropic.com/engineering/equipping-agents-for-the-real-world-with-agent-skills).

- **Three-level progressive disclosure with concrete budgets.** Level 1:
  name + description, always preloaded, roughly 100 tokens per skill.
  Level 2: SKILL.md body, loaded when triggered, target under 5k tokens.
  Level 3+: bundled references, effectively unlimited because they load
  only as needed. This on-demand economics is the stated reason skills
  beat inline or always-loaded prompts.
- **Size and format limits.** Keep SKILL.md under 500 lines and split
  reference material into supporting files. Frontmatter `name` max 64
  chars; `description` non-empty, max 1,024 chars, no XML tags. The
  combined skill-listing text is truncated at 1,536 chars (configurable
  via `skillListingMaxDescChars`).
- **The description is the trigger surface.** It must convey both what
  the skill does and when to use it, because it is all the model sees
  before deciding to load the body. Front-load the "when to use" signal.
- **Eval-driven authoring loop.** Anthropic's recommended workflow starts
  from observed capability gaps in evaluation runs, then edits skills,
  and splits SKILL.md into referenced files once unwieldy.
- **Slash commands have been merged into skills.** `.claude/commands/deploy.md`
  and `.claude/skills/deploy/SKILL.md` both create `/deploy`; commands
  files keep working but skills add optional invocation-control
  frontmatter: `disable-model-invocation` (manual triggering for
  side-effectful workflows), `user-invocable`, `allowed-tools` /
  `disallowed-tools`, `model`, `effort`, `context: fork` + `agent`,
  `hooks`, and `paths` (glob-scoped activation).
- **Refuted claim worth recording:** SKILL.md frontmatter is NOT limited
  to exactly `name` + `description` (a 1-2 verification vote killed that
  reading of the engineering blog). Many optional fields exist in the
  Claude Code extension of the spec. This repo's minimal-frontmatter lint
  is therefore a portability choice, not a spec requirement.
- **Context rot is the technical rationale.** As tokens in the window
  increase, recall accuracy over that context decreases (independently
  corroborated across 18 frontier models by Chroma's 2025 study). Claude
  Code itself is the reference hybrid design: memory file up front,
  just-in-time retrieval via glob/grep instead of pre-built indexes.

### 3. Hooks, settings, permissions

- **Hooks are the enforcement layer.** "Unlike CLAUDE.md instructions
  which are advisory, hooks are deterministic." A Stop hook can run a
  check script and block the turn from ending until it passes. The
  documented textbook case is exactly "run the linter before every
  commit."
- **Headless and CI usage:** `claude -p` with `--allowedTools` to scope
  permissions for unattended runs; the flag restricts what Claude can do,
  which matters when nobody is watching.
- Verification coverage in this area was thinner than for areas 1 and 2
  (fewer claims survived the panels); the
  [hooks](https://code.claude.com/docs/en/hooks) and
  [permissions](https://code.claude.com/docs/en/permissions) docs plus
  the trailofbits claude-code-config repo are the primary references.

### 4. Subagents, commands, MCP, orchestration

- **Subagents keep the main thread clean.** They run in separate context
  windows and report back summaries. Read-only research/review agents are
  the canonical shape.
- **Plugins are the bundling unit** for skills, hooks, subagents, and MCP
  servers as a single installable.
- **Long-running work needs on-disk state.** Anthropic's
  [long-running harness blog](https://www.anthropic.com/engineering/effective-harnesses-for-long-running-agents)
  reports that compaction alone is insufficient even for Opus 4.5;
  progress files, structured feature lists, and git history are required
  because each session starts memoryless. (Caveat: derived from one
  internal experiment.)
- MCP-curation thresholds (how many servers/tools measurably degrade tool
  selection) had no surviving quantitative claims; this remains an open
  question below.

## Part 2: What this repo already gets right

The audit confirmed strong alignment on the load-bearing architecture:

- **The CLAUDE.md + `@AGENTS.md` shim** matches the documented pattern
  exactly. No change needed to the mechanism itself.
- **The marketplace/plugin split** (one default plugin, 15 opt-in plugins,
  symlink farm into a canonical `skills/` pool, every skill owned by
  exactly one plugin, enforced by `validate.py`) matches the official
  plugin/marketplace model and directly mitigates the ~100-tokens-per-skill
  listing overhead: a user who installed all 60 published skills would
  carry roughly 6k tokens of always-on listing; opt-in plugins keep that
  proportional to actual use.
- **Read-only subagents** (`@reviewer`, `@explorer`, `@debugger`) match
  the separate-context-window, report-a-summary guidance.
- **On-demand references** (umbrella skills pushing sub-topics into
  `references/`, `languages/nix` with 13 topic subdirectories) are
  textbook level-3 progressive disclosure.
- **The eval harness design** (per-skill `cases.yaml` colocated with the
  skill, deterministic-first assertions, judge-family invariants,
  cassette replay for CI) matches the eval-first authoring loop Anthropic
  recommends. Coverage, not design, is the gap (see below).
- **Externalized cross-session state** (upstream-tracker's append-only
  decision logs and review cursor, the improvement-memory JSONL, the
  handoff skill) is exactly the persistent-state pattern the long-running
  harness guidance calls for.
- **`.mcp.json` abstinence with native `.lsp.json`** avoids MCP context
  bloat for a need Claude Code covers natively. No verified evidence
  contradicted this policy.

## Part 3: Gap analysis and prioritized recommendations

Measurements below are from the local audit (exact `wc -l` / frontmatter
parsing), which supersedes the research pass's quick approximations.

### P1: Enforcement belongs in hooks, not prose

`AGENTS.md` line 204 says portable skills must pass `validate.py`, "Run on
every commit," but the repo ships zero hooks, no `.claude/settings.json`,
and no pre-commit config anywhere (verified tree-wide). This is the
documented textbook case for a deterministic hook.

Recommended shape (when implemented): a repo-level checked-in
`.claude/settings.json` with a Stop or PreToolUse(git commit) hook running
`just validate`, plus (optionally) the same hook shipped in
`jylhis-skills-core` via the plugin hooks mechanism, and/or a conventional
pre-commit hook for non-agent contributors. Note `.claude/` is currently
gitignored; that entry would need to be narrowed (e.g. ignore
`.claude/settings.local.json` only).

### P1: Prune always-loaded context toward the 200-line target

Always-loaded footprint today: CLAUDE.md 46 lines + AGENTS.md 247 lines,
~293 lines (~2.3k tokens) per session, in a repo whose whole thesis is
on-demand loading. AGENTS.md alone exceeds the 200-line target. Candidates
to move out (procedures and rarely needed matrices, per the official
decision rule):

- "Installing opt-in plugins" table and plugin list (lines 115-128):
  duplicated in `docs/install.md`; a one-line pointer suffices.
- "Recording corrections" procedure (lines 228-247): already the domain
  of the `skill-improver` meta-skill; keep a two-line pointer.
- Script-migration detail (lines 222-226) and parts of the layout
  narration that restate what `docs/` files already cover.
- The eight-category taxonomy is stated twice (Layout and Repo
  conventions); state it once.

A realistic pass gets AGENTS.md to roughly 150 lines without losing any
always-relevant fact. Remember: moving text into an `@import` saves
nothing; it must leave the always-loaded set entirely (into `docs/`,
`meta/` skills, or path-scoped rules).

### P2: Oversized skills

Guidance: SKILL.md under 500 lines, body under ~5k tokens. Violations:

| Skill | Lines | Note |
|---|---|---|
| `domains/taste` | 1,211 | 2.4x the target; no `references/` at all |
| `services/terraform-refactor-module` | 542 | upstream import (hashicorp) |
| `personal/obsidian-bases` | 504 | upstream import (obsidian-skills) |

Splitting upstream-imported skills complicates future backports
(`upstream-tracker` diffs), so the tradeoff differs per skill: `taste` is
the clear case; for the two upstream ones, consider whether the
`umbrella-references` merge-strategy already used elsewhere in
`sources.yaml` can absorb the split at import time.

Also: `services/azure-cost` is the only skill with a bespoke layout (three
topic directories, 21 files, directly under the skill dir instead of
`references/`). Normalizing it keeps the level-3 convention uniform.

### P2: Description hygiene for trigger quality

All 60 published-skill descriptions currently pass the 50-1024 lint
(the lint covers `skills/` only, not `meta/`) (max is azure-cost at
970 chars), but several push toward both the 1,024-char hard limit and the
1,536-char listing truncation window: azure-cost 970, grafana-oss 921,
grafana-alerting 863, upstream-tracker (meta) 843, azure-deploy 808,
azure-storage 753. Long descriptions are permanent per-session overhead
(level 1 is always loaded) and risk truncation burying the "when to use"
signal. Recommended: editorial pass front-loading the trigger conditions
in the first sentence; consider tightening the lint's advisory ceiling
(e.g. warn above ~600 chars) rather than only enforcing the platform max.

### P2: Eval coverage is 1 of 60, on synthetic data

Only `engineering/ast-grep` has `evals/cases.yaml`, and its 24 cassettes
are explicit synthetic placeholders ("Replace with real recording before
treating any score as a measurement"). The harness design is aligned with
best practice; the loop is not yet closed. Recommended order: record real
cassettes for ast-grep first, then add cases for the highest-traffic core
skills (security, offline-docs, tdd, diagnose), using eval failures as the
trigger for skill edits via `skill-improver`, which is exactly the
Anthropic authoring loop.

### P3: Decide a policy on Claude-only invocation controls

`validate.py` rejects all Claude-specific frontmatter to keep the skills
tree portable to Pi and claude.ai. Verification confirmed this is a
choice, not a spec requirement, and it currently forfeits documented
controls, most notably `disable-model-invocation: true` for side-effectful
workflows (e.g. anything that mutates state should arguably not be
model-triggerable). The docs' escape hatch: extensions can live outside
the portable tree. A per-plugin overlay (analogous to how `.lsp.json` and
`commands/` already live at plugin level, invisible to Pi) could carry
invocation-control frontmatter for the Claude Code target without
touching `skills/`. Relatedly, the three `commands/` files are
legacy-shaped now that commands have merged into skills; they keep
working, so migration is optional, but the skills-based model would let
`/remember-correction` carry `disable-model-invocation` semantics.

### P3: Document a headless CI recipe

CI currently runs lint + stub evals via devenv. There is no documented
`claude -p --allowedTools ...` recipe for running live evals (L3) or
agentic validation headlessly. A short `docs/` section (or an eval recipe
in the justfile) would close the gap the best-practices docs describe for
unattended runs.

### P3: Housekeeping

- `AGENTS.md` claims validation runs on every commit; until the P1 hook
  exists, the prose overstates reality. Fix whichever direction you
  choose.
- Script-language preference tier 2 (TypeScript + Bun) has zero instances
  on disk (1 Go, 11 Python, 10 shell). Either the migration plan in
  `docs/script-migrations.md` should move, or the tier list should
  reflect practice.

## Caveats

- Doc-based figures reflect code.claude.com and platform.claude.com as
  fetched 2026-07-11; this surface changes fast (the commands-into-skills
  merge is recent; the 1,536-char truncation is configurable). The
  200-line and 500-line figures are stated targets, not enforced limits.
- Coverage is uneven: memory files and skills are backed by multiple
  unanimous primary sources; hooks/permissions/sandboxing detail and MCP
  curation/orchestration had fewer surviving verified claims.
- Academic and non-Anthropic industry sources largely dropped out during
  adversarial verification; surviving evidence is Anthropic-primary, with
  third-party corroboration only on context rot (Chroma 2025). Treat the
  NVIDIA/DeepMind angle as not-yet-substantiated rather than absent.
- Pi portability constraints were taken from this repo's own docs, not
  independently verified against Pi.

## Open questions

1. Do path-scoped `.claude/rules/` files (or skill `paths:` frontmatter)
   stay invisible to Pi the way `agents/` and `commands/` do? If yes,
   they are the natural home for the pruned AGENTS.md procedures.
2. Is there quantitative evidence on how many MCP servers / tool
   definitions measurably degrade tool selection, to ground the
   `.mcp.json`-abstinence policy beyond the LSP-native rationale?
3. Will Claude Code gain native AGENTS.md support (removing the shim),
   and will Pi or agentskills.io adopt invocation-control fields,
   letting the portable lint accept them?
4. Should `validate.py` mirror the platform's hard 1,024-char description
   maximum with an advisory warning band below it?

## Primary sources

- https://code.claude.com/docs/en/memory
- https://code.claude.com/docs/en/best-practices
- https://code.claude.com/docs/en/skills
- https://code.claude.com/docs/en/hooks
- https://code.claude.com/docs/en/permissions
- https://code.claude.com/docs/en/plugin-marketplaces
- https://platform.claude.com/docs/en/agents-and-tools/agent-skills/overview
- https://www.anthropic.com/engineering/effective-context-engineering-for-ai-agents
- https://www.anthropic.com/engineering/equipping-agents-for-the-real-world-with-agent-skills
- https://www.anthropic.com/engineering/effective-harnesses-for-long-running-agents
- https://www.anthropic.com/engineering/multi-agent-research-system
- https://www.anthropic.com/engineering/code-execution-with-mcp
- https://www.anthropic.com/engineering/claude-code-best-practices
- https://github.com/anthropics/claude-plugins-official
- https://github.com/trailofbits/claude-code-config
- Community/secondary: awesome-claude-code, awesome-harness-engineering,
  practitioner posts (José Parreño García on memory, Hidekazu Konishi on
  skills, nyosegawa on harness engineering 2026).
