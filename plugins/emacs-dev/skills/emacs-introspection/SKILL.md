---
name: emacs-introspection
description: "Use for finding information in Emacs including the help system (C-h), describe-function, describe-variable, describe-key, describe-mode, describe-symbol, apropos, Info manuals, source code navigation (find-function, xref, M-.), shortdoc function groups, Elisp introspection functions, emacs --batch --eval for programmatic queries, emacsclient --eval, or when the user asks how to look up, discover, or query Emacs functionality interactively or from scripts."
user-invocable: false
---

# Finding Information in Emacs

## The Help Prefix (`C-h`)

### The Essential Eight

| Key | Command | What it does |
|-----|---------|-------------|
| `C-h f` | `describe-function` | Function docstring, arglist, source file |
| `C-h v` | `describe-variable` | Variable value, docstring, buffer-local status |
| `C-h k` | `describe-key` | What command a key sequence runs |
| `C-h o` | `describe-symbol` | Everything about a symbol (function + variable + face) |
| `C-h m` | `describe-mode` | Current major mode and all active minor modes |
| `C-h b` | `describe-bindings` | Every active keybinding in the current buffer |
| `C-h x` | `describe-command` | Like `C-h f` but restricted to interactive commands |
| `C-h w` | `where-is` | Which key(s) run a given command |

### More Help Commands

| Key | Command | What it does |
|-----|---------|-------------|
| `C-h c` | `describe-key-briefly` | Command name for a key (echo area) |
| `C-h a` | `apropos-command` | Find commands matching a pattern |
| `C-h d` | `apropos-documentation` | Search documentation strings |
| `C-h i` | `info` | Open the Info manual browser |
| `C-h r` | `info-emacs-manual` | Jump to the Emacs manual |
| `C-h R` | `info-display-manual` | Choose a manual by name |
| `C-h S` | `info-lookup-symbol` | Look up symbol in language-appropriate manual |
| `C-h F` | `Info-goto-emacs-command-node` | Find a command in the manual |
| `C-h K` | `Info-goto-emacs-key-command-node` | Find a key in the manual |
| `C-h p` | `finder-by-keyword` | Browse packages by category |
| `C-h P` | `describe-package` | Package documentation |
| `C-h l` | `view-lossage` | Last 300 keystrokes |
| `C-h e` | `view-echo-area-messages` | Message history |
| `C-h n` | `view-emacs-news` | Release notes |

### Navigating Help Buffers

| Key | Action |
|-----|--------|
| `TAB` / `S-TAB` | Jump between hyperlinks |
| `RET` | Follow hyperlink at point |
| `s` | Jump to source code |
| `i` | Look up in Info manual |
| `c` | Open customization |
| `l` / `r` | History back / forward |
| `q` | Quit help window |

## The Describe Family (beyond the essential eight)

**Keys and Bindings:** `describe-keymap`, `describe-prefix-bindings` (`C-x C-h` shows everything after `C-x`), `describe-personal-keybindings`.

**Text and Display:** `describe-char` (unicode, properties, overlays, face, font at point), `describe-text-properties`, `describe-face`, `describe-syntax`.

**International:** `describe-coding-system`, `describe-input-method`, `describe-language-environment`.

**Packages, Themes:** `describe-package`, `describe-theme`.

## Apropos: Finding What You Don't Know

| Command | Searches |
|---------|----------|
| `apropos-command` (`C-h a`) | Interactive command names |
| `apropos-documentation` (`C-h d`) | Documentation strings |
| `apropos` | Names of functions, variables, and faces |
| `apropos-function` | Function names (including non-interactive) |
| `apropos-variable` | All variable names |
| `apropos-value` | Values of variables and function definitions |
| `apropos-user-option` | `defcustom` variable names |
| `apropos-library` | Symbols defined in a specific library file |

**Pattern syntax:** Single word matches substrings. Multiple words match symbols containing at least two. Regex characters (`^$*+?.\[`) trigger regex matching.

## The Info Reader

| Key | What it opens |
|-----|---------------|
| `C-h i` | Top-level directory with all manuals |
| `C-h r` | GNU Emacs Manual |
| `C-h R` | Choose a manual by name |

**Navigation:** `n`/`p` next/previous node, `u` up, `]`/`[` reading order, `m` menu item, `f` cross-reference, `l`/`r` history, `d` top directory, `q` quit.

**Searching:** `i` searches the index (best approach), `,` next index match, `I` regexp index search, `s` full-text search, `M-x info-apropos` searches all manuals.

### `info-lookup-symbol` (`C-h S`)

Language-aware: in Elisp buffers searches the Elisp Reference, in C searches the C library manual.

## Source Code Navigation

### find-function Family

| Command | Finds |
|---------|-------|
| `find-function` | Source of a function |
| `find-variable` | Source of a variable |
| `find-face-definition` | Source of a face |
| `find-library` | Library file by name |
| `find-function-on-key` | Source of command bound to a key |

Shortcut: in any `*Help*` buffer, press `s` to jump to source.

### xref

| Key | Action |
|-----|--------|
| `M-.` | Jump to definition |
| `M-?` | Find all references |
| `M-,` | Go back |
| `C-M-,` | Go forward |

## Shortdoc

`M-x shortdoc` shows common functions by topic with live examples.

Groups: `string`, `list`, `alist`, `sequence`, `number`, `vector`, `regexp`, `buffer`, `process`, `file-name`, `file`, `hash-table`, `keymaps`, `text-properties`, `overlay`, `symbol`, `comparison`, `map`.

## Elisp Introspection Functions

### Documentation

```elisp
(documentation 'mapcar t)
(documentation-property 'tab-width 'variable-documentation)
(help-function-arglist 'mapcar)  ;; -> (FUNCTION SEQUENCE)
```

### Finding Where Things Come From

```elisp
(symbol-file 'python-mode 'defun)
(subrp (symbol-function 'forward-char))  ;; -> t (C primitive)
(subr-native-elisp-p (symbol-function 'forward-word))
(locate-library "org")
```

### Discovering API Surfaces

```elisp
(apropos-internal "^font-lock-" #'functionp)
(apropos-internal "^describe-" #'commandp)
(apropos-internal "^org-" #'custom-variable-p)
```

### Key Binding Introspection

```elisp
(key-binding (kbd "C-x C-f"))  ;; -> find-file
(where-is-internal 'find-file)
(mapconcat #'key-description (where-is-internal 'find-file) ", ")
```

### Symbol Properties

```elisp
(symbol-plist 'font-lock-mode)
(get 'tab-width 'safe-local-variable)
(require 'cus-edit)
(custom-variable-type 'font-lock-maximum-decoration)
```

### Feature and Capability Testing

```elisp
(featurep 'native-compile)
(featurep 'treesit)
emacs-version
system-type
```

## Programmatic Access from Outside Emacs

### `emacs --batch --eval`

Starts a fresh Emacs, evaluates code, exits. No GUI, no user config.

```bash
# Function documentation
emacs --batch --eval '(princ (documentation '\''mapcar t))' 2>/dev/null

# What command a key runs
emacs --batch --eval '(princ (key-binding (kbd "C-x C-f")))' 2>/dev/null

# List functions matching a prefix
emacs --batch --eval '(princ (mapconcat #'\''symbol-name (apropos-internal "^font-lock-" #'\''functionp) "\n"))' 2>/dev/null

# Where a function is defined
emacs --batch --eval '(princ (symbol-file '\''python-mode '\''defun))' 2>/dev/null

# Load a library first, then query
emacs --batch --eval '(progn
  (require '\''auth-source)
  (princ (documentation '\''auth-source-search t)))' 2>/dev/null
```

### `emacsclient --eval`

Connects to a running Emacs server. Faster, has access to user config.

```bash
emacsclient --eval '(documentation '\''mapcar t)'
emacsclient --eval '(buffer-list)'
```

### Comparison

| | `emacs --batch --eval` | `emacsclient --eval` |
|-|----------------------|---------------------|
| Startup | ~0.5-1.0s (cold) | ~0.1s (warm) |
| Requires server | No | Yes |
| State persistence | None | Shared with running Emacs |
| Best for | Scripts, CI | Interactive workflows |

## Quick Reference

| I want to know... | Do this |
|---|---|
| What a function does | `C-h f function-name` |
| What a variable controls | `C-h v variable-name` |
| What a key does | `C-h k` then press the key |
| What key runs a command | `C-h w command-name` |
| What this mode provides | `C-h m` |
| All keybindings right now | `C-h b` |
| Everything about a symbol | `C-h o symbol-name` |
| Functions I can't name | `C-h a partial-name` or `C-h d keyword` |
| Read the manual on a topic | `C-h i` then `i topic` |
| How a function is implemented | `C-h f fn` then `s` to jump to source |
| What functions exist for X | `M-x shortdoc` or `(apropos-internal "^prefix-" #'functionp)` |
| From a script / AI agent | `emacs --batch --eval '(princ (documentation '\''fn t))' 2>/dev/null` |
