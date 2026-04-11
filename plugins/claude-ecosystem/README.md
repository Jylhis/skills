# claude-ecosystem

Claude API and MCP server development intelligence for jstack: 4 skills
covering building applications with Claude, creating MCP servers, writing
promptfoo eval suites, and developing redteam plugins.

## Contents

- `.claude-plugin/plugin.json` -- plugin manifest
- `skills/` -- 4 skill directories

This plugin is part of [jstack](../../).

## Skills

`claude-api`, `mcp-builder`, `promptfoo-evals`, `redteam-plugin-development`

### claude-api

Build LLM-powered applications with the Claude API or Anthropic SDK.
Covers language detection, surface selection (API vs Agent SDK), model
configuration, thinking/effort, streaming, prompt caching, and tool use
across Python, TypeScript, Java, Go, Ruby, C#, PHP, and cURL.

### mcp-builder

Guide for creating high-quality MCP (Model Context Protocol) servers.
Covers research, implementation in Python (FastMCP) or TypeScript (MCP SDK),
tool design, testing, and evaluation.

### promptfoo-evals

Create or update promptfoo evaluation suites (`promptfooconfig.yaml`,
prompts, tests, assertions, providers). Use when adding eval coverage,
debugging regressions, or scaffolding a new eval matrix. Includes a
`references/cheatsheet.md` with the full assertion and provider reference.

### redteam-plugin-development

Standards for creating redteam plugins and graders: tag standardization
(`<UserQuery>`, `<purpose>`), grader rubric structure, attack template
structure, template variables, image dataset plugins, conditional rubric
logic, and the plugin registration checklist.

## Sources

Adapted from official Anthropic skill files.
