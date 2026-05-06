# evals/

Evaluation scaffolding for skills and agents. Currently a stub — no
cases are wired yet because `skills/` is empty (see top-level
`staging/` for content awaiting per-skill review).

## Target structure (per `docs/skills-spec-v3.md` §10)

```
evals/
├── skills/
│   └── <skill-name>/
│       ├── cases.yaml
│       ├── fixtures/
│       └── rubric.md
└── agents/
    └── <agent-name>/
        ├── cases.yaml
        └── rubric.md
```

`cases.yaml` shape:

```yaml
cases:
  - id: missing-regression-test
    fixture: fixtures/missing-regression-test
    prompt: Review this diff.
    expected:
      must_find:
        - Missing regression test for changed validation behavior.
      must_not_claim:
        - SQL injection
        - authentication bypass
```

Rubric dimensions: triggering, procedure adherence, evidence,
correctness, false positives, verification, portability.

## Levels

- **Level 0** — Human review of `SKILL.md`.
- **Level 1** — Static lint and frontmatter validation
  (`scripts/validate.py`).
- **Level 2** — Fixture-based prompt tests (not yet implemented).
- **Level 3** — Target smoke tests in Claude / Codex / Gemini.
- **Level 4** — Regression suite from historical failures.

Add eval cases as skills are promoted out of `staging/`.
