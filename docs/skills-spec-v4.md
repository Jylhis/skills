# Cross-Tool Agent Skills Repository Spec — v4

> **Status: current target spec.** Supersedes `docs/skills-spec-v3.md` (retained
> for history). v4 retargets the repo, adds the custom-tools taxonomy and the
> role-forward marketplace model, and reconciles the spec with what is actually
> on disk. Sections are tagged **[Implemented]**, **[Planned]**, or **[Dropped]**.

## 1. What changed in v4

1. **Targets changed.** OpenAI Codex is **dropped**. The repo now targets:
   - **Claude Code** — the CLI *and* Claude Code on the web (code.claude.com
     sessions). Both consume the same `.claude-plugin/marketplace.json`.
   - **Pi** — `pi-coding-agent` (`earendil-works/pi`), a provider-agnostic CLI
     with a first-class `SKILL.md` mechanism.
   - **claude.ai Skills** — the claude.ai chat app's Skills feature, fed
     per-skill `.zip` uploads.
2. **Custom tools are first-class.** v3 left MCP/tools as a vague future. v4
   defines a four-way taxonomy (bundled CLI · Agent-SDK tool · MCP server ·
   subagent/command) with a decision tree and a per-target support matrix.
3. **Role-forward marketplace.** The primary *published/installed* unit becomes a
   role plugin, composed from the shared canonical skill pool. The canonical
   `skills/<category>/<name>/` tree stays the source of truth (skills are never
   physically moved).
4. **Spec reconciled with disk.** v3 referenced `flake.nix`, root `agents/`,
   `target-skills/`, `failure-log/`, packaging/locks that were never built. v4
   uses `devenv.nix`, the real `plugins/` layout, and marks the rest as planned.

The guiding rule is unchanged:

```text
Portable format is possible.
Portable behavior is not assumed.
Target-native runtime behavior must stay target-native.
```

## 2. Targets and capability matrix

| Capability | Claude Code (CLI + web) | Pi (`pi-coding-agent`) | claude.ai Skills |
|---|---|---|---|
| Portable `SKILL.md` | ✅ via plugin marketplace | ✅ auto-discovered under `~/.pi/agent/skills/` | ✅ per-skill `.zip` |
| Distribution | `.claude-plugin/marketplace.json` | `install.sh` mirrors skills + links `AGENTS.md` | upload `.zip` (Settings → Capabilities → Skills) |
| Project context | `CLAUDE.md` / `@AGENTS.md` | `~/.pi/agent/AGENTS.md`, `.pi/AGENTS.md` | n/a (skill body only) |
| MCP servers | ✅ `.mcp.json` (plugin/user/project) | ✅ via `~/.pi/agent/mcp.json` (extension) | ❌ skills-only |
| In-process custom tools | ✅ Claude Agent SDK | ✅ Pi TS extensions | ❌ |
| Subagents | ✅ plugin `agents/` | ⚠️ community extension | ❌ |
| Slash commands | ✅ plugin `commands/` | ✅ extension-registered | ❌ |
| Hooks | ✅ plugin `hooks/` | ⚠️ extension events | ❌ |
| LSP | ✅ plugin `.lsp.json` | ❌ | ❌ |

`✅` native · `⚠️` available via an extension/community add-on · `❌` unsupported.

**Implication for the portable core:** the strictest target is claude.ai Skills
(skills-only, must be self-contained). A portable `SKILL.md` that is
self-contained and free of target-specific frontmatter runs everywhere; anything
beyond a skill (tools, hooks, LSP, subagents) is a target-native overlay that
never enters the portable lint surface.

## 3. Repository layout (reconciled) **[Implemented unless noted]**

```text
repo/
├── devenv.nix, devenv.yaml, .envrc       # dev shell (NOT flake.nix)
├── justfile                              # check / validate / install / package / eval*
├── README.md
├── AGENTS.md, CLAUDE.md                  # always-loaded context (CLAUDE.md imports AGENTS.md)
│
├── skills/<category>/<name>/             # canonical portable skill pool (source of truth)
│   ├── SKILL.md
│   ├── references/  scripts/  assets/    # optional, on-demand
│   └── evals/                            # cases.yaml + golden cassettes (not shipped)
│
├── plugins/<plugin>/                     # distribution units (Claude Code)
│   ├── .claude-plugin/plugin.json        # the ONLY per-plugin manifest now
│   ├── skills/<name> -> ../../../skills/<category>/<name>   # symlink farm
│   ├── agents/  commands/                # default plugin only
│   ├── .lsp.json                         # language plugins only
│   └── .mcp.json                         # [Planned] per-plugin MCP wiring
│
├── plugins/jylhis-role-<role>/           # [Planned] role plugins composing the pool
│
├── servers/<name>/                       # [Planned] shared MCP server implementations
├── tools/<name>/                         # [Planned] Claude Agent SDK in-process tools
├── extensions/<name>/                    # [Planned] Pi-native TS extensions
│
├── meta/<name>/                          # repo-only maintenance skills (not shipped)
├── upstream/                             # upstream-tracker manifest + decision logs
├── evals/                                # promptfoo harness (providers: claude, pi, stub)
├── docs/                                 # this spec, install, authoring, migrations…
├── scripts/                              # install.sh, validate.py, package-skill.py, …
└── dist/skills/<name>.zip                # generated by `just package`; gitignored
```

`.claude-plugin/marketplace.json` is the single marketplace manifest (Codex's
`.agents/plugins/marketplace.json` was removed). Pi has no marketplace file — it
discovers skills from a directory that `install.sh` populates.

## 4. Portable skill profile **[Implemented]**

Unchanged from v3 §6 and enforced by `scripts/validate.py`. Allowed frontmatter:
`name`, `description`, `license`, `compatibility`, `metadata`. Rejected:
target-specific keys (`allowed-tools`, `mcpServers`, `hooks`, `model`, …) and
target path variables (`${CLAUDE_PLUGIN_ROOT}`, `` !`…` ``, …).

Note on Pi: Pi *accepts* `allowed-tools` and `disable-model-invocation` in
frontmatter. We still keep these OUT of the portable core — a skill that needs
them is a target-native overlay, not a portable skill. This keeps one skill body
valid across all three targets, claude.ai included.

**Self-containment (claude.ai constraint):** a portable skill must reference only
files inside its own directory (its `scripts/`, `references/`, `assets/`), so it
survives being zipped in isolation. `just package` is the packaging path; a
self-containment lint is **[Planned]** in `validate.py`.

## 5. Custom tools taxonomy **[Planned scaffolding; design current]**

Four ways to ship a capability beyond a skill. Pick the lowest-friction one that
fits, by this decision tree:

```text
Needs an external system (GitHub, DB, telemetry) or sharing across clients?
  └─ yes → MCP server            (servers/<name>/ + target-native .mcp.json / Pi mcp.json)
Needs to run in-process with agent state, shipped as a runnable app/library?
  └─ yes → Agent SDK tool        (tools/<name>/, claude-agent-sdk @tool / create_sdk_mcp_server)
Open-ended investigation / critique / role behavior?
  └─ yes → subagent or command   (plugin agents/ + commands/ ; Pi extension)
Deterministic, mechanical, single-purpose helper?
  └─ yes → bundled CLI script    (skill scripts/ or plugin bin/, nix-run shebang)
```

Per-target homes:

| Kind | Claude Code | Pi | claude.ai |
|---|---|---|---|
| Bundled CLI | skill `scripts/` / plugin `bin/` | skill `scripts/` (mirrored) | skill `scripts/` (zipped) |
| MCP server | plugin/user `.mcp.json` → `servers/<name>` | `~/.pi/agent/mcp.json` → `servers/<name>` | — |
| In-process tool | Claude Agent SDK (`tools/<name>`) | Pi TS extension (`extensions/<name>`) | — |
| Subagent / command | plugin `agents/` + `commands/` | extension | — |

MCP safety rules (carried from v3 §16): least privilege, read-only first, no
production write tools by default, paginate, keep credentials out of committed
config, smoke-test startup, transport `stdio` or Streamable HTTP (SSE is
deprecated per MCP spec 2025-06-18).

A repo meta-skill `meta/tool-creator/` **[Planned]** scaffolds the correct
artifact from a short spec — the "define my own Tools" workflow, sibling to
`meta/skill-creator-lang`.

## 6. Role-forward marketplace **[Planned]**

The marketplace's primary axis becomes the **role**. Roles are composed, not
filed: the canonical `skills/<category>/<name>/` pool is unchanged, and each role
is a `plugins/jylhis-role-<role>/` whose `skills/` farm symlinks the pool.

Recommended role taxonomy (software + knowledge-work):

```text
backend-engineer  security-engineer  data-engineer
platform-engineer frontend-engineer  knowledge-work (PKM/Obsidian)
```

A skill may belong to its technology/practice plugin **and** one or more role
plugins (e.g. `security` ∈ `jylhis-skills-core` and `jylhis-role-security-engineer`).
This requires relaxing `validate.py`'s current "every skill in exactly one
plugin" rule to **"≥1 plugin"**, plus a duplicate rule: the same skill name
across plugins must resolve to the same canonical path. **[Planned]**

Rationale for compose-not-move: ~⅓ of skills are multi-role; physical role
folders would force duplication or arbitrary single-role assignment and break the
"skills are never moved" invariant. Composition matches the shared-pool +
symlink model the repo already uses.

## 7. Distribution & packaging per target **[Implemented]**

- **Claude Code (CLI + web):** `scripts/install.sh` registers this repo as a
  local marketplace and installs `jylhis-skills-core`. Web sessions reuse the
  same marketplace. A `SessionStart` hook to bootstrap web sessions is
  **[Planned]** (see the `session-start-hook` skill).
- **Pi:** `install.sh` mirrors the default plugin's `skills/` into
  `~/.pi/agent/skills/<plugin>/` (real files; symlinks flattened with `rsync
  -aL`) and links `~/.pi/agent/AGENTS.md`. Opt-in plugins are mirrored the same
  way and refreshed on re-run.
- **claude.ai Skills:** `just package` (`scripts/package-skill.py`) writes
  `dist/skills/<name>.zip` per skill, each archived under a single top-level
  `<name>/` directory and self-contained. Upload via Settings → Capabilities.

## 8. Quality loop **[Implemented]**

Eval levels (carried from v3 §10), now over **two** live providers (`claude`,
`pi`) plus the deterministic `stub`:

```text
L0 human review · L1 lint+frontmatter · L2 fixture prompt tests (just eval-stub)
L3 live smoke (just eval) · L4 failure-log regression [Planned] · L5 external [Planned]
```

`evals/` keeps deterministic-first assertions, per-provider trigger metrics (no
cross-provider aggregation), and hash-keyed VCR cassettes for CI replay. The
same-family judge guard still applies (`pi` advertises family `unknown`).

A SkillOpt / "Ralph-loop" scoring layer atop `evals/` + `meta/skill-improver`
(held-out cases, bounded edits gated on score) is **[Planned]**.

## 9. Dropped from v3

```text
OpenAI Codex as a target            .codex-plugin/plugin.json manifests
.agents/plugins/marketplace.json    run_codex.sh / judge_codex.sh eval lanes
flake.nix (use devenv.nix)          universal command/hook/MCP compilers (still rejected)
```

## 10. Implementation order (from here)

```text
1. [done]    Remove Codex surface; retarget docs; spec v4; README.
2. [done]    Pi as a first-class install target (install.sh) + claude.ai packaging.
3. [next]    Self-containment lint; SessionStart hook for Claude Code on web.
4. [next]    Custom-tools scaffolding: servers/, tools/, extensions/, meta/tool-creator.
5. [next]    Role plugins (jylhis-role-*) + validate.py ≥1-plugin relaxation.
6. [later]   Skill-optimization scoring loop; failure-log.
```

## 11. References

- Agent Skills spec: https://agentskills.io/specification
- Claude Code skills / plugins: https://code.claude.com/docs/en/skills ·
  https://code.claude.com/docs/en/plugins-reference ·
  https://code.claude.com/docs/en/plugin-marketplaces
- Claude Agent SDK custom tools: https://code.claude.com/docs/en/agent-sdk/custom-tools
- Model Context Protocol (2025-06-18): https://modelcontextprotocol.io
- Pi (`pi-coding-agent`): https://pi.dev/docs · https://github.com/earendil-works/pi
- Predecessor: `docs/skills-spec-v3.md`; taxonomy notes: `docs/skills-organization-review.md`
