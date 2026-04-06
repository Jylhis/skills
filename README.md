# jstack

Opinionated workflow system for AI-assisted software engineering.

Inspired by gstack, obra/superpowers, and github spec-kit.

## Why this exists

I don't have enough hours in a day to work a full-time job and build my side projects. So I created jstack to reclaim that time.

jstack turns Claude Code into a virtual team. A CEO who thinks about the product. An engineer who locks the architecture. A designer who catches AI slop. A reviewer who finds bugs. A security officer who runs audits. A release engineer who ships the PR. Software engineers and specialists who do the work.

This is my software factory. I use it every day.

I want to encode my thinking and automate as much as possible. How I would run a company, the culture, how to work, how to design products I would actually use, how to do it efficiently, what metrics to track. A virtual software engineering shop.

## Who this is for

- Me
- Software engineers who think wider than just code, about the whole product and company

## Quick start

1. Install jstack (see [Installation](#installation))
2. /what? initialize new project
  - Run `/onboard` to reverse-engineer artifacts from an existing project
3. Run `/brainstorm` on any new feature idea
4. Run `/plan` TODO: what would better name that doesn't conflict?
5. Run `/implement` to build it
6. Run `/review` to catch issues before shipping
7. Run `/ship` to create the PR

## How it works

### Skills are prompt documents, not code

Each skill lives in `skills/<name>/SKILL.md`. These are prompt templates that Claude reads and executes. There is no build step. Edit the SKILL.md directly to change behavior.

## Installation

**Requirements:** Claude Code, Nix, Git

### Claude Code marketplace

Coming soon.

### AI-assisted

Tell your assistant:

> Fetch and follow instructions from https://raw.githubusercontent.com/Jylhis/jstack/refs/heads/main/INSTALL.md

### Manual

1. Clone the repository:
   ```bash
   git clone https://github.com/Jylhis/jstack.git
   ```
2. Add jstack as a Claude Code plugin by referencing the `.claude-plugin/` directory
3. Verify the installation (see below)

### Verify installation

Run any jstack command like `/onboard` in Claude Code. If it loads the skill and responds, you're set.

## What's inside

```
skills/           # Each subdirectory has one SKILL.md
lib/              # Shared context (preamble, constitution, artifacts, auto-detect)
.claude-plugin/   # Plugin distribution metadata
ETHOS.md          # Builder philosophy
```

## Philosophy

A single person with AI can now build what used to take a team of twenty. The engineering barrier is gone.

Five core principles drive jstack:

1. **Boil the lake.** AI makes completeness nearly free. When complete implementation costs minutes more than a shortcut, do the complete thing. 100% test coverage, all edge cases handled, every path tested. Those are boilable lakes. Full rewrites and multi-quarter migrations are oceans. Know the difference.

2. **Search before building.** Before designing solutions with unfamiliar patterns, search for runtime and framework built-ins first. Prefer tried-and-true over new-and-popular. Scrutinize Layer 2 knowledge. Build from first principles only when you must.

3. **Spec before code.** Understand what you're building before you build it.

4. **Test-driven by default.** Tests before implementation. RED-GREEN-REFACTOR. Every behavior has a test. Every bug fix includes a regression test.

5. **Review before ship.** Someone (or something) other than the author checks the work.

## Contributing

This project is open source under the MIT license. Contributions are welcome.

Skills are markdown files, not code. To add or modify a skill, edit the SKILL.md directly. Follow the voice rules: direct, concrete, no AI vocabulary, no em dashes.

Development uses Bun for testing (`bun test`) and Nix via devenv for the environment. Commits follow the [Conventional Commits](https://www.conventionalcommits.org/en/v1.0.0/) style.

## Updating

Run `/jstack-upgrade` to update to the latest version.

## License

MIT. See [LICENSE](LICENSE) for details.
