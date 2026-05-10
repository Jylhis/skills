---
description: Spawn the `explorer` subagent to answer a "where is X / how does Y work" question across the codebase, read-only.
argument-hint: <question about the codebase>
---

Use the `explorer` subagent (defined by this plugin) to answer the following codebase question. The agent should locate code, follow symbols, and report file paths with line numbers — no edits.

Question:

$ARGUMENTS

If the question is ambiguous, state the interpretation used and why before answering.
