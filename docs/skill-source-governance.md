# Skill Source Governance Policy

This policy defines the acceptance gates for adding third-party skill sources to this repository. It applies to all additions and updates that touch `flake.nix` and `bundled-sources.nix`.

## Scope and goals

- Ensure legal compatibility, provenance, reproducibility, and security for bundled skill sources.
- Provide one contributor path from proposal to merge.
- Standardize exception handling and approvals.

## Acceptance criteria

A source is eligible only when all required gates below pass.

### 1) License compatibility

- The upstream repository license must permit redistribution and internal packaging in this catalogue.
- Any per-skill or per-subdirectory license overrides must be reviewed when they differ from the repository root license.
- Sources with unclear or missing licensing are blocked until clarified upstream.

### 2) Provenance and authenticity

- Source must be hosted in a reputable, attributable upstream (for example: official org/user repository with visible history).
- Repository ownership, commit history, and release/tag practices must be reviewable.
- Mirror-only or scraped copies are not acceptable unless explicitly approved as an exception.

### 3) Pinning and update model

- Every source must be pinned via `flake.lock` through a non-flake input in `flake.nix`.
- Branch-only references without lock updates are not allowed.
- Updates must use `nix flake update <input>` or `just update`, not manual lockfile edits.

### 4) Maintenance signals

- Source should show signs of maintenance (recent activity, responsive issues/PRs, or stable tagged releases).
- Abandoned sources are not automatically rejected, but require an explicit risk note and approval.

### 5) Required metadata for bundle registration

Each source entry must include:

- `flake.nix` input name and upstream URL.
- `bundled-sources.nix` registration with clear `namespace`.
- Discovery mapping (`subdir`, `paths`, `include`) constrained to vetted skill directories.
- Brief rationale in PR description for why the source is useful.

### 6) Security review

- Instructions and prompts must be reviewed for malicious or unsafe behavior (credential exfiltration, destructive commands, privilege escalation advice without safeguards).
- Skills that fetch remote code at runtime require additional scrutiny for reproducibility and trust.
- High-risk content must be excluded with `include`/path scoping or rejected.

## Mandatory pre-add checks

Before adding any entry to `flake.nix` and `bundled-sources.nix`, contributors must complete all checks:

1. **Layout check:** upstream contains real `SKILL.md`-based skills (not only link lists).
2. **Instruction safety check:** sampled and targeted review indicates non-malicious instructions.
3. **Stable pin check:** source is pinned to a reproducible revision through `flake.lock`.
4. **Reproducibility check:** selection uses deterministic paths (`subdir`/`paths`/`include`) and avoids floating or generated-at-runtime content when possible.
5. **Metadata check:** namespace and mapping fields are complete and unambiguous.
6. **Validation check:** run repository validation commands (at minimum `just list-skills`, and the standard checks expected by maintainers).

## Exceptions and approvals

When a source cannot satisfy one or more mandatory gates:

- Record the exception in `TODO.md` under an **Exceptions** subsection for the affected source.
- Include: failed gate(s), risk summary, compensating controls, and expiry/revisit date.
- Approval required from repository maintainers before merge (minimum one maintainer approval; two for security or license exceptions).
- PR title/body must clearly mark the change as an exception and link to the `TODO.md` record.

## TODO backlog alignment

All import backlog items in `TODO.md` must be tracked against policy gates. Use the following categories and gate mapping:

- **Awesome-list / aggregator repos** → must pass stronger layout/provenance checks to prove in-repo `SKILL.md` content.
- **Language or regional packs** → must pass instruction safety review with language-capable reviewer support.
- **Domain-specific repos (security/finance/git/workflow)** → must pass enhanced security review due to higher command-impact risk.

For each backlog item, annotate gate status directly in `TODO.md` with concise markers (for example: `license`, `provenance`, `layout`, `pinning`, `security`, `metadata`).
