---
name: using-skills
description: Meta-skill that explains how the jylhis-skills catalogue is organized and how to route a task to the right skill. Use at session start, when the user says "which skill should I use for X", "what skills do I have", "list skills", "is there a skill for Y", or when you're about to tackle a task and want to check whether a purpose-built skill already exists.
---

# Using skills in this repository

This repository ships a small, opinionated set of **umbrella** skills.
Each umbrella covers one language or tooling category; deeper guidance
lives under that umbrella's `references/` directory and is read on
demand.

## Layout

```
skills/                          ← published catalogue (jylhis-skills plugin)
├── engineering/
│   ├── ast-grep/                ast-grep tool (standalone)
│   └── offline-docs/            offline man / info / doc discovery (standalone)
├── languages/
│   ├── go/                      Modern Go (per project's Go version)
│   ├── jvm/                     Gradle build, Maven Central publishing, JUnit/AssertJ/kotest
│   ├── nix/                     Nix language, flakes, Nixpkgs, NixOS, nix-darwin, home-manager, devenv, ...
│   ├── python/                  Python 3.12+
│   └── typescript/              TypeScript 5.9+ on Node 22 LTS
├── domains/
│   └── security/                Cross-language security review (Python, TS/Node, JVM)
├── services/
│   └── gitlab/                  GitLab CI/CD + glab CLI
├── stack/
│   └── filesystems/             APFS, Btrfs, ZFS
├── misc/
│   └── emacs/                   Emacs Lisp + Emacs tooling
├── productivity/                reserved category (currently empty)
└── personal/                    reserved category (currently empty)

meta/                      ← repo-only, not shipped to users
├── skill-creator-lang/          Authoring new language/stack skills
├── skill-improver/              Surface improvement notes from the JSONL log
├── upstream-tracker/            Tracking external upstream skill repos
└── using-skills/                This skill
```

## Routing a task

1. **Identify the language or tool category.** Match it to one of the
   umbrellas in the table.
2. **Read the umbrella's `SKILL.md`.** It lists sub-topics with
   reference paths.
3. **Read the matching `references/<topic>.md`** before writing or
   reviewing code. Each reference is the focused, opinionated guidance
   for that sub-topic.

| Task involves … | Umbrella |
|---|---|
| Python (any aspect) | `python` |
| TypeScript / Node.js (any aspect) | `typescript` |
| Nix, Nixpkgs, NixOS, nix-darwin, home-manager, devenv, flakes | `nix` |
| Go | `go` |
| Gradle build, Maven Central publishing, JUnit / kotest tests | `jvm` |
| Emacs Lisp, major modes, ERT, gptel/MCP, keybindings | `emacs` |
| APFS, Btrfs, ZFS, snapshots, replication | `filesystems` |
| GitLab CI/CD or `glab` CLI | `gitlab` |
| Security review of untrusted-input code (Python, TS, JVM) | `security` |
| ast-grep structural search/replace | `ast-grep` |
| Offline man / info / doc discovery | `offline-docs` |

If the umbrella exists but no sub-topic matches, fall back to the
umbrella body's general guidance — or proceed without a skill if the
task is trivial.

## Repo-only meta skills

`meta/` is **not** shipped via any published plugin. The skills are
repo-local and only relevant when developing skills *inside* this repo.
They are not auto-loaded by any tool; invoke them by name when needed.

- `skill-creator-lang` — authoring new language / stack skills.
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
- Tasks outside the scope of any umbrella — proceeding without a
  skill is fine. Skill invocation is opportunistic acceleration, not
  a hard prerequisite.

## Recording corrections

When the user corrects your behaviour on something skill-related, append
one entry to the improvement-memory JSONL. The canonical reference is in
AGENTS.md § Recording corrections; the schema is at
`meta/skill-improver/references/schema.md`; the helper is
`plugins/jylhis-skills-core/scripts/append-correction.go`; the user-facing invocation is
`/jylhis-skills-core:remember-correction`.

The `skill-improver` meta-skill consumes the JSONL when iterating on a
named skill.

## Discovering the catalogue

```bash
just list                       # find skills -name SKILL.md
just validate                   # portable lint + plugin.json cross-check
```
