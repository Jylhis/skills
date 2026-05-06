# AI Skills Ecosystem Research

> Researched: 2026-04-20

## Open Standard

**Agent Skills spec** — maintained by Anthropic at https://agentskills.io, spec at https://github.com/agentskills/agentskills (16.7k stars). A skill is a directory containing `SKILL.md` with YAML frontmatter (`name`, `description`, optional `license`, `compatibility`, `metadata`, `allowed-tools`) followed by Markdown. Optional subdirs: `scripts/`, `references/`, `assets/`. Supported by Claude Code, Codex, Gemini CLI, GitHub Copilot, Cursor, Cline, Windsurf, OpenCode, Antigravity, Kiro, and more.

**AGENTS.md** — parallel "README for agents" format donated by OpenAI to the Agentic AI Foundation (Linux Foundation, Dec 2025). Adopted by 60,000+ open-source projects.

---

## Official Vendor Skill Repositories

| Repo | Stars | Notes |
|------|-------|-------|
| [anthropics/skills](https://github.com/anthropics/skills) | 121k | Anthropic's official curated skills; separate from `claude-plugins-official` |
| [openai/skills](https://github.com/openai/skills) | 17.1k | OpenAI's curated Codex skills; partially bundled in this repo |
| [google-gemini/gemini-cli](https://github.com/google-gemini/gemini-cli) | — | Built-in skills; auto-discovers from `.gemini/skills/` |
| [github/awesome-copilot](https://github.com/github/awesome-copilot) | 30.6k | 208+ community Copilot skills; `gh skill install github/awesome-copilot <name>` |
| [huggingface/skills](https://github.com/huggingface/skills) | — | Official HF skills (not yet bundled here) |
| [microsoft/skills](https://github.com/microsoft/skills) | 2.1k | 128 Azure/Microsoft skills |

---

## Community Skill Collections

| Repo | Stars | Notes |
|------|-------|-------|
| [VoltAgent/awesome-agent-skills](https://github.com/VoltAgent/awesome-agent-skills) | 16.6k | 1,000+ curated; Claude/Codex/Gemini/Cursor |
| [sickn33/antigravity-awesome-skills](https://github.com/sickn33/antigravity-awesome-skills) | 34.2k | 1,400+ SKILL.md playbooks; npm installer |
| [hesreallyhim/awesome-claude-code](https://github.com/hesreallyhim/awesome-claude-code) | — | 75+ Claude Code repos (skills, hooks, commands) |
| [alirezarezvani/claude-skills](https://github.com/alirezarezvani/claude-skills) | 12.1k | 232+ skills; engineering/marketing/compliance |
| [ComposioHQ/awesome-claude-skills](https://github.com/ComposioHQ/awesome-claude-skills) | 55.2k | Composio-integrated |
| [mukul975/Anthropic-Cybersecurity-Skills](https://github.com/mukul975/Anthropic-Cybersecurity-Skills) | — | 754 skills; MITRE ATT&CK/NIST/D3FEND; Apache 2.0 |
| [K-Dense-AI/scientific-agent-skills](https://github.com/K-Dense-AI/scientific-agent-skills) | — | Research/science/finance/engineering |

---

## npm/npx Installer Tools

### vercel-labs/skills — `npx skills`
- **GitHub**: https://github.com/vercel-labs/skills — 14.7k stars, v1.5.1 (April 17, 2026)
- **Install**: `npx skills add <owner/repo>` or `npx skills add <owner/repo> --skill <name>`
- **Source**: GitHub shorthand, full URLs, GitLab, local paths
- **Install paths**: `.claude/skills/`, `~/.claude/skills/` (project/global per agent)
- **Cross-agent**: 45+ agents
- **Registry**: https://skills.sh (91,014 skills indexed)
- **Language**: TypeScript

### numman-ali/openskills — `npx openskills`
- **GitHub**: https://github.com/numman-ali/openskills — 9.9k stars, v1.5.0 (Jan 2026)
- **Commands**: `install`, `sync`, `list`, `read`, `update`, `manage`, `remove`
- **Flags**: `--global`, `--universal` (`.agent/skills/`), `-y`, `-o <path>`
- **Cross-agent**: Claude Code, Cursor, Windsurf, Aider, Codex
- **Language**: TypeScript; Apache 2.0; requires Node.js 20.6+

### rohitg00/skillkit — `npx skillkit`
- **GitHub**: https://github.com/rohitg00/skillkit — 851 stars, v1.22.1 (April 2026)
- **Commands**: `install`, `remove`, `translate`, `sync`, `recommend`, `generate`
- **Feature**: auto-translates between agent formats (SKILL.md ↔ .mdc ↔ etc.)
- **Source**: 15,000+ skills from marketplace + GitHub repos
- **Cross-agent**: 45 agents; Apache 2.0

### sickn33/antigravity-awesome-skills — `npx antigravity-awesome-skills`
- **GitHub**: https://github.com/sickn33/antigravity-awesome-skills — 34.2k stars, v10.5.0 (April 20, 2026)
- **Flags**: `--claude`, `--cursor`, `--gemini`, `--codex`, `--antigravity`, `--kiro`, `--path`
- **Source**: bundled 1,400+ SKILL.md playbooks
- **Language**: Python 82%, JavaScript 7%, Shell 5%

### ahmadawais/add-skill — `npx add-skill`
- **GitHub**: https://github.com/ahmadawais/add-skill
- **Install**: `npx add-skill <owner/repo>` or `-g` for global
- **Source**: GitHub, GitLab, git URLs
- **Cross-agent**: 15 agents; zero dependencies
- **Website**: https://add-skill.org

### Karanjot786/agent-skills-cli — `npm i -g agent-skills-cli`
- **GitHub**: https://github.com/Karanjot786/agent-skills-cli — 128 stars
- **Commands**: `skills install <name>`, `skills search <query>`, `skills check`, `skills add`, `skills remove`
- **Source**: SkillsMP marketplace (500,000+ skills)
- **Cross-agent**: 45 agents; TypeScript

### agentskill-sh/ags — `@agentskill.sh/cli`
- **GitHub**: https://github.com/agentskill-sh/ags — 15 stars
- **Commands**: `ags search`, `ags install`, `ags list`, `ags update`, `ags remove`, `ags feedback`
- **Source**: central registry 100,000+ skills
- **Security**: server-side static analysis + client-side verification

### antfu/skills-npm — bundled in npm packages
- **GitHub**: https://github.com/antfu/skills-npm — 421 stars, v1.1.1 (March 2026)
- **Model**: embed skills inside npm packages; `npm install` auto-deploys via `prepare` script
- **Use case**: library authors bundle skills alongside their library

---

## Python/pip/uv Tools

### sparfenyuk/agent-skills-cli — `uv tool install agent-skills-cli`
- **GitHub**: https://github.com/sparfenyuk/agent-skills-cli — 3 stars, v0.1.1 (Dec 2025)
- **Commands**: `init`, `install <url> --rev <tag> --skill <name>`, `enable`, `sync`, `update`, `list`
- **Lockfile**: `.agent-skills.yaml` with `resolved_sha` — **only tool with true SHA-pinned lockfile semantics**
- **Store**: `.agent-skills/store/` (git worktrees per SHA) → symlinks into agent dirs
- **Cross-agent**: Codex, Claude, OpenCode
- **Language**: Python 100%; PyPI: `agent-skills-cli`

### davidyangcool/agent-skill — `pip install agent-skill`
- **GitHub**: https://github.com/davidyangcool/agent-skill
- **Commands**: `skill search`, `skill show`, `skill install <name> [-a claude] [-g]`, `skill list`, `skill uninstall`
- **Also**: MCP server mode
- **Source**: SkillMaster registry
- **Cross-agent**: OpenCode, Claude Code, Codex, Cursor, Antigravity
- **PyPI**: `agent-skill` v1.0.3 (Jan 2026)

### timmyb824/one-skills-manager — `pip install one-skills-manager`
- **Central store**: `~/.one-skills/skills/<name>/` → symlinks per agent dir
- **Cross-agent**: Claude Code, Cursor, Windsurf, Codex
- **PyPI**: `one-skills-manager` v1.4.0 (April 2026); requires Python ≥3.13

### huggingface/upskill — `uvx upskill`
- **GitHub**: https://github.com/huggingface/upskill — 485 stars; Apache 2.0
- **Purpose**: *generate and evaluate* skills (not install); teacher→student model
- **Commands**: `upskill generate "task"`, `upskill eval ./skills/<name>/`, `upskill list`, `upskill runs`
- **Output**: saves to `./skills/{skill-name}/SKILL.md`
- **PyPI**: `upskill`

---

## GitHub CLI

### `gh skill` — built into GitHub CLI v2.90.0 (April 16, 2026)
- **Docs**: https://cli.github.com/manual/gh_skill_install
- **Commands**:
  ```
  gh skill search <query>
  gh skill preview <owner/repo> [<skill>]
  gh skill install <owner/repo> [<skill[@version]>] [--pin <sha/tag>] [--agent <name>] [--scope project|user]
  gh skill update [<skill>] [--all] [--dry-run]
  gh skill publish [--dry-run]
  ```
- **Version pinning**: `--pin <git-tag-or-SHA>`; `@version` syntax; pinned skills skipped by `update`
- **Provenance**: writes into `SKILL.md` frontmatter: `github-repo`, `github-path`, `github-ref`, `github-tree-sha`, `github-pinned`
- **Cross-agent**: GitHub Copilot (default), Claude Code, Cursor, Codex, Gemini CLI, Antigravity
- **Language**: Go (part of gh CLI)
- **Status**: public preview

### trieloff/gh-upskill — `gh extension install ai-ecoverse/gh-upskill`
- **GitHub**: https://github.com/trieloff/gh-upskill — 19 stars
- **Commands**: `upskill <owner/repo> --list`, `--skill <name>`, `--all`, `--dest-path`, `-g`
- **Language**: Shell; pre-dates native `gh skill`

---

## Desktop GUI

### xingkongliang/skills-manager
- **GitHub**: https://github.com/xingkongliang/skills-manager — 692 stars, v1.14.1 (April 18, 2026)
- **Type**: Tauri app (TypeScript + Rust); native binary
- **Agents**: 15+ (Cursor, Claude Code, Codex, OpenCode, Amp, Kilo Code, Roo Code, Goose, Gemini CLI, Copilot, Windsurf, Antigravity, Clawdbot, Droid, TRAE IDE)

---

## Nix-Specific Projects

| Project | URL | Notes |
|---------|-----|-------|
| **Kyure-A/agent-skills-nix** | https://github.com/Kyure-A/agent-skills-nix | Closest competitor; declarative HM integration, namespacing, enable/disable. Skills only — no agents/commands/settings/MCP/evals |
| **numtide/llm-agents.nix** | https://github.com/numtide/llm-agents.nix | Packages AI CLI tools (not skill content); daily auto-update; binary cache |
| **Qumulo/llm-agents** | https://github.com/Qumulo/llm-agents | Similar to numtide — packaging agents, not managing skills |

---

## Registries / Marketplaces

| Registry | URL | Size | Notes |
|----------|-----|------|-------|
| skills.sh | https://skills.sh | 91,014 | vercel-labs ecosystem; install stats |
| LobeHub | https://lobehub.com/skills | 100,000+ | Strong curation and ratings |
| SkillsMP | https://skillsmp.com | 500,000+ | Aggregates GitHub; ≥2 stars filter |
| ClawHub | https://clawhub.ai | 13,729 | OpenClaw registry; security incident Feb 2026 (341 malicious skills) |
| agentskills.io | https://agentskills.io | spec + examples | Official standard site |

---

## Key Observations

1. **`npx skills` (vercel-labs)** is the de facto standard npm installer; skills.sh is the npm registry equivalent for skills (91k skills).

2. **`gh skill` (April 16, 2026)** is the richest feature set: SHA-pinned versions, provenance in SKILL.md frontmatter, interactive browsing, publish validation — closest to Nix's reproducibility model in the npm/gh world.

3. **Only `sparfenyuk/agent-skills-cli`** (Python) has true lockfile semantics (`resolved_sha` in `.agent-skills.yaml`) — conceptually closest to `flake.lock`.

4. **`antfu/skills-npm`** is a novel distribution model: skills bundled in npm packages, deployed as `npm install` side effects.

5. **ClawHub's malicious skills incident** (Feb 2026) validates the curated+Nix-pinned approach over direct registry pulls.

6. **No tool manages the full stack** (skills + agents + commands + hooks + settings + MCP servers) — this repo's main differentiator.

7. **Not yet bundled here but worth considering**: `huggingface/skills`, `mukul975/Anthropic-Cybersecurity-Skills` (754 skills, Apache 2.0), `anthropics/skills` (separate repo from `claude-plugins-official`).
