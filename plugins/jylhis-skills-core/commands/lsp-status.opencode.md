---
description: Show which language servers are wired into opencode by jylhis-* plugins, and which Nix packages they would fetch on first use.
---

Report the status of every LSP server registered by jylhis-* plugins for opencode. Language plugins (jylhis-nix, jylhis-python, jylhis-typescript, jylhis-go, jylhis-rust, jylhis-terraform) each ship a `.lsp.json`; the install script converts those into `~/.config/opencode/plugins/jylhis-lsp.ts`, which injects them into opencode's LSP config at startup.

Steps:

1. Locate the generated plugin and its sources:
   ```bash
   cat ~/.config/opencode/plugins/jylhis-lsp.ts 2>/dev/null
   ```
   If that returns nothing, fall back to the source repo checkout:
   ```bash
   find "$(dirname "$(readlink -f ~/.config/opencode/plugins/jylhis-lsp.ts 2>/dev/null)")" -maxdepth 0 2>/dev/null
   rg -l 'extensionToLanguage' <skills-repo>/plugins/*/.lsp.json 2>/dev/null
   ```
   The generated file lists each server with a `// <plugin>` provenance comment; the `.lsp.json` sources carry the same data.

2. For each server entry, list the language key, its `command` + `extensions`, and the plugin it came from.

3. For each entry, derive the nixpkgs attribute(s) from the `nix shell nixpkgs#<pkg>` arguments and run:
   ```bash
   nix --extra-experimental-features 'nix-command flakes' eval --raw "nixpkgs#<pkg>.meta.description"
   ```
   to confirm the package resolves. Report PRESENT / MISSING per package.

4. Summarize as a short table: plugin → language → LSP binary → nixpkgs attr(s) → status.

5. If any package is MISSING, suggest checking the nixpkgs registry pin (`nix registry list | grep nixpkgs`) and offer to swap to a `github:NixOS/nixpkgs/nixos-unstable` reference for that entry.

6. If step 1 finds no generated plugin and no `.lsp.json` sources, report that and remind the user that LSPs ship with the language plugins - installing one and re-running `bash scripts/install.sh` regenerates `jylhis-lsp.ts`.

7. If a server is registered but diagnostics do not appear, remind the user that opencode loads config at startup: regenerate via `scripts/install.sh`, then restart opencode.

Do not start the LSP servers from this command - opencode spawns them lazily when an editing tool touches a matching file extension.
