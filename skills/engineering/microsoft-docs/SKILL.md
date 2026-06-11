---
name: microsoft-docs
description: Understand Microsoft technologies by querying official documentation. Use whenever the user asks how something works, wants tutorials, needs configuration options, limits, quotas, or best practices for any Microsoft technology (Azure, .NET, M365, Windows, Power Platform, etc.)—even if they don't mention "docs." If the question is about understanding a concept rather than writing code, this is the right skill.
compatibility: "Primarily uses the Microsoft Learn MCP Server (https://learn.microsoft.com/api/mcp). If unavailable, fall back to fetching the public Microsoft Learn web docs directly."
metadata:
  upstream-id: microsoft-docs
  upstream-rev: b71de35cb5a1acc458e1f518cbb9acc830f6d7c6
  upstream-path: microsoft-docs
  upstream-imported: 2026-05-12
---

# Microsoft Docs

## Tools

| Tool | Use For |
|------|---------|
| `microsoft_docs_search` | Find documentation—concepts, guides, tutorials, configuration |
| `microsoft_docs_fetch` | Get full page content (when search excerpts aren't enough) |

## When to Use

- **Understanding concepts** — "How does Cosmos DB partitioning work?"
- **Learning a service** — "Azure Functions overview", "Container Apps architecture"
- **Finding tutorials** — "quickstart", "getting started", "step-by-step"
- **Configuration options** — "App Service configuration settings"
- **Limits & quotas** — "Azure OpenAI rate limits", "Service Bus quotas"
- **Best practices** — "Azure security best practices"

## Query Effectiveness

Good queries are specific:

```
# ❌ Too broad
"Azure Functions"

# ✅ Specific
"Azure Functions Python v2 programming model"
"Cosmos DB partition key design best practices"
"Container Apps scaling rules KEDA"
```

Include context:
- **Version** when relevant (`.NET 8`, `EF Core 8`)
- **Task intent** (`quickstart`, `tutorial`, `overview`, `limits`)
- **Platform** for multi-platform docs (`Linux`, `Windows`)

## When to Fetch Full Page

Fetch after search when:
- **Tutorials** — need complete step-by-step instructions
- **Configuration guides** — need all options listed
- **Deep dives** — user wants comprehensive coverage
- **Search excerpt is cut off** — full context needed

## Why Use This

- **Accuracy** — live docs, not training data that may be outdated
- **Completeness** — tutorials have all steps, not fragments
- **Authority** — official Microsoft documentation

## Fallback when the MCP server is unavailable

The Microsoft Learn MCP Server (`microsoft_docs_search`,
`microsoft_docs_fetch`) is the primary path. If it is not available,
fetch the public Microsoft Learn web docs directly:

- **Search** — query `https://learn.microsoft.com/search/?terms=<query>`
  (or a normal web search scoped to `site:learn.microsoft.com`) to find
  the relevant page URLs.
- **Fetch** — retrieve the page at its `https://learn.microsoft.com/...`
  URL and read the rendered content. Narrow to the heading you need and
  skip navigation chrome.

Keep the same query-effectiveness rules above (be specific, include
version/task/platform context). The web fallback is lower-fidelity than
the MCP tools — prefer the MCP server whenever it is reachable.
