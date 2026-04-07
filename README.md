# jstack — claude-config

Personal Claude Code configuration: skills, agents, slash commands, hooks,
settings, and plugin bundles. Installed into `~/.claude/` via a
symlink-based `install.bash` script.

The full documentation site lives in [`docs/`](docs/) and is rendered
with [Mintlify](https://mintlify.com). Run `mintlify dev` from inside
`docs/` to preview locally.

## Layout

```
.
├── settings.json              # source of truth for ~/.claude/settings.json
├── CLAUDE.md                  # source of truth for ~/.claude/CLAUDE.md
├── skills/                    # personal skills (dir-per-skill, SKILL.md inside)
├── agents/                    # personal subagent .md files
├── commands/                  # personal slash command .md files
├── hooks/                     # hook scripts referenced from settings.json
├── plugins/                   # one directory per plugin (e.g. plugins/rust-dev/)
├── runtime/default.nix        # pkgs.buildEnv with MCP servers, LSPs
├── evals/                     # promptfoo eval suite
├── docs/                      # Mintlify documentation site (docs.json + .mdx)
└── scripts/
    ├── install.bash           # link the repo into ~/.claude, build runtime
    └── eval.bash              # run promptfoo (--fast for routing only)
```

## Plugin bundles

| Plugin | Skills | What it ships |
|---|---|---|
| [rust-dev](plugins/rust-dev) | 29 | Rust language mechanics, design, domain packs, LSP analyzers |
| [golang-dev](plugins/golang-dev) | 36 | Go idioms, perf, testing, security, observability, samber libraries |
| [nix-dev](plugins/nix-dev) | 7 | Nix language, NixOS modules, flakes, devenv, home-manager + `mcp-nixos` MCP server |
| [productivity](plugins/productivity) | 1 | Weekly session log appender |
| [skill-creator](plugins/skill-creator) | 1 | Anthropic's official skill authoring + eval framework |
| [obsidian](plugins/obsidian) | 5 | Obsidian markdown, canvas, bases, CLI, web extraction |

## Install

Run inside a devenv shell (or anywhere `nix-build`, `git`, `awk`, and
`readlink` are on `PATH`):

```bash
bash scripts/install.bash --dry-run     # preview
bash scripts/install.bash               # apply
exec zsh                                # pick up the PATH change
```

The install is idempotent — re-running reports zero actions if nothing
changed. A timestamped backup of any displaced files lands in
`~/.claude/.claude-config-backups/<timestamp>/` along with a
`RESTORE.md`.

### First-run prerequisites

If `~/.claude/settings.json` or `~/.claude/CLAUDE.md` is currently a
symlink into the nix store (managed by an existing home-manager module),
`install.bash` will replace it but the home-manager module will recreate
the link on the next `home-manager switch`. Disable the module
out-of-band first:

1. Remove `programs.claude-config.enable = true;` (or equivalent) from
   your home-manager configuration
2. Run `home-manager switch`
3. Then run `bash scripts/install.bash`

## Develop

```bash
direnv allow                   # enter the devenv shell
lint                           # markdownlint + jq settings.json
eval                           # full promptfoo run
eval-fast                      # routing tests only
install                        # alias for scripts/install.bash
```

## Documentation

The full documentation is in [`docs/`](docs/), rendered with Mintlify:

| Page | Path |
|---|---|
| Project overview | [`docs/index.mdx`](docs/index.mdx) |
| Install | [`docs/install.mdx`](docs/install.mdx) |
| Develop | [`docs/develop.mdx`](docs/develop.mdx) |
| Architecture | [`docs/architecture.mdx`](docs/architecture.mdx) |
| Plugins | [`docs/plugins/`](docs/plugins/) |

To preview locally:

```bash
cd docs
mintlify dev
```

## Marketplace UI conflict

After install, `~/.claude/plugins/` is a symlink into this repo. If you
install a plugin via Claude Code's marketplace UI (`/plugin install foo`),
it will write a new directory under `plugins/` and show up in
`git status`. Either commit the new plugin to the repo or revert it.
