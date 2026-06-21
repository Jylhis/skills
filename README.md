# jylhis-skills

A curated [Agent Skills](https://agentskills.io) **marketplace** by Jylhis: a
shared pool of portable `SKILL.md` workflows plus the plugin scaffolding that
ships them to three targets —

- **Claude Code** — the CLI *and* Claude Code on the web (same plugin marketplace).
- **Pi** — [`pi-coding-agent`](https://github.com/earendil-works/pi), a
  provider-agnostic CLI with a first-class skills mechanism.
- **claude.ai Skills** — the claude.ai chat app, via per-skill `.zip` upload.

> Looking for the architecture? See **[`docs/skills-spec-v4.md`](docs/skills-spec-v4.md)**
> (current target spec) and **[`AGENTS.md`](AGENTS.md)** (always-loaded repo
> context). `docs/skills-spec-v3.md` is kept for history.

## Install

```bash
bash scripts/install.sh        # or: just install
```

Idempotent; backs up anything it would overwrite under `~/.skills-backup-<ts>/`.
Pass `--dry-run` to preview. It installs the default plugin
(`jylhis-skills-core`) only — opt-in plugins are registered with the marketplace
and surface in the tool UI but are not installed automatically.

| Target | What the script does |
|---|---|
| Claude Code (CLI + web) | registers a local marketplace and installs `jylhis-skills-core@jylhis-skills` |
| Pi | mirrors the default plugin's skills into `~/.pi/agent/skills/` and links `~/.pi/agent/AGENTS.md` (install `pi` first: `npm i -g @earendil-works/pi-coding-agent`) |
| claude.ai | `just package` → upload `dist/skills/<name>.zip` via Settings → Capabilities → Skills |

Full instructions, opt-in plugins, and scope options: **[`docs/install.md`](docs/install.md)**.

## What's inside

- **`skills/<category>/<name>/`** — the canonical, portable skill pool (source of
  truth). Categories: `engineering`, `languages`, `domains`, `services`,
  `stack`, `productivity`, `personal`, `misc`.
- **`plugins/<plugin>/`** — distribution units for Claude Code. Each has a
  `.claude-plugin/plugin.json` and a `skills/` farm of symlinks into the pool.
  The default plugin also ships subagents (`@reviewer`, `@explorer`,
  `@debugger`) and commands (`/explore`, `/lsp-status`, `/remember-correction`);
  language plugins ship an `.lsp.json`.
- **`meta/`** — repo-only maintenance skills (skill-creator, skill-improver,
  upstream-tracker, …); not shipped to any target.
- **`evals/`** — offline, deterministic-first eval harness (providers: `claude`,
  `pi`, `stub`) with hash-keyed cassettes for CI replay.

## Develop

All tooling comes from [devenv](https://devenv.sh). Enter the shell with
`direnv allow` (or `devenv shell`), then:

```bash
just            # list recipes
just check      # shellcheck + portable skill lint + plugin cross-check
just validate   # portable skill lint only
just list       # list every SKILL.md
just package    # build dist/skills/<name>.zip for claude.ai
just eval-stub  # CI-safe eval smoke (stubbed SUT + judge)
```

Adding a skill, building custom tools (MCP servers, Agent-SDK tools, Pi
extensions, subagents), and the role-forward marketplace plan are all described
in **[`docs/skills-spec-v4.md`](docs/skills-spec-v4.md)** and
**[`docs/skill-authoring-guide.md`](docs/skill-authoring-guide.md)**.

## License

Skills retain their upstream licenses where applicable (tracked in
`upstream/sources.yaml`). See individual skill `license` frontmatter.
