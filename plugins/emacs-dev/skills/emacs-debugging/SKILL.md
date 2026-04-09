---
name: emacs-debugging
description: "Use for Emacs debugging and troubleshooting including init errors, startup failures, --debug-init, debug-on-error, debug-on-message, Edebug, Emacs profiling, emacs-init-time, startup performance, native compilation issues, eln-cache, GC tuning, emacs --batch debugging, backtrace interpretation, freeze diagnosis, or when the user says Emacs is crashing, hanging, slow, or behaving unexpectedly."
user-invocable: false
---

# Emacs Debugging

Systematic approach to diagnosing Emacs problems. Start by identifying the symptom category, then follow the appropriate decision tree.

## Symptom Decision Tree

1. **Emacs won't start / errors on init** → Init Debugging
2. **Error during use** → Runtime Error Debugging
3. **Slow startup** → Startup Performance
4. **Slow during use** → Runtime Performance
5. **Emacs freezes** → Freeze Diagnosis
6. **Native compilation errors** → Native Comp Debugging
7. **Nix build failure** → Nix Build Debugging

## 1. Init Debugging

### Isolate the error

```bash
# Start with debug-on-error for a backtrace
emacs --debug-init

# Start with zero configuration to confirm it's your config
emacs -Q

# Load init file in batch mode for cleaner error output
emacs --batch -l ~/.emacs.d/init.el
```

### Binary search the config

If `--debug-init` doesn't pinpoint the issue, bisect:

```elisp
;; Comment out halves of your init.el until the error disappears
;; The last uncommented section contains the problem

;; Alternatively, use use-package's :catch to isolate
(use-package suspect-package
  :catch (lambda (keyword err)
           (message "Error in suspect-package %s: %s" keyword err)))
```

### Common init errors

| Error | Likely cause |
|-------|-------------|
| `Symbol's value as variable is void` | Missing `require` or typo in variable name |
| `Symbol's function definition is void` | Package not loaded, or function renamed/removed |
| `Wrong number of arguments` | API changed between Emacs versions |
| `Cannot open load file` | Package not installed or not on `load-path` |
| `Recursive load` | Circular `require` dependencies |

## 2. Runtime Error Debugging

### Get a backtrace

```elisp
;; Enable automatic backtrace on any error
(setopt debug-on-error t)

;; Break on a specific error signal
(setopt debug-on-signal t)

;; Break when a specific message appears
(setopt debug-on-message "regexp-matching-the-error")
```

### Read the backtrace

Backtraces read bottom-to-top. Look for the first frame that references your code (not Emacs internals):

```
Debugger entered--Lisp error: (wrong-type-argument stringp 42)
  my-module--format-value(42)         ; ← your code, the bug is here
  my-module-display-results()
  command-execute(my-module-display-results)
```

### Edebug (step debugger)

For complex logic, step through interactively:

```elisp
;; Instrument a function: place point inside it and run
M-x edebug-defun

;; Then call the function normally. Edebug takes over:
;; SPC = step, n = next, c = continue, q = quit
;; e = eval expression in current context
;; i = step into function call
```

To instrument all functions in a file:

```elisp
M-x edebug-all-defs  ;; toggle — then re-evaluate the file
```

### Batch debugging

For debugging in scripts or CI:

```bash
emacs --batch \
  --eval '(setq debug-on-error t)' \
  -l my-module.el \
  --eval '(my-module-do-thing)'
```

## 3. Startup Performance

### Measure total init time

```elisp
;; After startup, run:
M-x emacs-init-time
```

### Profile init

```elisp
;; Add to very beginning of early-init.el or init.el:
(defvar my--init-start-time (current-time))

;; At the end of init:
(message "Init completed in %.2f seconds"
         (float-time (time-subtract (current-time) my--init-start-time)))
```

### Per-package timing with use-package

```elisp
;; Add before any use-package forms:
(setopt use-package-compute-statistics t)

;; After startup:
M-x use-package-report
```

### Detailed require profiling

```elisp
;; Wrap require to measure each one
(defvar my--require-times nil)

(define-advice require (:around (orig feature &rest args) measure-time)
  (let ((start (current-time)))
    (prog1 (apply orig feature args)
      (push (cons feature (float-time (time-subtract (current-time) start)))
            my--require-times))))

;; After startup, inspect:
;; (sort my--require-times (lambda (a b) (> (cdr a) (cdr b))))
```

### Common slowdowns

- **`:ensure t` with slow MELPA connection** — remove if using Nix
- **Eager package loading** — add `:defer t` or use autoload triggers
- **`(require 'org)` at top level** — Org is large; defer with `with-eval-after-load`
- **Synchronous network calls** — DNS resolution, package refresh at startup

## 4. Runtime Performance

### Built-in profiler

```elisp
;; Start profiling
M-x profiler-start     ;; choose CPU, memory, or both

;; Do the slow thing

;; View results
M-x profiler-report
M-x profiler-stop
```

In the report, press `TAB` to expand call trees. Look for your functions with high self-time.

### ELP (Emacs Lisp Profiler)

Profile specific functions:

```elisp
(require 'elp)
(elp-instrument-package "my-module")

;; Do the slow thing

(elp-results)          ;; shows call count and time per function
(elp-restore-all)      ;; remove instrumentation
```

### Benchmark specific code

```elisp
(require 'benchmark)
(benchmark-run 100
  (my-module-expensive-operation))
;; → (elapsed-time gc-count gc-time)
```

### GC pressure

```elisp
;; See GC activity
(setopt garbage-collection-messages t)

;; Check GC stats
(garbage-collect)  ;; returns detailed memory breakdown

;; Tune GC threshold (carefully)
(setopt gc-cons-threshold (* 16 1024 1024))  ;; 16 MB
;; Reset after init if you raised it for startup:
(add-hook 'emacs-startup-hook
          (lambda () (setopt gc-cons-threshold (* 2 1024 1024))))

;; Memory report (Emacs 29+)
M-x memory-report
```

## 5. Freeze Diagnosis

When Emacs stops responding:

### macOS
```bash
# Get a stack trace of the frozen process
sample Emacs -e -f /tmp/emacs-sample.txt
```

### Linux
```bash
# Attach to the process
sudo perf record -p $(pgrep emacs) -g -- sleep 10
sudo perf report

# Or send SIGUSR2 to enter the debugger
kill -USR2 $(pgrep emacs)
```

### Common freeze causes

- **Busy loop in Elisp** — usually a `while` without advancing state
- **Synchronous subprocess** — `call-process` or `shell-command` waiting on a hung process
- **Regex catastrophic backtracking** — overly complex regex on large input
- **Lock contention** — file locks, process locks
- **Network wait** — synchronous URL retrieval with no timeout

## 6. Native Compilation Debugging

### ABI mismatch after Emacs upgrade

```bash
# Symptoms: wrong-type-argument, strange errors in previously working code
# Fix: clear the eln-cache
rm -rf ~/.emacs.d/eln-cache/
# Emacs will recompile on next load
```

### Compilation errors

```elisp
;; Check native-comp status
(native-comp-available-p)  ;; → t if working

;; See what failed
M-x native-compile-async  ;; recompile with output

;; Verbose logging
(setopt native-comp-verbose 3)  ;; 0=silent, 3=very verbose
```

### Disable native comp for a problematic package

```elisp
(setopt native-comp-jit-compilation-deny-list
        '("problematic-package"))
```

## 7. Nix Build Debugging

When building Emacs from source with Nix:

```bash
# Show full build log with trace
nix build .#emacs --show-trace -L

# Keep the build directory for inspection
nix build .#emacs --keep-failed

# Enter a dev shell to run build phases manually
nix develop .#emacs
unpackPhase && cd $sourceRoot
configurePhase
buildPhase
```

### Common Nix + Emacs issues

| Issue | Fix |
|-------|-----|
| Missing native library | Add the library to `buildInputs` in the derivation |
| Tree-sitter grammar not found | Check the grammar is in `treesit-extra-load-path` |
| Version mismatch after update | `nix flake update` and rebuild |
| `eln-cache` stale after rebuild | Clear `~/.emacs.d/eln-cache/` |

## General Debugging Tips

- **Reproduce minimally** — start with `emacs -Q`, load only what's needed
- **Check `*Messages*`** — most errors and warnings appear here
- **Check `*Warnings*`** — native-comp and other async warnings land here
- **Use `toggle-debug-on-error`** — keybinding: `M-x toggle-debug-on-error`
- **Read the backtrace bottom-to-top** — your code frame is what matters
- **Check Emacs version** — `M-x emacs-version` to verify you're running what you think
