---
description: Find the root cause of a software issue. No guessing, no shotgun fixes.
---

# Debug

Find the root cause of a software issue. No guessing, no shotgun fixes.

## Steps

1. Get the symptoms: error message, stack trace, repro steps, expected vs actual behavior. If the user gave partial info, ask for the rest.
2. Form a hypothesis. Say it out loud: "I think X is happening because Y."
3. Read the relevant code. Trace the execution path from input to the point of failure.
4. Verify the hypothesis with evidence: log output, test results, or code analysis. If the evidence contradicts the hypothesis, form a new one. Don't force-fit.
5. Once you have the root cause, propose a fix. Explain what it changes and why that addresses the cause.

## Rules

- No fix without a root cause. "I'm not sure why it's broken" is a valid answer. A random change that happens to work is not.
- If you apply a fix, write a regression test that fails without the fix and passes with it.
- If you've tried 3 hypotheses and none panned out, stop and tell the user what you've ruled out. That's still useful progress.

## Output

- **Root cause**: what is actually wrong, with evidence
- **Fix**: what to change and why
- **Regression test**: a test that would catch this if it came back
