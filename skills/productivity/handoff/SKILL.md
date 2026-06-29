---
name: handoff
description: Compact the current conversation into a handoff document for another agent to pick up.
metadata:
  upstream-id: mattpocock-skills
  upstream-rev: d54c497aa94400a496d3f2c38be10fa5f284c5a9
  upstream-path: productivity/handoff
  upstream-imported: 2026-05-12
---

Write a handoff document summarising the current conversation so a fresh agent can continue the work. Save it to a path produced by `mktemp -t handoff-XXXXXX.md` (read the file before you write to it).

Include a "suggested skills" section in the document, which suggests skills that the agent should invoke.

Do not duplicate content already captured in other artifacts (PRDs, plans, ADRs, issues, commits, diffs). Reference them by path or URL instead.

Redact any sensitive information, such as API keys, passwords, or personally identifiable information.

If the user passed arguments, treat them as a description of what the next session will focus on and tailor the doc accordingly.
