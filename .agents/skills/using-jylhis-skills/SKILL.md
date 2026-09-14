---
name: using-jylhis-skills
description: Routing map for the jylhis skill catalogue as adopted for Devin. Use at the start of a task in any Jylhis repo (j10s, jotain, marchyo, skills) to pick the right skill, when the user asks "which skill should I use for X", "what skills do I have", "list skills", "is there a skill for Y", or when a task touches Nix, Go, TypeScript, Rust, Python, Bash, Terraform/OpenTofu, Emacs Lisp, systemd, ZFS/Btrfs/APFS, security review, frontend design, TDD, debugging, code review, commit messages, or docs.
---

# Using the jylhis skills in Devin

The canonical catalogue lives at `skills/<category>/<name>/SKILL.md` in the
`Jylhis/skills` repo. `.agents/skills/` holds symlinks into that tree so
Devin discovers the subset that is useful for Devin's work (autonomous
coding on `Jylhis/j10s`, `Jylhis/jotain`, `Jylhis/marchyo`, `Jylhis/skills`).
There is one source of truth: edit the file under `skills/`, never the
symlink.

## Routing

| Task involves | Skill |
|---|---|
| Nix, flakes, NixOS, nix-darwin, home-manager, devenv, nixpkgs, overlays | `nix` |
| Go code, `go test`, modules, gopls | `go` |
| TypeScript, Node, Bun, Astro | `typescript` |
| Rust | `rust` |
| Python | `python` |
| Shell scripts, `bash`, POSIX sh | `bash` |
| Terraform, OpenTofu, terranix | `terraform` |
| Emacs Lisp, major modes, ERT, gptel | `emacs` |
| systemd units, timers, journald, service hardening | `systemd` |
| ZFS, Btrfs, APFS, snapshots, replication, backups | `filesystems` |
| Security review of code handling untrusted input, secrets handling | `security` |
| Frontend / landing pages / visual design quality | `taste` |
| Writing tests first, red-green-refactor | `tdd` |
| A failing build, flaky test, or unexplained runtime bug | `diagnose` |
| Reviewing a diff or someone else's PR | `code-review` |
| Deciding whether a comment should exist | `code-comments` |
| Writing a commit message | `commit-messages` |
| README / docs / design docs | `documentation` |
| Branching, short-lived branches, keeping main green | `trunk-based-development` |
| Any coding task, as a bias check against overbuilding | `karpathy-guidelines`, `ponytail` |
| Looking up CLI flags or config on this machine | `offline-docs` |
| Prose that reads like it was generated | `humanizer` |

Umbrella skills (`nix`, `go`, `typescript`, `emacs`, `security`, ...) list
sub-topics in their body; read the matching `references/<topic>.md` before
writing or reviewing code.

Skip skills for trivial one-step tasks. Skill invocation is acceleration,
not a prerequisite.

## Devin-specific notes

These skills were written for Claude Code and Pi. When following them
inside Devin, translate the harness details:

- Git and PR work goes through Devin's builtin git tools, not `gh pr
  create` or plugin slash commands. `commit-messages` and
  `trunk-based-development` still define the content and branching rules.
- The repo's `/remember-correction` slash command and the improvement
  memory JSONL do not exist in a Devin session. To persist a correction,
  propose a Devin knowledge note or a skill update instead.
- Subagent references (`@reviewer`, `@explorer`, `@debugger`) map to
  Devin's own subagents; the review or exploration checklist in the skill
  body is the part that carries over.
- `.lsp.json` LSP wiring is a Claude Code plugin feature. In Devin, run the
  language server or its CLI directly (for example `gopls`, `nixd`,
  `basedpyright`) when a skill's reference assumes one.
- Devin already has a task list, handoff, and memory mechanism, so the
  catalogue's `task-management`, `handoff`, and `memory-management` skills
  are deliberately not adopted here.

## Core operating behaviors

Apply across every skill:

1. State non-obvious assumptions before implementing.
2. On an inconsistency, name the specific confusion and resolve it rather
   than silently picking one reading.
3. Push back with concrete tradeoffs instead of agreeing by default.
4. Prefer simplicity: three similar lines beat a premature abstraction.
5. Do not invent skills or commands that are not listed, and surface
   destructive actions before running them.
6. No em dashes in generated prose (repo output-style rule), and no runs of
   `=` as section dividers.

## Adopting or dropping a skill

Add: create the skill under `skills/<category>/<name>/` with its plugin
manifest entry as `AGENTS.md` describes, then, if Devin should see it,
`ln -s ../../skills/<category>/<name> .agents/skills/<name>`.

Drop: remove only the symlink. `scripts/validate.py` validates the
canonical tree, so `.agents/skills/` needs no manifest bookkeeping.
