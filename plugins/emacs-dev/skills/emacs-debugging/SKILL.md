---
name: emacs-debugging
description: "Use for Emacs debugging and troubleshooting including init errors, startup failures, --debug-init, debug-on-error, debug-on-message, Edebug, Emacs profiling, emacs-init-time, startup performance, native compilation issues, eln-cache, GC tuning, emacs --batch debugging, backtrace interpretation, freeze diagnosis, or when the user says Emacs is crashing, hanging, slow, or behaving unexpectedly."
user-invocable: false
---

# Emacs Debugging

## Symptom Decision Tree

1. **Emacs won't start / errors on init** -> Init Debugging
2. **Error during use** -> Runtime Error Debugging
3. **Slow startup** -> Startup Performance
4. **Slow during use** -> Runtime Performance
5. **Emacs freezes** -> Freeze Diagnosis
6. **Native compilation errors** -> Native Comp Debugging
7. **Nix build failure** -> Nix Build Debugging

## 1. Init Debugging

### Isolate the error

```bash
emacs --debug-init       # backtrace on init error
emacs -Q                 # zero config — confirm it's your config
emacs --batch -l ~/.emacs.d/init.el  # batch mode for cleaner output
```

### Binary search the config

```elisp
;; Comment out halves of init.el until the error disappears

;; Or use use-package's :catch
(use-package suspect-package
  :catch (lambda (keyword err)
           (message "Error in suspect-package %s: %s" keyword err)))
```

### Common init errors

| Error | Likely cause |
|-------|-------------|
| `Symbol's value as variable is void` | Missing `require` or typo |
| `Symbol's function definition is void` | Package not loaded or function removed |
| `Wrong number of arguments` | API changed between Emacs versions |
| `Cannot open load file` | Package not installed or not on `load-path` |
| `Recursive load` | Circular `require` dependencies |

## 2. Runtime Error Debugging

### Get a backtrace

```elisp
(setopt debug-on-error t)
(setopt debug-on-signal t)
(setopt debug-on-message "regexp-matching-the-error")
```

### Read the backtrace

Backtraces read bottom-to-top. Look for the first frame referencing your code:

```
Debugger entered--Lisp error: (wrong-type-argument stringp 42)
  my-module--format-value(42)         ; <- your code, the bug is here
  my-module-display-results()
  command-execute(my-module-display-results)
```

### Edebug (step debugger)

```elisp
;; Instrument a function: place point inside it and run
M-x edebug-defun

;; Then call the function normally. Edebug takes over:
;; SPC = step, n = next, c = continue, q = quit
;; e = eval expression in current context
;; i = step into function call
```

To instrument all functions in a file: `M-x edebug-all-defs` then
re-evaluate the file.

### Batch debugging

```bash
emacs --batch \
  --eval '(setq debug-on-error t)' \
  -l my-module.el \
  --eval '(my-module-do-thing)'
```

## 3. Startup Performance

### Measure

```elisp
M-x emacs-init-time
```

### Per-package timing with use-package

```elisp
(setopt use-package-compute-statistics t)
;; After startup:
M-x use-package-report
```

### Detailed require profiling

```elisp
(defvar my--require-times nil)

(define-advice require (:around (orig feature &rest args) measure-time)
  (let ((start (current-time)))
    (prog1 (apply orig feature args)
      (push (cons feature (float-time (time-subtract (current-time) start)))
            my--require-times))))
```

### Common slowdowns

- **`:ensure t` with slow MELPA connection** — remove if using Nix
- **Eager package loading** — add `:defer t` or use autoload triggers
- **`(require 'org)` at top level** — Org is large; defer with `with-eval-after-load`
- **Synchronous network calls** at startup

## 4. Runtime Performance

### Built-in profiler

```elisp
M-x profiler-start     ;; choose CPU, memory, or both
;; Do the slow thing
M-x profiler-report
M-x profiler-stop
```

### ELP (Emacs Lisp Profiler)

```elisp
(require 'elp)
(elp-instrument-package "my-module")
;; Do the slow thing
(elp-results)
(elp-restore-all)
```

### Benchmark

```elisp
(require 'benchmark)
(benchmark-run 100
  (my-module-expensive-operation))
;; -> (elapsed-time gc-count gc-time)
```

### GC tuning

```elisp
(setopt garbage-collection-messages t)
(setopt gc-cons-threshold (* 16 1024 1024))  ;; 16 MB
;; Reset after init:
(add-hook 'emacs-startup-hook
          (lambda () (setopt gc-cons-threshold (* 2 1024 1024))))

;; Memory report (Emacs 29+)
M-x memory-report
```

## 5. Freeze Diagnosis

### macOS
```bash
sample Emacs -e -f /tmp/emacs-sample.txt
```

### Linux
```bash
sudo perf record -p $(pgrep emacs) -g -- sleep 10
sudo perf report

# Or send SIGUSR2 to enter the debugger
kill -USR2 $(pgrep emacs)
```

### Common causes

- **Busy loop in Elisp** — `while` without advancing state
- **Synchronous subprocess** waiting on a hung process
- **Regex catastrophic backtracking**
- **Network wait** — synchronous URL retrieval with no timeout

## 6. Native Compilation Debugging

### ABI mismatch after upgrade

```bash
# Fix: clear the eln-cache
rm -rf ~/.emacs.d/eln-cache/
```

### Compilation errors

```elisp
(native-comp-available-p)  ;; -> t if working
M-x native-compile-async   ;; recompile with output
(setopt native-comp-verbose 3)
```

### Disable native comp for a problematic package

```elisp
(setopt native-comp-jit-compilation-deny-list
        '("problematic-package"))
```

## 7. Nix Build Debugging

```bash
nix build .#emacs --show-trace -L
nix build .#emacs --keep-failed
nix develop .#emacs
unpackPhase && cd $sourceRoot
configurePhase
buildPhase
```

### Common Nix + Emacs issues

| Issue | Fix |
|-------|-----|
| Missing native library | Add to `buildInputs` |
| Tree-sitter grammar not found | Check `treesit-extra-load-path` |
| Version mismatch after update | `nix flake update` and rebuild |
| `eln-cache` stale after rebuild | Clear `~/.emacs.d/eln-cache/` |

## General Tips

- **Reproduce minimally** — start with `emacs -Q`, load only what's needed
- **Check `*Messages*`** and **`*Warnings*`** buffers
- **Use `toggle-debug-on-error`**
- **Read the backtrace bottom-to-top**
- **Check Emacs version** — `M-x emacs-version`
