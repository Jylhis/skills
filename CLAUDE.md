# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## What is jstack

Opinionated workflow system for AI-assisted software engineering.
Distributed as a Claude Code plugin via `.claude-plugin/`.

## Development

- **Environment:** Nix via devenv (`devenv shell` or `devenv shell -- <command>`)
- **Commits:** Conventional Commits style (https://www.conventionalcommits.org/en/v1.0.0/)
- **No build step.** Skills are markdown files read directly by Claude.

## Architecture

### Skills are prompt documents, not code

Each skill lives in `skills/<name>/SKILL.md`. These are prompt templates that Claude
reads and executes. Edit the SKILL.md directly to change behavior.

## Project structure

```
skills/           # Each subdirectory has one SKILL.md
.claude-plugin/   # Plugin distribution metadata (plugin.json, marketplace.json)
```

## Writing skills

- Use natural language for logic and state between code blocks
- Don't hardcode branch names, detect dynamically
- Keep bash blocks self-contained
- Express conditionals as English, not nested if/elif/else
- Direct, concrete, no AI vocabulary, no em dashes
