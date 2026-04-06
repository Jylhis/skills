---
description: Review code changes before they land. Works with PRs, MRs, branch diffs, or staged changes.
---

# Review

Review code changes before they land. Works with PRs, MRs, branch diffs, or staged changes.

## Steps

1. Figure out what to review. If the user gave a PR number, fetch it. Otherwise, diff the current branch against the base branch (detect the default branch dynamically, don't assume `main`).
2. Read the full diff. Understand what changed, what it connects to, and what the intent was.
3. Check for:
   - **Correctness**: does it do what it claims? Edge cases handled?
   - **Security**: injection, auth bypass, secrets in code, unsafe deserialization
   - **Tests**: are the changes tested? Are the tests meaningful or just covering lines?
   - **Complexity**: anything unnecessarily clever? Could it be simpler?
   - **Naming**: do names say what things are?
4. Flag issues by severity:
   - **Must-fix**: bugs, security holes, data loss risks
   - **Should-fix**: unclear code, missing tests, poor naming
   - **Nit**: style, minor improvements, optional cleanups
5. Call out what is good. If the approach is clean or a test is well-written, say so.

## Output

Group findings by severity. For each issue, name the file and line, describe the problem, and suggest a fix. End with an overall assessment: ship it, ship with fixes, or rethink.
