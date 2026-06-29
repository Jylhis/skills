---
name: bash
description: "Bash and shell-scripting guidance: choose the right script form, keep error handling explicit, prefer exact probes, and keep shell lint suppressions narrow."
---

# Bash

## Scope

- Use when writing, reviewing, or refactoring Bash or POSIX-shell-adjacent scripts and sourced shell helpers.

## Script Form Rules

- When a file is intended to be sourced rather than executed, model it as a sourced helper: do not add a shebang, do not keep the executable bit, do not add top-level safety pragmas such as `set -o ...` that would mutate the caller shell unexpectedly, remove dead source-vs-exec compatibility scaffolding once the file is sourced-only, and prefer top-level `return`, not `exit`, for sourced-only early exits. This keeps sourced files distinguishable and prevents accidental shell-mode changes from leaking into callers.

- When a file is intended to be executed directly, make that explicit: add the correct shebang, keep the executable bit set, and place required safety pragmas near the top so the runtime contract is visible from the file itself.

## Structure And Naming Rules

- When a Bash construct carries static data and no behavior, represent it as data rather than wrapping it in a parameterless function: prefer variables or arrays for fixed target lists or constant fragments so call sites stay direct and reviews do not chase dead indirection.

- When variables are not exported, use shell-local naming conventions: use `snake_case` for non-exported variables and reserve all-caps names for exported environment variables or well-established shell constants so reviewers can distinguish local script state from process environment at a glance.

- When the shell already has a direct builtin form for an operation, prefer that form over extra wrappers or subshells when behavior is equivalent: use straightforward redirections, assignments, and array literals over helper functions or subprocesses that add no behavior, and prefer direct idempotent commands such as `rm -rf path` over separate existence checks when behavior is equivalent. This reduces incidental process spawning and review noise.

- When the same non-trivial command sequence is open-coded multiple times, extract one named helper or shared data definition when that sequence carries behavior such as retries, timeouts, readiness checks, fallback handling, or terminal diagnostics. This keeps operational semantics consistent and prevents later edits from drifting across copies.

- When an `EXIT`, `ERR`, or `RETURN` trap or deferred cleanup path calls helper functions, make those helpers structurally available before the trap can fire: define the helpers before installing the trap, or guard the call explicitly, and do not rely on later function definitions if any top-level command between trap installation and that later definition can fail. This prevents cleanup-on-exit paths from raising a second failure because the cleanup helper was never defined.

## Error Handling And Logging Rules

- When handling expected failure cases, narrow the ignored case instead of suppressing all failures: do not use blanket `|| true`, branch on the specific expected error or state, and verify the intended postcondition after any fallback path so real failures remain visible and tolerated failures stay intentional and auditable.

- When suppressing command output, preserve diagnostics unless the code would break without silence: do not suppress stderr or exit status just to keep logs quiet, keep any suppression to the narrowest stream and scope necessary, and if retry loops keep transient retries quiet, emit the concrete stderr on terminal failure so failures still retain actionable diagnostics.

- When a message represents degraded but acceptable behavior, log it as a warning: emit warnings to stderr and prefix them consistently, for example with `WARN:`, so operators can separate warnings from normal progress output.

- When an input is required for all supported invocations, validate it at the script boundary instead of carrying an empty or derived placeholder forward. If an input is only needed for one branch, validate it at the point that branch becomes active.

- When a script enables `set -o noclobber`, treat every `>` redirection as suspicious: use `>|` when intentionally writing to a file that may already exist, especially paths returned by `mktemp`, and keep plain `>` only when failure on pre-existing output is the intended guard.

## Environment And Probe Rules

- When the runtime environment is controlled by repo-owned images or infrastructure, prefer explicit prerequisites over broad compatibility fallbacks: assume required tools are present when we own the environment as infrastructure code, and if a tool is mandatory, fail clearly when it is missing rather than layering speculative fallback code. This keeps environment contracts explicit and avoids dead or untested fallback logic.

- When probing filesystem or mount state, prefer exact state probes over path heuristics: use tools such as `mountpoint` or other identity-aware probes when checking mounts, and do not treat mere path existence as proof of the intended mount state so stale paths or partial mounts do not pass as success.

## Linting Rules

- When disabling shell lint rules, keep the suppression exact and justified: do not disable groups of `shellcheck` rules pre-emptively, disable only the specific rule that is still necessary after simplifying the code, and leave a short reason when the need is not obvious from the code itself. This keeps risky shell patterns visible to tooling.
