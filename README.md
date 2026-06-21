# Jylhis Skills

A curated Agent Skills marketplace for Claude Code, Codex, and Google
Antigravity.

The default plugin, `jylhis-skills-core`, ships cross-cutting engineering and
productivity skills. Language, service, and tool-specific plugins are available
as opt-in installs from the same marketplace.

## Install

Run the installer from this repository:

```sh
just install
```

The installer registers the marketplace in each supported tool and installs
only the default plugin. Opt-in plugins can then be installed from the
marketplace.

See [docs/install.md](docs/install.md) for full installation instructions.

## Development

Enter the devenv shell, then use the `just` recipes:

```sh
devenv shell
just check
just validate
```

Skills live under `skills/<category>/<name>/SKILL.md`. Plugin directories under
`plugins/` expose symlinks back to those canonical skill directories.

See [docs/skill-authoring-guide.md](docs/skill-authoring-guide.md) for the
portable skill format and authoring rules.
