# Running checks headlessly

How to run this repo's checks in CI, cron jobs, or any environment
without an interactive shell. Ordered from fewest to most dependencies.

## Fast path: no devenv

The portable skill lint needs only `python3` and PyYAML. No Nix, no
devenv, no just:

```sh
python3 scripts/validate.py
```

Exit code 0 means every skill passes; advisory warnings (upstream drift,
script-language nudges) print to stderr but do not fail the run.

The eval smoke test is also plain Python (stubbed SUT and judge, no
network, no promptfoo). To run it without just, loop over the discovered
suites directly:

```sh
suites="$(python3 -c 'import sys; sys.path.insert(0, "evals/scripts"); from _paths import discover_suites; print("\n".join(discover_suites()))')"
for suite in $suites; do
    python3 evals/scripts/expand.py "$suite" --stub-sut --no-rubric
    python3 evals/scripts/invariants.py --provider stub --judge stub --suite "$suite"
done
```

## Full local gate (requires devenv)

With Nix and devenv installed, enter the shell and run the composite
recipes. `just check` runs shellcheck plus the skill lint; `just
eval-smoke` runs the smoke test for every discovered suite
(`skills/*/*/evals/cases.yaml`), or a single suite if you name one:

```sh
devenv shell        # or: direnv allow
just check
just eval-smoke             # all suites
just eval-smoke ast-grep    # one suite
```

Non-interactively (one-shot, suitable for CI steps):

```sh
devenv shell -- just check
devenv shell -- just eval-smoke
```

## Agentic headless recipe (requires the claude CLI)

For unattended runs where an agent should execute the gate and summarize
the outcome (nightly cron, a CI job that triages failures), use Claude
Code's headless mode: `claude -p` runs a single non-interactive turn, and
`--allowedTools` pre-approves only the listed tools. This is the
officially documented pattern for unattended automation: nobody is
watching the run, so the allowlist is what limits what the agent can do.
Scope it to exactly the commands the gate needs and nothing else.

```sh
claude -p "Run python3 scripts/validate.py. Then list the eval suites \
with a python3 -c one-liner that adds evals/scripts to sys.path and \
prints _paths.discover_suites(). For each suite run python3 \
evals/scripts/expand.py <suite> --stub-sut --no-rubric and python3 \
evals/scripts/invariants.py --provider stub --judge stub --suite \
<suite>. Report pass/fail per step; on failure include the command \
and its output." \
  --allowedTools "Bash(python3 scripts/validate.py),Bash(python3 evals/scripts/expand.py:*),Bash(python3 evals/scripts/invariants.py:*),Bash(python3 -c:*)"
```

Inside a devenv shell the allowlist can be even tighter, since just
wraps the individual commands:

```sh
claude -p "Run 'just check' and 'just eval-smoke'. Summarize failures." \
  --allowedTools "Bash(just check),Bash(just eval-smoke:*)"
```

Notes for unattended use:

- `Bash(cmd:*)` allows `cmd` plus arguments; `Bash(cmd)` allows only the
  exact string. Prefer exact entries where the command takes no
  arguments.
- Do not add broad entries like `Bash(*)`; that defeats the purpose of
  the allowlist on a run with no human in the loop.
- Add `--output-format json` if a wrapper script needs to parse the
  result (exit status, cost, final message).

## Recording real eval cassettes (requires a live claude CLI)

The smoke test replays hash-keyed cassettes; the shipped ones are
synthetic placeholders (invariants.py warns about this). To replace them
with real recordings later, run the record recipe on a machine with a
logged-in claude CLI:

```sh
just eval-record ast-grep claude
```

This is a live, interactive-credential run; it does not belong in
headless CI. Record locally, commit the cassettes, and let CI replay
them.
