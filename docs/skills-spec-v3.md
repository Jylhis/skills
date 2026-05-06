# Cross-Tool Agent Skills Repository Spec — v3

This version incorporates the latest adversarial review. The main change is that the repository spec is now explicitly separated from an engineering operating model.

The repository architecture governs how skills, agents, plugins, hooks, MCP configs, and target packages are stored and validated.

The operating model governs how engineers should use those assets in day-to-day software work: context hygiene, planning, TDD, debugging, review, QA, shipping, subagent delegation, and skill iteration.

The guiding rule is unchanged:

```text
Portable format is possible.
Portable behavior is not assumed.
Target-native runtime behavior must stay target-native.
```

## 1. What changed in v3

The previous spec was structurally sound but still underweighted three realities:

1. Good AI coding-agent setups are not just packaging systems. They also need an operating model for context management, task decomposition, verification, and iteration.

2. Skills are not deterministic by themselves. A skill is procedural guidance plus optional files and scripts. Only the scripts are deterministic. The agent’s interpretation of a skill remains probabilistic.

3. Context-management commands, permission modes, subagent behavior, hooks, MCP output handling, and command syntaxes differ by tool. They belong in tool-specific operator guidance or target-native config, not in portable skill definitions.

Therefore v3 adds:

```text
docs/operator-guide.md
docs/skill-authoring-guide.md
docs/skill-catalog.md
evals/
failure-log/
```

and keeps these rejected:

```text
skill.yaml
command.yaml
policy.yaml
mcp.yaml
hook.yaml
universal agent schema
semantic compiler
```

## 2. Goals

The repository must support:

```text
Claude Code
OpenAI Codex
Gemini CLI
```

It must support:

```text
Agent Skills
plugin / extension packages
optional agents
optional hooks
optional MCP server configs
optional Gemini slash-command wrappers
reproducible validation and packaging
content-hash based release integrity
skill evaluation and failure-driven iteration
operator guidance for day-to-day use
```

It must not claim identical behavior across tools.

It must not encode Claude-only, Gemini-only, or Codex-only behavior in portable skills.

## 3. Non-goals

The repository does not define a universal abstraction for:

```text
commands
agents
hooks
MCP configs
marketplaces
runtime permissions
permission classifiers
sandboxing
session commands
context compaction
tool output limits
```

Those stay target-native.

The repository also does not promise that a portable `SKILL.md` produces the same result in every tool. It only promises that a portable skill passes a strict format and lint profile.

## 4. Repository layout

```text
repo/
├── flake.nix
├── flake.lock
├── README.md
│
├── AGENTS.md
├── CLAUDE.md
├── GEMINI.md
│
├── docs/
│   ├── operator-guide.md
│   ├── skill-authoring-guide.md
│   ├── skill-catalog.md
│   ├── context-management.md
│   ├── security-model.md
│   └── release-process.md
│
├── skills/
│   ├── plan-feature/
│   │   ├── SKILL.md
│   │   └── references/
│   ├── tdd-cycle/
│   │   ├── SKILL.md
│   │   └── references/
│   ├── diagnose-bug/
│   │   ├── SKILL.md
│   │   ├── references/
│   │   └── scripts/
│   ├── review-pr/
│   │   ├── SKILL.md
│   │   ├── references/
│   │   ├── scripts/
│   │   └── tests/
│   ├── qa-staging/
│   │   ├── SKILL.md
│   │   └── references/
│   ├── refactor-safely/
│   │   ├── SKILL.md
│   │   └── references/
│   ├── ship-pr/
│   │   ├── SKILL.md
│   │   └── references/
│   ├── modern-python/
│   │   ├── SKILL.md
│   │   └── references/
│   └── typescript-react/
│       ├── SKILL.md
│       └── references/
│
├── target-skills/
│   ├── claude/
│   ├── codex/
│   └── gemini/
│
├── agents/
│   ├── reviewer.md
│   ├── reviewer.codex.toml
│   ├── explorer.md
│   ├── explorer.codex.toml
│   ├── debugger.md
│   └── debugger.codex.toml
│
├── hooks/
│   └── no-secrets/
│       ├── README.md
│       └── no-secrets.sh
│
├── servers/
│   ├── github-context/
│   ├── issue-tracker-context/
│   ├── telemetry-context/
│   └── database-context/
│
├── plugins/
│   ├── code-review/
│   │   ├── README.md
│   │   ├── CHANGELOG.md
│   │   ├── skills.txt
│   │   ├── agents.txt
│   │   ├── claude/
│   │   │   ├── .claude-plugin/
│   │   │   │   └── plugin.json
│   │   │   ├── .mcp.json
│   │   │   └── hooks/
│   │   │       └── hooks.json
│   │   ├── codex/
│   │   │   ├── .codex-plugin/
│   │   │   │   └── plugin.json
│   │   │   ├── .mcp.json
│   │   │   └── hooks/
│   │   │       └── hooks.json
│   │   └── gemini/
│   │       ├── gemini-extension.json
│   │       ├── commands/
│   │       │   └── review/
│   │       │       └── pr.toml
│   │       └── hooks/
│   │           └── hooks.json
│   └── engineering-workflows/
│       ├── README.md
│       ├── CHANGELOG.md
│       ├── skills.txt
│       ├── agents.txt
│       ├── claude/
│       ├── codex/
│       └── gemini/
│
├── evals/
│   ├── skills/
│   │   ├── review-pr/
│   │   │   ├── cases.yaml
│   │   │   ├── fixtures/
│   │   │   └── rubric.md
│   │   └── diagnose-bug/
│   │       ├── cases.yaml
│   │       ├── fixtures/
│   │       └── rubric.md
│   └── agents/
│       └── reviewer/
│           ├── cases.yaml
│           └── rubric.md
│
├── failure-log/
│   ├── README.md
│   └── 2026/
│
├── scripts/
│   ├── validate.py
│   ├── package.py
│   ├── hash.py
│   ├── eval.py
│   └── smoke/
│       ├── claude.sh
│       ├── codex.sh
│       └── gemini.sh
│
├── tests/
│   ├── fixtures/
│   └── snapshots/
│
└── dist/
    ├── claude/
    ├── codex/
    └── gemini/
```

`dist/` is generated and normally gitignored.

## 5. The three-layer operating model

The repo now distinguishes three human-facing layers.

### 5.1 Global context

Files:

```text
AGENTS.md
CLAUDE.md
GEMINI.md
```

Purpose:

```text
Always-loaded project context.
```

Use for:

```text
build commands
test commands
lint commands
package manager conventions
branch and PR conventions
critical architectural facts
environment setup notes
non-obvious repository etiquette
```

Do not use for:

```text
long API docs
file-by-file architecture descriptions
generic advice such as "write clean code"
multi-step procedures
task-specific domain knowledge
tool-specific runtime permissions
long troubleshooting guides
```

Recommended root file pattern:

```markdown
# AGENTS.md

## Build and test

- Install dependencies: `pnpm install`
- Run unit tests: `pnpm test`
- Run type checks: `pnpm typecheck`
- Run lint: `pnpm lint`

## Repository rules

- Do not edit generated files under `dist/`.
- Prefer small PRs with one behavior change.
- Run the relevant test command before reporting completion.

## Architecture

- `src/domain/` contains pure domain logic.
- `src/adapters/` contains I/O and framework integration.
- Do not import adapters from domain modules.
```

Tool wrappers:

```markdown
<!-- CLAUDE.md -->
@AGENTS.md

## Claude Code

Use skills for procedural workflows.
Do not rely on plugin behavior from subdirectory CLAUDE.md imports.
```

```markdown
<!-- GEMINI.md -->
@AGENTS.md

## Gemini CLI

Prefer skills over always-loaded context.
Use bundled skills for task-specific workflows.
```

### 5.2 Skills

Purpose:

```text
Repeatable workflow knowledge loaded on demand.
```

Use for:

```text
planning workflows
TDD workflows
debugging loops
code review checklists
staging QA
safe refactoring
release preparation
language/framework conventions
deployment procedures
```

Do not use for:

```text
global personality
broad reasoning style
runtime permission policy
MCP config
hook config
agent persona
tool-specific commands
```

Important correction:

```text
A skill is not deterministic by itself.
A skill is procedural guidance.
Scripts inside a skill can be deterministic.
Verification steps inside a skill make outcomes more reliable.
```

### 5.3 Agents / subagents

Purpose:

```text
Delegated roles for isolated exploration, critique, and investigation.
```

Use for:

```text
large codebase exploration
root-cause analysis
security review
architecture review
parallel read-only investigation
returning a concise summary to the main session
```

Do not use for:

```text
shared deterministic automation
release-critical behavior that must be identical for all users
simple one-shot commands
global project rules
```

Rule of thumb:

```text
If the task is a repeatable procedure, write a skill.
If the task is open-ended investigation or critique, use a subagent.
If the task is deterministic and mechanical, write a script.
If the task needs external systems, add MCP.
If the task must block unsafe behavior, add a target-native hook or permission rule.
```

## 6. Portable skill profile

Portable `skills/<name>/SKILL.md` files may use only:

```text
name
description
license
compatibility
metadata
```

Constraints:

```text
name:
  required
  must match parent directory
  lowercase letters, numbers, and hyphens only
  no leading or trailing hyphen
  no consecutive hyphens

description:
  required
  describes what the skill does and when to use it
  should include explicit trigger phrases

license:
  optional string

compatibility:
  optional string
  use only for real environment requirements

metadata:
  optional map
  values should be strings where possible
```

Rejected in portable skills:

```text
allowed-tools
disable-model-invocation
user-invocable
argument-hint
arguments
paths
hooks
context
agent
model
effort
tools
disallowedTools
mcpServers
permissionMode
isolation
shell
${CLAUDE_PLUGIN_ROOT}
${CLAUDE_SKILL_DIR}
${extensionPath}
${workspacePath}
!`...`
!{...}
```

Reason:

```text
These fields or syntaxes are target-specific, experimental, or imply runtime behavior that is not portable.
```

## 7. Portable skill example

```markdown
---
name: review-pr
description: Review pull requests and local diffs for correctness, regressions, missing tests, security issues, and risky architecture changes. Use when asked to review a PR, inspect a diff, audit changes, or prepare review feedback.
license: MIT
compatibility: Requires git for optional diff inspection.
metadata:
  owner: platform-engineering
---

# Review pull request

Use this skill to review a pull request, local diff, or proposed patch.

## Process

1. Identify the changed files and intended behavior.
2. Look for correctness, security, migration, compatibility, and test-risk issues.
3. Prefer evidence-backed comments with file paths and concrete failure modes.
4. Distinguish blocking issues from suggestions.
5. Do not invent findings. If evidence is insufficient, say so.

## Verification

Before finalizing:

1. Confirm every finding has file-path evidence.
2. Confirm each blocking issue has a plausible failure mode.
3. Check whether relevant tests exist or are missing.
4. If the review is based on incomplete context, state what was not inspected.

## References

Use these references when relevant:

- `references/review-rubric.md`
- `references/security-checklist.md`

## Helper scripts

Helper scripts live under `scripts/`.

Use relative paths from the skill directory. Do not use tool-specific plugin-root variables.
```

## 8. Target-specific skills

If a skill requires target behavior, fork it explicitly:

```text
target-skills/
├── claude/
│   └── review-pr/
│       └── SKILL.md
├── codex/
│   └── review-pr/
│       └── SKILL.md
└── gemini/
    └── review-pr/
        └── SKILL.md
```

A fork must include metadata:

```yaml
metadata:
  forked-from: skills/review-pr
  forked-from-hash: sha256-...
  fork-reason: Uses Claude dynamic context injection and allowed-tools preapproval.
```

Rules:

```text
No silent overlays.
No hidden target-specific behavior in portable skills.
No automatic rewriting of portable SKILL.md into target-specific variants.
```

## 9. Recommended engineering skill catalog

These are recommended starting skills for general software engineering. Names are suggestions, not mandatory.

### 9.1 `plan-feature`

Purpose:

```text
Turn a vague feature request into a scoped plan before editing code.
```

Should include:

```text
requirements clarification
constraints
assumptions
affected modules
test plan
migration plan
rollback plan
open questions
```

Should not include:

```text
automatic code edits
tool-specific plan mode fields
```

### 9.2 `tdd-cycle`

Purpose:

```text
Guide implementation through red, green, refactor.
```

Should include:

```text
write or update a failing test first
run the smallest relevant test
implement the minimal change
run the test again
refactor only after green
run broader tests before completion
```

### 9.3 `diagnose-bug`

Purpose:

```text
Prevent speculative debugging.
```

Should include:

```text
reproduce
minimize
hypothesize
instrument
fix
regression-test
explain root cause
```

### 9.4 `review-pr`

Purpose:

```text
Review a PR or diff for correctness, regressions, tests, security, and maintainability.
```

Should include:

```text
evidence-backed findings
severity categories
non-findings section when no issue is found
test coverage assessment
risk assessment
```

### 9.5 `qa-staging`

Purpose:

```text
Perform structured QA against a staging URL or local app.
```

Should include:

```text
test matrix
happy paths
edge cases
accessibility checks
screenshot or trace capture where tool-supported
regression test suggestions
```

Browser automation is target-specific. Keep the portable skill as procedure only; put Playwright scripts or browser-MCP wiring in target-native config or optional scripts.

### 9.6 `refactor-safely`

Purpose:

```text
Improve code structure without changing behavior.
```

Should include:

```text
characterization tests first
small refactoring steps
no behavior changes unless explicitly requested
run tests after each step or batch
summarize before/after structure
```

### 9.7 `ship-pr`

Purpose:

```text
Prepare changes for review or release.
```

Should include:

```text
sync branch
run tests
check generated files
check migrations
prepare commit message
prepare PR summary
document risks and follow-ups
```

Any actual push, release, deploy, or production-impacting action must be target-native and permission-gated.

### 9.8 Stack-specific skills

Examples:

```text
modern-python
typescript-react
go-service
rust-crate
nix-flake
angular-i18n
cloudflare-workers
netlify-deploy
postgres-debugging
```

Stack-specific skills should encode real team conventions:

```text
preferred tools
test commands
lint commands
file layout
migration rules
deployment steps
known pitfalls
verification steps
```

Avoid generic language advice. A `modern-python` skill is useful only if it says exactly how this repo uses `uv`, `ruff`, `pytest`, type checking, dependency management, and packaging.

## 10. Skill evaluation

Every serious skill should include verification in the skill body and formal evals in `evals/`.

```text
evals/
└── skills/
    └── review-pr/
        ├── cases.yaml
        ├── fixtures/
        └── rubric.md
```

Example `cases.yaml` shape:

```yaml
cases:
  - id: missing-regression-test
    fixture: fixtures/missing-regression-test
    prompt: Review this diff.
    expected:
      must_find:
        - Missing regression test for changed validation behavior.
      must_not_claim:
        - SQL injection
        - authentication bypass
```

Rubric dimensions:

```text
triggering:
  Did the tool select the skill when appropriate?

procedure adherence:
  Did it follow the workflow?

evidence:
  Did it cite concrete files, diffs, or observations?

correctness:
  Were the findings true?

false positives:
  Did it invent issues?

verification:
  Did it run or request the relevant checks?

portability:
  Did it avoid target-specific assumptions?
```

Evaluation levels:

```text
Level 0: Human review of SKILL.md
Level 1: Static lint and frontmatter validation
Level 2: Fixture-based prompt tests
Level 3: Target smoke tests in Claude, Codex, and Gemini
Level 4: Regression suite from historical failures
Level 5: External benchmark integration if needed
```

## 11. Skill iteration loop

When an agent fails, do not immediately patch only the generated code. First decide whether the process failed.

Use this loop:

```text
1. Record the failure in failure-log/.
2. Classify the failure:
   - missing context
   - noisy context
   - wrong skill trigger
   - incomplete procedure
   - missing verification
   - target-specific behavior leak
   - tool permission issue
   - MCP/hook/config issue
3. Update the smallest durable artifact:
   - AGENTS.md for always-needed facts
   - SKILL.md for repeatable procedure
   - references/ for task-specific docs
   - scripts/ for deterministic repeated logic
   - agent instructions for role behavior
   - target-native config for tool behavior
4. Add or update an eval case.
5. Re-run validation and smoke tests.
```

If the same correction is given twice, it should become one of:

```text
a root context rule
a skill instruction
a reference note
a script
an eval case
a target-native config change
```

## 12. Meta-skills

Optional repository-maintenance skills may exist, but they must follow the same portability rules.

Useful meta-skills:

```text
skill-improver
skill-extractor
eval-writer
failure-analyzer
```

### 12.1 `skill-improver`

Purpose:

```text
Review an existing skill against lint rules, failure logs, and eval results.
```

Should not automatically rewrite target-specific forks without explicit approval.

### 12.2 `skill-extractor`

Purpose:

```text
Convert a successful manual workflow into a reusable skill.
```

Should produce:

```text
draft SKILL.md
references/
optional scripts/
eval case
failure modes
```

## 13. Agents

Agents are shared only where native formats are close enough.

Claude and Gemini can share Markdown only under a strict intersection profile:

```text
agents/reviewer.md
```

Codex gets TOML:

```text
agents/reviewer.codex.toml
```

### 13.1 Shared Claude/Gemini Markdown agent

Allowed shared frontmatter:

```yaml
name: reviewer
description: Reviews pull requests for correctness, security, regressions, and missing tests.
```

Rejected in shared Markdown agents unless split by target:

```text
tools
disallowedTools
model
mcpServers
hooks
permissionMode
skills
memory
background
isolation
effort
color
initialPrompt
```

Example:

```markdown
---
name: reviewer
description: Reviews pull requests for correctness, security, regressions, and missing tests.
---

Review code like an owner.

Prioritize:

- correctness
- security
- behavior regressions
- missing tests
- risky migrations

Do not modify files. Return findings with evidence and file paths.
```

### 13.2 Codex TOML agent

```toml
name = "reviewer"
description = "Reviews pull requests for correctness, security, regressions, and missing tests."

developer_instructions = """
Review code like an owner.

Prioritize:

- correctness
- security
- behavior regressions
- missing tests
- risky migrations

Do not modify files. Return findings with evidence and file paths.
"""

sandbox_mode = "read-only"
```

### 13.3 Drift detection

CI compares:

```text
agents/reviewer.md body
agents/reviewer.codex.toml developer_instructions
```

If they diverge, the Codex TOML must contain:

```toml
# divergence-ok: <reason>
```

without which CI fails.

### 13.4 Subagent use rules

Use subagents for:

```text
large codebase exploration
independent review
root-cause investigation
security audit
parallel read-only research
```

Avoid subagents for:

```text
single-file edits
shared deterministic workflows
tasks that require multiple agents editing the same files at once
production-impacting operations
```

Parallel subagents must be read-only unless there is an explicit worktree/isolation plan.

## 14. Commands

Commands are not canonical.

Use skills as the primary invocation model.

Gemini may need TOML command wrappers because its custom command system is target-native.

```text
plugins/code-review/gemini/commands/review/pr.toml
```

Example:

```toml
description = "Review the current pull request using the review-pr skill."
prompt = """
Use the review-pr skill to review the current pull request or local diff.

Focus on correctness, security, regressions, and missing tests.
"""
```

Claude and Codex should usually rely on skill invocation unless there is a proven target-specific need.

Rejected:

```text
commands/review-pr/command.yaml
catalog/commands/
canonical command compiler
```

## 15. Hooks

Hooks are target-native.

Shared hook implementation code may live here:

```text
hooks/no-secrets/no-secrets.sh
```

Hook config lives here:

```text
plugins/code-review/claude/hooks/hooks.json
plugins/code-review/codex/hooks/hooks.json
plugins/code-review/gemini/hooks/hooks.json
```

Do not define:

```text
hook.yaml
canonical hook schema
cross-tool hook compiler
```

Hooks should be used for deterministic non-negotiables:

```text
block secrets
block writes to generated output
run formatting after edits
run lightweight validation
cap dangerous tool outputs
emit audit logs
```

Hooks should not be used to hide broad agent behavior rules that belong in skills or root context.

## 16. MCP servers

Shared MCP server implementation code may live here:

```text
servers/github-context/
servers/issue-tracker-context/
servers/telemetry-context/
servers/database-context/
```

MCP configuration is target-native:

```text
plugins/code-review/claude/.mcp.json
plugins/code-review/codex/.mcp.json
plugins/code-review/gemini/gemini-extension.json
```

Do not define:

```text
mcp.yaml
canonical MCP manifest
cross-tool MCP config compiler
```

MCP safety rules:

```text
Use least privilege.
Prefer read-only servers first.
Do not expose production write tools by default.
Paginate large outputs.
Prefer search/list/read workflows over bulk dumps.
Keep credentials out of committed config.
Smoke-test every server startup.
Document prompt-injection risks for tools that fetch untrusted content.
```

Recommended MCP categories:

```text
GitHub or GitLab:
  issues, PRs, commits, reviews

Linear or Jira:
  tickets, requirements, planning context

Sentry or Datadog:
  production errors, traces, logs

PostgreSQL or Supabase:
  schema and read-only diagnostic queries

Docs search:
  internal docs, API docs, runbooks
```

## 17. Runtime permissions and safeguards

There is no `policy.yaml`.

Runtime policy is target-native:

```text
Claude:
  permissions settings
  permission modes
  auto mode where appropriate
  sandboxing where available
  hooks

Codex:
  sandbox and approval settings
  custom agent config
  plugin availability policy
  hooks where supported

Gemini:
  settings
  excludeTools
  policy engine
  hooks
  extension trust controls
```

Important:

```text
Auto-approval is not a portable safety guarantee.
A classifier-based auto mode is convenience, not proof of safety.
Use isolated environments for long-running autonomous work.
Production deploys, migrations, IAM changes, force-pushes, and destructive data operations require explicit human review.
```

The validator may emit a capability matrix, but it must not claim cross-tool enforcement unless smoke tests verify it.

Example:

```text
Plugin: engineering-workflows
Skill: ship-pr

Portable format:
  yes

Portable behavior:
  limited

Runtime guarantees:
  Claude:
    plan mode recommended before release tasks
    auto mode allowed only in isolated environment
    deploy commands require explicit approval

  Codex:
    sandbox required for local automation
    branch push permitted only by target-native config

  Gemini:
    extension policy cannot auto-allow risky actions
    release command is prompt-only unless target-native scripts are installed
```

## 18. Plugins

A plugin is a distribution unit, not the source of workflow logic.

Example:

```text
plugins/engineering-workflows/
├── README.md
├── CHANGELOG.md
├── skills.txt
├── agents.txt
├── claude/
│   ├── .claude-plugin/
│   │   └── plugin.json
│   ├── .mcp.json
│   └── hooks/
│       └── hooks.json
├── codex/
│   ├── .codex-plugin/
│   │   └── plugin.json
│   ├── .mcp.json
│   └── hooks/
│       └── hooks.json
└── gemini/
    ├── gemini-extension.json
    ├── commands/
    │   └── review/
    │       └── pr.toml
    └── hooks/
        └── hooks.json
```

### 18.1 `skills.txt`

```text
plan-feature
tdd-cycle
diagnose-bug
review-pr
qa-staging
refactor-safely
ship-pr
```

### 18.2 `agents.txt`

```text
reviewer
explorer
debugger
```

The packager maps names to target outputs.

## 19. Target package outputs

### 19.1 Claude

```text
dist/claude/engineering-workflows/
├── .claude-plugin/
│   └── plugin.json
├── README.md
├── CHANGELOG.md
├── skills/
├── agents/
├── hooks/
│   └── hooks.json
├── .mcp.json
├── SKILLS.lock
└── AGENTS.lock
```

### 19.2 Codex

Safer default:

```text
dist/codex/engineering-workflows/
├── plugin/
│   ├── .codex-plugin/
│   │   └── plugin.json
│   ├── README.md
│   ├── CHANGELOG.md
│   ├── skills/
│   ├── hooks/
│   │   └── hooks.json
│   └── .mcp.json
├── project-config/
│   └── .codex/
│       └── agents/
│           └── reviewer.toml
├── SKILLS.lock
└── AGENTS.lock
```

Do not assume Codex plugin installation installs custom agents unless documented and smoke-tested.

### 19.3 Gemini

```text
dist/gemini/engineering-workflows/
├── gemini-extension.json
├── README.md
├── CHANGELOG.md
├── GEMINI.md
├── skills/
├── agents/
├── commands/
├── hooks/
│   └── hooks.json
├── SKILLS.lock
└── AGENTS.lock
```

## 20. Versioning and locks

Plugin version is the installable artifact version.

Every package must include:

```text
SKILLS.lock
AGENTS.lock
```

Example:

```toml
plugin = "engineering-workflows"
version = "0.1.0"
target = "claude"

[skills]
plan-feature = "sha256-..."
tdd-cycle = "sha256-..."
diagnose-bug = "sha256-..."
review-pr = "sha256-..."
```

Version bump rule:

```text
Any changed packaged skill hash requires plugin version bump.
Any changed packaged agent hash requires plugin version bump.
Any changed hook, MCP config, target manifest, command, or wrapper requires plugin version bump.
```

Duplicate skill rule:

```text
If the same skill appears in multiple plugins, the source hash must match unless an explicit different revision or target-specific fork is declared.
```

## 21. Validation

`scripts/validate.py` performs:

```text
1. Agent Skills spec validation.
2. Portable frontmatter lint.
3. Rejection of target-specific fields in portable skills.
4. Rejection of target-specific path variables in portable skills.
5. Script existence and executable-bit checks.
6. shellcheck for shell scripts.
7. Plugin skills.txt and agents.txt existence checks.
8. Agent frontmatter checks.
9. Agent drift detection.
10. Target manifest parse checks.
11. Lock-file checks.
12. Version bump checks.
13. Behavioral portability report generation.
14. Target-native smoke test dispatch.
```

## 22. Packaging

`scripts/package.py` does only:

```text
copy
stage
hash
lock
validate
```

It does not:

```text
semantically compile skills
rewrite portable skills into target-specific skills
translate permissions
translate hooks
translate MCP configs
generate universal commands
```

## 23. Context and session operating guide

This belongs in `docs/operator-guide.md`, not in the portable spec.

Recommended guidance:

```text
Use a fresh session for unrelated tasks.
Clear context between distinct tasks.
Stop after repeated correction loops and restart with a sharper prompt.
Compact only when history is still useful.
Delegate large read-only investigations to subagents.
Use skills instead of pasting long procedural prompts.
Use MCP only when the task needs external systems.
Avoid dumping huge logs or schemas into chat.
```

Tool-specific examples are allowed in the operator guide:

```text
Claude:
  /clear
  /compact
  /btw
  /rewind
  /plan
  /permissions
  /mcp

Gemini:
  /memory show
  /memory reload
  custom commands under .gemini/commands
  context.fileName to include AGENTS.md

Codex:
  AGENTS.md instruction chain
  custom agents under .codex/agents or Codex home
  skills and plugins
```

Do not encode these commands into portable skills unless the skill is target-specific.

## 24. Manual spike

Before implementing automation, hand-author one plugin package for all three tools:

```text
scratch/
├── claude-engineering-workflows/
├── codex-engineering-workflows/
└── gemini-engineering-workflows/
```

Test:

```text
install package
list skills
invoke review-pr
invoke diagnose-bug
invoke tdd-cycle
run optional helper script
invoke reviewer subagent
run Gemini command wrapper
start MCP server if configured
trigger hook if configured
verify lock hashes
```

Only automate the pain observed in this manual spike.

## 25. Implementation order

```text
1. Hand-author engineering-workflows for Claude, Codex, Gemini.
2. Install and smoke-test all three.
3. Add strict portable skill lint.
4. Add target-specific skill fork support.
5. Add shared Markdown agent plus Codex TOML agent.
6. Add drift detection.
7. Add evals for review-pr and diagnose-bug.
8. Add content hashes and version checks.
9. Add minimal Python packaging.
10. Add behavioral portability report.
11. Add Nix-pinned CI.
12. Add hooks only for deterministic enforcement.
13. Add MCP only where external context is necessary.
14. Add target-specific command wrappers only where they improve UX.
```

## 26. Final position

The v3 architecture is:

```text
Portable:
  skills/<name>/SKILL.md under strict lint

Explicit forks:
  target-skills/<target>/<name>/SKILL.md

Shared with drift detection:
  agents/<name>.md for Claude/Gemini intersection
  agents/<name>.codex.toml for Codex

Target-native:
  plugin manifests
  commands
  hooks
  MCP configs
  runtime permissions
  session commands
  marketplace/release metadata

Operational guidance:
  docs/operator-guide.md
  docs/context-management.md
  docs/skill-authoring-guide.md
  docs/skill-catalog.md

Quality loop:
  evals/
  failure-log/
  smoke tests
  content locks
  version bump enforcement

Rejected:
  skill.yaml
  command.yaml
  policy.yaml
  mcp.yaml
  hook.yaml
  universal agent schema
  semantic compiler
```

## 27. References

- Agent Skills specification: https://agentskills.io/specification
- Claude Code skills: https://code.claude.com/docs/en/skills
- Claude Code best practices: https://code.claude.com/docs/en/best-practices
- Claude Code memory: https://code.claude.com/docs/en/memory
- Claude Code plugins reference: https://code.claude.com/docs/en/plugins-reference
- Claude Code permissions: https://code.claude.com/docs/en/permissions
- Claude Code permission modes: https://code.claude.com/docs/en/permission-modes
- Claude Code MCP: https://code.claude.com/docs/en/mcp
- Codex customization: https://developers.openai.com/codex/concepts/customization
- Codex skills: https://developers.openai.com/codex/skills
- Codex subagents: https://developers.openai.com/codex/subagents
- Codex AGENTS.md: https://developers.openai.com/codex/guides/agents-md
- Gemini CLI extensions: https://google-gemini.github.io/gemini-cli/docs/extensions/
- Gemini CLI extension reference: https://geminicli.com/docs/extensions/reference/
- Gemini CLI custom commands: https://google-gemini.github.io/gemini-cli/docs/cli/custom-commands.html
- Gemini CLI context files: https://geminicli.com/docs/cli/gemini-md/
- Gemini CLI hooks reference: https://geminicli.com/docs/hooks/reference/
- Gemini CLI subagents announcement: https://developers.googleblog.com/subagents-have-arrived-in-gemini-cli/
