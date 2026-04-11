---
name: elisp-package-publishing
description: >
  Publishing an Elisp package to MELPA and GNU ELPA: file headers,
  autoloads, package-lint, MELPA recipe, releases, and the Copilot of
  ELPA review workflow. Apply when preparing a package for publication
  or updating an existing release.
---

# Publishing an Elisp package

Two main registries:

- **GNU ELPA** — official GNU package archive. Requires copyright
  assignment to the FSF. Slower review, stricter criteria.
- **NonGNU ELPA** — GNU-adjacent, **no copyright assignment required**.
  The default for new packages that want to ship with stock Emacs out
  of the box.
- **MELPA** — community archive. Most packages live here. Two channels:
  `melpa` (rolling, always-latest-commit) and `melpa-stable` (tagged
  releases).

Target **NonGNU ELPA + MELPA Stable** for new packages. Drop GNU ELPA
unless you've already assigned copyright.

## File headers

The package's main `.el` file must begin with a valid headers block:

```elisp
;;; foo.el --- Does the foo thing  -*- lexical-binding: t; -*-

;; Copyright (C) 2026 Markus Jylhänkangas

;; Author: Markus Jylhänkangas <markus@example.com>
;; Maintainer: Markus Jylhänkangas <markus@example.com>
;; URL: https://github.com/jylhis/foo.el
;; Version: 0.1.0
;; Package-Requires: ((emacs "29.1") (transient "0.5"))
;; Keywords: tools, convenience

;; This file is NOT part of GNU Emacs.

;; This program is free software; you can redistribute it and/or modify
;; it under the terms of the GNU General Public License version 3 or later.

;;; Commentary:

;; Foo does the thing.  See README.md for usage.

;;; Code:

(require 'transient)

;; ... package code ...

(provide 'foo)
;;; foo.el ends here
```

Mandatory:

- **First line:** `;;; FILENAME.el --- SUMMARY  -*- lexical-binding: t; -*-`
- **Author / Maintainer / URL / Version** — one per line.
- **`Package-Requires:`** — list of `(package version)` forms. `emacs`
  is always first and should be the lowest version you test against.
- **`Keywords:`** — pick from the list in `finder-known-keywords`.
- **`;;; Commentary:` section** — user-facing description.
- **Last line:** `;;; FILENAME.el ends here`
- **`(provide 'FOO)`** before the end-here line.

## Autoloads

Mark user-facing entry points with `;;;###autoload`:

```elisp
;;;###autoload
(defun foo-run ()
  "Run foo in the current buffer."
  (interactive)
  ...)

;;;###autoload
(add-to-list 'auto-mode-alist '("\\.foo\\'" . foo-mode))
```

- Put the cookie above `defun`, `define-minor-mode`, major mode
  registrations, and `add-to-list` calls that should run at startup.
- Package managers generate an `autoloads.el` file by scanning these
  cookies — users don't pay the load cost until they call the
  command.

## package-lint

`package-lint` catches every common packaging mistake:

```bash
emacs -Q --batch \
  -L . \
  --eval "(require 'package-lint)" \
  -f package-lint-batch-and-exit \
  foo.el
```

Or interactively: `M-x package-lint-current-buffer`.

Fix every error before submitting. Warnings (`experimental`,
`unusual`) are fine to suppress if you have a reason.

## MELPA recipe

Fork `melpa/melpa` and add `recipes/foo`:

```
(foo
 :fetcher github
 :repo "jylhis/foo.el"
 :files ("*.el" "README.md" (:exclude "tests/*.el")))
```

- `:fetcher` — `github`, `gitlab`, `sourcehut`, `codeberg`, or `url`.
- `:files` — defaults cover most cases; override only when needed.
- **For MELPA Stable**, also tag your release commits with
  `vMAJOR.MINOR.PATCH` (e.g. `v0.1.0`) — MELPA Stable picks up tags
  matching the default pattern.

Open a PR to `melpa/melpa`. The CI runs `package-lint`, builds the
package, and posts results on the PR.

## NonGNU ELPA submission

Follow https://git.savannah.gnu.org/cgit/emacs/nongnu.git/tree/README.
Submit via a mailing list patch or by opening an issue. No copyright
assignment; include a clear license statement in every file.

## Version discipline

- Use semantic versioning.
- Bump the `Version:` header **and** any tag in the same commit as the
  change.
- Maintain a `CHANGELOG.md` or `NEWS` file — MELPA Stable does not read
  it but your users will.
- Breaking changes require a major version bump. Don't surprise users.

## Release workflow

1. Update `CHANGELOG.md` with the new version notes.
2. Bump `Version:` in headers.
3. Run `package-lint` + `checkdoc` + byte-compile with warnings.
4. Run ERT tests via `emacs -Q --batch -L . -l ert -l tests/foo-test.el -f ert-run-tests-batch-and-exit`.
5. Commit, tag `vX.Y.Z`, push with `--tags`.
6. MELPA Stable and NonGNU ELPA pick up the tag on their next build.

## Continuous integration

A minimal GitHub Actions workflow:

```yaml
name: CI
on: [push, pull_request]
jobs:
  test:
    runs-on: ubuntu-latest
    strategy:
      matrix:
        emacs_version: ['29.4', '30.1', 'snapshot']
    steps:
      - uses: actions/checkout@v4
      - uses: purcell/setup-emacs@master
        with:
          version: ${{ matrix.emacs_version }}
      - run: |
          emacs -Q --batch -L . \
            --eval "(setq byte-compile-error-on-warn t)" \
            -f batch-byte-compile *.el
      - run: |
          emacs -Q --batch -L . \
            --eval "(require 'package-lint)" \
            -f package-lint-batch-and-exit *.el
      - run: |
          emacs -Q --batch -L . \
            -l ert -l tests/foo-test.el \
            -f ert-run-tests-batch-and-exit
```

Treat byte-compile warnings as errors in CI.

## Copilot of ELPA review

The Elisp community runs a cooperative review process called "Copilot
of ELPA" — before submitting to MELPA, post your recipe PR and ask for
review in `#emacs` on Libera Chat or on the `emacs-devel` or
`emacs-orgmode` lists. It catches packaging issues, naming conflicts
with existing packages, and API design concerns.

## Anti-patterns

- Missing `;;; Commentary:` section — MELPA CI fails.
- Missing `(provide 'FOO)` — byte-compile fails.
- Version string without `Version:` header — package.el uses date-stamp
  fallback that nobody wants.
- `Package-Requires: ((emacs "28"))` when you use 29+ features —
  package-lint catches this.
- `lexical-binding: nil` (the default) — use `t` always in new code.
- Bundling third-party libraries into your repo — list them in
  `Package-Requires` so package.el resolves them.
- Publishing before running `checkdoc` and `package-lint`.

## Tool detection

```bash
for tool in emacs; do
  command -v "$tool" >/dev/null && echo "ok: $tool" || echo "MISSING: $tool"
done
```

## References

- Elisp manual - Packaging: https://www.gnu.org/software/emacs/manual/html_node/elisp/Packaging.html
- MELPA recipes: https://github.com/melpa/melpa#recipe-format
- NonGNU ELPA: https://elpa.nongnu.org
- package-lint: https://github.com/purcell/package-lint
- Setup-emacs GitHub Action: https://github.com/purcell/setup-emacs
