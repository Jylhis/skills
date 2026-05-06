---
name: using-skills
description: Meta-skill that explains how this repository's skill catalog is organized and how to discover the right skill for a task. Use at session start, when the user says "which skill should I use for X", "what skills do I have", "list skills", "is there a skill for Y", "do we have a skill on Z", "how do I find the skill that handles W", or when you're about to tackle a task and want to check whether a purpose-built skill already exists. Also use as a routing aid when the user's request touches a broad domain (Go, Rust, Python, TypeScript, Nix, Obsidian, Terraform, Azure, Cloudflare, security auditing, testing, documentation, CI/CD, PR review, skill authoring, shader work) — surface the relevant namespace before diving in.
---

# Using skills in this repository

This repository is a curated catalogue of agent skills — a superset of
[trailofbits/skills-curated](https://github.com/trailofbits/skills-curated) —
combining imported upstream skills with a small set of locally maintained
ones. Rather than enumerate every skill in a decision tree (there are
too many to fit), this meta-skill explains the taxonomy so you can
navigate to the right skill quickly.

## Before you start a task

When a non-trivial task arrives, check whether a purpose-built skill
already exists. The triggering system will normally surface matching
skills via their descriptions, but you can also look them up directly:

```bash
just list-skills               # full catalog with namespace + name
just list-skills | jq '.[] | select(.namespace == "golang")'  # filter
```

In agent sessions, skill descriptions already appear in
`available_skills`. Read the descriptions before acting — a skill
usually encodes battle-tested practice that beats reinventing it.

## Namespaces in this catalogue

Every skill has a `namespace` prefix that tells you where it came from
and what domain it addresses.

| Namespace | Scope | Source |
|---|---|---|
| `jstack` | Local — personal skills maintained in this repo (including the merged `skill-creator` and this meta-skill) | repo root |
| `golang` | Go language, stdlib, samber/* ecosystem | `samber/cc-skills-golang` |
| `rust` | Rust language, LSP-based navigation, ownership/lifetime mental models | `actionbook/rust-skills` |
| `obsidian` | Obsidian vault automation | `kepano/obsidian-skills` |
| `anthropic` | Claude plugin toolkit (skills, agents, slash commands) | `anthropics/claude-plugins-official` |
| `terraform` | Terraform test, style, module refactoring, stacks | `hashicorp/agent-skills` |
| `openai` | ASP.NET Core, frontend, GH workflow, security skills | `openai/skills` |
| `ms` | Microsoft tech skills (cloud architect, Microsoft docs) | `microsoft/skills` |
| `azure` | Azure SDK skills (compute, storage, AI, identity, ...) | `microsoft/skills` |
| `cloudflare` | Cloudflare Workers, Durable Objects, wrangler | `cloudflare/skills` |
| `tob` | Trail of Bits — security auditing, static analysis, semgrep, yara, constant-time analysis, supply-chain, skill authoring craft | `trailofbits/skills` |
| `tobc` | Trail of Bits curated external skills (fuzzing, ghidra, PDF, deploy workflows) | `trailofbits/skills-curated` |
| `addy` | General engineering workflow skills (spec-driven, TDD, incremental implementation, code review, performance, ...) | `addyosmani/agent-skills` |
| `minimax` | Shader/GPU programming | `MiniMax-AI/skills` |

## How to route a task

Rather than picking a specific skill upfront, match the **phase of work**
to a namespace, then rely on the trigger descriptions to pick the exact
skill.

```text
Task arrives
    │
    ├── "What should we build?" / unclear scope
    │   → addy (spec-driven-development, planning-and-task-breakdown, idea-refine)
    │
    ├── Writing new code in a specific language
    │   → golang / rust / typescript / python / jvm / cloudflare
    │     (code-style, error-handling, testing, concurrency, ...)
    │
    ├── Infrastructure / ops
    │   → terraform / azure / cloudflare / nix* / zfs / btrfs / apfs
    │
    ├── Editor / tooling automation
    │   → obsidian / gitlab / devenv / flakes / home-manager / nix-darwin
    │
    ├── Security review / hardening
    │   → tob (static-analysis, semgrep-rule-creator, constant-time-analysis,
    │          supply-chain-risk-auditor, yara-authoring, insecure-defaults,
    │          agentic-actions-auditor, zeroize-audit, variant-analysis, ...)
    │   → openai (security-best-practices, security-threat-model, security-ownership-map)
    │
    ├── Reviewing / improving code
    │   → addy (code-review-and-quality, code-simplification, performance-optimization)
    │   → anthropic (code-reviewer, pr-* variants, code-architect, code-explorer, code-simplifier)
    │   → tob (differential-review, variant-analysis)
    │
    ├── PR / git workflow
    │   → openai (gh-address-comments, gh-fix-ci)
    │   → anthropic (review-pr, revise-claude-md, feature-dev)
    │   → addy (git-workflow-and-versioning, ci-cd-and-automation)
    │
    ├── Writing / evaluating agent skills
    │   → jstack/skill-creator (local, merged from anthropic + openai + microsoft)
    │   → tob/skill-improver, tob/workflow-skill-design
    │
    ├── Graphics / GPU
    │   → minimax/shader-dev
    │
    └── Debugging
        → addy (debugging-and-error-recovery)
        → golang-troubleshooting, python-error-handling, rust m06-error-handling
```

## Core operating behaviors (always)

These apply across every skill; they are not skill-specific:

### 1. Surface assumptions before acting

Before implementing anything non-trivial, state the assumptions you're
making. Give the human a chance to correct silent misinterpretations
before rework piles up:

```text
Assumptions I'm making:
1. [scope / requirements / architecture]
2. ...
→ Correct me now or I'll proceed with these.
```

### 2. Manage confusion actively

When you hit an inconsistency or ambiguity: **stop**, name the specific
confusion, present the tradeoff or ask the clarifying question, wait
for resolution. Never silently pick one interpretation and hope it
holds.

### 3. Push back when warranted

You are not a yes-machine. If an approach has a concrete downside,
point it out — quantify where possible ("this adds ~200ms latency",
not "this might be slow"), propose an alternative, and accept the
human's override only after they've seen the concrete tradeoff.
Sycophancy is a failure mode.

### 4. Prefer simplicity

Three similar lines beat a premature abstraction. Default to no
comments, no helpers for hypothetical futures, no error handling for
impossible states. Trust internal code and framework guarantees;
validate only at system boundaries.

### 5. Respect boundaries

- Don't invent slash commands, agents, or skills that aren't listed
  in `available_skills` / the catalog.
- Don't extend a task beyond what was asked. A bug fix is a bug fix.
- Surface destructive actions (deletes, force-pushes, schema drops)
  before running them.

## Discovering what's here

```bash
# Full catalog as JSON
just list-skills

# Group by namespace
just list-skills | jq 'group_by(.namespace) | map({namespace: .[0].namespace, count: length, names: map(.name)})'

# Search by keyword
just list-skills | jq '.[] | select(.name | test("review|security"))'

# Open a specific skill
just list-skills | jq -r '.[] | select(.name == "using-skills") | .relativePath'
```

Upstream provenance is tracked in `bundled-sources.nix`. To add a new
upstream, add a non-flake input to `flake.nix`, lock it, add an entry
to `bundled-sources.nix`.

## Merged / overridden skills

Where a locally maintained skill supersedes an upstream version, the
local one wins. Current overrides:

- `jstack:skill-creator` — merged distillation of `anthropics/skills`,
  `anthropics/claude-plugins-official`, `openai/skills`, and
  `microsoft/skills`. See `skills/skill-creator/README.md` for
  provenance and refresh procedure.
- `jstack:using-skills` — this skill. Points at the repo's catalogue;
  replaces `addyosmani/using-agent-skills` (which is excluded from the
  `addy` namespace import).

## When to *not* invoke a skill

- Trivial one-step tasks the model can handle directly ("add a newline
  at the end of file X") — descriptions won't trigger and shouldn't.
- Tasks explicitly outside the scope of any catalogued skill —
  proceeding without a skill is fine. Skill invocation is opportunistic
  acceleration, not a hard prerequisite.

---

Upstream inspiration:

- Structure and "core operating behaviors" from
  `addyosmani/using-agent-skills`
  <https://github.com/addyosmani/agent-skills/blob/main/skills/using-agent-skills/SKILL.md>
