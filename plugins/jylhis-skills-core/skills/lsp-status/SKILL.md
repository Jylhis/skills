---
name: lsp-status
description: Show which language servers shipped by jylhis-* plugins are reachable, and which Nix packages they would fetch on first use. Invoke as /jylhis-skills-core:lsp-status.
allowed-tools: Bash(find:*), Bash(nix:*), Bash(cat:*), Bash(jq:*), Read
---

Report the status of every LSP server registered by an installed `jylhis-*` plugin. Each language plugin (jylhis-nix, jylhis-python, jylhis-typescript, jylhis-go) ships its own `.lsp.json`; this skill discovers them at runtime so the answer reflects only the LSPs the user actually opted into.

Steps:

1. Discover every active `.lsp.json` shipped by a `jylhis-*` plugin. Run:
   ```bash
   find ~/.claude/plugins -name .lsp.json -path '*/jylhis-*' 2>/dev/null
   ```
   If that returns nothing, fall back to the source-repo layout:
   ```bash
   find "$(dirname "${CLAUDE_PLUGIN_ROOT}")" -name .lsp.json -path '*/jylhis-*' 2>/dev/null
   ```
   List the plugin name (e.g. `jylhis-python`) for each file found.

2. For each `.lsp.json`, list every language entry along with its `command` + `args`.

3. For each entry, derive the nixpkgs attribute(s) from the `nix shell nixpkgs#<pkg>` arguments and run:
   ```bash
   nix --extra-experimental-features 'nix-command flakes' eval --raw "nixpkgs#<pkg>.meta.description"
   ```
   to confirm the package resolves. Report PRESENT / MISSING per package.

4. Summarize as a short table: plugin, language, LSP binary, nixpkgs attr(s), status.

5. If any package is MISSING, suggest checking the user's nixpkgs channel pin (`nix registry list | grep nixpkgs`) and offer to swap to a `github:NixOS/nixpkgs/nixos-unstable` reference for that entry.

6. If step 1 finds zero `.lsp.json` files, report that and remind the user that LSPs ship with the language plugins (`jylhis-nix`, `jylhis-python`, `jylhis-typescript`, `jylhis-go`): installing one of those is what registers its LSP.

Do not start the LSP servers from this skill. Claude Code spawns them lazily when an editing tool touches a matching file extension.
