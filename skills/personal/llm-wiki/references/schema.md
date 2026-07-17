# Starter schema for a new LLM wiki

Copy this into the wiki root as `SCHEMA.md` and adjust with the user. The
schema is the contract between the user and the LLM maintainer; keep it
short and concrete.

```markdown
# SCHEMA.md

## Layout

- raw/                 immutable sources; never edited
- raw/assets/          downloaded images and attachments
- wiki/                LLM-maintained pages
- wiki/index.md        catalog of all pages
- wiki/log.md          append-only operation log

## Page types

- summary: one per raw source; filename mirrors the source name
- entity: a person, organization, product, or system
- concept: an idea, technique, or recurring theme
- synthesis: comparisons, timelines, and answers worth keeping

## Page format

Every page starts with frontmatter:

    ---
    type: summary | entity | concept | synthesis
    created: YYYY-MM-DD
    updated: YYYY-MM-DD
    sources: [relative links into raw/]
    ---

Then: a one-paragraph overview, the body, and a Related section of links
to other wiki pages.

## index.md format

One bullet per page, grouped by type:

    - [Page title](path.md) (type, YYYY-MM-DD): one-line summary

## log.md format

Append-only entries, newest last:

    ## [YYYY-MM-DD] ingest | <source title>
    ## [YYYY-MM-DD] query | <question>
    ## [YYYY-MM-DD] lint | <scope>

    One short paragraph per entry: what changed and which pages were
    touched.

## Workflows

- ingest: summary page, index entry, update related pages, log entry
- query: index first, cite pages, offer to file synthesis back
- lint: report contradictions, stale claims, orphans, missing links
```

Optional extensions to discuss with the user:

- qmd collection over `wiki/` and `raw/` once index.md scanning gets slow.
- Obsidian: wikilinks instead of relative links, Dataview over frontmatter,
  Web Clipper to capture articles into `raw/`.
- Marp for generating slide decks from synthesis pages.
- A `graphify` run over the corpus to visualize hubs and orphan clusters.
