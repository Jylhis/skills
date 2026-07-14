---
name: llm-wiki
description: Maintain a persistent, LLM-curated markdown wiki over a collection of raw sources. Use when the user wants to build or maintain a personal knowledge base, second brain, or research wiki; ingest an article, paper, or note into a wiki; query an existing wiki for synthesized answers; or lint a wiki for contradictions, stale claims, and orphan pages.
metadata:
  source: "https://gist.github.com/karpathy/442a6bf555914893e9891c11519de94f"
  adapted: "concept adaptation, original prose"
---

# LLM Wiki

Maintain a markdown wiki that compounds over time instead of re-deriving
answers from raw documents on every question. You act as the wiki's
librarian: the user curates and directs, you do the bookkeeping. Pattern
adapted from Andrej Karpathy's
[LLM Wiki](https://gist.github.com/karpathy/442a6bf555914893e9891c11519de94f).

## Layout

A wiki has three layers. Never blur them.

```
raw/          immutable source documents (articles, papers, transcripts)
raw/assets/   images and attachments, downloaded locally
wiki/         pages you create and maintain
wiki/index.md catalog of every page: link, one-line summary, type, date
wiki/log.md   append-only operation log
SCHEMA.md     conventions for this wiki (layout, page format, workflows)
```

Rules:

- Read `raw/`, never modify it. Sources are the ground truth.
- You own `wiki/` entirely: summaries, entity pages, concept pages,
  synthesis pages, all cross-linked with relative markdown links.
- `SCHEMA.md` (or the project's CLAUDE.md) defines this wiki's specific
  conventions. Read it first; it overrides the defaults here. If the wiki
  has no schema file yet, propose one from
  [references/schema.md](references/schema.md) and adjust it with the user.

## Operation: ingest

When the user drops a new source into `raw/` (or asks you to fetch one):

1. Read the source fully. Discuss takeaways with the user when they are
   present; batch-ingest silently when asked to process a backlog.
2. Write a summary page under `wiki/` following the schema's page format,
   linking back to the raw source.
3. Update `wiki/index.md` with the new page's link, one-line summary, and
   metadata.
4. Update related wiki pages. This is the step that makes the wiki compound:
   add cross-references, extend entity and concept pages, and reconcile the
   new information with what existing pages claim. Touching roughly 5 to 15
   related pages per ingest is normal.
5. Append one entry to `wiki/log.md` using the schema's prefix format, for
   example `## [2026-07-14] ingest | Title of source`.

## Operation: query

When the user asks a question against the wiki:

1. Start from `wiki/index.md` to locate candidate pages. At modest scale
   (up to a few hundred pages) scanning the index beats any search
   infrastructure. Beyond that, use the qmd skill if the wiki is indexed
   with qmd.
2. Read the relevant pages, follow cross-links, and synthesize an answer
   with citations to wiki pages and raw sources.
3. If the answer required real synthesis (comparisons, timelines, tables),
   offer to file it back into `wiki/` as a new page so the work is not lost
   to chat history. Update index.md and log.md when you do.

## Operation: lint

Run periodically, or when the user asks for a health check:

- Contradictions between pages, and claims that newer sources have made
  stale.
- Orphan pages that index.md does not list, and index entries whose pages
  are missing.
- Broken or one-directional cross-references. Drift here is the pattern's
  main failure mode, so prefer running lint after every few ingests.
- Gaps: entities or concepts referenced often but lacking their own page.

Report findings first; fix them only with the user's go-ahead, and log the
lint as one log.md entry.

## Gotchas

- Never rewrite log.md history; it is append-only.
- Keep page edits surgical during ingest. Reconciling is not rewriting.
- Download referenced images into `raw/assets/` instead of hot-linking URLs
  that may rot.
- Keep the wiki in git; commit after each ingest or lint so the evolution
  stays inspectable.
- The obsidian-markdown skill applies when the wiki lives in an Obsidian
  vault (wikilinks, properties, graph view for spotting orphans). The
  para-method skill applies when the user also wants an organizing scheme
  for the surrounding vault.

## Verification

After any operation: index.md lists every page under `wiki/`, every new
page links back to its raw source, log.md gained exactly one entry, and
`git status` shows no changes under `raw/`.
