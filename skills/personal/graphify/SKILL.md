---
name: graphify
description: Build and query a knowledge graph over a repo, docs folder, papers, or notes corpus using the graphify CLI. Use when the user asks to graphify a directory, map a codebase or research corpus into a knowledge graph, find connections between concepts or files, explain how entities relate, or export a graph as an Obsidian vault, HTML visualization, GraphML, or Neo4j.
compatibility: "Requires the graphify CLI (Python 3.10+). Install via `pip install graphifyy` (PyPI name is temporarily graphifyy)."
metadata:
  source: "https://github.com/Graphify-Labs/graphify"
  source-license: MIT
  adapted: "workflow adaptation of upstream graphify/skill.md"
---

# Graphify

Turn a folder of mixed files (code, markdown, PDFs, images) into a
persistent, queryable knowledge graph: entities and edges, clustered into
communities, exported as an Obsidian vault and interactive HTML. Adapted
from the skill shipped by
[Graphify-Labs/graphify](https://github.com/Graphify-Labs/graphify) (MIT).

What the graph adds over reading files directly: relationships persist
across sessions in `graphify-out/graph.json`, every edge carries an
audit tag (EXTRACTED from source, INFERRED by the model, or AMBIGUOUS),
and community detection surfaces cross-document connections that grepping
misses.

## Prerequisites

Check the install before anything else:

```sh
graphify --version || pip install graphifyy
```

Code parsing is local AST work (tree-sitter, no LLM cost). Semantic
extraction from docs, PDFs, and images calls an LLM, so large corpora
cost real tokens; warn the user before deep runs on big folders.

## Build a graph

```sh
graphify <path>              # full pipeline: extract, build, cluster, report
graphify <path> --mode deep  # aggressive cross-document inference (slower, costlier)
graphify <path> --update     # re-extract changed files only, merge into graph
graphify <path> --watch      # auto-rebuild on change (code-only, no LLM cost)
```

Scope before running: if the corpus exceeds roughly 200 files or 2M
words, ask the user to pick a subfolder instead of forcing the whole
tree through. Skip obviously sensitive files (secrets, credentials) from
the corpus.

Outputs land in `graphify-out/`: `graph.json` (persistent store), an
Obsidian vault, `graph.html` (interactive view, practical below ~5000
nodes), and a markdown report. Community labels in the report are meant
to be reviewed and renamed by a human; offer to relabel them with the
user rather than trusting auto-generated names.

## Query the graph

```sh
graphify query "<question>"      # answer by traversing the graph
graphify path "<A>" "<B>"        # shortest path between two concepts
graphify explain "<entity>"      # everything the graph knows about one node
graphify add <url>               # fetch a URL into the corpus and update
```

When relaying answers: cite the source locations the graph gives, keep
the EXTRACTED / INFERRED / AMBIGUOUS distinction visible for
load-bearing claims, and say so plainly when the graph has no coverage
instead of filling gaps from your own knowledge.

## Exports

```sh
graphify <path> --svg        # embeddable diagram
graphify <path> --graphml    # Gephi / yEd
graphify <path> --neo4j      # Cypher export or direct push
graphify <path> --mcp        # serve the graph over MCP
```

The Obsidian vault export pairs with the obsidian-markdown skill; a
graphify run over an llm-wiki corpus is a quick way to visualize hubs
and orphan pages.

## Gotchas

- Upstream's `graphify install` drops its own copy of this skill into
  `~/.claude/skills/graphify/`. If that copy is present, they overlap;
  prefer one and tell the user which.
- `--update` beats full rebuilds once a graph exists; full runs redo the
  LLM extraction.
- Rerunning clustering alone is cheap: `graphify <path> --cluster-only`.

## Verification

After a build: `graphify-out/graph.json` exists and is non-empty, the
report lists communities with sensible labels, and a spot-check
`graphify explain` on a known entity returns edges pointing at real
source locations.
