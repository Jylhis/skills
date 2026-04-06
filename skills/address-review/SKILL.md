---
description: Work through PR/MR review comments. Implement fixes, respond to questions, close the feedback loop.
---

# Address Review

Work through PR/MR review comments. Implement fixes, respond to questions, and close the feedback loop.

## Steps

1. Get the review comments. Fetch from the PR/MR if given a link or number. Otherwise, take them from the user's message.
2. Categorize each comment:
   - **Must-fix**: bugs, security issues, correctness problems
   - **Should-fix**: valid improvements worth doing now
   - **Nit**: style tweaks, take-or-leave suggestions
   - **Question**: reviewer asking for clarification
   - **Out-of-scope**: valid point, but not for this PR
3. Fix must-fix and should-fix items. One commit per fix so the reviewer can verify each change individually.
4. For questions, draft a reply that answers directly. No filler, just the answer.
5. For nits, fix the easy ones. For the rest, note whether you agree or disagree and why.
6. For out-of-scope items, acknowledge the point and suggest a follow-up issue if it matters.

## Output

- **Commits**: one per fix, with a clear message linking to the comment
- **Draft replies**: a response for each comment the reviewer left
- **Summary**: what was fixed, what was deferred, what needs discussion
