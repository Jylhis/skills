---
description: Get up to speed on an existing codebase. Use when starting work on an unfamiliar project.
---

# Onboard

Get up to speed on an existing codebase. Produce a clear picture of what the project does, how it is built, and how to work in it.

## Steps

1. Read the project root: README, package manifests, config files, CI config, Dockerfile if present.
2. Run `ls` on top-level directories. Identify where the source, tests, and config live.
3. Identify the tech stack: language, framework, database, build tool, test runner, package manager.
4. Trace the entry point. Follow the main code path to understand what the app actually does.
5. Note conventions: file naming, module structure, commit message style (check `git log --oneline -20`), branching model.
6. List anything surprising, undocumented, or risky (no tests, outdated deps, hardcoded secrets).

## Output

Write a summary covering:
- **What it does**: one paragraph, plain English
- **Tech stack**: languages, frameworks, infra
- **Project structure**: key directories and what lives where
- **How to run it**: build, test, and start commands
- **Conventions**: naming, commits, branching
- **Watch out for**: anything unusual or risky

Ask the user where to save the summary (project root, `.jstack/`, or just print it).
