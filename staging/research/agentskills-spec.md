---
date: 2026-04-16
researcher: Claude Code (Opus 4.6)
method: web fetch of agentskills.io, GitHub repo analysis
version: unversioned (commit 8d8fcbc, 2026-04-14)
---

# Agent Skills Specification (agentskills.io)

Open standard for AI agent skills. Originally developed by Anthropic, now an open spec.
Repo: https://github.com/agentskills/agentskills (Apache 2.0 code, CC-BY-4.0 docs)

## Skill Schema

File: `SKILL.md` (YAML frontmatter + Markdown body)

| Field | Required | Constraints |
|-------|----------|-------------|
| `name` | Yes | 1-64 chars. Lowercase alphanumeric + hyphens. No leading/trailing hyphen, no consecutive `--`. Must match parent dir name. |
| `description` | Yes | Max 1024 chars. What the skill does and when to use it. |
| `license` | No | License name or reference. |
| `compatibility` | No | Max 500 chars. Environment requirements. |
| `metadata` | No | Arbitrary key-value (string:string). |
| `allowed-tools` | No | Space-separated tool names. **Experimental.** |

Body: free-form Markdown, recommended <500 lines / <5000 tokens.

## Directory Structure

```
skill-name/
  SKILL.md          # Required
  scripts/          # Optional executables
  references/       # Optional documentation
  assets/           # Optional templates/resources
```

## Discovery

Three-tier progressive disclosure:

1. **Metadata** (~100 tokens): name + description loaded at startup for all skills
2. **Instructions** (<5000 tokens): full SKILL.md body loaded on activation
3. **Resources** (varies): scripts/references/assets loaded on demand

### Discovery Paths (convention)

| Scope | Path | Notes |
|-------|------|-------|
| Project | `<project>/.agents/skills/` | Cross-client interop |
| Project | `<project>/.<client>/skills/` | Client-specific |
| User | `~/.agents/skills/` | Cross-client interop |
| User | `~/.<client>/skills/` | Client-specific |

`.agents/skills/` is the widely-adopted cross-client convention. Project-level overrides user-level on name collision.

Scanning: look for subdirs containing `SKILL.md`. Skip `.git/`, `node_modules/`. Max depth 4-6.

## Activation

- **Model-driven**: model reads catalog, decides relevance, calls `activate_skill` or reads file directly
- **User-explicit**: `/skill-name` slash command

## Compatible Tools (37)

Claude Code, GitHub Copilot, OpenAI Codex, Cursor, Gemini CLI, Kiro, JetBrains Junie,
Roo Code, OpenHands, Goose, Amp, OpenCode, Pi, Windsurf, TRAE, Autohand Code CLI,
Mux, Letta, Firebender, Piebald, Factory, Databricks Genie Code, Agentman, Spring AI,
Mistral AI Vibe, Command Code, Ona, VT Code, Qodo, Laravel Boost, Emdash,
Snowflake Cortex Code, Workshop, Google AI Edge Gallery, nanobot, and more.

## Versioning

No spec versioning. Living document. `allowed-tools` marked Experimental.

## Validation

`skills-ref validate ./my-skill` (Python library in repo)
