# TODO: Import upstream skill repositories

- [ ] Import [ComposioHQ/awesome-codex-skills](https://github.com/ComposioHQ/awesome-codex-skills) — awesome-list; verify skills are hosted in-repo
- [ ] Import [jnMetaCode/superpowers-zh](https://github.com/jnMetaCode/superpowers-zh) — Chinese-language skills
- [ ] Import [Prat011/awesome-llm-skills](https://github.com/Prat011/awesome-llm-skills) — awesome-list; verify in-repo hosting
- [ ] Import [wgpsec/AboutSecurity](https://github.com/wgpsec/AboutSecurity) — security-focused
- [ ] Import [himself65/finance-skills](https://github.com/himself65/finance-skills) — finance domain
- [ ] Import [CloudAI-X/claude-workflow-v2](https://github.com/CloudAI-X/claude-workflow-v2) — workflow/skills package
- [ ] Import [rohitg00/awesome-claude-code-toolkit](https://github.com/rohitg00/awesome-claude-code-toolkit) — awesome-list; verify in-repo hosting
- [ ] Import [foryourhealth111-pixel/Vibe-Skills](https://github.com/foryourhealth111-pixel/Vibe-Skills)
- [ ] Import [tech-leads-club/agent-skills](https://github.com/tech-leads-club/agent-skills)
- [ ] Import [open-gitagent/gitagent](https://github.com/open-gitagent/gitagent) — git-focused agent
- [ ] Import [tw93/Waza](https://github.com/tw93/Waza)

Per-entry checklist:

1. Verify layout contains `SKILL.md` files (not just curated links)
2. Add non-flake input to `flake.nix`
3. Re-export in `_sources.nix`
4. Add entry in `bundled-sources.nix` (pick `namespace`, `subdir`/`paths`)
5. `nix flake lock`
6. `just check` passes


## Policy gate alignment (docs/skill-source-governance.md)

Gate markers: `license`, `provenance`, `layout`, `pinning`, `security`, `metadata`.

- [ ] Import [ComposioHQ/awesome-codex-skills](https://github.com/ComposioHQ/awesome-codex-skills) — category: awesome-list; gates: layout, provenance, license, security, pinning, metadata
- [ ] Import [jnMetaCode/superpowers-zh](https://github.com/jnMetaCode/superpowers-zh) — category: language pack; gates: layout, provenance, license, security, pinning, metadata
- [ ] Import [Prat011/awesome-llm-skills](https://github.com/Prat011/awesome-llm-skills) — category: awesome-list; gates: layout, provenance, license, security, pinning, metadata
- [ ] Import [wgpsec/AboutSecurity](https://github.com/wgpsec/AboutSecurity) — category: domain-specific (security); gates: layout, provenance, license, security, pinning, metadata
- [ ] Import [himself65/finance-skills](https://github.com/himself65/finance-skills) — category: domain-specific (finance); gates: layout, provenance, license, security, pinning, metadata
- [ ] Import [CloudAI-X/claude-workflow-v2](https://github.com/CloudAI-X/claude-workflow-v2) — category: domain-specific (workflow); gates: layout, provenance, license, security, pinning, metadata
- [ ] Import [rohitg00/awesome-claude-code-toolkit](https://github.com/rohitg00/awesome-claude-code-toolkit) — category: awesome-list; gates: layout, provenance, license, security, pinning, metadata
- [ ] Import [foryourhealth111-pixel/Vibe-Skills](https://github.com/foryourhealth111-pixel/Vibe-Skills) — category: general skills; gates: layout, provenance, license, security, pinning, metadata
- [ ] Import [tech-leads-club/agent-skills](https://github.com/tech-leads-club/agent-skills) — category: general skills; gates: layout, provenance, license, security, pinning, metadata
- [ ] Import [open-gitagent/gitagent](https://github.com/open-gitagent/gitagent) — category: domain-specific (git); gates: layout, provenance, license, security, pinning, metadata
- [ ] Import [tw93/Waza](https://github.com/tw93/Waza) — category: general skills; gates: layout, provenance, license, security, pinning, metadata

## Exceptions (approval required)

Record exceptions to policy gates here before merge:

- Source:
  - Failed gate(s):
  - Risk summary:
  - Compensating controls:
  - Expiry/revisit date:
  - Approver(s):
