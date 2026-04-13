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
  assignment to the FSF.
- **NonGNU ELPA** — no copyright assignment required. Default for new
  packages that want to ship with stock Emacs.
- **MELPA** — community archive. Two channels: `melpa` (rolling) and
  `melpa-stable` (tagged releases).

Target **NonGNU ELPA + MELPA Stable** for new packages.

## File headers

```elisp
;;; foo.el --- Does the foo thing  -*- lexical-binding: t; -*-

;; Copyright (C) 2026 Markus Jylhankangas

;; Author: Markus Jylhankangas <markus@example.com>
;; Maintainer: Markus Jylhankangas <markus@example.com>
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
- **Author / Maintainer / URL / Version** headers.
- **`Package-Requires:`** — `emacs` first, lowest version you test against.
- **`Keywords:`** — from `finder-known-keywords`.
- **`;;; Commentary:` section**.
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

## package-lint

```bash
emacs -Q --batch \
  -L . \
  --eval "(require 'package-lint)" \
  -f package-lint-batch-and-exit \
  foo.el
```

Fix every error before submitting.

## MELPA recipe

Fork `melpa/melpa` and add `recipes/foo`:

```
(foo
 :fetcher github
 :repo "jylhis/foo.el"
 :files ("*.el" "README.md" (:exclude "tests/*.el")))
```

- `:fetcher` — `github`, `gitlab`, `sourcehut`, `codeberg`, or `url`.
- For **MELPA Stable**, tag releases with `vMAJOR.MINOR.PATCH`.

## NonGNU ELPA submission

Follow https://git.savannah.gnu.org/cgit/emacs/nongnu.git/tree/README.
Submit via mailing list patch or issue. Include a clear license
statement in every file.

## Version discipline

- Semantic versioning.
- Bump `Version:` header **and** tag in the same commit.
- Breaking changes require a major version bump.

## Release workflow

1. Update `CHANGELOG.md`.
2. Bump `Version:` in headers.
3. Run `package-lint` + `checkdoc` + byte-compile with warnings.
4. Run ERT tests via `emacs -Q --batch -L . -l ert -l tests/foo-test.el -f ert-run-tests-batch-and-exit`.
5. Commit, tag `vX.Y.Z`, push with `--tags`.

## Continuous integration

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

Before submitting to MELPA, post your recipe PR and ask for review in
`#emacs` on Libera Chat or on the `emacs-devel` list. Catches naming
conflicts and API design concerns.

## Anti-patterns

- Missing `;;; Commentary:` section — MELPA CI fails.
- Missing `(provide 'FOO)` — byte-compile fails.
- Version string without `Version:` header.
- `Package-Requires: ((emacs "28"))` when you use 29+ features.
- `lexical-binding: nil` in new code.
- Bundling third-party libraries — list them in `Package-Requires`.
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
