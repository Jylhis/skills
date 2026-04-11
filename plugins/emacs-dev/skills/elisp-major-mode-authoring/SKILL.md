---
name: elisp-major-mode-authoring
description: >
  Authoring a major mode in Elisp with define-derived-mode, font-lock,
  indentation, syntax tables, and tree-sitter ts-mode parents. Apply
  when building a new language mode, refactoring an old one, or
  migrating a classic mode to the tree-sitter foundation.
---

# Writing an Emacs major mode

A major mode is Emacs's unit of "this is a file of type X." Modern
Elisp uses `define-derived-mode` to inherit structure from a parent
mode, and `treesit-*` infrastructure when a tree-sitter grammar is
available.

## Pick the parent mode

- **`prog-mode`** — general parent for programming modes. Sets up
  hooks, default fill behaviour, comment handling.
- **`text-mode`** — parent for prose modes (Markdown, Org, LaTeX).
- **`special-mode`** — parent for read-only view buffers (magit,
  dired). Sets `buffer-read-only`, disables self-insert keys.
- **A language's `ts-mode`** — when you're extending a tree-sitter mode
  with domain-specific features.

Never derive directly from `fundamental-mode`; always pick the
semantic parent.

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

- **`lexical-binding: t`** in the file header — required for modern
  Elisp; unlocks closures and many macros.
- **`defgroup`** — every customizable mode needs its own group.
- **`defvar-keymap`** (Emacs 29+) — cleaner than `defvar ... (let ((map (make-sparse-keymap))) ...))`.
- **`;;;###autoload`** on the mode defun and the `auto-mode-alist`
  entry — lets users load the mode lazily.
- **`setq-local`** — mode hooks should set buffer-local values, not
  globals.

## Syntax tables

Syntax tables define comment syntax, string syntax, word characters,
and matching delimiters. Study the syntax classes:

- `<` / `>` — comment start / end.
- `"` — string delimiter.
- `\`/`/` — escape character.
- `w` — word constituent.
- `_` — symbol constituent.
- `(` / `)` — matching parens.

Two-character comments (e.g. `//`) use comment style sequences — see
`modify-syntax-entry` docstring and the Elisp manual's *Syntax Table
Internals* chapter.

## Font-lock

Font-lock patterns are a list of `(MATCHER . FACEDEF)` or
`(MATCHER HIGHLIGHT-SPEC ...)`. Prefer the faces from the `font-lock-*`
family (`font-lock-keyword-face`, `font-lock-type-face`,
`font-lock-function-name-face`, …) rather than custom faces. Users
customise the `font-lock-*` faces in their theme; custom faces do not
pick up theme changes.

For performance-sensitive modes use multi-level highlighting:

```elisp
(setq-local font-lock-defaults
            '((foo-mode-font-lock-keywords
               foo-mode-font-lock-keywords-extra)  ; levels
              nil nil nil nil))
```

## Indentation

Simple indent via `indent-line-function`. The function receives no
arguments and should move point to the correct column based on the
preceding lines. Use `save-excursion` so the caller's point doesn't
move unexpectedly.

For grammar-based languages, SMIE (Simple Minded Indentation Engine)
is the built-in framework. For tree-sitter languages, prefer
`treesit-simple-indent-rules` over SMIE.

## Tree-sitter (ts-mode) variants

From Emacs 29 onward, many languages ship two modes: a classic
`lang-mode` and a `lang-ts-mode` powered by tree-sitter. When you build
on top of a language that has a `ts-mode`, derive from `ts-mode`:

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

Use `major-mode-remap-alist` (Emacs 29+) to tell Emacs to open `.ts`
files with your mode instead of the built-in `typescript-ts-mode`:

```elisp
(add-to-list 'major-mode-remap-alist '(typescript-ts-mode . foo-ts-mode))
```

## Hook naming

Each `define-derived-mode` automatically creates a `MODE-hook`. Users
add to it via `add-hook`. Do not create parallel "before" / "after"
hooks unless you have a specific reason.

Run custom initialization inside the mode body; it runs after parent
mode setup and before `MODE-hook`.

## Testing

Use ERT with `ert-with-temp-file` fixtures:

```elisp
(ert-deftest foo-mode-indent-line-test ()
  (ert-with-temp-file file
    (with-temp-buffer
      (insert "let foo =\n1")
      (foo-mode)
      (indent-region (point-min) (point-max))
      (should (equal (buffer-string) "let foo =\n  1")))))
```

See `elisp-testing` skill for full ERT patterns.

## Anti-patterns

- Defining keybindings in the top-level of the file without a keymap —
  they end up global.
- Using `setq` instead of `setq-local` inside the mode body — bleeds
  into other buffers.
- Creating a new `defface` for every syntactic category — users
  can't theme them.
- Forgetting `;;;###autoload` — users can't open a file of your type
  without `(require 'foo-mode)` first.
- Deriving from `fundamental-mode`.
- Writing a whole new mode when a tree-sitter `ts-mode` exists for the
  language — derive from it instead.

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
