# Upstream skill repository imports

Resolved on 2026-05-04. All listed upstreams were pinned as non-flake
inputs in `flake.nix`, re-exported from `_sources.nix`, and registered in
`bundled-sources.nix`.

## Imported sources

Gate markers: `license`, `provenance`, `layout`, `pinning`, `security`, `metadata`.

| Source                                                                                          | Category                   | Namespace        | Imported skills | Gate status                                              | Notes                                                                                           |
|-------------------------------------------------------------------------------------------------|----------------------------|------------------|----------------:|----------------------------------------------------------|-------------------------------------------------------------------------------------------------|
| [ComposioHQ/awesome-codex-skills](https://github.com/ComposioHQ/awesome-codex-skills)           | awesome-list               | `composio`       |              45 | license, provenance, layout, pinning, security, metadata | Imported curated top-level skills only. Excluded generated `composio-skills/` marketplace tree. |
| [jnMetaCode/superpowers-zh](https://github.com/jnMetaCode/superpowers-zh)                       | language pack              | `superpowers-zh` |              20 | license, provenance, layout, pinning, security, metadata | Chinese-language skill pack under `skills/`.                                                    |
| [Prat011/awesome-llm-skills](https://github.com/Prat011/awesome-llm-skills)                     | awesome-list               | `prat011`        |              31 | license, provenance, layout, pinning, security, metadata | Verified in-repo `SKILL.md` directories, not only links.                                        |
| [wgpsec/AboutSecurity](https://github.com/wgpsec/AboutSecurity)                                 | domain-specific (security) | `aboutsecurity`  |             245 | license, provenance, layout, pinning, security, metadata | Imported `skills/` only. Excluded `Dic/`, `Payload/`, and `Vuln/` data layers.                  |
| [himself65/finance-skills](https://github.com/himself65/finance-skills)                         | domain-specific (finance)  | `finance`        |              22 | license, provenance, layout, pinning, security, metadata | Imported plugin skills under `plugins/`; excluded duplicate `skill-creator`.                    |
| [CloudAI-X/claude-workflow-v2](https://github.com/CloudAI-X/claude-workflow-v2)                 | domain-specific (workflow) | `workflow`       |              14 | license, provenance, layout, pinning, security, metadata | Imported skills only; agents/commands left out for separate review.                             |
| [rohitg00/awesome-claude-code-toolkit](https://github.com/rohitg00/awesome-claude-code-toolkit) | awesome-list               | `cc-toolkit`     |              38 | license, provenance, layout, pinning, security, metadata | Imported curated `skills/` tree.                                                                |
| [foryourhealth111-pixel/Vibe-Skills](https://github.com/foryourhealth111-pixel/Vibe-Skills)     | general skills             | `vibe`           |               1 | license, provenance, layout, pinning, security, metadata | Imported root orchestration skill only. Excluded large bundled third-party warehouse.           |
| [tech-leads-club/agent-skills](https://github.com/tech-leads-club/agent-skills)                 | general skills             | `tlc`            |              80 | license, provenance, layout, pinning, security, metadata | Imported `packages/skills-catalog/skills`.                                                      |
| [open-gitagent/gitagent](https://github.com/open-gitagent/gitagent)                             | domain-specific (git)      | `gitagent`       |               1 | license, provenance, layout, pinning, security, metadata | Imported concrete `gmail-email`; excluded `example-skill`.                                      |
| [tw93/Waza](https://github.com/tw93/Waza)                                                       | general skills             | `waza`           |               8 | license, provenance, layout, pinning, security, metadata | Imported `skills/` tree.                                                                        |
