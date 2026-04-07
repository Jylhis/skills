# Cowork-Specific Instructions

## What works

- Subagents are available, so the main workflow (spawn test cases in parallel, run baselines, grade, etc.) all works. If timeouts are severe, run test prompts in series rather than parallel.
- Packaging works — `package_skill.py` just needs Python and a filesystem.
- Description optimization (`run_loop.py` / `run_eval.py`) works since it uses `claude -p` via subprocess. Save this step until the skill is finalized and the user agrees it is in good shape.

## No browser or display

When generating the eval viewer, use `--static <output_path>` to write a standalone HTML file instead of starting a server. Then provide a link the user can click to open the HTML in their browser.

## Always generate the eval viewer before revising

After running tests, always generate the eval viewer for the user to review examples before making revisions yourself. Use `generate_review.py` — do not write custom HTML. The user's feedback is the primary signal for improvement, so getting results in front of them quickly matters more than your own assessment.

## Feedback mechanism

Since there is no running server, the viewer's "Submit All Reviews" button downloads `feedback.json` as a file. Read it from the download location (you may need to request access first).
