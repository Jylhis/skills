---
name: using-skills
description: Meta-skill that explains how the jylhis-skills catalogue is organized and how to route a task to the right skill. Use at session start, when the user says "which skill should I use for X", "what skills do I have", "list skills", "is there a skill for Y", or when you're about to tackle a task and want to check whether a purpose-built skill already exists.
---

# Using skills in this repository

This repository ships a curated catalogue of portable `SKILL.md` files under
`skills/<category>/<name>/`. Each skill is a focused, opinionated guide for a
specific task or topic. Some are standalone practices (tdd, diagnose,
commit-messages); others are **umbrella** skills that route to deeper
`references/<topic>.md` sub-documents read on demand.

## Layout

```
skills/                          ← published catalogue
├── engineering/                 practices and workflows
│   ├── code-comments/           when a comment earns its place
│   ├── code-review/             structured diff/PR review
│   ├── commit-messages/         atomic, imperative commit messages
│   ├── diagnose/                disciplined bug diagnosis loop
│   ├── documentation/           technical writing (README, API, runbook)
│   ├── karpathy-guidelines/     behavioral LLM coding guidelines
│   ├── microsoft-docs/          Microsoft Learn docs via MCP
│   ├── offline-docs/            local man/info/doc discovery
│   ├── ponytail/                lazy-senior minimal-solution enforcement
│   ├── tdd/                     red-green test-driven development
│   ├── to-prd/                  synthesize a PRD from context
│   └── trunk-based-development/ short-lived branches, daily integration
├── languages/                   per-language guidance (umbrellas)
│   ├── bash/                    shell scripting form and lint rules
│   ├── go/                      modern Go (slices/maps/cmp, iter, sync)
│   ├── jvm/                     Gradle Kotlin DSL, Maven Central, JUnit
│   ├── nix/                     Nix, Nixpkgs, NixOS, flakes, devenv
│   ├── python/                  Python 3.12+ (asyncio, types, Ruff, uv)
│   ├── rust/                    typed boundaries, newtypes, error discipline
│   ├── terraform/               HCL style, testing, module refactoring
│   └── typescript/              TypeScript 5.9+ / Node 22 (ESLint 9, Vitest)
├── domains/                     cross-cutting topic deep dives
│   ├── security/                cross-language security review
│   └── taste/                   anti-slop frontend design skill
├── services/                    specific named platforms and ecosystems
│   ├── azure-*/                 (7 skills) Azure AI, compliance, cost, deploy, AKS, storage
│   ├── convert-file/            data format conversion via DuckDB
│   ├── duckdb-docs/             DuckDB/DuckLake doc search
│   ├── gitlab/                  GitLab CI/CD + glab CLI
│   ├── grafana-*/               (5 skills) alerting, dashboarding, OTel, OSS, PromQL
│   ├── install-duckdb/          DuckDB extension installer
│   ├── query/                   SQL queries via DuckDB
│   ├── read-file/               read any data file via DuckDB
│   ├── read-memories/           search past session logs
│   ├── s3-explore/              explore S3/R2/GCS via DuckDB
│   └── spatial/                 geospatial queries via DuckDB
├── stack/                       deep dives on specific technologies
│   ├── filesystems/             APFS, Btrfs, ZFS / OpenZFS
│   └── systemd/                 Linux init, unit files, sandboxing, cgroups
├── productivity/                workflow tools
│   ├── handoff/                 compact conversation into a handoff doc
│   ├── humanizer/               remove AI writing patterns
│   ├── job-search/              candidate-side resume/CV tailoring
│   ├── memory-management/       two-tier workplace memory (CLAUDE.md + memory/)
│   └── task-management/         shared-file TASKS.md tracking
├── product/                     product-management practices
│   ├── competitive-brief/       competitive analysis briefs
│   ├── product-brainstorming/   product thinking partner
│   ├── roadmap-update/          roadmap create/update/reprioritize
│   └── sprint-planning/         sprint scope, capacity, goals
├── business/                    small-business operations
│   ├── job-post-builder/        employer-side hiring packets
│   └── tax-season-organizer/    tax prep materials for CPA
├── personal/                    Obsidian and knowledge-management
│   ├── defuddle/                clean markdown extraction from web pages
│   ├── graphify/                build knowledge graphs from a corpus
│   ├── json-canvas/             Obsidian .canvas file authoring
│   ├── llm-wiki/                LLM-curated markdown wiki
│   ├── obsidian-bases/          Obsidian .base database views
│   ├── obsidian-cli/            Obsidian vault CLI interaction
│   ├── obsidian-markdown/       Obsidian-flavored markdown syntax
│   └── para-method/             PARA organization (Projects/Areas/Resources/Archives)
└── misc/
    └── emacs/                   Emacs Lisp + Emacs tooling

.claude/skills/            ← repo-dev skills, auto-loaded in-repo, not shipped to users
├── skill-creator-lang/          Authoring new language/stack skills
├── skill-extractor/             Extract reusable skills from work sessions
├── skill-improver/              Surface improvement notes from the JSONL log
├── upstream-tracker/            Tracking external upstream skill repos
└── using-skills/                This skill
```

## Routing a task

1. **Identify the category and skill.** Match the task to one of the skills
   in the table below.
2. **For umbrella skills**, read the umbrella's `SKILL.md` — it lists
   sub-topics with reference paths.
3. **Read the matching `references/<topic>.md`** before writing or reviewing
   code. Each reference is the focused, opinionated guidance for that sub-topic.

| Task involves … | Skill |
|---|---|
| Python (any aspect) | `languages/python` |
| TypeScript / Node.js (any aspect) | `languages/typescript` |
| Go | `languages/go` |
| Rust | `languages/rust` |
| JVM / Gradle / Maven Central | `languages/jvm` |
| Nix, Nixpkgs, NixOS, nix-darwin, home-manager, devenv, flakes | `languages/nix` |
| Terraform / HCL | `languages/terraform` |
| Bash / shell scripting | `languages/bash` |
| Emacs Lisp, major modes, ERT, gptel/MCP | `misc/emacs` |
| Security review of untrusted-input code | `domains/security` |
| Frontend design (landing pages, portfolios, redesigns) | `domains/taste` |
| APFS, Btrfs, ZFS, snapshots, replication | `stack/filesystems` |
| systemd unit files, timers, sandboxing, cgroups | `stack/systemd` |
| GitLab CI/CD or `glab` CLI | `services/gitlab` |
| Azure (AI, cost, deploy, AKS, storage, compliance) | `services/azure-*` |
| Grafana (dashboards, alerting, PromQL, OTel, OSS) | `services/grafana-*` |
| DuckDB (read files, query, S3, spatial, doc search) | `services/*duckdb*` / `services/query` / `services/read-file` etc. |
| Offline man / info / doc discovery | `engineering/offline-docs` |
| Microsoft Learn documentation | `engineering/microsoft-docs` |
| Test-driven development | `engineering/tdd` |
| Diagnosing a hard bug or perf regression | `engineering/diagnose` |
| Writing commit messages | `engineering/commit-messages` |
| Code review (diff, PR, security audit) | `engineering/code-review` |
| Code comments (when, why, doc formats) | `engineering/code-comments` |
| Technical documentation (README, API, runbook) | `engineering/documentation` |
| Trunk-based development / branching | `engineering/trunk-based-development` |
| Minimal / lazy solution enforcement | `engineering/ponytail` |
| Behavioral LLM coding guidelines | `engineering/karpathy-guidelines` |
| Synthesizing a PRD | `engineering/to-prd` |
| Handoff document for another agent | `productivity/handoff` |
| Removing AI writing patterns | `productivity/humanizer` |
| Workplace memory (glossary, people, projects) | `productivity/memory-management` |
| Task tracking (TASKS.md) | `productivity/task-management` |
| Job search (resume tailoring, cover letters) | `productivity/job-search` |
| Competitive analysis brief | `product/competitive-brief` |
| Product brainstorming / thinking partner | `product/product-brainstorming` |
| Roadmap update / reprioritization | `product/roadmap-update` |
| Sprint planning | `product/sprint-planning` |
| Hiring packet (job post, interview, offer) | `business/job-post-builder` |
| Tax season prep (quarterly, 1099s) | `business/tax-season-organizer` |
| Obsidian vault interaction (CLI) | `personal/obsidian-cli` |
| Obsidian-flavored markdown | `personal/obsidian-markdown` |
| Obsidian Bases (.base files) | `personal/obsidian-bases` |
| JSON Canvas (.canvas files) | `personal/json-canvas` |
| LLM-maintained markdown wiki | `personal/llm-wiki` |
| PARA method organization | `personal/para-method` |
| Knowledge graph from a corpus | `personal/graphify` |
| Clean content extraction from web pages | `personal/defuddle` |

If the skill exists but no sub-topic matches, fall back to the skill body's
general guidance — or proceed without a skill if the task is trivial.

## Repo-development meta skills

`.claude/skills/` holds the repo-maintenance skills. Claude Code
**auto-loads them when this repo is open**, but they are **not** shipped
via any published plugin (`.claude/` is excluded from `install.sh`), so
they stay relevant only when developing skills *inside* this repo.

- `skill-creator-lang` — authoring new language / stack skills.
- `skill-extractor` — extract reusable skills from work sessions.
- `skill-improver` — surface improvement notes from the correction JSONL.
- `upstream-tracker` — vendoring and reviewing upstream skill repos.
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
- Tasks outside the scope of any skill — proceeding without a
  skill is fine. Skill invocation is opportunistic acceleration, not
  a hard prerequisite.

## Recording corrections

When the user corrects your behaviour on something skill-related, append
one entry to the improvement-memory JSONL. The canonical reference is in
AGENTS.md § Recording corrections; the schema is at
`.claude/skills/skill-improver/references/schema.md`; the helper is
`go run scripts/append-correction.go --json -`; the slash command is
`/remember-correction`.

The `skill-improver` meta-skill consumes the JSONL when iterating on a
named skill.

## Discovering the catalogue

```bash
just list                       # find skills -name SKILL.md
just validate                   # portable lint + plugin.json cross-check
```
