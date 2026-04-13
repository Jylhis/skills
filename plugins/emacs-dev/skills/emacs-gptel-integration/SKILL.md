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
access, and uses Org-mode as the default conversation format.

## Install

```elisp
(use-package gptel
  :ensure t
  :custom
  (gptel-default-mode 'org-mode))

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

- **`:stream t`** enables streaming responses.
- **`:key` as a function** reads the key lazily from auth-source.
- Store the key in `~/.authinfo.gpg`:
  `machine api.anthropic.com login apikey password sk-ant-...`
- Use symbols for model names, not strings.

## Basic usage

- `M-x gptel` opens a buffer.
- `C-c RET` (`gptel-send`) sends the region (or up to point).
- `C-u C-c RET` opens `gptel-menu` for per-call options.
- In Org mode, responses become new headings — use `C-c C-j` to branch.
- `gptel-mode` can be enabled in any buffer.

## MCP client: wiring external servers

```elisp
(setq mcp-hub-servers
      '(("filesystem"
         :command "npx" :args ("-y" "@modelcontextprotocol/server-filesystem" "/tmp"))
        ("git"
         :command "uvx" :args ("mcp-server-git"))))

(mcp-hub-start-all)
```

- **Per-session tools:** `C-u C-c RET` -> `@` menu to attach/detach tools.
- **Tool confirmation:** set `gptel-confirm-tool-calls` to `t` for
  auditing; `nil` only for trusted read-only tools.

## MCP server: exposing Emacs to external clients

### `mcp-server-lib.el` + `elisp-dev-mcp`

```elisp
(use-package elisp-dev-mcp
  :ensure t
  :config
  (elisp-dev-mcp-start))
```

### `emacs-mcp-server` (standalone)

Talks to a running Emacs daemon over Unix domain sockets:

```bash
emacs --daemon
emacs-mcp-server --socket ~/.emacs.d/server/server
```

Wire into your MCP client's config as an external server.

## Common settings

```elisp
(setq gptel-default-mode 'org-mode
      gptel-org-branching-context t     ; branches share earlier context
      gptel-track-media t               ; include images in requests
      gptel-log-level 'info)            ; 'debug for troubleshooting
```

## Debugging

- **Backend errors:** check `*gptel-log*`.
- **MCP server errors:** inspect with `M-x mcp-hub-list`.
- **Auth failures:** `M-x toggle-debug-on-error` and send a test
  message.

## Anti-patterns

- Hardcoding the API key in `init.el` — use auth-source.
- Running `mcp-hub-start-all` without reviewing `mcp-hub-servers`.
- Using string model names — gptel uses symbols.
- Running `emacs-mcp-server` without a daemon.

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
