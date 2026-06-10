---
name: reverse-engineering
description: Use for binary reverse engineering and program analysis — triage of unknown executables, disassembly and decompilation, recovering symbols / control flow / cross-references, ELF / PE / Mach-O internals, dynamic analysis (gdb, pwndbg, Frida, ltrace/strace), firmware extraction (binwalk), CTF crackmes, and malware analysis. Covers AI-assisted RE via MCP servers (GhidraMCP, radare2-mcp, frida-mcp, CutterMCP) plus the underlying CLI tools (radare2 / rizin, Ghidra headless, objdump, gdb). Read the matching reference before touching a binary, and confirm authorization first.
---

# Reverse-engineering skill index

Reverse engineering means recovering the structure and behavior of a
program from its compiled form. Pick the topic for the task and read its
reference before acting.

| Topic | When to read | Reference |
|---|---|---|
| MCP-assisted RE | Drive Ghidra / radare2 / Frida from Claude Code; wire MCP servers; agent-driven triage→decompile→rename loop | `references/mcp-servers.md` |
| Tooling & selection | Choose between Ghidra, radare2 / rizin, Cutter, Binary Ninja, IDA, objdump, binwalk; free vs paid, static vs dynamic | `references/tooling.md` |
| Static analysis | First-look triage, disassembly, decompilation, xrefs, control flow; radare2 and Ghidra-headless cheatsheets | `references/static-analysis.md` |
| Dynamic analysis | Run under gdb + pwndbg/gef, Frida hooking, ltrace/strace, breakpoints, patching, anti-debug | `references/dynamic-analysis.md` |
| Binary formats | ELF / PE / Mach-O headers, sections/segments, symbols, relocations, imports — what to read and with which tool | `references/binary-formats.md` |
| Malware & safety | Isolating untrusted samples, defanging, sandbox/VM hygiene, OPSEC, and the authorization gate | `references/malware-safety.md` |

## Authorization gate — read first

**Before analyzing any binary, confirm you are authorized to.** Reverse
engineering can violate software license terms (EULA anti-RE clauses),
the DMCA / equivalent anti-circumvention law, and computer-misuse
statutes. Proceed only for:

- Binaries **you own or wrote**, or your own firmware/devices.
- An **authorized engagement** (pentest scope, bug bounty in-scope target,
  signed RE/research agreement) — get it in writing.
- **CTF / crackme / training** binaries explicitly published for it.
- **Malware analysis** for defense, in an isolated lab you control.
- Interoperability/security research where local law grants an exemption.

If the provenance or authorization is unclear, ask the user before
running tools on the sample. Do not help defeat licensing/DRM or build
offensive capability without a clear authorized-defense or
research/CTF context. See `references/malware-safety.md`.

## Common workflow (applies across topics)

1. **Triage before depth.** `file`, `strings`, hashes, entropy, and the
   format header (`references/binary-formats.md`) before opening a
   disassembler. Cheap signals first.
2. **Static before dynamic.** Read the code before running it — especially
   for untrusted samples, which must only run isolated
   (`references/malware-safety.md`).
3. **Annotate as you go.** Rename functions/variables and add comments in
   the tool's database so progress accumulates; with MCP this is the
   agent's main job (`references/mcp-servers.md`).
4. **Cross-check tools.** A radare2 disassembly + a Ghidra decompile of the
   same function catch each other's mistakes; decompiler output is a lossy
   reconstruction, not ground truth.

After reading the reference, follow its guidance for the task.
