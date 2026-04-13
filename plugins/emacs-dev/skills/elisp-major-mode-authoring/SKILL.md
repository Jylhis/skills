---
name: elisp-major-mode-authoring
description: >
  Authoring a major mode in Elisp with define-derived-mode, font-lock,
  indentation, syntax tables, and tree-sitter ts-mode parents. Apply
  when building a new language mode, refactoring an old one, or
  migrating a classic mode to the tree-sitter foundation.
---

# Writing an Emacs major mode

## Pick the parent mode

- **`prog-mode`** — programming modes.
- **`text-mode`** — prose modes (Markdown, Org, LaTeX).
- **`special-mode`** — read-only view buffers (magit, dired).
- **A language's `ts-mode`** — when extending a tree-sitter mode.

Never derive directly from `fundamental-mode`.

## `define-derived-mode` skeleton

```elisp
;;; foo-mode.el --- Major mode for Foo files  -*- lexical-binding: t; -*-

(require 'prog-mode)

(defgroup foo-mode nil
  "Major mode for editing Foo files."
  :group 'languages
  :prefix "foo-mode-")

(defvar foo-mode-font-lock-keywords
  `((,(regexp-opt '("let" "fn" "if" "else" "match") 'symbols)
     . font-lock-keyword-face)
    ("\"[^\"]*\"" . font-lock-string-face))
  "Highlighting for `foo-mode'.")

(defvar-keymap foo-mode-map
  :doc "Keymap for `foo-mode'."
  "C-c C-c" #'foo-mode-compile
  "C-c C-r" #'foo-mode-run)

(defvar foo-mode-syntax-table
  (let ((st (make-syntax-table)))
    (modify-syntax-entry ?\; "<" st)
    (modify-syntax-entry ?\n ">" st)
    (modify-syntax-entry ?_ "_" st)
    st)
  "Syntax table for `foo-mode'.")

;;;###autoload
(define-derived-mode foo-mode prog-mode "Foo"
  "Major mode for editing Foo source files.

\\{foo-mode-map}"
  :syntax-table foo-mode-syntax-table
  (setq-local font-lock-defaults '(foo-mode-font-lock-keywords))
  (setq-local comment-start "; ")
  (setq-local comment-end "")
  (setq-local indent-line-function #'foo-mode-indent-line))

;;;###autoload
(add-to-list 'auto-mode-alist '("\\.foo\\'" . foo-mode))

(provide 'foo-mode)
;;; foo-mode.el ends here
```

Key points:

- **`lexical-binding: t`** — required.
- **`defvar-keymap`** (Emacs 29+) — cleaner than the `make-sparse-keymap` pattern.
- **`;;;###autoload`** on the mode defun and `auto-mode-alist` entry.
- **`setq-local`** — mode body should set buffer-local values.

## Syntax tables

Syntax classes:

- `<` / `>` — comment start / end.
- `"` — string delimiter.
- `\`/`/` — escape character.
- `w` — word constituent.
- `_` — symbol constituent.
- `(` / `)` — matching parens.

Two-character comments (e.g. `//`) use comment style sequences — see
`modify-syntax-entry` docstring.

## Font-lock

Patterns are `(MATCHER . FACEDEF)` or `(MATCHER HIGHLIGHT-SPEC ...)`.
Prefer `font-lock-*` faces over custom faces — users customise them
via themes.

For multi-level highlighting:

```elisp
(setq-local font-lock-defaults
            '((foo-mode-font-lock-keywords
               foo-mode-font-lock-keywords-extra)  ; levels
              nil nil nil nil))
```

## Indentation

Set `indent-line-function`. The function should move point to the
correct column based on preceding lines.

For grammar-based languages, SMIE is the built-in framework. For
tree-sitter languages, prefer `treesit-simple-indent-rules`.

## Tree-sitter (ts-mode) variants

When a tree-sitter grammar is available, derive from the `ts-mode`:

```elisp
(define-derived-mode foo-ts-mode typescript-ts-mode "Foo[TS]"
  "Foo mode built on top of typescript-ts-mode."
  (treesit-parser-create 'typescript)
  (setq-local treesit-simple-indent-rules
              '((typescript
                 ((parent-is "program") column-0 0)
                 ((node-is "}") parent-bol 0)
                 ;; ...
                 ))))
```

Use `major-mode-remap-alist` (Emacs 29+) to remap file associations:

```elisp
(add-to-list 'major-mode-remap-alist '(typescript-ts-mode . foo-ts-mode))
```

## Hook naming

`define-derived-mode` automatically creates `MODE-hook`. Custom
initialization goes in the mode body (runs after parent setup, before
`MODE-hook`).

## Testing

```elisp
(ert-deftest foo-mode-indent-line-test ()
  (ert-with-temp-file file
    (with-temp-buffer
      (insert "let foo =\n1")
      (foo-mode)
      (indent-region (point-min) (point-max))
      (should (equal (buffer-string) "let foo =\n  1")))))
```

## Anti-patterns

- Defining keybindings at top-level without a keymap — they end up
  global.
- Using `setq` instead of `setq-local` inside the mode body.
- Creating a new `defface` for every syntactic category.
- Forgetting `;;;###autoload`.
- Deriving from `fundamental-mode`.
- Writing a new mode when a tree-sitter `ts-mode` exists — derive
  from it instead.

## Tool detection

```bash
for tool in emacs; do
  command -v "$tool" >/dev/null && echo "ok: $tool" || echo "MISSING: $tool"
done
```

## References

- Elisp manual - Major Modes: https://www.gnu.org/software/emacs/manual/html_node/elisp/Modes.html
- `define-derived-mode`: https://www.gnu.org/software/emacs/manual/html_node/elisp/Derived-Modes.html
- Tree-sitter in Emacs: https://www.gnu.org/software/emacs/manual/html_node/elisp/Parsing-Program-Source.html
- SMIE: https://www.gnu.org/software/emacs/manual/html_node/elisp/SMIE.html
