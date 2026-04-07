# Claude.ai-Specific Instructions

The core workflow is the same (draft, test, review, improve, repeat), but Claude.ai lacks subagents, so some mechanics change.

## Running test cases

No subagents means no parallel execution. For each test case, read the skill's SKILL.md, then follow its instructions to accomplish the test prompt yourself, one at a time. This is less rigorous than independent subagents (you wrote the skill and are also running it), but the human review step compensates. Skip baseline runs — just use the skill to complete the task as requested.

## Reviewing results

If no browser is available (e.g., Claude.ai's VM has no display, or a remote server), skip the browser reviewer. Instead, present results directly in the conversation: show the prompt and the output for each test case. If the output is a file the user needs to see (like a .docx or .xlsx), save it to the filesystem and tell them where to download it. Ask for feedback inline: "How does this look? Anything you'd change?"

## Benchmarking

Skip quantitative benchmarking — it relies on baseline comparisons which are not meaningful without subagents. Focus on qualitative feedback from the user.

## The iteration loop

Same as the main workflow: improve the skill, rerun the test cases, ask for feedback — just without the browser reviewer. Organize results into iteration directories on the filesystem if available.

## Description optimization

Requires the `claude` CLI tool (specifically `claude -p`), which is only available in Claude Code. Skip this section on Claude.ai.

## Blind comparison

Requires subagents. Skip on Claude.ai.

## Packaging

The `package_skill.py` script works anywhere with Python and a filesystem. On Claude.ai, run it and the user can download the resulting `.skill` file.
