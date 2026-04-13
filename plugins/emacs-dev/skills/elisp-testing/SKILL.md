---
name: elisp-testing
description: "Use for writing Emacs Lisp tests including ERT (Emacs Regression Testing), ert-deftest, ert-with-temp-file, ert-with-temp-directory, test assertions (should, should-not, should-error), running tests in batch mode, mocking with cl-letf, test fixtures, state isolation for Emacs tests, buttercup BDD testing, or when the user asks to write tests for .el files or test Emacs Lisp code."
user-invocable: false
---

# Elisp Testing with ERT

## Test File Structure

```elisp
;;; my-module-test.el --- Tests for my-module  -*- lexical-binding: t; -*-

;;; Commentary:

;; ERT tests for my-module.

;;; Code:

(require 'ert)
(require 'my-module)

;; ... tests ...

(provide 'my-module-test)
;;; my-module-test.el ends here
```

Place test files in `test/`, named `<module>-test.el`.

## Running Tests

```bash
# Run all tests in a file
emacs --batch -L lisp -L test \
  -l test/my-module-test.el \
  -f ert-run-tests-batch-and-exit

# Run specific test
emacs --batch -L lisp -L test \
  -l test/my-module-test.el \
  --eval '(ert-run-tests-batch-and-exit "my-module-test-specific-name")'

# Run tests matching a pattern
emacs --batch -L lisp -L test \
  -l test/my-module-test.el \
  --eval '(ert-run-tests-batch-and-exit "my-module")'
```

## Basic Assertions

```elisp
(ert-deftest my-module-test-addition ()
  "Addition produces expected results."
  (should (= (my-module-add 2 3) 5))
  (should-not (= (my-module-add 2 3) 6))
  (should-error (my-module-add "a" 3) :type 'wrong-type-argument))
```

| Form | Checks |
|------|--------|
| `(should EXPR)` | EXPR is non-nil |
| `(should-not EXPR)` | EXPR is nil |
| `(should-error EXPR)` | EXPR signals an error |
| `(should-error EXPR :type 'TYPE)` | EXPR signals error of TYPE |

## State Isolation

Use `let`-binding to temporarily override variables:

```elisp
(ert-deftest my-module-test-respects-config ()
  "Feature respects the configuration variable."
  (let ((my-module-enable-feature t)
        (my-module-backend 'fast))
    (should (eq (my-module-current-backend) 'fast))))
```

### Isolation Macro

```elisp
(defmacro my-module-test-with-clean-state (&rest body)
  "Execute BODY with a clean module state."
  (declare (indent 0) (debug t))
  `(let ((my-module-enable-feature nil)
         (my-module--cache nil)
         (my-module-backend 'default))
     ,@body))

(ert-deftest my-module-test-default-state ()
  (my-module-test-with-clean-state
    (should (eq (my-module-current-backend) 'default))))
```

### Buffer Isolation

```elisp
(ert-deftest my-module-test-buffer-operation ()
  "Operation modifies buffer correctly."
  (with-temp-buffer
    (insert "hello world")
    (goto-char (point-min))
    (my-module-capitalize-word)
    (should (equal (buffer-string) "Hello world"))))
```

### File Isolation

```elisp
;; Emacs 29+
(ert-deftest my-module-test-file-operation ()
  "Read/write cycle preserves content."
  (ert-with-temp-file tmpfile
    :suffix ".txt"
    (my-module-write-file tmpfile "test content")
    (should (equal (my-module-read-file tmpfile) "test content"))))

(ert-deftest my-module-test-directory-operation ()
  "Processes all files in a directory."
  (ert-with-temp-directory tmpdir
    (let ((f1 (expand-file-name "a.txt" tmpdir))
          (f2 (expand-file-name "b.txt" tmpdir)))
      (write-region "aaa" nil f1)
      (write-region "bbb" nil f2)
      (should (= (my-module-count-files tmpdir) 2)))))
```

## Mocking with cl-letf

```elisp
(require 'cl-lib)

(ert-deftest my-module-test-with-mock ()
  "Uses mock when network is unavailable."
  (cl-letf (((symbol-function 'url-retrieve-synchronously)
             (lambda (_url)
               (with-current-buffer (generate-new-buffer " *mock*")
                 (insert "HTTP/1.1 200 OK\n\nmocked response")
                 (current-buffer)))))
    (should (equal (my-module-fetch-data "http://example.com")
                   "mocked response"))))
```

### Spy Pattern

```elisp
(ert-deftest my-module-test-calls-hook ()
  "Runs the hook function when activated."
  (let ((called nil))
    (cl-letf (((symbol-function 'my-module--notify)
               (lambda (&rest _) (setq called t))))
      (my-module-activate)
      (should called))))
```

### Capturing Messages

```elisp
(ert-deftest my-module-test-messages ()
  "Produces the expected message."
  (let ((messages '()))
    (cl-letf (((symbol-function 'message)
               (lambda (fmt &rest args)
                 (push (apply #'format fmt args) messages))))
      (my-module-greet "world")
      (should (member "Hello, world!" messages)))))
```

## Testing Hooks

```elisp
(ert-deftest my-module-test-hook-fires ()
  "Hook runs when expected."
  (let ((hook-ran nil))
    (add-hook 'my-module-after-action-hook
              (lambda () (setq hook-ran t)))
    (unwind-protect
        (progn
          (my-module-do-action)
          (should hook-ran))
      (remove-hook 'my-module-after-action-hook
                   (car (last my-module-after-action-hook))))))
```

## Testing Keybindings

```elisp
(ert-deftest my-module-test-keybinding ()
  "Keybinding resolves to the correct command."
  (should (eq (keymap-lookup my-module-map "C-c m a")
              #'my-module-action)))
```

## Testing Minor Modes

```elisp
(ert-deftest my-module-test-mode-activation ()
  "Minor mode activates and deactivates cleanly."
  (with-temp-buffer
    (my-module-mode 1)
    (should my-module-mode)
    (should (eq (current-local-map) my-module-mode-map))
    (my-module-mode -1)
    (should-not my-module-mode)))
```

## Testing Async / Timers

```elisp
(ert-deftest my-module-test-debounced ()
  "Debounced function eventually executes."
  (let ((result nil))
    (my-module-debounced-set (lambda () (setq result 'done)))
    ;; Force timer execution
    (ert-run-idle-timers)
    (should (eq result 'done))))
```

## Expected Failures

```elisp
(ert-deftest my-module-test-known-issue ()
  :expected-result :failed
  "Documents issue #42 — off-by-one in range calculation."
  (should (= (my-module-range 1 5) 4)))
```

## Test Naming

Convention: `<module>-test-<what-is-being-tested>`

```elisp
(ert-deftest my-module-test-parse-empty-input () ...)
(ert-deftest my-module-test-export-with-unicode () ...)
(ert-deftest my-module-test-handles-missing-file () ...)
```
