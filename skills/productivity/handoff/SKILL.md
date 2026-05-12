---
name: handoff
description: Compact the current conversation into a handoff document for another agent to pick up.
metadata:
  upstream-id: mattpocock-skills
  upstream-rev: f304057d61d3df3c9fd992ac2b6e3833cb9325fb
  upstream-path: productivity/handoff
  upstream-imported: 2026-05-12
---

Write a handoff document summarising the current conversation so a fresh agent can continue the work. Save it to a path produced by `mktemp -t handoff-XXXXXX.md` (read the file before you write to it).

Suggest the skills to be used, if any, by the next session.

Do not duplicate content already captured in other artifacts (PRDs, plans, ADRs, issues, commits, diffs). Reference them by path or URL instead.

If the user passed arguments, treat them as a description of what the next session will focus on and tailor the doc accordingly.
