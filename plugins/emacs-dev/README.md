# emacs-dev

Emacs and Elisp development intelligence for jstack: 10 skills covering
modern Elisp conventions, code review, ERT testing, debugging,
keybinding design, help-system introspection, Nix-based Emacs packaging,
major-mode authoring, package publishing, and gptel + MCP integration.

## Contents

- `plugin.nix` — plugin manifest
- `skills/` — 10 skill directories with `SKILL.md`

This plugin is part of [jstack](../../) and is installed into
`~/.claude/plugins/emacs-dev/` automatically by `scripts/install.bash`.
There is no separate install step.

## Skills

| Skill | Description |
|---|---|
| `elisp-conventions` | Modern Elisp coding conventions and API usage |
| `elisp-review` | Code review heuristics, byte-compile warnings, lint |
| `elisp-testing` | ERT tests, fixtures, mocking, batch runs |
| `elisp-major-mode-authoring` | define-derived-mode, font-lock, indent, tree-sitter ts-mode parents |
| `elisp-package-publishing` | MELPA / NonGNU ELPA headers, autoloads, package-lint, releases |
| `emacs-debugging` | init errors, edebug, GC tuning, performance |
| `emacs-introspection` | describe-function, describe-variable, xref, help system |
| `emacs-keybindings` | keymap-set, defvar-keymap, key layers, conflicts |
| `emacs-nix-packaging` | emacsWithPackages, overlays, trivialBuild, nixpkgs integration |
| `emacs-gptel-integration` | gptel + mcp.el wiring; Emacs as MCP client and MCP server |
