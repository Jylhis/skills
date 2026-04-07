# jstack — claude-config

Personal Claude Code configuration: skills, agents, slash commands, hooks,
settings, and a vendored set of upstream plugin collections. Installed into
`~/.claude/` via a symlink-based `install.bash` script.

## Layout

```
.
├── settings.json              # source of truth for ~/.claude/settings.json
├── CLAUDE.md                  # source of truth for ~/.claude/CLAUDE.md
├── skills/                    # personal skills (dir-per-skill, SKILL.md inside)
├── agents/                    # personal subagent .md files
├── commands/                  # personal slash command .md files
├── hooks/                     # hook scripts referenced from settings.json
├── plugins/
│   ├── .marker                # sentinel for the vendored layout
│   └── jstack-vendored/       # symlinks into vendor/<name>/plugin
├── vendor/                    # git submodules (upstream plugin sources)
├── runtime/default.nix        # pkgs.buildEnv with MCP servers, LSPs
├── evals/                     # promptfoo eval suite
└── scripts/
    ├── install.bash           # link the repo into ~/.claude, build runtime
    ├── eval.bash              # run promptfoo (--fast for routing only)
    └── bump-vendor.bash       # ff submodules, run evals, commit
```

## Install

Run inside a devenv shell (or anywhere `nix-build`, `git`, and `awk` are on PATH):

```bash
bash scripts/install.bash --dry-run     # preview
bash scripts/install.bash               # apply
exec zsh                                # pick up the PATH change
```

The install is idempotent — re-running reports zero actions if nothing changed.
A timestamped backup of any displaced files lands in
`~/.claude/.claude-config-backups/<timestamp>/` along with a `RESTORE.md`.

### First-run prerequisites

If `~/.claude/settings.json` or `~/.claude/CLAUDE.md` is currently a symlink
into the nix store (managed by an existing home-manager module), `install.bash`
will replace it but the home-manager module will fight back on the next
`home-manager switch`. Disable the module out-of-band first:

1. Remove `programs.claude-config.enable = true;` (or equivalent) from your
   home-manager configuration
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

## Marketplace UI conflict

After migration, `~/.claude/plugins/` is a symlink into this repo. If you
install a plugin via Claude Code's marketplace UI (`/plugin install foo`),
it will write into the symlinked directory — files will appear in
`git status`. The next `install.bash` run will warn about unexpected dirs
under `plugins/`.

Either commit the new plugin to the repo, revert it, or vendor it properly
as a git submodule under `vendor/`.

## Bumping vendored plugins

```bash
bash scripts/bump-vendor.bash
```

This fast-forwards every submodule under `vendor/` to its remote default
branch, runs the full eval suite, and commits the bumped pointers only if
evals pass. On failure the working tree is left as-is for inspection.
