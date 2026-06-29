# Commit message examples and formats

## Conventional Commits cheat-sheet

Format: `type(scope): subject`, then an optional body and footers, one blank line between each.

| Type | Use for | SemVer bump |
|---|---|---|
| `feat` | a new feature | MINOR |
| `fix` | a bug fix | PATCH |
| `docs` | documentation only | none |
| `style` | formatting, whitespace, no logic change | none |
| `refactor` | code change that is neither a feature nor a fix | none |
| `perf` | a performance improvement | PATCH |
| `test` | adding or fixing tests | none |
| `build` | build system or dependencies | none |
| `ci` | CI configuration | none |
| `chore` | tooling, housekeeping | none |
| `revert` | reverts a previous commit | varies |

- Scope is optional and names the area: `feat(parser): ...`.
- Breaking change: append `!` (`feat!: drop Node 16`) or add a `BREAKING CHANGE:` footer. Either one bumps MAJOR.
- Use this format only when the repo already does. Some projects enforce it with commitlint / commitizen; look for a `.commitlintrc*` file.

## Subject line: before and after

| Bad | Better | Why |
|---|---|---|
| `WIP` | `Reject expired tokens at auth boundary` | names the behaviour change |
| `fixes` | `Fix off-by-one in pagination cursor` | says what was wrong |
| `update auth.py` | `Require MFA for service-account logins` | intent, not file |
| `cleanup` | `Remove dead OAuth1 fallback path` | what was removed |
| `more changes` | `Cut /v1 retry loop to one attempt` | concrete |

## A full example (Conventional subject plus narrative body)

```
fix(parser): handle UTF-8 non-breaking spaces in headers

Header values containing a U+00A0 non-breaking space raised
`ArgumentError: invalid byte sequence in US-ASCII` during parsing,
which surfaced as intermittent CI test failures but never locally.

Normalise the byte string to UTF-8 before the regex split rather than
widening the regex, so the fix stays local to the decode boundary.

Closes #482
```

What this does well: the subject is a complete imperative summary; the body opens with the problem (most-important-first), includes the exact error string for searchability, names the rejected alternative, and links the issue instead of restating it.

## Case study: narrative versus structure

David Thompson's "my favourite git commit" (<https://dhwthompson.com/2019/my-favourite-git-commit>) celebrates a long, story-rich commit: it explains the problem, the investigation, and the reasoning, and it is searchable.

Michael Lynch's reply, "no longer my favourite git commit" (<https://mtlynch.io/no-longer-my-favorite-git-commit/>), agrees the richness is good but argues the example buries the lede, never states plainly why the character was a problem, and references code without linking to it.

The synthesis this skill follows: write with Thompson's richness, but structure the way Lynch's critique asks. Lead with what changed and why, state the problem explicitly, then add investigation detail, and link every commit or issue you mention.
