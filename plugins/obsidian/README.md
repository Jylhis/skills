# obsidian

Obsidian knowledge base skills for jstack: 5 skills covering Obsidian
Flavored Markdown, JSON Canvas, Bases, the Obsidian CLI, and web content
extraction with Defuddle.

## Contents

- `.claude-plugin/plugin.json` — plugin manifest
- `skills/` — 5 skill directories, three with `references/` subdirs

This plugin is part of [jstack](../../) and is installed into
`~/.claude/plugins/obsidian/` automatically by `scripts/install.bash`.
There is no separate install step.

## Skills

| Skill | Description |
|---|---|
| `defuddle` | Extract clean markdown from web pages using the Defuddle CLI |
| `json-canvas` | Create and edit JSON Canvas files (`.canvas`) with nodes, edges, and groups |
| `obsidian-bases` | Create and edit Obsidian Bases (`.base` files) with views, filters, and formulas |
| `obsidian-cli` | Interact with Obsidian vaults via the Obsidian CLI |
| `obsidian-markdown` | Create and edit Obsidian Flavored Markdown with wikilinks, embeds, callouts, and properties |

## External CLI dependencies

Two skills require external CLI tools that are not currently in
`runtime/default.nix`:

- `defuddle` requires the [Defuddle CLI](https://github.com/kepano/defuddle)
- `obsidian-cli` requires the [Obsidian CLI](https://github.com/Yakitrak/obsidian-cli)

The skills will trigger on matching prompts but will fail at exec time
if the corresponding CLI is not on `PATH`.

## Sources

- [`kepano/obsidian-skills`](https://github.com/kepano/obsidian-skills) — 5 skills by kepano (MIT)

Skills retain the licenses of their original sources.

## See also

- jstack docs: [`docs/plugins/obsidian.mdx`](../../docs/plugins/obsidian.mdx)
