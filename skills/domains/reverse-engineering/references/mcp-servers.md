# AI-assisted RE via MCP servers

The modern RE workflow lets an agent drive a disassembler/debugger
directly. An MCP server wraps a tool (Ghidra, radare2, Frida) and exposes
its operations as tools the model can call: list functions, decompile,
read disassembly, rename symbols, set comments, run a debugger, hook a
function. The agent does the tedious loop — triage → decompile → rename →
re-read with better names → repeat — and you steer.

This is additive to the CLI skills, not a replacement. When no MCP server
is wired up, fall back to the raw tools in `static-analysis.md` and
`dynamic-analysis.md` (you can still run `r2`, `gdb`, `objdump` through
Bash).

## The server landscape

| Server | Backend | Strength | Repo |
|---|---|---|---|
| **GhidraMCP** | Ghidra | Best free decompiler; richest tool surface (100–200+ tools, symbol/xref/type editing). Most-starred. | `LaurieWired/GhidraMCP`, also `cyberkaida/reverse-engineering-assistant` (ReVa) |
| **radare2-mcp** | radare2 | Fast, scriptable, terminal-native; great for rapid triage of many files. | `radareorg/radare2-mcp` (`r2mcp`) |
| **CutterMCP** | Cutter / rizin | Rizin core with a modern GUI you can watch. | `crowdere`-listed; Cutter plugin |
| **frida-mcp** | Frida | **Dynamic** instrumentation — hook live processes, trace calls, dump memory on Android/iOS/desktop. | search `frida-mcp` |

A curated list lives at `crowdere/Awesome-RE-MCP`. Pick the backend by the
job: **GhidraMCP** for deep static decompilation, **radare2-mcp** for fast
CLI-style triage and scripting, **frida-mcp** for runtime behavior. They
compose — static-map a binary in Ghidra, then confirm a hypothesis live
with Frida.

## Wiring a server into Claude Code

MCP servers are configured per-project in `.mcp.json` (or globally via
`claude mcp add`). Most RE servers run a local process that talks to a
running tool instance.

**GhidraMCP** — typically a Ghidra extension (the bridge plugin) plus a
small Python/stdio MCP server:

1. Install the GhidraMCP extension into Ghidra and enable it; it serves a
   local HTTP endpoint (default `http://127.0.0.1:8080/`).
2. Open the target program in Ghidra and let auto-analysis finish.
3. Register the bridge MCP server with Claude Code, e.g.:

   ```
   claude mcp add ghidra -- uvx ghidra-mcp --ghidra-url http://127.0.0.1:8080/
   ```

   or the equivalent `.mcp.json` entry:

   ```json
   {
     "mcpServers": {
       "ghidra": {
         "command": "uvx",
         "args": ["ghidra-mcp", "--ghidra-url", "http://127.0.0.1:8080/"]
       }
     }
   }
   ```

   (Exact package/command depends on the implementation you chose —
   follow that repo's README; the shape is the same.)

**radare2-mcp** — runs `r2mcp` over stdio and opens the binary itself:

```
claude mcp add r2 -- r2mcp
```

```json
{ "mcpServers": { "r2": { "command": "r2mcp", "args": [] } } }
```

**frida-mcp** — needs the `frida-server` running on the target (device or
local) and the MCP server pointed at it; register similarly. Dynamic
hooking runs untrusted code — only against samples you are authorized to
run, in isolation (`malware-safety.md`).

After adding a server, confirm Claude Code lists its tools (`/mcp` or the
session tool list) before driving it.

## The agent loop

A productive MCP RE session, whether you run it or delegate to a subagent:

1. **Orient.** List functions, imports, strings, entry point. Ask the
   server for the binary's metadata (arch, format) — cross-check against
   `binary-formats.md`.
2. **Find the interesting code.** Xref from imports (`recv`, `strcmp`,
   crypto, `system`) or from suspicious strings to their callers. Start
   where untrusted data enters.
3. **Decompile + read.** Pull the decompilation of a target function;
   read it as a lossy reconstruction, not source.
4. **Rename & comment.** Write back meaningful names for functions, args,
   locals, and add comments. This is the highest-value agent action — it
   makes the *next* decompile readable and compounds. Use
   convention-consistent names.
5. **Recover types.** Define structs/enums and apply them so field
   accesses become named; re-decompile to confirm.
6. **Iterate outward.** Re-read callers with the improved names; repeat
   until the behavior of interest is explained.
7. **Confirm dynamically (optional).** Hand a hypothesis to Frida/gdb —
   hook the function, log args/returns, verify (`dynamic-analysis.md`).

Keep the agent **grounded**: have it quote the exact disassembly/decompile
lines behind each claim, and verify a renamed function's behavior before
trusting the name. Decompilers hallucinate-adjacent artifacts (bad
signatures, phantom variables); the agent will faithfully reason over
wrong output if you let it. Cross-check anything load-bearing with a
second view or a dynamic check.

## When NOT to use MCP

- A one-function crackme — raw `r2` or a single Ghidra decompile is faster
  than wiring a server.
- Air-gapped malware work where you don't want the model issuing live
  debugger commands against the sample — do static-only, manually.
- When you need a capability the server doesn't expose — drop to the CLI.
