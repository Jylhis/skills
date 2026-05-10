---
description: Show which language servers shipped by jylhis-skills are reachable, and which Nix packages they would fetch on first use.
allowed-tools: Bash(nix:*), Bash(cat:*), Bash(jq:*), Read
---

Report the status of the LSP servers wired by this plugin's `.lsp.json`.

Steps:

1. Read `${CLAUDE_PLUGIN_ROOT}/.lsp.json` and list every language entry along with its `command` + `args`.
2. For each entry, derive the nixpkgs attribute(s) from the `nix shell nixpkgs#<pkg>` arguments and run `nix --extra-experimental-features 'nix-command flakes' eval --raw "nixpkgs#<pkg>.meta.description"` to confirm the package resolves. Report PRESENT / MISSING per package.
3. Summarize as a short table: language → LSP binary → nixpkgs attr(s) → status.
4. If any package is MISSING, suggest checking the user's nixpkgs channel pin (`nix registry list | grep nixpkgs`) and offer to swap to a `github:NixOS/nixpkgs/nixos-unstable` reference for that entry.

Do not start the LSP servers from this command — Claude Code spawns them lazily when an editing tool touches a matching file extension.
