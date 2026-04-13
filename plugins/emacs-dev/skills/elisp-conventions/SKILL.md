---
name: elisp-conventions
description: "Use for Emacs Lisp coding conventions and modern API usage including lexical-binding, use-package, keymap-set, setopt, defcustom, defvar-keymap, if-let*, when-let*, with-eval-after-load, major-mode-remap-alist, tree-sitter ts-mode setup, Elisp file structure, naming conventions, hook best practices, or any Emacs Lisp code style questions. Also triggers when writing or reviewing .el files, configuring Emacs packages, or asking about modern vs legacy Elisp APIs."
user-invocable: false
---

# Modern Elisp Conventions

Guidelines for writing clean, modern Emacs Lisp targeting Emacs 29+/30+.

## File Structure

Every `.el` file follows this layout:

```elisp
;;; my-module.el --- Short description  -*- lexical-binding: t; -*-

;; Author: Name <email>
;; Keywords: convenience
;; Package-Requires: ((emacs "30.1"))

;;; Commentary:

;; Longer description of the module.

;;; Code:

(require 'cl-lib)  ; only if needed

(defgroup my-module nil
  "My module customization."
  :group 'convenience
  :prefix "my-module-")

;; ... definitions ...

(provide 'my-module)
;;; my-module.el ends here
```

**Mandatory:**
- `lexical-binding: t` on line 1
- `(provide 'my-module)` at the bottom, matching the filename
- Footer comment `;;; my-module.el ends here`

## Modern APIs (Emacs 29+/30+)

### Keybindings

```elisp
;; Modern (Emacs 29+)
(keymap-set global-map "C-c f" #'find-file)
(keymap-global-set "C-c f" #'find-file)
(keymap-set mode-map "C-c m" #'my-command)

;; Define keymaps declaratively
(defvar-keymap my-mode-map
  :doc "Keymap for my-mode."
  "C-c m a" #'my-action
  "C-c m b" #'my-other-action)

;; AVOID: define-key, global-set-key, local-set-key
```

### Variables

```elisp
;; For defcustom variables — use setopt (Emacs 29+)
(setopt display-line-numbers-type 'relative)
(setopt tab-width 4)

;; For plain defvar / internal state — setq is fine
(setq my--internal-state nil)

;; AVOID: setq for defcustom variables (bypasses :set/:type validation)
```

### Conditional Binding

```elisp
;; Modern (Emacs 30+ built-in, no require needed)
(if-let* ((buf (get-buffer "foo"))
          (win (get-buffer-window buf)))
    (select-window win)
  (message "Not found"))

(when-let* ((val (thing-at-point 'symbol)))
  (do-something val))

;; AVOID: if-let, when-let (deprecated single-binding forms)
;; AVOID: (require 'subr-x) for if-let*/when-let* on Emacs 30+
```

### Loading

```elisp
;; Modern
(with-eval-after-load 'org
  (setopt org-startup-indented t))

;; AVOID: eval-after-load (legacy, requires quoting the form)
```

### Tree-sitter Modes

```elisp
;; Remap to tree-sitter variants via major-mode-remap-alist
(setopt major-mode-remap-alist
        '((python-mode . python-ts-mode)
          (js-mode . js-ts-mode)
          (rust-mode . rust-ts-mode)
          (go-mode . go-ts-mode)))

;; AVOID: directly setting auto-mode-alist for *-ts-mode
```

## Built-in Packages (Emacs 30+)

These are built-in — do NOT add them as dependencies or use `require` unless noted:

**No require needed:** `use-package`, `eglot`, `which-key`, `if-let*`/`when-let*`, `string-trim`, `named-let`, `seq-*`, `map-do`

**Still need require:** `cl-lib` (cl-loop, cl-letf, cl-defstruct), `subr-x` (thread-first, thread-last, string-join), `map` (map-let)

## Naming Conventions

```elisp
;; Public API — single hyphen after prefix
(defun my-module-do-thing () ...)

;; Internal — double hyphen
(defun my-module--internal-helper () ...)

;; Predicates — -p suffix
(defun my-module-active-p () ...)

;; Variables follow same rules
(defvar my-module-default-value 42)
(defvar my-module--cache nil)
```

Choose a consistent namespace prefix matching the filename.

## defcustom

Always declare with `:type` and `:group`:

```elisp
(defcustom my-module-enable-feature nil
  "Whether to enable the feature."
  :type 'boolean
  :group 'my-module)

(defcustom my-module-backend 'default
  "Which backend to use."
  :type '(choice (const :tag "Default" default)
                 (const :tag "Fast" fast)
                 (const :tag "Legacy" legacy))
  :group 'my-module)
```

Set defcustom values with `setopt`, not `setq`.

## Hooks

Always use named functions, never lambdas:

```elisp
;; Good
(defun my-module--setup-mode ()
  "Configure mode settings."
  (display-line-numbers-mode 1)
  (setq-local indent-tabs-mode nil))

(add-hook 'prog-mode-hook #'my-module--setup-mode)

;; Use DEPTH parameter for ordering (Emacs 27+)
(add-hook 'after-init-hook #'my-late-init 90)

;; AVOID: lambdas in hooks (hard to remove, debug, and inspect)
```

## use-package

```elisp
(use-package magit
  :bind ("C-c g" . magit-status)
  :custom
  (magit-display-buffer-function
   #'magit-display-buffer-same-window-except-diff-v1)
  :config
  (setopt magit-save-repository-buffers 'dontask))
```

**When using Nix-managed packages:** omit `:ensure t` — Nix handles installation and load-path.

**Defer loading by default:** use-package with `:bind`, `:hook`, `:commands`, or `:mode` auto-defers. Only add `:demand t` when you need eager loading.

## Autoloads and Loading

```elisp
;; Good — declares that my-func exists; loads the file on first call
(autoload 'my-func "my-module" "Do a thing." t)

;; Better — use-package handles autoloading automatically via :commands
(use-package my-module
  :commands (my-func my-other-func))

;; Eager require only when you need macros or definitions at compile time
(require 'cl-lib)
```

## Common Anti-patterns

| Anti-pattern | Modern replacement |
|---|---|
| `(define-key map (kbd "...") ...)` | `(keymap-set map "..." ...)` |
| `(global-set-key (kbd "...") ...)` | `(keymap-global-set "..." ...)` |
| `(setq custom-var value)` | `(setopt custom-var value)` |
| `(eval-after-load 'pkg '(...))` | `(with-eval-after-load 'pkg ...)` |
| `(require 'cl)` | `(require 'cl-lib)` |
| `(if-let ((x val)) ...)` | `(if-let* ((x val)) ...)` |
| `(lambda () ...) in add-hook` | Named function in `add-hook` |
| `:ensure t` with Nix packages | Omit `:ensure` |
| `(define-minor-mode)` without keymap | Use `:keymap` parameter |
| Direct `auto-mode-alist` for ts-modes | `major-mode-remap-alist` |
