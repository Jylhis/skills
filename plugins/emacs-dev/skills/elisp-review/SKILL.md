---
name: elisp-review
description: "Use for reviewing Emacs Lisp code quality including byte-compilation warnings, Elisp linting, checkdoc, package-lint, elisp-lint, code style audit, undefined function warnings, obsolete API detection, unused variable warnings, or when the user asks to review, audit, lint, or check an .el file for issues."
user-invocable: false
---

# Elisp Code Review

Systematic three-phase review process for Emacs Lisp files.

## Phase 1: Static Pattern Checks

Scan the file for these issues before doing anything else. Report all findings grouped by severity.

### Critical

- **Missing lexical-binding** — line 1 must contain `-*- lexical-binding: t; -*-`
- **Missing `provide`** — file must end with `(provide 'filename)` matching the filename
- **`(require 'cl)`** — must be `(require 'cl-lib)` instead; `cl` has been obsolete since Emacs 27
- **Bare `lambda` in hooks** — `(add-hook 'hook (lambda () ...))` cannot be removed or inspected; extract to a named function

### Warnings

- **Legacy keybinding APIs** — `define-key`, `global-set-key`, `local-set-key` should be `keymap-set`, `keymap-global-set`
- **`eval-after-load`** — should be `with-eval-after-load`
- **`setq` on defcustom variables** — should be `setopt` (Emacs 29+)
- **`:ensure t` in use-package** — remove if packages are Nix-managed
- **`if-let` / `when-let`** — use `if-let*` / `when-let*` (modern multi-binding forms)
- **Deprecated functions** — check for known obsolete functions (use `byte-compile` to catch these)

### Style

- **Missing namespace prefix** — all top-level definitions should share a consistent `prefix-` namespace
- **Single-hyphen internal functions** — internal helpers should use `prefix--double-hyphen`
- **`defcustom` without `:type` or `:group`** — both are required for proper Customize UI support
- **Magic numbers** — unexplained numeric constants should be `defconst` or `defcustom`

## Phase 2: Byte-compilation

Run byte-compilation in batch mode to catch issues the static scan misses:

```bash
emacs --batch \
  --eval '(setq byte-compile-error-on-warn t)' \
  -L . \
  --eval '(byte-compile-file "target-file.el")'
```

This catches:
- Undefined functions (including typos)
- Wrong number of arguments
- Unused `let`-bound variables
- References to free variables
- Obsolete function/variable warnings
- Malformed `defcustom` `:type` specs

If the file has dependencies, add their load paths with additional `-L` flags.

**Interpret the output:**
- `Warning: reference to free variable` — either missing `require`, missing `defvar` declaration, or a typo
- `Warning: the function 'X' is not known to be defined` — missing `require` or `autoload`, or the function is defined at runtime only
- `Warning: Unused lexical variable` — remove or prefix with `_` if intentionally unused

## Phase 3: Semantic Review

With Phases 1-2 clean, review the code for deeper quality issues:

### API Usage
- Uses modern APIs consistently (see elisp-conventions skill for the full list)
- Proper use of `cl-lib` functions (e.g., `cl-loop`, `cl-destructuring-bind`) rather than rolling custom equivalents
- Buffer-local variables set with `setq-local`, not `(set (make-local-variable ...) ...)`

### Error Handling
- Interactive commands use `user-error` (not `error`) for user-facing messages — `user-error` skips the debugger
- `condition-case` for expected failure modes (file not found, network errors)
- `unwind-protect` around resource acquisition (temp buffers, process handles)

### Performance
- Avoid `with-current-buffer` in tight loops — bind the buffer once
- Use `save-excursion` / `save-restriction` correctly (narrowing + point restoration)
- Heavy regex operations should use `looking-at` / `re-search-forward` with limits rather than matching against buffer substrings
- Prefer `pcase` over deeply nested `cond` for structural matching

### Documentation
- All public functions have docstrings
- Docstrings follow Emacs conventions: first line is a complete sentence, mentions arguments in UPCASE
- `defcustom` variables have meaningful docstrings explaining valid values

## Checkdoc

For documentation completeness, run checkdoc:

```bash
emacs --batch \
  -L . \
  --eval '(checkdoc-file "target-file.el")'
```

Checks: docstring formatting, sentence structure, argument references, spelling.

## Package-lint (if available)

For packages intended for MELPA/ELPA distribution:

```bash
emacs --batch \
  -L . \
  --eval '(require (quote package-lint))' \
  -f package-lint-batch-and-exit \
  target-file.el
```

Checks: header conventions, dependency declarations, naming compliance.

## Review Report Format

Structure your review output as:

```
## Critical Issues (must fix)
- [file:line] description

## Warnings (should fix)
- [file:line] description

## Style Suggestions (consider)
- [file:line] description

## Byte-compile Output
<output or "clean">

## Summary
N critical, N warnings, N style suggestions
```
