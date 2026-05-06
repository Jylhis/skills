---
name: offline-docs
description: "Discover and use offline documentation on Unix systems (Linux, macOS, FreeBSD). Use when the user asks about CLI tool usage, flags, options, or behavior; needs to look up a man page or info page; wants to find configuration references; asks 'how do I use <tool>'; needs help finding documentation for an unfamiliar command; asks what a flag does; or wants to explore available system documentation. Prefer local docs over web search -- they are authoritative and version-matched to installed software."
user-invocable: false
---

# Offline Documentation Discovery

Local documentation is authoritative and version-matched to the software actually installed. Prefer it over web search for CLI usage, flags, configuration options, and system behavior. Web search results often describe different versions, different platforms, or deprecated features.

Unix documentation hierarchy (check in this order):

1. Man pages -- the primary reference for most commands and config files
2. Info pages -- book-length GNU references (bash, coreutils, make)
3. `--help` / `help` -- quick inline summaries
4. Bundled docs -- `/usr/share/doc/`, examples, READMEs

Fall back to web only when: no local docs exist, the tool has no man page or `--help`, or the user explicitly asks for web results.

## Decision Tree

Route the question to the right lookup method:

| Question type | Lookup |
|---|---|
| Tool usage, flags, options | `man <tool>` or `<tool> --help` |
| File format or config syntax | `man 5 <name>` |
| System calls (open, read, mmap) | `man 2 <name>` |
| C library functions (printf, malloc) | `man 3 <name>` |
| Device or kernel interfaces | `man 4 <name>` or `man 7 <name>` |
| System admin commands (mount, systemctl) | `man 8 <name>` |
| In-depth reference (bash, make, coreutils) | `info <topic>` |
| Shell builtins (cd, export, alias) | `help <builtin>` (bash) or `man zshbuiltins` |
| Package search | Platform-specific -- see references/ |
| "What docs exist for X?" | Search strategy below |
| Nix options or Nix CLI | Read `references/nix-managed.md` |
| macOS-specific tools or conventions | Read `references/macos.md` |

## Man Pages

The primary documentation system on Unix. Nearly every command, config file, library function, and system call has a man page.

### Sections

| Section | Contents | Example |
|---|---|---|
| 1 | User commands | `man 1 grep` |
| 2 | System calls | `man 2 open` |
| 3 | Library functions | `man 3 printf` |
| 4 | Device/special files | `man 4 tty` |
| 5 | File formats, config files | `man 5 crontab` |
| 6 | Games | `man 6 fortune` |
| 7 | Miscellaneous (conventions, protocols) | `man 7 signal` |
| 8 | System administration | `man 8 mount` |

When a name exists in multiple sections (e.g., `printf` in 1 and 3), specify the section: `man 3 printf`.

### Reading

```bash
man <name>              # Open man page (searches sections in order)
man <section> <name>    # Open specific section
```

Inside the pager (`less`), use `/pattern` to search forward, `n` for next match, `q` to quit.

### Searching

```bash
man -k <keyword>        # Search man page descriptions (same as apropos)
man -f <name>           # Show one-line description (same as whatis)
man -w <name>           # Show file path without opening -- reveals which package provides it
```

If `man -k` returns "nothing appropriate", the whatis database needs rebuilding:

- Linux: `sudo mandb`
- BSD/macOS: `sudo /usr/libexec/makewhatis`

### MANPATH

Man searches directories listed in MANPATH. Check with:

```bash
man -w                  # Show full search path
manpath                 # Alternative (not available everywhere)
```

On Nix-managed systems, MANPATH includes per-package store paths. See `references/nix-managed.md`.

### Extracting from Large Man Pages

Some man pages are enormous (e.g., `bash.1` is ~5,000 lines, configuration references can be larger). Extract what you need:

```bash
# Search for a specific option or section
man <page> | col -bx | grep -A 15 '<pattern>'

# Extract a named section
man <page> | col -bx | sed -n '/^ENVIRONMENT/,/^[A-Z]/p'
```

`col -bx` strips backspace-based formatting so grep works reliably.

## Info Pages

GNU Info provides structured, hyperlinked documentation. Some GNU tools have minimal man pages that say "see info for the full manual" -- in those cases, info is the authoritative source.

### When to Use Info

Use info instead of man when:

- The man page says "The full documentation is maintained as a Texinfo manual"
- You need comprehensive coverage of bash, coreutils, make, grep, sed, awk, gzip, or texinfo

### Reading

```bash
info <topic>                    # Open interactively
info <topic> '<node name>'     # Jump to specific section
```

Navigation: `n` next node, `p` previous, `u` up, `/` search, `q` quit.

### Non-Interactive Extraction

```bash
# Dump a specific node to stdout
info <topic> '<node name>' --output=-

# Dump everything (large -- pipe to grep)
info <topic> --subnodes --output=- | grep -A 10 '<pattern>'
```

### Key Info Pages

| Topic | Coverage |
|---|---|
| bash | Complete shell reference (builtins, expansion, scripting) |
| coreutils | All GNU core utilities in detail |
| make | GNU Make manual |
| grep, sed, awk | Pattern matching and text processing |
| texinfo | The info format itself |

## --help and Inline Help

Quick reference when you need a flag reminder, not a full manual.

```bash
<tool> --help               # Most tools (GNU convention)
<tool> -h                   # Short form (some tools)
<tool> help                 # Top-level help with subcommand list
<tool> help <subcommand>    # Subcommand-specific help (git, docker, nix, cargo)
<tool> <subcommand> --help  # Alternative subcommand help
```

### Shell Builtins

Shell builtins (cd, export, alias, set, etc.) are not external commands -- they have no man page on some systems. Use:

```bash
help <builtin>              # bash built-in help system
man zshbuiltins             # zsh builtins reference
man builtin                 # some systems document them here
```

To determine if a command is a builtin, alias, function, or external:

```bash
type <cmd>                  # Shows what <cmd> resolves to
type -a <cmd>               # Shows all matches (builtin + external)
```

## Bundled Documentation

Packages often ship supplementary docs beyond man pages.

### Standard Locations

```text
/usr/share/doc/<package>/           # Package-specific docs
/usr/share/doc/<package>/examples/  # Config samples, scripts
/usr/share/doc/<package>/README*    # Package README
/usr/share/doc/<package>/changelog* # Change history
```

### Finding Package Docs

```bash
# Debian/Ubuntu
dpkg -L <package> | grep -E '(doc|man|info)'

# RHEL/Fedora
rpm -ql <package> | grep -E '(doc|man|info)'

# General: check relative to the binary
dirname "$(which <tool>)"/../share/doc/
```

For Nix-managed systems, see `references/nix-managed.md`.

## Search Strategy

When you don't know where documentation lives for a tool or topic:

### Step 1: Check if a man page exists

```bash
man -w <name> 2>/dev/null && echo "found" || echo "no man page"
```

### Step 2: Search by keyword

```bash
man -k <keyword>            # Search descriptions
```

### Step 3: Locate the binary and check siblings

```bash
which <tool>                # Find the binary
# Then check ../share/man/ and ../share/doc/ relative to the binary
```

### Step 4: Try inline help

```bash
<tool> --help 2>&1 | head -20
```

### Step 5: Check if it's a builtin

```bash
type <cmd>
# If builtin: help <cmd> (bash) or man zshbuiltins (zsh)
```

### Step 6: Check bundled docs

```bash
ls /usr/share/doc/ | grep -i <name>
```

### Step 7: Platform-specific sources

- Nix-managed systems: read `references/nix-managed.md`
- macOS: read `references/macos.md`

### Reading Large Reference Pages Efficiently

Configuration reference man pages (like `nix.conf`, `sshd_config`, `configuration.nix`) can be thousands of lines. Don't read the whole thing -- extract what you need:

```bash
# Grep for a specific option
man 5 sshd_config | col -bx | grep -A 10 'PermitRootLogin'

# In the pager: type /PermitRootLogin to jump directly
man 5 sshd_config
# then type: /PermitRootLogin<Enter>
```

## Cross-References

- **Nix-managed systems** (NixOS, nix-darwin, Home Manager): read `references/nix-managed.md` for multi-tier MANPATH, `nix repl :doc`, configuration reference man pages, and Nix CLI documentation
- **macOS**: read `references/macos.md` for system man pages, `open x-man-page://`, and Xcode CLI docs
- **Language-specific docs** (godoc, rustdoc, pydoc, perldoc): covered by their respective language skills, not this one
