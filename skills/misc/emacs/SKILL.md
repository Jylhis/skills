---
name: emacs
description: Use for Emacs and Emacs Lisp work — modern Elisp conventions (lexical-binding, use-package, keymap-set, setopt, defvar-keymap, if-let*, tree-sitter ts-mode), authoring major modes (define-derived-mode, font-lock, indent-line-function, syntax tables, treesit-simple-indent-rules), package publishing (MELPA / GNU ELPA / NonGNU ELPA, ;;;###autoload, package-lint, checkdoc), code review (linting, byte-compile, obsolete API detection), ERT testing, debugging (--debug-init, Edebug, profiler, native-comp), gptel + MCP integration, introspection (describe-*, apropos, find-function), and keybinding design (keymap layers, key-valid-p). Read the matching reference before acting.
---

# Emacs skill index

Pick the topic and read its reference before writing or reviewing
Emacs Lisp.

| Topic | When to read | Reference |
|---|---|---|
| Elisp conventions | lexical-binding, use-package, modern API (keymap-set, setopt, defvar-keymap, if-let*), file structure, hooks | `references/elisp-conventions.md` |
| Major mode authoring | define-derived-mode, font-lock, indent-line-function, syntax tables, tree-sitter ts-mode parents, treesit-simple-indent-rules | `references/elisp-major-mode-authoring.md` |
| Package publishing | MELPA / GNU ELPA / NonGNU ELPA, file headers, ;;;###autoload, package-lint, checkdoc, version tagging, CI | `references/elisp-package-publishing.md` |
| Code review | byte-compile warnings, checkdoc, package-lint, elisp-lint, obsolete API detection, unused-variable warnings | `references/elisp-review.md` |
| Testing (ERT) | ert-deftest, should/should-not/should-error, batch mode, mocking with cl-letf, fixtures, buttercup | `references/elisp-testing.md` |
| Debugging | --debug-init, debug-on-error, Edebug, profiler, emacs-init-time, native-comp eln-cache, freezes | `references/debugging.md` |
| gptel + MCP | gptel-make-anthropic, gptel-backend, mcp-hub-servers, auth-source key, exposing Emacs as MCP server | `references/gptel-integration.md` |
| Introspection | describe-function/variable/key/mode, apropos, Info, find-function, xref, M-., shortdoc | `references/introspection.md` |
| Keybindings | keymap-set, keymap-global-set, defvar-keymap, key-valid-p, keymap layers, prefix keys, repeat-mode | `references/keybindings.md` |

For Emacs **packaging via Nix** (`emacsWithPackages`, melpaBuild,
trivialBuild, native-comp, tree-sitter grammars), use the `nix` skill's
`references/emacs-packaging.md` instead.

After reading the reference, follow its guidance for the task.
