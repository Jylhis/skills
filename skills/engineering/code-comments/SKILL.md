---
name: code-comments
description: "Write and review code comments: when a comment earns its place versus self-documenting code, explaining why and intent rather than restating what, doc comments (docstrings, JSDoc/TSDoc, godoc, rustdoc, Javadoc) versus inline notes, TODO and FIXME conventions, avoiding comment rot and commented-out code, and the AI tendency to over-comment. Use when writing or reviewing comments, documenting an API, or cleaning up noisy or redundant comments."
---

# Code comments

The best comment is often a better name. Reach for a comment only when the code cannot carry the meaning on its own. A comment that restates the code adds maintenance cost and drifts out of date; a comment that explains why earns its place.

## When to use this skill

- Writing a comment or a documentation block.
- Reviewing a diff for comment quality (too few, too many, or stale).
- Documenting a public API.
- Cleaning up noisy, redundant, or commented-out code.

## When a comment earns its place

Try self-documenting code first: a precise name, a smaller function, a named constant, an early return. Add a comment when:

- The **why is not obvious**: a non-obvious rationale, a tradeoff, a workaround for an upstream bug, a performance or security reason.
- The behaviour is **surprising**: an ordering constraint, a side effect, a deliberate deviation from the obvious approach.
- It is a **public API contract**: callers need the parameters, return values, errors, and invariants without reading the body.
- It is **legal or license** boilerplate the project requires.

Do not comment the obvious. `i += 1  # increment i` is noise.

## Explain why, not what

The code already says what it does. The comment says what the code cannot:

```python
# Bad: restates the code
# loop over users and send email
for user in users:
    send_email(user)

# Better: explains the non-obvious why
# Vendor API rate-limits at 10 req/s; batching avoids the 429 retry
# storm we hit in INC-204.
for batch in chunked(users, 10):
    send_batch(batch)
```

## Doc comments versus inline notes

- **Public API:** use the language's documentation format (docstring, JSDoc/TSDoc, godoc, rustdoc, Javadoc) so generated docs and editor tooltips work. See [references/doc-formats.md](references/doc-formats.md).
- **Implementation notes:** a terse inline comment sits next to the tricky line, not in a header block far from the code it describes.

## Keep comments close and current

A wrong comment is worse than no comment, because the reader trusts it. When you change code, update or delete the comment in the same edit. Delete commented-out code: version control already remembers it, and dead code in comments rots silently.

## TODO and FIXME markers

Use a consistent marker (`TODO`, `FIXME`, `HACK`, `XXX`) and attach an owner or an issue link so it can be found and closed:

```
# TODO(JYL-512): replace with the streaming parser once it ships
```

A TODO with no link and no owner is a comment that will never be removed.

## Anti-patterns

- **Redundant comments** that restate the code.
- **Commented-out code** left in the file.
- **Stale comments** that no longer match the code.
- **Decorative banners and divider lines** (rows of `#`, `*`, or `=`) used as section separators; prefer a blank line or a short heading comment.
- **Comments that apologise for a bad name:** rename the symbol instead.

## AI-specific pitfalls

Models tend to over-comment: a comment on every line, a docstring that repeats the signature, narration of the obvious. Rules when generating comments:

- Add a comment only when it tells the reader something the code cannot.
- Do not annotate self-evident lines.
- For a doc comment, describe the contract (params, returns, errors, invariants), not a paraphrase of the body.
- **Match the file's existing comment density and style.** A sparsely commented file should stay sparse.

## Relationship to the language skills

This skill is the cross-cutting philosophy. For language-specific syntax and conventions (docstring style, JSDoc tags, godoc rules, rustdoc doctests), use the matching language skill and [references/doc-formats.md](references/doc-formats.md).
