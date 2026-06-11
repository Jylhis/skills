---
name: using-skills
description: Meta-skill that explains how the jylhis-skills catalogue is organized and how to route a task to the right skill. Use at session start, when the user says "which skill should I use for X", "what skills do I have", "list skills", "is there a skill for Y", or when you're about to tackle a task and want to check whether a purpose-built skill already exists.
---

# Using skills in this repository

This repository is a **skills marketplace**. It publishes one default
plugin (`jylhis-skills-core`) plus several opt-in plugins to Claude
Code, Codex, and Google Antigravity. Many skills are **umbrellas** —
one entry covers a language or tooling category, with deeper guidance
under that skill's `references/` directory, read on demand.

## Layout

Skills are **two levels deep** on disk: `skills/<category>/<name>/SKILL.md`.
The eight categories are `engineering` (practices and workflows),
`languages` (per-language guidance), `domains` (cross-cutting topic deep
dives), `services` (specific named platforms), `stack` (deep dives on
specific named technologies), `productivity`, `personal`, and `misc`.

```
skills/                          ← canonical SKILL.md tree (source of truth)
├── engineering/                 practices: ast-grep, semgrep, tdd, diagnose, …
├── languages/                   per-language: python, typescript, go, jvm, nix
├── domains/                     cross-cutting: security, taste
├── services/                    named platforms: gitlab, azure, grafana, terraform
├── stack/                       named technologies: filesystems
├── productivity/                handoff, humanizer, caveman, …
├── personal/                    Obsidian / knowledge-management workflows
└── misc/                        uncategorised

plugins/                         ← published plugins (marketplace)
├── jylhis-skills-core/          default plugin (core engineering + productivity skills)
│   ├── skills/                  symlinks into skills/<category>/<name>/
│   ├── agents/                  @reviewer, @explorer, @debugger
│   └── commands/                /explore, /lsp-status, /remember-correction
└── jylhis-<lang|service|tool>/  opt-in plugins (python, typescript, go, jvm,
                                 nix, emacs, gitlab, azure, terraform, grafana,
                                 filesystems, obsidian, taste, duckdb,
                                 reverse-engineering, …)

meta/                            ← repo-only, not shipped to users
├── skill-creator-lang/          Authoring new language/stack skills
├── skill-improver/              Surface improvement notes from the JSONL log
├── upstream-tracker/            Tracking external upstream skill repos
├── skill-extractor/             Extract reusable skills from work sessions
└── using-skills/                This skill
```

Each plugin's `skills/` directory holds symlinks pointing back into the
canonical `skills/<category>/<name>/` tree. Skill files are never moved
out of that tree. The repo root is the marketplace, not a plugin.

## Routing a task

1. **Identify the category and the skill.** Map the task to one of the
   eight categories, then to a skill within it. Skill `description:`
   fields carry explicit trigger phrases — the runtime routes on those.
2. **Discover what exists** rather than relying on a fixed list — there
   are ~58 skills and the set grows. Use `just list` (below), browse
   `skills/<category>/`, or grep skill descriptions.
3. **Read the skill's `SKILL.md`.** Umbrella skills list sub-topics with
   reference paths.
4. **Read the matching `references/<topic>.md`** before writing or
   reviewing code. Each reference is the focused, opinionated guidance
   for that sub-topic.

Representative routing (not exhaustive — discover the rest):

| Task involves … | Category | Skill |
|---|---|---|
| Python / TypeScript / Go / JVM / Nix | `languages` | `python`, `typescript`, `go`, `jvm`, `nix` |
| Structural search/replace, linting | `engineering` | `ast-grep`, `semgrep` |
| TDD, diagnosing, prototyping, triage | `engineering` | `tdd`, `diagnose`, `prototype`, `triage` |
| Security review of untrusted-input code | `domains` | `security` |
| GitLab CI/CD, Azure, Grafana, Terraform | `services` | `gitlab`, `azure`, `grafana`, `terraform` |
| APFS / Btrfs / ZFS, snapshots, replication | `stack` | `filesystems` |
| Handoff notes, humanizing prose | `productivity` | `handoff`, `humanizer` |
| Obsidian / knowledge management | `personal` | (browse `skills/personal/`) |

Most language and service skills are opt-in plugins — they are only
loaded when the user has installed the matching `jylhis-<name>` plugin.
If no skill matches, fall back to general guidance, or proceed without a
skill if the task is trivial.

## Repo-only meta skills

`meta/` is **not** shipped via any published plugin. The skills are
repo-local and only relevant when developing skills *inside* this repo.
They are not auto-loaded by any tool; invoke them by name when needed.

- `skill-creator-lang` — authoring new language / stack skills.
- `skill-improver` — surface improvement notes from the correction JSONL.
- `upstream-tracker` — vendoring and reviewing upstream skill repos.
- `skill-extractor` — extract a reusable skill from a work session.
- `using-skills` — this skill.

## Core operating behaviors

These apply across every skill:

### 1. Surface assumptions before acting

Before implementing anything non-trivial, state the assumptions you're
making. Give the human a chance to correct silent misinterpretations
before rework piles up.

### 2. Manage confusion actively

When you hit an inconsistency or ambiguity: **stop**, name the specific
confusion, present the tradeoff or ask the clarifying question, wait
for resolution. Never silently pick one interpretation and hope it
holds.

### 3. Push back when warranted

If an approach has a concrete downside, point it out — quantify where
possible ("this adds ~200ms latency", not "this might be slow"),
propose an alternative, and accept the human's override only after
they've seen the concrete tradeoff. Sycophancy is a failure mode.

### 4. Prefer simplicity

Three similar lines beat a premature abstraction. Default to no
comments, no helpers for hypothetical futures, no error handling for
impossible states. Trust internal code and framework guarantees;
validate only at system boundaries.

### 5. Respect boundaries

- Don't invent skills, agents, or slash commands that aren't listed.
- Don't extend a task beyond what was asked.
- Surface destructive actions (deletes, force-pushes, schema drops)
  before running them.

## When to *not* invoke a skill

- Trivial one-step tasks the model can handle directly.
- Tasks outside the scope of any umbrella — proceeding without a
  skill is fine. Skill invocation is opportunistic acceleration, not
  a hard prerequisite.

## Recording corrections

When the user corrects your behaviour on something skill-related, append
one entry to the improvement-memory JSONL. The canonical reference is in
AGENTS.md § Recording corrections; the schema is at
`meta/skill-improver/references/schema.md`; the helper is
`plugins/jylhis-skills-core/scripts/append-correction.go` (run with
`go run`); the slash command is `/remember-correction`.

The `skill-improver` meta-skill consumes the JSONL when iterating on a
named skill.

## Discovering the catalogue

```bash
just list                       # find skills -name SKILL.md
just validate                   # portable lint + plugin.json cross-check
```
