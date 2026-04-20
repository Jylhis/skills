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
