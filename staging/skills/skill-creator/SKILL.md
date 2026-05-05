---
name: skill-creator
description: Create new Claude / Codex / agent skills, modify and improve existing skills, and measure skill quality through evals and benchmarks. Use when the user says things like "create a skill", "turn this workflow into a skill", "make a SKILL.md", "write a skill for X", "update/edit/optimize this skill", "improve the skill description", "run evals on the skill", "benchmark my skill", "test whether the skill triggers correctly", "is the new version better", "why isn't my skill triggering", "package this skill", or otherwise discusses authoring, iterating on, validating, or shipping an agent skill (SKILL.md + bundled scripts/references/assets). Also triggers on requests to design skill structure, set degrees of freedom, write skill frontmatter descriptions, measure trigger accuracy, or set up acceptance criteria and scenario-based tests for a skill. Use this skill proactively whenever the user is working on anything under a `skills/` directory or editing a `SKILL.md` file, even if they don't explicitly ask.
---

# Skill Creator

A skill for creating new skills and iteratively improving them. Merged from upstream skill-creators published by Anthropic, OpenAI, and Microsoft — see attribution at the bottom and `README.md` for provenance details.

## The core loop

At a high level, creating a skill goes like this:

1. Decide what the skill should do and roughly how it should do it (capture intent from concrete examples).
2. Plan the reusable contents — which parts become scripts, references, or assets.
3. Write a draft SKILL.md.
4. Create a few realistic test prompts and run agent-with-access-to-the-skill on them.
5. Help the user evaluate results qualitatively (the viewer) and quantitatively (assertions + benchmark).
6. Rewrite the skill based on feedback.
7. Repeat until satisfied. Then expand the test set and try again at larger scale.
8. Optionally: optimize the description for trigger accuracy, then package.

Figure out where the user is in this process and jump in. If they already have a draft, skip straight to eval/iterate. If they say "just vibe with me, no evals," do that — flexibility wins over ceremony.

## Communicating with the user

Skill creation users span from expert engineers to absolute beginners who just discovered what a terminal is. Read context cues:

- "evaluation" / "benchmark" — borderline, usually OK.
- "JSON" / "assertion" — need strong cues the user knows these before using them unexplained.

It's fine to briefly define a term if in doubt. Prefer plain English over jargon.

---

## Core principles

### 1. Concise is key

The context window is a shared resource. Skills compete for it with the system prompt, conversation history, other skills' metadata, and the user's actual request. Challenge every paragraph: *does the agent really need this? Does it justify its tokens?*

**Default assumption: the agent is already smart.** Only add information it doesn't already have. Prefer concise examples over verbose explanations.

### 2. Fresh documentation first

When a skill wraps an SDK, API, or CLI that changes over time, instruct the agent to verify current behavior before coding — via MCP doc search, context7, or an explicit `--help` / `man` / offline-docs step. Pinning training-era knowledge into a skill is how skills rot.

```markdown
## Before implementation
Search docs for current API patterns:
- Query: "<sdk/tool> <operation> <language>"
- Verify: parameters match your installed version
```

### 3. Set appropriate degrees of freedom

Match specificity to task fragility:

| Freedom | When to use | Example |
|---|---|---|
| **High** (text-based guidance) | Multiple valid approaches; decisions depend on context; heuristics guide choice | Prose instructions, rules of thumb |
| **Medium** (pseudocode / scripts with parameters) | Preferred pattern exists; some variation acceptable | Templates, parameterized scripts |
| **Low** (specific scripts, few knobs) | Operation is fragile; consistency critical; specific sequence required | Bundled scripts called by exact name |

Think of the agent as walking a path. A narrow bridge over a cliff needs guardrails (low freedom). An open field allows many routes (high freedom).

### 4. Principle of lack of surprise

Skills must not contain malware, exploit code, or anything that would surprise the user given the skill's description. Don't build misleading skills or skills designed to facilitate unauthorized access or data exfiltration. Roleplay and stylistic skills are fine.

---

## Anatomy of a skill

```text
skill-name/
├── SKILL.md (required)
│   ├── YAML frontmatter (name, description — required)
│   └── Markdown instructions
└── Bundled resources (optional)
    ├── scripts/     — executable code (Python / Bash / etc.) for deterministic, repetitive tasks
    ├── references/  — docs loaded into context only when needed
    └── assets/      — files used IN output (templates, icons, fonts, boilerplate)
```

### Progressive disclosure (three-level loading)

1. **Metadata** (name + description) — always in context (~100 words).
2. **SKILL.md body** — in context whenever the skill triggers (<500 lines / <5k words ideal).
3. **Bundled resources** — read or executed as needed (effectively unlimited; scripts can run without loading into context).

Keep SKILL.md under 500 lines. If you're approaching it, add hierarchy — split into reference files and point at them clearly from SKILL.md with guidance on *when to read them*.

For reference files >100 lines, include a table of contents at the top so the agent can preview scope. For files >10k words, include grep patterns in SKILL.md.

### Avoid duplication

Information should live in either SKILL.md or references, **not both**. Keep only essential procedural instructions in SKILL.md; move detailed schemas, examples, and deep dives into references. This keeps SKILL.md lean while everything stays discoverable.

### Organizing multi-variant skills

When a skill supports multiple providers/frameworks/domains, put only workflow + selection in SKILL.md and split variants:

```text
cloud-deploy/
├── SKILL.md (workflow + provider selection)
└── references/
    ├── aws.md
    ├── gcp.md
    └── azure.md
```

The agent reads only the relevant reference file. Keep references one level deep — don't nest.

### What NOT to include

A skill should contain only what the agent needs to do the job. Do **not** add:

- `README.md`, `INSTALLATION_GUIDE.md`, `QUICK_REFERENCE.md`, `CHANGELOG.md`
- meta-documentation about creation process
- user-facing setup docs

Clutter adds tokens and confusion. (Exception: a sibling `README.md` outside the agent's load path may be appropriate for repositories that document merged/vendored provenance — like this one.)

---

## Step 1: Capture intent

Start by understanding the user's intent. Extract answers from history first — tools used, sequence of steps, corrections made, input/output formats observed. Fill gaps with targeted questions; confirm before proceeding.

Ask, with concrete examples:

1. What should this skill enable the agent to do?
2. When should this skill trigger? (what phrases/contexts)
3. What's the expected output format?
4. Should we set up test cases? Skills with objectively verifiable outputs (file transforms, data extraction, code generation, fixed workflow steps) benefit. Skills with subjective outputs (writing style, art) often don't need them.

Don't dump all four questions at once — start with the most important and follow up. Pre-research via MCPs, subagents, or context7 if available.

## Step 2: Plan reusable contents

For each concrete example, ask:

1. How would I execute this example from scratch?
2. What scripts, references, or assets would be reusable across invocations?

Examples:

- `pdf-editor` skill handling "rotate this PDF" → ship `scripts/rotate_pdf.py`. Rotation code gets re-written the same way every time.
- `frontend-webapp-builder` handling "build me a todo app" → ship `assets/hello-world/` boilerplate.
- `bigquery` handling "how many users logged in today" → ship `references/schema.md`.

Skip this planning pass and you'll write bloated SKILL.md instructions that re-derive the same thing per invocation.

## Step 3: Naming

- Lowercase letters, digits, and hyphens only. Normalize user-provided titles to hyphen-case ("Plan Mode" → `plan-mode`).
- Under 64 characters.
- Short, verb-led phrases describing the action when possible.
- Namespace by tool when it improves clarity or triggering (`gh-address-comments`, `linear-address-issue`).
- The folder name must match the `name` field in frontmatter.

## Step 4: Write the SKILL.md

### Frontmatter

Only two fields are read before triggering: `name` and `description`.

- **`name`**: the skill identifier (matches the directory name).
- **`description`**: the **primary triggering mechanism**. Must include both *what the skill does* AND *specific contexts for when to use it*. All "when to use" information belongs here — the body isn't loaded until after triggering, so "When to Use" sections in the body are wasted.

Agents tend to **undertrigger** skills. Compensate by making descriptions a little "pushy." Instead of:

> "How to build a simple fast dashboard to display internal Anthropic data."

write:

> "How to build a simple fast dashboard to display internal Anthropic data. Use this skill whenever the user mentions dashboards, data visualization, internal metrics, or wants to display any kind of company data, even if they don't explicitly ask for a 'dashboard.'"

### Body — writing style

Use **imperative/infinitive** form. Prefer explaining the *why* behind instructions over heavy-handed ALL-CAPS MUSTs. Modern LLMs have good theory of mind — given the reasoning, they'll do the right thing in novel cases. If you find yourself writing ALWAYS/NEVER in caps or over-constraining structure, that's a yellow flag: reframe and explain why the thing matters.

Make the skill general, not narrowly tied to specific examples. Draft, then look at it with fresh eyes and improve it.

### Writing patterns

**Defining output formats:**

```markdown
## Report structure
Use this template:
# [Title]
## Executive summary
## Key findings
## Recommendations
```

**Examples pattern:**

```markdown
## Commit message format
**Example 1:**
Input: Added user authentication with JWT tokens
Output: feat(auth): implement JWT-based authentication
```

**Start with bundled resources, then SKILL.md.** Test scripts by actually running them — if you bundle ten similar scripts, run a representative sample at minimum.

---

## Step 5: Test cases

After the draft, come up with 2–3 realistic test prompts — the kind of thing a real user would actually say. Share them with the user: *"Here are a few test cases I'd like to try. Do these look right, or do you want to add more?"* Then run them.

Save test cases to `evals/evals.json`. Don't write assertions yet — just the prompts.

```json
{
  "skill_name": "example-skill",
  "evals": [
    {
      "id": 1,
      "prompt": "User's task prompt",
      "expected_output": "Description of expected result",
      "files": []
    }
  ]
}
```

---

## Step 6: Running and evaluating test cases

This section is one continuous sequence — don't stop partway through. Do **not** use `/skill-test` or any other testing skill.

Put results in `<skill-name>-workspace/` as a sibling to the skill directory. Organize by iteration (`iteration-1/`, `iteration-2/`, …) and within that, each test case gets a directory (`eval-0/`, `eval-1/`, …).

### Step 6.1: Spawn all runs (with-skill AND baseline) in the same turn

For each test case, spawn two subagents in the same turn — one with the skill, one without. Don't spawn with-skill first and come back for baselines later; launch everything at once so they finish together.

**With-skill run:**

```text
Execute this task:
- Skill path: <path-to-skill>
- Task: <eval prompt>
- Input files: <eval files if any, or "none">
- Save outputs to: <workspace>/iteration-<N>/eval-<ID>/with_skill/outputs/
- Outputs to save: <what the user cares about — e.g. "the .docx file", "the final CSV">
```

**Baseline run** (same prompt, baseline depends on context):

- **New skill**: no skill at all. Save to `without_skill/outputs/`.
- **Improving an existing skill**: the old version. Snapshot first: `cp -r <skill-path> <workspace>/skill-snapshot/`, then point the baseline at the snapshot. Save to `old_skill/outputs/`.

Write `eval_metadata.json` per test case (assertions empty for now). Give each eval a **descriptive name** based on what it's testing, not just "eval-0"; use it for the directory too.

### Step 6.2: While runs are in progress, draft assertions

Don't wait. Use this time to draft quantitative assertions for each test case and explain them to the user. If assertions exist, review and explain them.

Good assertions are **objectively verifiable** with descriptive names — they should read clearly in the benchmark viewer so anyone glancing at results knows what each one checks. Subjective skills (writing style, design) are better evaluated qualitatively — don't force assertions onto things that need human judgment.

For SDK or pattern-oriented skills, the `expected_patterns` / `forbidden_patterns` / `mock_response` structure works well for scenario files:

```yaml
scenarios:
  - name: basic_client_creation
    prompt: |
      Create a basic example using the SDK. Include auth + client init.
    expected_patterns:
      - "DefaultAzureCredential"
      - "MyClient"
    forbidden_patterns:
      - "api_key="
      - "hardcoded"
    mock_response: |
      # complete working code that passes all checks
```

### Step 6.3: As runs complete, capture timing data

When each subagent task completes, you receive a notification with `total_tokens` and `duration_ms`. Save to `timing.json` in that run's directory **immediately** — this is the only opportunity:

```json
{
  "total_tokens": 84852,
  "duration_ms": 23332,
  "total_duration_seconds": 23.3
}
```

Process notifications as they arrive; don't batch.

### Step 6.4: Grade, aggregate, and launch the viewer

1. **Grade each run** — spawn a grader subagent (or grade inline) that evaluates each assertion against the outputs. Save to `grading.json`. The `expectations` array must use fields `text`, `passed`, `evidence` — the viewer depends on these names. For programmatically checkable assertions, write and run a script rather than eyeballing.

2. **Aggregate into benchmark:**

   ```bash
   python -m scripts.aggregate_benchmark <workspace>/iteration-N --skill-name <name>
   ```

   Produces `benchmark.json` and `benchmark.md` with pass_rate, time, tokens per configuration, mean ± stddev, and the delta.

3. **Do an analyst pass** — read the benchmark and surface patterns aggregates might hide (non-discriminating assertions, flaky evals, time/token tradeoffs).

4. **Launch the viewer** with both qualitative outputs and quantitative data:

   ```bash
   nohup python <skill-creator-path>/eval-viewer/generate_review.py \
     <workspace>/iteration-N \
     --skill-name "my-skill" \
     --benchmark <workspace>/iteration-N/benchmark.json \
     > /dev/null 2>&1 &
   VIEWER_PID=$!
   ```

   For iteration 2+, also pass `--previous-workspace <workspace>/iteration-<N-1>`.

   **Headless environments:** use `--static <output_path>` to produce standalone HTML. Feedback downloads as `feedback.json` when the user clicks "Submit All Reviews"; copy it into the workspace for the next iteration.

5. **Tell the user**: *"I've opened the results. There are two tabs — 'Outputs' lets you click through each test case and leave feedback; 'Benchmark' shows the quantitative comparison. When you're done, come back and let me know."*

### Step 6.5: Read the feedback

When the user says they're done, read `feedback.json`:

```json
{
  "reviews": [
    {"run_id": "eval-0-with_skill", "feedback": "the chart is missing axis labels", "timestamp": "..."},
    {"run_id": "eval-1-with_skill", "feedback": "", "timestamp": "..."}
  ],
  "status": "complete"
}
```

Empty feedback = the user was satisfied. Focus improvements on the test cases where they had specific complaints.

Kill the viewer when done:

```bash
kill $VIEWER_PID 2>/dev/null
```

---

## Step 7: Improving the skill

This is the heart of the loop.

### How to think about improvements

1. **Generalize from the feedback.** Skills will be used thousands of times across many prompts. Instead of fiddly overfitty changes or oppressive MUSTs, try different metaphors, different working patterns. Cheap to try.

2. **Keep the prompt lean.** Remove things that aren't pulling their weight. Read the transcripts, not just outputs — if the skill is making the model waste time on unproductive work, yank the bits causing it and see what happens.

3. **Explain the why.** Given reasoning, modern LLMs go beyond rote instructions. Even if user feedback is terse or frustrated, understand *why* they wrote what they wrote and transmit that understanding into the instructions. Reframe ALWAYS/NEVER rules into "here's why this matters."

4. **Look for repeated work across test cases.** If all three runs independently wrote `create_docx.py` or `build_chart.py`, that's a strong signal to bundle it in `scripts/`.

### The iteration loop

1. Apply improvements to the skill.
2. Rerun all test cases into `iteration-<N+1>/`, baselines included.
3. Launch the reviewer with `--previous-workspace` pointing at the prior iteration.
4. Wait for user review.
5. Read feedback, improve again, repeat.

Stop when the user is happy, feedback is all empty, or you've stopped making meaningful progress.

---

## Step 8 (optional): Description optimization

The description field is the primary trigger mechanism. After the skill is solid, offer to optimize triggering accuracy.

### 8.1: Generate trigger eval queries

Create 20 eval queries — mix of should-trigger and should-not-trigger.

```json
[
  {"query": "the user prompt", "should_trigger": true},
  {"query": "another prompt", "should_trigger": false}
]
```

Queries must be realistic — things a real user would type. Concrete and detailed. File paths, column names, personal context, company names, URLs, a little backstory. Some lowercase, abbreviations, typos, casual speech. Mix lengths. Focus on edge cases over clear-cut ones — the user gets to sign off.

**Bad:** `"Format this data"`, `"Extract text from PDF"`.

**Good:** `"ok so my boss just sent me this xlsx file (its in my downloads, called something like 'Q4 sales final FINAL v2.xlsx') and she wants me to add a column that shows the profit margin as a percentage. The revenue is in column C and costs are in column D i think"`

**Should-trigger (8–10):** coverage of different phrasings, formal and casual. Cases where the user doesn't explicitly name the skill but clearly needs it. Some uncommon use cases. Competing-skill cases where this one should win.

**Should-not-trigger (8–10):** near-misses are the most valuable — shared keywords/concepts but actually need something different. Adjacent domains. Ambiguous phrasing where naive keyword match would trigger but shouldn't. Avoid trivially irrelevant cases.

### 8.2: Review with the user

Use the HTML template from `assets/eval_review.html` if available. Replace placeholders, write to `/tmp/eval_review_<skill-name>.html`, `open` it. User edits, clicks "Export Eval Set," file downloads to `~/Downloads/eval_set.json`.

Bad eval queries → bad descriptions. This step matters.

### 8.3: Run the optimization loop

Tell the user: *"This will take some time — I'll run it in the background and check in periodically."*

```bash
python -m scripts.run_loop \
  --eval-set <path-to-trigger-eval.json> \
  --skill-path <path-to-skill> \
  --model <model-id-powering-this-session> \
  --max-iterations 5 \
  --verbose
```

Use the model ID from your system prompt so the triggering test matches what the user actually experiences. The loop splits evals 60/40 train/test, evaluates the current description (each query 3x for reliable trigger rate), calls the model with extended thinking to propose improvements based on failures, re-evaluates on train and test, iterates up to 5 times. Returns JSON with `best_description` selected by *test* score (not train) to avoid overfitting.

### How triggering works

Skills appear in the model's `available_skills` list with name + description. The model decides whether to consult a skill based on the description. Crucially: the model only consults skills for tasks it can't easily handle alone — simple one-step queries like "read this PDF" may not trigger even with a perfect match, because the model handles them directly. **Complex, multi-step, or specialized queries reliably trigger skills.** So your eval queries should be substantive.

### 8.4: Apply the result

Take `best_description` and update SKILL.md frontmatter. Show the user before/after and report scores.

---

## Advanced: blind comparison

For rigorous comparison between two skill versions, use the blind-comparison system. Give two outputs to an independent agent without saying which is which, let it judge quality, then analyze why the winner won. Optional; most users won't need it.

---

## Validate and package

Run the basic validator (checks YAML frontmatter, required fields, naming rules):

```bash
scripts/quick_validate.py <path/to/skill-folder>
```

Fix any issues and rerun.

If the `present_files` tool is available, package and hand over a `.skill` file:

```bash
python -m scripts.package_skill <path/to/skill-folder>
```

### Updating an existing skill

- **Preserve the original name.** The directory name and `name` frontmatter field stay the same.
- **Copy to a writeable location first.** Installed paths may be read-only. Copy to `/tmp/skill-name/`, edit there, package from the copy.
- **Stage in `/tmp/` first** when packaging manually, then copy to the output dir.

---

## Harness-specific notes

### Claude.ai (no subagents, often no browser)

- No parallel execution. For each test case, read SKILL.md, follow its instructions, do them one at a time. Skip baseline runs.
- If no browser, skip the viewer. Present results inline: prompt + output.
- Skip benchmarking — no meaningful baseline without subagents.
- Description optimization requires the `claude` CLI, only in Claude Code. Skip on Claude.ai.
- Blind comparison requires subagents. Skip.

### Cowork (subagents yes, browser no)

- Main workflow works in parallel. If timeouts are severe, run test prompts in series.
- Use `--static <output_path>` to write standalone HTML and link the user to it.
- **Always generate the eval viewer** after running tests, before revising yourself.
- "Submit All Reviews" downloads `feedback.json`; you may need to request access to read it.

---

## Anti-patterns

| Don't | Why |
|---|---|
| Put "when to use" info in the body | The body loads only *after* triggering; put all trigger context in the description |
| Write undertrigger-prone descriptions ("how to X") | Descriptions should be "pushy" — include explicit trigger phrases |
| Ship README.md / CHANGELOG.md / INSTALLATION_GUIDE.md inside the skill | The agent doesn't need meta-docs; clutter costs tokens |
| Duplicate content between SKILL.md and references | Information belongs in one place; prefer references for detail |
| Deeply nest reference files | Keep references one level deep from SKILL.md |
| Use ALL-CAPS MUSTs as the primary mechanism | Explain *why*; modern LLMs respond better to reasoning than rigid rules |
| Bake in SDK/API details without a "verify current docs" step | APIs drift; skills that don't refresh go stale |
| Hardcode credentials in examples | Security; always env vars + default credential chain |
| Ship a skill without any test cases | Subjective skills can skip; anything verifiable should have test cases |
| Write "Extract text from PDF" as a trigger eval query | Too abstract; use concrete, detailed user speech |
| Test non-discriminating assertions | If an assertion passes regardless of the skill, it's not measuring skill quality |

---

## Pre-flight checklist

Before shipping a skill:

### Content

- [ ] Description includes both *what* and *when* (explicit trigger phrases).
- [ ] SKILL.md under ~500 lines; bulky material lives in `references/`.
- [ ] Imperative form throughout.
- [ ] *Why* is explained where constraints are strict.
- [ ] Scripts tested by actually running them.
- [ ] No duplication between SKILL.md and references.
- [ ] No README.md / CHANGELOG.md / installation guide files inside the skill.

### Testing

- [ ] 2–3 realistic test prompts saved to `evals/evals.json`.
- [ ] Assertions are objectively verifiable with descriptive names.
- [ ] `with_skill` vs baseline runs completed.
- [ ] Timing data captured per run (`timing.json`).
- [ ] Benchmark aggregated (`benchmark.json` + `benchmark.md`).
- [ ] User reviewed outputs in the viewer.

### Optional

- [ ] Trigger eval set (20 queries) generated and user-reviewed.
- [ ] Description optimized via `run_loop.py`; `best_description` applied.
- [ ] Skill validated with `quick_validate.py`.
- [ ] Skill packaged into `.skill` if `present_files` is available.

---

Repeating the core loop one more time:

- Figure out what the skill is about (with concrete examples).
- Plan reusable contents (scripts, references, assets).
- Draft or edit the skill.
- Run agent-with-access-to-the-skill on test prompts.
- With the user, evaluate outputs — qualitative (viewer) + quantitative (benchmark).
- Improve based on feedback; repeat.
- Optimize the description; validate; package.

Add these steps to your todo list so you don't forget any of them. In headless environments specifically, put *"Create evals JSON and run `eval-viewer/generate_review.py` so human can review test cases"* on the list — it's the step most often skipped.

---

### Upstream attribution

Merged from four upstream skill-creators; see sibling `README.md` for details:

- `anthropics/skills` — <https://github.com/anthropics/skills>
- `anthropics/claude-plugins-official` — <https://github.com/anthropics/claude-plugins-official>
- `openai/skills` — <https://github.com/openai/skills>
- `microsoft/skills` — <https://github.com/microsoft/skills>
