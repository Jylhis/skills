---
name: job-search
description: "Candidate-side job-search umbrella: tailor a resume/CV and cover letter to a specific posting, and track applications. Triggers on: 'help me apply', 'tailor my resume', 'tailor my CV', 'write a cover letter', 'apply for this role', 'match my resume to this job', 'application tracker', 'I am job hunting', 'job search', or any request to prepare or track a job application as a candidate. Produces documents only; never submits an application or sends email without explicit confirmation. Does NOT write job posts or screen applicants (that is the employer-side job-post-builder)."
---

# Job Search

Prepare a strong, posting-specific application as a candidate: a tailored
resume/CV, a matching cover letter, and a running tracker of where you have
applied. This is the candidate-side counterpart to `job-post-builder` (which is
employer-side).

## Quick start

Invoke when someone is applying for a role and wants help tailoring their
materials or tracking applications. The skill walks a 5-phase workflow:
understand the candidate and posting, research the company, tailor the
resume/CV, draft the cover letter, then log the application.

**Example trigger:**
> "Here's my resume and a job posting for a senior data engineer. Can you tailor
> my resume and write a cover letter?"

## Workflow

1. **Understand candidate + posting** — Gather the current resume/CV and the target
   posting (pasted text or URL). Extract the role's must-have and nice-to-have
   requirements. Source: conversation / provided files.
2. **Research the company and role** — Web-search the company and comparable
   postings to learn what the role really values and how to phrase impact.
   Source: web search.
3. **Tailor the resume/CV** — Rewrite to foreground the posting's priorities,
   using `references/resume-structure.md`.
4. **Draft the cover letter** — Write a specific, non-generic letter using
   `references/cover-letter-structure.md`.
5. **Track the application** — Record the application in a tracker table using
   `references/application-tracker.md`.

## Approval gates

This skill prepares materials; it does not act on the candidate's behalf.

- **Never submit an application.** Produce the tailored documents and stop. The
  candidate applies through the employer's system themselves.
- **Never send email on the candidate's behalf without explicit confirmation.**
  If asked to draft an outreach or follow-up email, show the draft and wait for
  a clear "send it" before doing anything externally visible.
- **Never invent facts.** Do not add employers, dates, degrees, or metrics that
  are not in the candidate's real history. Leave gaps as questions, not fiction.

## Phase 1 — Understand the candidate and the posting

Gather two inputs before writing anything:

- **The candidate's current resume/CV** (or a summary of their experience).
- **The target posting** — pasted text or a URL. If a URL, read it; if it cannot
  be fetched, ask the candidate to paste the text.

From the posting, extract and list back:

- Role title, team, and seniority.
- **Must-have requirements** (hard filters: years, specific skills, credentials).
- **Nice-to-have requirements** (differentiators).
- The role's stated impact / what success looks like.

Then map the candidate's real experience against that list. Flag any must-have
the candidate does not obviously meet, and ask about it rather than papering
over it. One focused clarifying question beats a long form.

## Phase 2 — Research the company and role

Ground the tailoring in what the market and the company actually say. In parallel:

- Web-search the company (product, recent news, mission, tech or domain) so the
  cover letter can be specific rather than generic.
- Web-search 3–5 comparable postings for this role to see which requirements are
  table stakes and how impact is usually described.

Use this to decide which of the candidate's experiences to foreground, and to
pressure-test the posting (is a "requirement" actually standard, or unusual?).

## Phase 3 — Tailor the resume/CV

Read `references/resume-structure.md` first.

- **Preserve the candidate's real history.** Reorder, reword, and re-emphasise;
  never fabricate.
- Lead each role with impact and quantified results, phrased toward the posting's
  priorities.
- Mirror the posting's key terminology where it is truthfully applicable (many
  first-pass filters are keyword-based).
- Keep it tight: one page for early-career, two for extensive experience.

If the candidate has an existing format they like, keep it as the source of
truth and tailor within it. Save as a `.docx` or Markdown per the candidate's
preference.

## Phase 4 — Draft the cover letter

Read `references/cover-letter-structure.md` first.

- Open with a specific hook tied to the company (from Phase 2 research), not a
  template greeting.
- Connect two or three of the candidate's concrete achievements to the role's
  needs.
- Close with a clear, low-pressure call to action.
- Keep it under one page. Use bracketed `[PLACEHOLDERS]` for anything the
  candidate must confirm (hiring manager name, referral, specific dates).

## Phase 5 — Track the application

Read `references/application-tracker.md`. Append a row to the candidate's
tracker (create one if none exists) capturing company, role, date applied,
status, source, and next action. This keeps follow-ups from slipping.

## Delivering the package

Present the deliverables together: the tailored resume/CV, the cover letter, and
the updated tracker row. Remind the candidate to:

- Review every claim for accuracy before submitting (they own the facts).
- Submit through the employer's own system; this skill does not apply for them.
- Confirm any `[PLACEHOLDER]` before sending.

## Reference Files

Load these when reaching the relevant phase; do not load all upfront.

| File | Load when |
|---|---|
| `references/resume-structure.md` | Phase 3 — before tailoring the resume/CV |
| `references/cover-letter-structure.md` | Phase 4 — before drafting the cover letter |
| `references/application-tracker.md` | Phase 5 — tracker schema and follow-up cadence |
| `references/gotchas.md` | Any phase — non-obvious edge cases (ATS, gaps, career changes) |
| `references/examples/worked-example.md` | For reference on expected output shape |
