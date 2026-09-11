# License Compatibility Guide

Reference for `upstream-tracker` §1 (adopt a new upstream). The manifest
records each source's `license:` for audit; this guide is what to check
*before* recording it. Licenses here gate importing third-party content,
not our own code.

## License Categories

### Permissive (Auto-approved)

These licenses allow redistribution, modification, and inclusion in this
marketplace without restrictions beyond attribution:

| License | SPDX ID | Notes |
|---------|---------|-------|
| MIT | MIT | Most common for skills repos |
| Apache 2.0 | Apache-2.0 | Requires NOTICE file if present |
| BSD 2-Clause | BSD-2-Clause | "Simplified" BSD |
| BSD 3-Clause | BSD-3-Clause | "New" BSD, no endorsement clause |
| ISC | ISC | Functionally equivalent to MIT |
| Unlicense | Unlicense | Public domain dedication |
| CC0 1.0 | CC0-1.0 | Public domain dedication |
| MPL 2.0 | MPL-2.0 | File-level copyleft, compatible |
| 0BSD | 0BSD | Zero-clause BSD |
| Zlib | Zlib | Permissive, rare |

### Copyleft (Requires Confirmation)

These licenses have share-alike requirements that may affect the
marketplace:

| License | SPDX ID | Risk |
|---------|---------|------|
| GPL 2.0 | GPL-2.0-only | Derived works must also be GPL |
| GPL 3.0 | GPL-3.0-only | Derived works must also be GPL |
| AGPL 3.0 | AGPL-3.0-only | Network use triggers copyleft |
| LGPL 2.1 | LGPL-2.1-only | Library exception, may be OK |
| LGPL 3.0 | LGPL-3.0-only | Library exception, may be OK |

Note: `trailofbits/skills` and `grafana/skills` content is AGPL-3.0 and
already vendored — the confirmation happened at adoption time. Treat the
copyleft rule as a gate for **new** sources, not a reason to revisit
existing entries.

When encountering copyleft licenses:
1. Warn the user about the implications
2. Explain that importing may require the vendored skill to keep the same
   license (per-skill frontmatter `license:` field)
3. Ask for explicit confirmation before proceeding
4. If confirmed, record the license in `upstream/sources.yaml` and keep
   the per-skill `license:` / source attribution in the imported SKILL.md

### No License

If no license is detected:
- The code is under exclusive copyright by default
- Redistribution is NOT permitted without explicit permission from the author
- Do NOT import — inform the user and suggest they contact the repo owner

## Checking Licenses

### Repository-Level License

```bash
# GitHub API returns detected license
gh api "repos/{owner}/{repo}" -q '.license.spdx_id'

# Fetch full LICENSE file
gh api "repos/{owner}/{repo}/contents/LICENSE" -q '.content' | base64 -d
```

### Per-Skill License

Some repos include license fields in skill frontmatter:

```yaml
---
name: my-skill
license: MIT
metadata:
  author: someone
---
```

Per-skill licenses override the repository license for that specific
skill. Check for `license:` in YAML frontmatter when fetching each skill
(the upstream-tracker import preserves frontmatter; verify non-portable
fields get stripped for `scripts/validate.py`).

### Multi-License Repos

Some repositories contain skills from multiple authors with different
licenses (e.g. `jetbrains-skills` is tracked as "mixed"). In such cases:
- Check each skill's frontmatter for a `license` field
- If per-skill licenses differ, record the source license in
  `upstream/sources.yaml` as the most restrictive common denominator or
  `mixed (per-skill ...)` and note the specifics
- Ensure all licenses are in the auto-approved or confirmed category

## Attribution Requirements

Attribution in this repo is structural, not README-based:

- **Manifest:** `upstream/sources.yaml` records `repo`, `license`, and
  the review cursor per source — the authoritative audit trail.
- **Per-skill metadata:** the import script injects
  `metadata.upstream-id / upstream-rev / upstream-path /
  upstream-imported` into each vendored SKILL.md (see
  `references/frontmatter-block.md`).
- **Decision log:** `upstream/decisions/<id>.log` records every
  upstream commit decision.

Additional per-license obligations:

### MIT / BSD / ISC
- Include original copyright notice (keep any `LICENSE.txt` shipped
  inside the skill directory; the import copies it verbatim)
- The `metadata.upstream-id` block references the source repo and author

### Apache 2.0
- Include original copyright notice
- If the source repo has a NOTICE file, note it in the source's
  `license` field comment or keep the file with the skill

### MPL 2.0
- Keep original license headers in modified files
- File-level copyleft: modified vendored files keep MPL headers

## Recording Format

`upstream/sources.yaml` per source:

```yaml
- id: <org>-<repo>
  repo: "https://github.com/<org>/<repo>"
  license: MIT          # SPDX ID, or "mixed (per-skill upstream licenses)"
  ...
```

See `references/manifest-schema.md` for the full field reference.