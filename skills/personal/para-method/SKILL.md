---
name: para-method
description: Organize notes, files, or an Obsidian vault with the PARA method (Projects, Areas, Resources, Archives). Use when the user asks to structure or restructure a knowledge base, vault, folder tree, or cloud drive; decide where a note or document belongs; separate active work from reference material; or clean up an overgrown collection by actionability.
metadata:
  source: "https://fortelabs.com/blog/para/"
  adapted: "concept adaptation, original prose"
---

# PARA method

Organize information into four top-level buckets sorted by actionability,
not by subject. Method by Tiago Forte
([Forte Labs](https://fortelabs.com/blog/para/)); this skill is an
original summary for applying it with an agent.

## The four categories

- **Projects**: short-term efforts with a defined outcome and an end state.
  "Ship the Q3 report", "renovate the bathroom". A project can be finished.
- **Areas**: ongoing responsibilities with a standard to maintain and no
  end date. "Health", "finances", "team hiring". An area is never done.
- **Resources**: topics of ongoing interest collected for future use.
  "Coffee", "typography", "Rust". No responsibility attached.
- **Archives**: inactive items from the other three. Completed or abandoned
  projects, areas no longer maintained, interests gone cold.

The same four buckets work in any tool: folder trees, Obsidian vaults,
note apps, email, cloud drives. Mirror the structure across tools rather
than inventing a different scheme per tool.

## Filing procedure

For each item, ask in order:

1. Does it advance a specific active project? File under that project.
2. Does it belong to an ongoing responsibility? File under that area.
3. Is it interesting enough to want again later? File under a resource
   topic.
4. Otherwise archive it. Archiving is cheap and reversible; deleting and
   elaborate taxonomies are not.

Two consequences worth stating to the user:

- Subject folders ("Psychology", "Business") are an anti-pattern here.
  The question is never "what is this about" but "what can I act on".
- The projects list doubles as the workload inventory. If a goal has no
  project, it is not being worked on; if an area keeps generating tasks,
  break a project out of it so completions stay visible.

## Lifecycle

Items flow toward Archives:

- Project completed or dropped: move the whole project folder to Archives.
- Area handed off or lapsed: archive it.
- Resource topic gone stale: archive it.
- The reverse flow is normal too: pull an archived project back when it
  reactivates, or promote a resource to a project when interest becomes a
  commitment.

Suggest a light periodic review (weekly or monthly): scan the projects
list for anything finished or stalled, and file the inbox backlog using
the procedure above. PARA tolerates mess between reviews; it only needs
the four boundaries kept honest.

## Restructuring an existing collection

When asked to convert an overgrown vault or folder tree:

1. Inventory the current top level and list active projects with the user.
   The projects list comes from the user, not from the folders.
2. Create the four top-level folders (prefix them `1 Projects`,
   `2 Areas`, `3 Resources`, `4 Archives` when sort order matters).
3. Move obvious matches in bulk; file stragglers with the four questions.
   When in doubt, archive rather than agonize.
4. Do not rename or reorganize inside moved folders in the same pass.
   One structural change at a time keeps the move reviewable.

In Obsidian, folders are the simplest mapping; the obsidian-markdown
skill covers using properties or tags instead when the user prefers flat
structure. A PARA vault pairs well with the llm-wiki skill: the wiki
typically lives inside a Resource or Area folder.

## Verification

After a restructure: every top-level item sits in one of the four buckets,
each project folder names an outcome that can finish, and nothing was
deleted (archives hold the doubtful cases).
