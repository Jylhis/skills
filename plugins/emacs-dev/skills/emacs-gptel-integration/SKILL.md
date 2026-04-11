---
name: emacs-gptel-integration
description: >
  Configuring gptel with Claude and wiring MCP servers via mcp.el so
  Emacs becomes both an MCP client and an MCP server. Apply when
  setting up LLM-assisted editing, Org-mode chat branches, or
  bidirectional MCP integration inside Emacs.
---

# gptel + Claude + MCP integration

`gptel` (karthink, NonGNU ELPA) is the dominant LLM client for Emacs.
It supports Claude natively, integrates with `mcp.el` for MCP server
access, and uses Org-mode as the default conversation format —
branches, headings, and all of Emacs's usual editing tools apply to
chat transcripts.

This skill covers:

1. Installing and configuring gptel with the Anthropic backend.
2. Wiring `mcp.el` so gptel can call tools exposed by external MCP
   servers.
3. Running `mcp-server-lib.el` / `emacs-mcp-server` so external LLM
   clients can call into Emacs (bidirectional).

## Install

Via `use-package` with a straight.el or built-in `package` source.
`gptel` is on NonGNU ELPA so the built-in package manager works.

```elisp
(use-package gptel
  :ensure t
  :custom
  (gptel-default-mode 'org-mode))
```

For `mcp.el`:

```elisp
(use-package mcp
  :ensure t   ; from MELPA once published, or :vc ...
  :after gptel)
```

## Configure the Anthropic backend

```elisp
(setq gptel-backend
      (gptel-make-anthropic "Claude"
        :stream t
        :key (lambda ()
               (auth-source-pick-first-password
                :host "api.anthropic.com"))))

(setq gptel-model 'claude-sonnet-4-6)
```

- **`:stream t`** enables streaming responses — much better UX than
  waiting for the full completion.
- **`:key` as a function** reads the key lazily from auth-source (or
  any other store), so it isn't baked into your config.
- Store the key in `~/.authinfo.gpg`:
  `machine api.anthropic.com login apikey password sk-ant-...`
- Use symbols for model names (`'claude-sonnet-4-6`), not strings — gptel
  uses `alist` lookups.

## Basic usage

- `M-x gptel` opens a buffer.
- `C-c RET` (`gptel-send`) sends the region (or up to point).
- `C-u C-c RET` opens `gptel-menu` for per-call options (model, system
  prompt, tools).
- In Org mode, responses become new headings — use `C-c C-j` to branch
  a conversation.
- `gptel-mode` is a minor mode that adds keybindings and faces; it can
  be enabled in any buffer (scratch, code, notes).

## MCP client: wiring external servers

`mcp.el` connects gptel to external MCP servers. Tools exposed by
those servers become callable from within gptel sessions.

```elisp
(setq mcp-hub-servers
      '(("filesystem"
         :command "npx" :args ("-y" "@modelcontextprotocol/server-filesystem" "/tmp"))
        ("git"
         :command "uvx" :args ("mcp-server-git"))))

(mcp-hub-start-all)
```

- **`mcp-hub-start-all`** launches every configured server and
  registers their tools with gptel.
- **Per-session tools:** use `C-u C-c RET` → `@` menu to attach or
  detach specific tools for one call.
- **Tool confirmation:** set `gptel-confirm-tool-calls` to `t` for
  auditing; set to `nil` only for read-only tools you trust.

Within jstack, the jstack-registered MCP servers (e.g. `mcp-nixos`,
`gopls`) are already available on PATH via devenv — no extra install
needed to reference them from `mcp-hub-servers`.

## MCP server: exposing Emacs to external clients

Run your Emacs as an MCP server so external clients (Claude Code, CLI
agents, other Emacs instances) can call Emacs commands. Two options:

### `mcp-server-lib.el` + `elisp-dev-mcp`

`mcp-server-lib.el` (laurynas-biveinis, MELPA) is infrastructure for
building MCP servers **in** Elisp. `elisp-dev-mcp` is built on top and
exposes Elisp development tools (buffer read/write, eval, docs):

```elisp
(use-package elisp-dev-mcp
  :ensure t
  :config
  (elisp-dev-mcp-start))
```

### `emacs-mcp-server` (standalone)

`emacs-mcp-server` (rhblind) is a standalone server that talks to a
running Emacs daemon over Unix domain sockets and exposes buffer
operations, Elisp eval, and diagnostics. Use this when you want
external clients (Claude Code itself) to call into a persistent Emacs
daemon:

```bash
emacs --daemon
emacs-mcp-server --socket ~/.emacs.d/server/server
```

Then wire it into your MCP client's config (`~/.claude.json` or
equivalent) as an external MCP server.

## Common settings

```elisp
(setq gptel-default-mode 'org-mode
      gptel-org-branching-context t     ; branches share earlier context
      gptel-track-media t               ; include images in requests
      gptel-log-level 'info)            ; 'debug for troubleshooting
```

- **`gptel-org-branching-context t`** — when you branch a conversation
  with `C-c C-j`, both branches inherit everything above the branch
  point.
- **`gptel-log-level 'info`** logs to the `*gptel-log*` buffer. Use
  `'debug` when troubleshooting backend or MCP issues.

## Debugging

- **Backend errors:** check `*gptel-log*`.
- **MCP server errors:** each MCP server writes to its own buffer via
  `mcp-hub`; inspect with `M-x mcp-hub-list`.
- **Auth failures:** `gptel-backend` evaluates the `:key` function on
  every call — step through with `M-x toggle-debug-on-error` and send
  a test message.

## Anti-patterns

- Hardcoding the API key in `init.el` — use auth-source.
- Running `mcp-hub-start-all` without reviewing `mcp-hub-servers`
  first — each entry spawns a process.
- Mixing `gptel-make-anthropic` with `gptel-make-openai` on the same
  backend value — configure both but keep them as separate backends.
- Using `string` model names — gptel uses symbols.
- Running `emacs-mcp-server` without a daemon — it's designed to
  bridge into a persistent Emacs.

## Tool detection

```bash
for tool in emacs npx uvx; do
  command -v "$tool" >/dev/null && echo "ok: $tool" || echo "MISSING: $tool"
done
```

## References

- gptel: https://github.com/karthink/gptel
- mcp.el: https://github.com/lizqwerscott/mcp.el (and similar)
- mcp-server-lib.el: https://github.com/laurynas-biveinis/mcp-server-lib.el
- elisp-dev-mcp: https://github.com/laurynas-biveinis/elisp-dev-mcp
- emacs-mcp-server (rhblind): https://github.com/rhblind/emacs-mcp-server
- Anthropic auth-source setup: https://www.gnu.org/software/emacs/manual/html_node/auth/index.html
