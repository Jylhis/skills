# Nix-Managed System Documentation

Documentation sources specific to systems managed by Nix (NixOS, nix-darwin, Home Manager). These supplement the general Unix documentation described in the parent skill.

## Multi-Tier MANPATH

Nix-managed systems have man pages distributed across multiple locations. The MANPATH includes:

1. **Per-package store paths** -- each Nix package contributes its own `share/man/` directly from `/nix/store/`
2. **User profile** -- `~/.nix-profile/share/man/` or `/etc/profiles/per-user/<name>/share/man/` (Home Manager packages)
3. **System profile** -- `/run/current-system/sw/share/man/` (NixOS or nix-darwin system packages)
4. **Default profile** -- `/nix/var/nix/profiles/default/share/man/`
5. **Base system** -- `/usr/share/man/` (macOS system pages, or distro base on non-NixOS Linux)

Check the full MANPATH:

```bash
man -w
```

`man -w <name>` reveals which store path provides a man page -- useful for understanding which derivation a tool comes from.

## Configuration Reference Man Pages

These are large, auto-generated man pages documenting every available module option. They are the offline equivalent of the NixOS/nix-darwin/Home Manager options search.

| Man page | System | What it covers |
|---|---|---|
| `man 5 configuration.nix` | NixOS or nix-darwin | All module options for the system configuration |
| `man 5 home-configuration.nix` | Home Manager | All Home Manager module options |
| `man 5 nix.conf` | All Nix systems | Nix daemon and client configuration |

These pages are very large (thousands of lines). Always extract specific options rather than reading the whole page:

```bash
# Search for a specific option
man 5 configuration.nix | col -bx | grep -B 2 -A 15 'services\.openssh'

# Search Home Manager options
man 5 home-configuration.nix | col -bx | grep -B 2 -A 15 'programs\.git'

# Search nix.conf options
man 5 nix.conf | col -bx | grep -B 2 -A 10 'experimental-features'
```

## darwin-option (nix-darwin only)

Query nix-darwin module options by dotted path:

```bash
darwin-option <option.path>
```

More targeted than grepping the configuration.nix man page. If it returns empty or fails, fall back to:

```bash
man 5 configuration.nix | col -bx | grep -B 2 -A 15 '<option.path>'
```

## Nix CLI Man Pages

The Nix CLI has ~130 man pages covering every command. Two naming conventions:

**Legacy commands** (stable):
```
nix-build, nix-shell, nix-env, nix-store, nix-instantiate,
nix-channel, nix-collect-garbage, nix-copy-closure, nix-hash,
nix-prefetch-url
```

Subcommands have their own pages: `man nix-env-install`, `man nix-store-query`, `man nix-store-gc`.

**New-style commands** (experimental, prefixed with `nix3-`):
```
nix3-build, nix3-develop, nix3-run, nix3-search, nix3-shell,
nix3-flake-lock, nix3-flake-show, nix3-flake-update,
nix3-profile-install, nix3-profile-list, nix3-store-gc,
nix3-repl, nix3-eval, nix3-fmt, nix3-log, nix3-why-depends
```

The naming pattern: `nix <command> <subcommand>` maps to `man nix3-<command>-<subcommand>`.

```bash
# Examples
man nix3-flake-lock         # nix flake lock
man nix3-profile-install    # nix profile install
man nix3-store-gc           # nix store gc
man nix                     # Top-level nix command overview
```

## nix repl Interactive Documentation

`nix repl` provides interactive documentation for Nix builtins and expressions:

```bash
nix repl
```

Key commands (type `:?` for the full list):

| Command | Purpose |
|---|---|
| `:doc builtins.<name>` | Show documentation for a builtin function |
| `:t <expr>` | Show the type of an expression |
| `:e <expr>` | Open the source of a derivation or function in `$EDITOR` |
| `:lf .` | Load the current flake and add its outputs to scope |
| `:l <nixpkgs>` | Load nixpkgs into scope |
| `:p <expr>` | Pretty-print an expression (strings printed directly) |
| `:log <drv>` | Show build logs for a derivation |

Example session:

```
nix-repl> :doc builtins.map
Synopsis: builtins.map f list
Apply the function f to each element in the list...

nix-repl> :t builtins.map
a lambda

nix-repl> :lf .
Added N variables.

nix-repl> :doc builtins.filter
Synopsis: builtins.filter f list
Return a list consisting of elements for which f returns true...
```

## Package Search

### nix search

Search the nixpkgs package set by regex:

```bash
nix search nixpkgs <regex>
nix search nixpkgs '#<name>'    # Exact attribute match
```

First run evaluates nixpkgs (slow, ~60s). Subsequent runs use the eval cache.

### devenv search

If devenv is available:

```bash
devenv search <query>
```

### MCP Tools

If MCP servers are available, these provide richer search:
- `mcp__devenv__search_packages` -- search nixpkgs packages
- `mcp__devenv__search_options` -- search devenv configuration options

## Nix Store Documentation

Nix packages may bundle documentation in their store paths:

```bash
# List doc directories from the system profile
ls /run/current-system/sw/share/doc/ 2>/dev/null

# List doc directories from the user profile
ls /etc/profiles/per-user/$(whoami)/share/doc/ 2>/dev/null
```

Notable bundled documentation:
- **Git**: `/nix/store/…-git-*/share/doc/git/` -- HTML manual, technical docs
- **Darwin HTML manual**: `/nix/store/…-darwin-manual-html/share/doc/darwin/index.html` -- full nix-darwin options reference as a single HTML page (find with `ls /nix/store/*darwin-manual-html*/share/doc/darwin/`)

## Info Pages (Nix-provided)

On Nix-managed systems, info pages live at:

```
/run/current-system/sw/share/info/
/nix/var/nix/profiles/default/share/info/
```

Common info pages available through Nix:
- `info bash` -- full Bash reference
- `info zsh` -- Zsh reference (multi-part)
- `info texinfo` -- Texinfo documentation system
