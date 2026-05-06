# skills

A flat catalogue of [Agent Skills](https://agentskills.io) for Claude
Code, plus a small Nix module to symlink the catalogue into `~/.claude/`.

## Layout

```
skills/                # one directory per skill, each with SKILL.md
staging/               # legacy content awaiting per-skill review
AGENTS.md              # tool-agnostic project context (Claude/Codex/Gemini)
CLAUDE.md GEMINI.md    # thin tool wrappers that import AGENTS.md
modules/default.nix    # NixOS / nix-darwin / Home Manager module
scripts/install.sh     # non-Nix install (symlinks into ~/.claude/)
scripts/validate.py    # portable SKILL.md lint
evals/                 # eval scaffolding (stub — see evals/README.md)
docs/skill-authoring-guide.md  # how to write a portable skill
docs/skills-spec-v3.md         # target architecture spec we are growing into
docs/upstream-sources.md       # parked list of repos to revisit
docs/history/          # archived design docs
```

A skill is a directory containing a `SKILL.md` with YAML frontmatter:

```markdown
---
name: my-skill
description: When to trigger this skill (50–1024 chars).
---

# Body — reference material, examples, best practices.
```

Optional siblings: `scripts/`, `references/`, `assets/`.

## Install

### Plain symlink (no Nix)

```bash
bash scripts/install.sh
```

Symlinks `skills/` → `~/.claude/skills` and `CLAUDE.md` → `~/.claude/CLAUDE.md`.
Idempotent. Backs up any existing files.

### Home Manager / NixOS / nix-darwin

```nix
{
  inputs.skills.url = "github:Jylhis/skills";

  outputs = { self, nixpkgs, home-manager, skills, ... }: {
    homeConfigurations.alice = home-manager.lib.homeManagerConfiguration {
      modules = [
        skills.homeModules.default
        { programs.skills.enable = true; }
      ];
    };
  };
}
```

Module options (all optional):

| Option | Default | Description |
|---|---|---|
| `enable` | `false` | Activate the module. |
| `src` | `./skills` (the flake's own) | Path to a directory of skill subdirectories. |
| `claudeMd` | `./CLAUDE.md` | Path to symlink as `~/.claude/CLAUDE.md`, or `null`. |
| `user` | `null` | Required on NixOS / nix-darwin. Ignored under HM. |
| `livePath` | `null` | HM only: out-of-store symlink to a live checkout. |

## Contributing

Add a skill: create `skills/<name>/SKILL.md` with the frontmatter above.
That's the entire contract. See [`docs/skill-authoring-guide.md`](docs/skill-authoring-guide.md)
for the portability profile and rejected fields.

Promote a skill from `staging/`: `git mv staging/skills/<name> skills/<name>`,
review and update the SKILL.md to current conventions, run
`just validate`, then commit.

## Development

```bash
direnv allow      # or: devenv shell
just              # list available recipes
just check        # nix-instantiate + flake check + statix + deadnix + markdownlint
just fmt          # nixfmt all .nix files
```
