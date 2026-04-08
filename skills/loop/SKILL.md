---
name: loop
description: Run a prompt or slash command on a recurring interval (e.g. /loop 5m /foo, defaults to 10m). When the user wants to set up a recurring task, poll for status, or run something repeatedly on an interval (e.g. "check the deploy every 5 minutes", "keep running the tests until they pass", "poll this endpoint until it's ready"), use this skill to schedule it.
---

# Loop

Schedule a prompt or slash command to run on a recurring interval inside the
current Claude Code session. Use this when the user wants polling,
periodic checks, or a task that should repeat until some condition changes.

## Invocation

The canonical form is:

```
/loop <interval> <prompt-or-slash-command>
```

- `<interval>` accepts duration syntax like `30s`, `5m`, `1h`. If omitted,
  the default is `10m`.
- `<prompt-or-slash-command>` is either a literal natural-language prompt or
  another slash command (including its arguments).

Examples:

```
/loop 5m /check-deploy
/loop 30s poll https://api.example.com/health and tell me if it's 200
/loop /run-smoke-tests          # defaults to 10m
/loop 2m check if the PR has new review comments and respond to any
```

## How it works

The loop is executed by the harness, not by Claude within a single turn.
After the initial invocation:

1. The interval timer starts.
2. When the interval elapses, the harness re-submits the configured prompt
   or slash command as a fresh user turn in the current session.
3. Claude runs it, responds, and the timer resets.
4. The loop continues until the user cancels it or explicitly instructs
   Claude to stop looping (e.g. "stop the loop", "cancel the recurring
   check", or when the termination condition in the prompt is met).

Because each tick is a fresh turn, the looped prompt should be
self-contained — don't rely on conversational state that might compact
away between ticks. If continuity is important, have the prompt read/write
a small status file.

## When to use

- **Polling external state** — CI runs, deploys, API health, queue depth.
- **Watching for events** — new PR comments, new commits on a branch, new
  log lines matching a pattern.
- **Retrying until success** — run a flaky test until it either passes or
  fails N times in a row.
- **Periodic summarization** — every 30 minutes, summarize what's happened
  in the session log.

## When NOT to use

- **One-shot waits.** If you just need to wait 30 seconds and check once,
  don't loop — sleep-and-check inline.
- **Tight polling loops.** Intervals shorter than ~10 seconds are usually a
  sign the user wants streaming or a webhook, not a loop.
- **Tasks that must not miss a tick.** The loop is best-effort; if Claude is
  mid-turn when the interval elapses, the tick waits. Don't use it where
  missed intervals are dangerous.

## Designing the looped prompt

Write the prompt so that each invocation is idempotent and bounded:

- **Bounded work per tick.** Don't ask for "run the full test suite and fix
  everything" every 5 minutes — that will never finish before the next
  tick.
- **Clear stop condition.** Tell Claude when to stop looping. For example:
  "Check the deploy status. If it's 'succeeded' or 'failed', cancel the
  loop and report the result."
- **Side-effect awareness.** If the looped prompt posts a GitHub comment or
  sends a notification, make sure it only does so on state changes, not on
  every tick.

## Canceling a loop

Tell Claude "stop the loop" or "cancel the recurring task" and it will
deregister the schedule. The harness surfaces active loops so Claude can
identify which one to cancel; if there are multiple, ask the user which.

## Examples

**Poll a deploy until it finishes.**
```
/loop 1m check the status of the current deploy with `gh run list --limit 1`. If it's completed, tell me the result and stop the loop. Otherwise just say "still running".
```

**Watch a PR for new review comments.**
```
/loop 5m /review-watch 1234
```

**Run tests every 10 minutes until they pass twice in a row.**
```
/loop 10m run `pytest tests/flaky_suite.py`. Keep a running count in /tmp/flaky-passes. When the count hits 2 consecutive passes, stop the loop and report.
```
