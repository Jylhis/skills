---
name: verify
description: >
  Run the repo's full verification gate and summarize pass or fail. Use when
  the user says "verify", "check all systems", "nix flake check all systems",
  "does it build", "run the tests", "is everything green", or asks for
  validation before or after a change without shipping it.
---

# Verify

The verification loop, wrapped once. Detect the repo's gates, run them, and
report a summary instead of raw command dumps.

## Step 1: Pick the gates

In order, using the first that applies:

| Repo shape | Gate |
|---|---|
| justfile with `check` + `test` (j10s, marchyo, skills) | `just check`, then `just test` |
| Focus inside one project (j10s `projects/<name>`) | that project's `just test` |
| Nix flake without just recipes | `nix flake check` |
| Plain project (Go, Rust, Python, ...) | its native test command (`go test ./...`, `cargo test`, `pytest`) |

`just check` is the fast local gate; `just test` is the full gate (`nix flake
check` plus every project's tests plus infrastructure). Use both when asked
to "verify"; use only the nearest gate when verifying a focused change.

## Step 2: Run them

- Run each gate separately so a failure in one does not hide the others.
- Nix eval gates can take minutes: run them with a generous timeout and say
  which gate is running while it works.
- nixbuild.net caches failed builds. When a check fails and the error looks
  stale or unrelated to the change, reproduce locally with `--builders ''`.

## Step 3: Summarize

A one-line-per-gate verdict:

```
verify: PASS
- just check     ok    (12s)
- just test      ok    (4m03s)
```

On failure, show the gate name, the first real error (skip the Nix eval
noise above it), and the file or derivation it points to. Name the most
likely fix in one sentence. Do not paste the full log; give the command to
re-run it instead.