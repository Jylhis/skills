---
name: explore
description: Answer a "where is X / how does Y work" question across the codebase by running the explorer agent in a forked context, read-only. Invoke as /jylhis-skills-core:explore <question>.
argument-hint: <question about the codebase>
context: fork
agent: explorer
---

Answer the following codebase question, working as the `explorer` subagent shipped by this plugin (if this content is not already running inside that agent, delegate the question to it). Locate code, follow symbols, and report file paths with line numbers, read-only, no edits.

Question:

$ARGUMENTS

If the question is ambiguous, state the interpretation used and why before answering.
