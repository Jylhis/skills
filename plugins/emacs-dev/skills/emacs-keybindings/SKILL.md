---
name: emacs-keybindings
description: "Use for Emacs keybinding design including keymap-set, keymap-global-set, defvar-keymap, keymap layers and lookup order, key-valid-p syntax, keybinding conflicts, reserved key ranges, prefix keys, minor-mode-map-alist, overriding-local-map, keybinding best practices, key sequences, repeat-mode integration, which-key, or when the user asks about Emacs key bindings, shortcut design, keymap hierarchy, or fixing keybinding conflicts."
user-invocable: false
---

# Emacs Keybinding Design

Guide for designing conflict-free, ergonomic keybinding schemes.

## Modern Keybinding API

Always use `keymap-set` and related functions (Emacs 29+):

```elisp
;; Single binding
(keymap-set global-map "C-c f" #'find-file)
(keymap-global-set "C-c f" #'find-file)        ;; shorthand

;; Mode-specific
(keymap-set emacs-lisp-mode-map "C-c e" #'eval-last-sexp)

;; Declarative keymap
(defvar-keymap my-prefix-map
  :doc "My custom prefix keymap."
  :prefix 'my-prefix-map                        ;; make it a named prefix
  "a" #'my-action-a
  "b" #'my-action-b
  "s" #'my-action-save)

(keymap-global-set "C-c m" my-prefix-map)
```

### Key Syntax

`keymap-set` uses `key-valid-p` syntax — no `kbd` wrapper needed:

```elisp
;; Correct key-valid-p syntax
"C-c a"           ;; Ctrl-c a
"C-M-f"           ;; Ctrl-Meta-f
"C-c C-c"         ;; Ctrl-c Ctrl-c
"M-<return>"      ;; Meta-Return
"C-<tab>"         ;; Ctrl-Tab
"s-f"             ;; Super-f
"H-a"             ;; Hyper-a
"<f5>"            ;; F5 function key
"C-c m a"         ;; Three-key sequence

;; Invalid (won't pass key-valid-p)
"C-c C-m a"       ;; C-m is ambiguous (RET vs Ctrl-m)
"C-["             ;; Ambiguous (ESC vs Ctrl-[)
```

Validate with `(key-valid-p "C-c a")` → `t` or `nil`.

## Keymap Lookup Order

Emacs resolves keys through 8 layers, checked top-to-bottom. Higher layers shadow lower ones:

| Priority | Keymap | Scope |
|----------|--------|-------|
| 1 | `overriding-terminal-local-map` | Terminal-local override (rare) |
| 2 | `overriding-local-map` | Buffer-local override (rare, used by isearch) |
| 3 | Text property / overlay keymaps | Per-character (buttons, links) |
| 4 | `minor-mode-overriding-map-alist` | Buffer-local minor mode override |
| 5 | `minor-mode-map-alist` | Minor mode keymaps (stacked) |
| 6 | Local (major mode) keymap | `current-local-map` |
| 7 | `global-map` | Baseline |
| 8 | Bindings in `function-key-map` etc. | Translation (rare) |

Understanding this explains why bindings "don't work" — a higher-priority keymap is intercepting the key.

## Reserved Key Ranges

Respect these conventions to avoid conflicts:

| Range | Reserved for | Safe to use? |
|-------|-------------|-------------|
| `C-c <letter>` | **Users** | Yes — this is your space |
| `C-c C-<letter>` | Major modes | No — modes own this |
| `C-c <punctuation>` | Minor modes | No |
| `C-x` | Emacs global commands | No |
| `C-h` | Help | No |
| `F1` | Help | No |
| `F2` | Two-column mode | Rarely used, OK to rebind |
| `F3`-`F4` | Keyboard macros | OK if you don't use kmacros |
| `F5`-`F9` | **Users** | Yes |
| `F10` | Menu bar | No |
| `F11`-`F12` | Available | Yes, but some DEs grab them |
| `M-<letter>` | Emacs commands | Rebinding is common but can conflict |
| `s-<key>` (Super) | Mostly free | Yes — great for custom bindings |

**Best practice:** Pick a prefix under `C-c <letter>` (e.g., `C-c p` for project commands) and put all your custom bindings under it.

## Conflict Detection

### Check what a key currently does

```elisp
;; What does C-c a do in the current buffer?
(key-binding (kbd "C-c a"))

;; Which minor modes bind a key?
(minor-mode-key-binding (kbd "C-c a"))

;; Where is a command bound?
(where-is-internal 'find-file)

;; Interactive: press the key and see what happens
C-h k C-c a          ;; describe-key

;; Interactive: see all bindings for a prefix
C-h C-c              ;; shows everything under C-c
```

### Systematic conflict scan

```elisp
;; Check if a key is free in all active keymaps
(defun my-key-free-p (key-string)
  "Return t if KEY-STRING is unbound in all active maps."
  (let ((key (kbd key-string)))
    (and (not (key-binding key))
         (not (minor-mode-key-binding key))
         (not (local-key-binding key))
         (not (global-key-binding key)))))

(my-key-free-p "C-c j a")  ;; → t if free
```

## Prefix Key Patterns

### Simple prefix

```elisp
(defvar-keymap my-project-map
  :doc "Project management commands."
  "f" #'project-find-file
  "g" #'project-find-regexp
  "b" #'project-switch-to-buffer
  "d" #'project-dired)

(keymap-global-set "C-c p" my-project-map)
;; Now: C-c p f → project-find-file, etc.
```

### Nested prefixes

```elisp
(defvar-keymap my-test-map
  :doc "Test commands."
  "t" #'my-run-test-at-point
  "f" #'my-run-test-file
  "a" #'my-run-all-tests)

(defvar-keymap my-main-map
  :doc "Main custom keymap."
  "t" my-test-map                ;; C-c m t → test prefix
  "g" #'magit-status
  "r" #'my-repl)

(keymap-global-set "C-c m" my-main-map)
;; C-c m t t → run test at point
;; C-c m g   → magit-status
```

## Repeat Mode Integration (Emacs 28+)

Make sequences of related commands repeatable without holding the prefix:

```elisp
(defvar-keymap my-window-repeat-map
  :doc "Repeatable window commands."
  :repeat t                      ;; enables repeat-mode for this map
  "o" #'other-window
  "n" #'next-buffer
  "p" #'previous-buffer
  "0" #'delete-window
  "1" #'delete-other-windows
  "2" #'split-window-below
  "3" #'split-window-right)
```

After pressing the initial key sequence (e.g., `C-x o`), subsequent keys from the repeat map work without the prefix (`o`, `o`, `n`, ...).

## which-key Integration

`which-key` (built-in since Emacs 30) shows available keys after a prefix delay:

```elisp
(use-package which-key
  :config
  (which-key-mode 1)
  :custom
  (which-key-idle-delay 0.5))

;; Add descriptions to your prefix maps
(which-key-add-keymap-based-replacements my-main-map
  "t" "test"
  "g" "git")
```

## Context-Sensitive Bindings

### Mode-specific overrides

```elisp
;; Override a global binding in specific modes
(keymap-set org-mode-map "C-c a" #'org-agenda)

;; Bind only in a derived mode
(with-eval-after-load 'python
  (keymap-set python-mode-map "C-c C-t" #'python-pytest-dispatch))
```

### Conditional bindings via menu-item

```elisp
;; Bind a key conditionally — falls through if condition is nil
(keymap-set global-map "C-c d"
  `(menu-item "" my-debug-command
    :filter ,(lambda (_cmd)
               (when (derived-mode-p 'prog-mode)
                 #'my-debug-command))))
```

## Design Principles

1. **Group related commands under a shared prefix** — easier to discover and remember
2. **Use mnemonic keys** — `f` for find, `s` for save, `t` for test
3. **Stay in `C-c <letter>`** — it's yours, guaranteed conflict-free
4. **Document your bindings** — use `:doc` on `defvar-keymap`, add which-key labels
5. **Test in relevant modes** — a binding that works in `fundamental-mode` might be shadowed in `org-mode`
6. **Consider ergonomics** — frequent commands get short sequences; rare commands can be longer
