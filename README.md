# Jylhis Skills

A curated [Agent Skills](https://agentskills.io) **marketplace** that publishes
one default plugin and several opt-in plugins to **Claude Code**, **Codex**, and
**Google Antigravity**.

- **Default plugin** — `jylhis-skills-core` ships cross-cutting engineering and
  productivity skills (security, ast-grep, semgrep, offline-docs, tdd, diagnose,
  prototype, triage, handoff, humanizer, feature-flags, trunk-based-development,
  …) plus shipped subagents (`@reviewer`, `@explorer`, `@debugger`) and slash
  commands (`/explore`, `/lsp-status`, `/remember-correction`).
- **Opt-in plugins** — per-language, per-service, and per-tool bundles
  (`jylhis-python`, `jylhis-typescript`, `jylhis-go`, `jylhis-jvm`,
  `jylhis-emacs`, `jylhis-nix`, `jylhis-filesystems`, `jylhis-gitlab`,
  `jylhis-terraform`, `jylhis-azure`, `jylhis-obsidian`, `jylhis-grafana`,
  `jylhis-taste`, `jylhis-duckdb`, `jylhis-reverse-engineering`). Language
  plugins also wire a native LSP into Claude Code.

## Install

See **[docs/install.md](docs/install.md)** for full instructions. Quick start:

```sh
just install   # register the marketplace in each tool, install jylhis-skills-core only
```

Then opt into language/tool plugins per the table in the install guide.

## Layout

```
skills/<category>/<name>/SKILL.md   canonical skill source (the source of truth)
plugins/<plugin>/                   per-plugin manifests + skills/ symlinks into skills/
meta/                               repo-only meta skills (not shipped)
docs/                               install guide, authoring guide, specs
evals/                              offline eval harness (no API keys)
scripts/                            validate.py, install.sh
```

The eight skill categories are `engineering`, `languages`, `domains`,
`services`, `stack`, `productivity`, `personal`, and `misc`. Skills are never
copied into plugins — each plugin's `skills/` directory contains relative
symlinks back into the canonical `skills/<category>/<name>/` tree.

## Development

All tooling comes from devenv (`direnv allow` or `devenv shell`):

```sh
just check      # shellcheck + validate.py
just validate   # portable skill lint + plugin-manifest cross-check
just list       # list every SKILL.md
just install    # register marketplace, install the default plugin
```

See **[AGENTS.md](AGENTS.md)** for the full repo conventions and
**[docs/skill-authoring-guide.md](docs/skill-authoring-guide.md)** for how to
write a portable SKILL.md.

## Licensing

This repository adopts skills from several upstream sources under different
licenses (MIT, MPL-2.0, AGPL-3.0); see `upstream/sources.yaml` for per-source
provenance and licenses. A consolidated root `LICENSE`/`NOTICE` is still to be
added — until then, consult each upstream source's license before redistributing
the vendored skills.
