# Elisp Anti-patterns Reference

Detailed before/after examples for common Elisp anti-patterns.

## Keybindings

**Before (legacy):**
```elisp
(define-key global-map (kbd "C-c f") 'find-file)
(global-set-key (kbd "C-c f") 'find-file)
(local-set-key (kbd "C-c l") 'my-command)

(let ((map (make-sparse-keymap)))
  (define-key map (kbd "C-c a") 'action-a)
  (define-key map (kbd "C-c b") 'action-b)
  (setq my-mode-map map))
```

**After (modern):**
```elisp
(keymap-global-set "C-c f" #'find-file)
(keymap-set my-mode-map "C-c l" #'my-command)

(defvar-keymap my-mode-map
  :doc "Keymap for my-mode."
  "C-c a" #'action-a
  "C-c b" #'action-b)
```

Key differences:
- `keymap-set` uses `key-valid-p` syntax — no `kbd` needed
- `defvar-keymap` is declarative and self-documenting
- `#'function` (sharp-quote) enables byte-compiler checks

## Variables

**Before:**
```elisp
(setq show-paren-mode t)           ; doesn't actually enable the mode
(setq custom-safe-themes '(all))   ; bypasses :set handler
(setq tab-width 4)                 ; works but skips validation
```

**After:**
```elisp
(show-paren-mode 1)                       ; call the mode function
(setopt custom-safe-themes '(all))         ; respects :set
(setopt tab-width 4)                       ; validates :type
```

## Hooks

**Before:**
```elisp
(add-hook 'prog-mode-hook
          (lambda ()
            (display-line-numbers-mode 1)
            (hl-line-mode 1)))

(add-hook 'before-save-hook 'delete-trailing-whitespace)
```

**After:**
```elisp
(defun my--prog-mode-setup ()
  "Standard prog-mode configuration."
  (display-line-numbers-mode 1)
  (hl-line-mode 1))

(add-hook 'prog-mode-hook #'my--prog-mode-setup)
(add-hook 'before-save-hook #'delete-trailing-whitespace)
```

Benefits: named functions are removable (`remove-hook`), inspectable (`describe-function`), and show meaningful names in `describe-variable`.

## Loading

**Before:**
```elisp
(eval-after-load 'org
  '(progn
     (setq org-startup-indented t)
     (setq org-hide-leading-stars t)))

(require 'cl)

(when (fboundp 'if-let)
  (require 'subr-x))
```

**After:**
```elisp
(with-eval-after-load 'org
  (setopt org-startup-indented t)
  (setopt org-hide-leading-stars t))

(require 'cl-lib)

;; if-let*/when-let* are built-in on Emacs 30+, no require needed
```

## Naming

**Before:**
```elisp
(defun do-my-thing () ...)          ; no namespace prefix
(defvar flag nil)                    ; generic name, will collide
(defun mymod/helper () ...)          ; slash separator (non-standard)
(defun MyModule-Action () ...)       ; CamelCase (non-idiomatic)
```

**After:**
```elisp
(defun my-module-do-thing () ...)    ; namespaced, hyphenated
(defvar my-module-flag nil)          ; clear ownership
(defun my-module--helper () ...)     ; double-hyphen for internal
(defun my-module-action () ...)      ; all lowercase, hyphenated
```

## Package Management

**Before (with Nix):**
```elisp
(use-package magit
  :ensure t)                         ; fights with Nix

(package-install 'company)           ; bypasses Nix
(straight-use-package 'vertico)      ; another package manager
(treesit-install-language-grammar 'rust) ; Nix provides grammars
```

**After (with Nix):**
```elisp
(use-package magit)                  ; Nix already installed it

;; Add packages in your Nix expression:
;; emacsWithPackages (epkgs: [ epkgs.magit epkgs.company ])
;; Tree-sitter grammars also come from Nix
```

## Feature Gating

**Before:**
```elisp
(when (>= emacs-major-version 29)
  (pixel-scroll-precision-mode 1))
```

**After:**
```elisp
(when (fboundp 'pixel-scroll-precision-mode)
  (pixel-scroll-precision-mode 1))
```

`fboundp` is more robust — it works regardless of which version introduced the feature, and handles cases where features are backported or compiled out.
