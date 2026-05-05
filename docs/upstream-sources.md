# Upstream skill sources (parked)

This file preserves the upstream skill repositories previously bundled via
`bundled-sources.nix`. The wiring (28 non-flake inputs in `flake.nix`,
`bundled-sources.nix`, the discovery / namespace / include / exclude
machinery) was removed in the v3 redesign in favor of a flat
content-only layout.

To re-import any of these later, vendor selected `<skill>/SKILL.md` trees
into `staging/` (or directly into `skills/`) under the original LICENSE,
or restore a Nix import path purpose-built for the specific source.

## Sources

| Key | Repo | Namespace | Subdir / paths | Notes |
|---|---|---|---|---|
| `cc-skills-golang` | github:samber/cc-skills-golang | `golang` | `skills/` | |
| `obsidian-skills` | github:kepano/obsidian-skills | `obsidian` | `skills/` | |
| `rust-skills` | github:actionbook/rust-skills | `rust` | `skills/`, `agents/`, `commands/` | |
| `claude-plugins-official` | github:anthropics/claude-plugins-official | `anthropic` | selected paths | `claude-md-improver` + 9 agents + 4 commands |
| `hashicorp-agent-skills` | github:hashicorp/agent-skills | `terraform` | `terraform-test`, `terraform-style-guide`, `refactor-module`, `terraform-stacks` | |
| `openai-skills` | github:openai/skills | `openai` | `aspnet-core`, `frontend-skill`, `gh-address-comments`, `gh-fix-ci`, `security-best-practices`, `security-ownership-map`, `security-threat-model` | from `skills/.curated/` |
| `microsoft-skills` | github:microsoft/skills | `ms` | `cloud-solution-architect`, `microsoft-docs` | from `.github/skills/` |
| `microsoft-azure-skills` | github:microsoft/skills | `azure` | `.github/plugins/azure-skills/skills` | full plugin |
| `cloudflare-skills` | github:cloudflare/skills | `cloudflare` | `cloudflare`, `durable-objects`, `workers-best-practices`, `wrangler` | |
| `trailofbits-skills` | github:trailofbits/skills | `tob` | 24 plugins | `agentic-actions-auditor`, `audit-context-building`, `differential-review`, `dimensional-analysis`, `insecure-defaults`, `semgrep-rule-creator`, `semgrep-rule-variant-creator`, `sharp-edges`, `static-analysis`, `supply-chain-risk-auditor`, `testing-handbook-skills`, `trailmark`, `variant-analysis`, `yara-authoring`, `constant-time-analysis`, `mutation-testing`, `zeroize-audit`, `dwarf-expert`, `gh-cli`, `modern-python`, `skill-improver`, `workflow-skill-design`, `culture-index` |
| `trailofbits-skills-curated` | github:trailofbits/skills-curated | `tobc` | 14 plugins | `ffuf-web-fuzzing`, `ghidra-headless`, `humanizer`, `last30days`, `openai-cloudflare-deploy`, `openai-develop-web-game`, `openai-pdf`, `planning-with-files`, `python-code-simplifier`, `react-pdf`, `scv-scan`, `security-awareness`, `skill-extractor`, `wooyun-legacy` |
| `addyosmani-agent-skills` | github:addyosmani/agent-skills | `addy` | `skills/` | excludes `using-agent-skills` |
| `minimax-skills` | github:MiniMax-AI/skills | `minimax` | `shader-dev` | |
| `taste-skill` | github:Leonxlnx/taste-skill | `taste` | `skills/` | UI design |
| `ai-research-skills` | github:Orchestra-Research/AI-Research-SKILLs | `ai-research` | `.` | ML research |
| `github-awesome-copilot` | github:github/awesome-copilot | `github` | `github-actions-workflow-spec`, `dependabot`, `gh-cli`, `secret-scanning`, `codeql`, `automate-this` | |
| `grafana-skills` | github:grafana/skills | `grafana` | `skills/` (recursive) | observability |
| `composio-awesome-codex-skills` | github:ComposioHQ/awesome-codex-skills | `composio` | 45 curated top-level skills | excludes generated `composio-skills/` marketplace |
| `superpowers-zh` | github:jnMetaCode/superpowers-zh | `superpowers-zh` | `skills/` | Chinese-language |
| `prat011-awesome-llm-skills` | github:Prat011/awesome-llm-skills | `prat011` | `.` | awesome-list |
| `aboutsecurity` | github:wgpsec/AboutSecurity | `aboutsecurity` | `skills/` | excludes `Dic/`, `Payload/`, `Vuln/` |
| `finance-skills` | github:himself65/finance-skills | `finance` | `plugins/` | excludes `skill-creator` |
| `claude-workflow-v2` | github:CloudAI-X/claude-workflow-v2 | `workflow` | `skills/` | |
| `awesome-claude-code-toolkit` | github:rohitg00/awesome-claude-code-toolkit | `cc-toolkit` | `skills/` | awesome-list |
| `vibe-skills` | github:foryourhealth111-pixel/Vibe-Skills | `vibe` | `.` | root orchestration only |
| `tech-leads-agent-skills` | github:tech-leads-club/agent-skills | `tlc` | `packages/skills-catalog/skills` | |
| `gitagent` | github:open-gitagent/gitagent | `gitagent` | `skills/` | excludes `example-skill` |
| `waza` | github:tw93/Waza | `waza` | `skills/` | |
| `mattpocock-skills` | github:mattpocock/skills | `mattpocock` | `skills/` | excludes `design-an-interface`, `edit-article`, `obsidian-vault`, `qa`, `request-refactor-plan`, `ubiquitous-language` |

## How this used to work

`flake.nix` listed each repo as a non-flake input. `bundled-sources.nix`
mapped each input to a namespace + subdir / paths / include / exclude
spec. `modules/skills.nix` walked each spec at module-eval time using
`lib/discover.nix` and registered every discovered SKILL.md as a
first-class skill, deployed alongside locally-maintained ones.

Removed because the resulting catalogue (~hundreds of skills, several
hundred LOC of resolution logic) was unreviewed and unmaintained. Re-add
incrementally and only after vetting.
