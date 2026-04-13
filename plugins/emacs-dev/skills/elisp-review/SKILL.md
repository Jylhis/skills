---
name: elisp-review
description: "Use for reviewing Emacs Lisp code quality including byte-compilation warnings, Elisp linting, checkdoc, package-lint, elisp-lint, code style audit, undefined function warnings, obsolete API detection, unused variable warnings, or when the user asks to review, audit, lint, or check an .el file for issues."
user-invocable: false
---

# Elisp Code Review

Three-phase review process for Emacs Lisp files.

## Phase 1: Static Pattern Checks

### Critical

- **Missing lexical-binding** — line 1 must contain `-*- lexical-binding: t; -*-`
- **Missing `provide`** — file must end with `(provide 'filename)` matching the filename
- **`(require 'cl)`** — must be `(require 'cl-lib)`; `cl` is obsolete since Emacs 27
- **Bare `lambda` in hooks** — extract to a named function

### Warnings

- **Legacy keybinding APIs** — `define-key`, `global-set-key`, `local-set-key` should be `keymap-set`, `keymap-global-set`
- **`eval-after-load`** — should be `with-eval-after-load`
- **`setq` on defcustom variables** — should be `setopt` (Emacs 29+)
- **`:ensure t` in use-package** — remove if packages are Nix-managed
- **`if-let` / `when-let`** — use `if-let*` / `when-let*`
- **Deprecated functions** — use byte-compile to catch these

### Style

- **Missing namespace prefix** — all top-level definitions should share a consistent `prefix-` namespace
- **Single-hyphen internal functions** — internal helpers should use `prefix--double-hyphen`
- **`defcustom` without `:type` or `:group`**
- **Magic numbers** — should be `defconst` or `defcustom`

## Phase 2: Byte-compilation

```bash
emacs --batch \
  --eval '(setq byte-compile-error-on-warn t)' \
  -L . \
  --eval '(byte-compile-file "target-file.el")'
```

Catches: undefined functions, wrong argument counts, unused `let`-bound
variables, free variable references, obsolete function/variable
warnings, malformed `defcustom` `:type` specs.

**Interpret the output:**
- `reference to free variable` — missing `require`, missing `defvar`, or typo
- `function 'X' is not known to be defined` — missing `require` or `autoload`
- `Unused lexical variable` — remove or prefix with `_`

## Phase 3: Semantic Review

### API Usage
- Modern APIs used consistently (see elisp-conventions skill)
- Proper `cl-lib` usage rather than custom equivalents
- Buffer-local variables set with `setq-local`

### Error Handling
- Interactive commands use `user-error` (not `error`) for user-facing messages
- `condition-case` for expected failure modes
- `unwind-protect` around resource acquisition

### Performance
- Avoid `with-current-buffer` in tight loops
- Use `save-excursion` / `save-restriction` correctly
- Prefer `pcase` over deeply nested `cond` for structural matching

### Documentation
- All public functions have docstrings
- First line is a complete sentence, arguments in UPCASE
- `defcustom` variables have meaningful docstrings

## Checkdoc

```bash
emacs --batch \
  -L . \
  --eval '(checkdoc-file "target-file.el")'
```

## Package-lint (if available)

```bash
emacs --batch \
  -L . \
  --eval '(require (quote package-lint))' \
  -f package-lint-batch-and-exit \
  target-file.el
```

## Review Report Format

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
