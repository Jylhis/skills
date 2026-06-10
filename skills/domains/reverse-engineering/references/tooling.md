# Tooling & selection

Reach for the cheapest tool that answers the question. Triage utilities
before a disassembler; a disassembler before a debugger; a debugger before
a custom harness.

## Selection matrix

| Tool | Cost | Mode | Best for | Weak at |
|---|---|---|---|---|
| **Ghidra** | Free (NSA) | Static | Decompilation (excellent free decompiler), large binaries, scripting (Java/Python), headless batch | No built-in debugger UX as polished as paid tools |
| **radare2 / rizin** | Free (OSS) | Static + dyn | Fast triage, scripting, CLI-native workflows, exotic formats, CTF | Steep, terse learning curve |
| **Cutter** | Free (OSS) | Static + dyn | GUI over rizin; ships a decompiler (rz-ghidra) | Heavier than bare `r2` |
| **Binary Ninja** | Paid (cheap) | Static + dyn | Clean UI, excellent API/ILs (BNIL), automation | Costs money; smaller arch set than IDA |
| **IDA Pro** | Paid (expensive) | Static + dyn | Industry gold standard, broadest CPU/format support, Hex-Rays decompiler | Price; Free edition is limited |
| **objdump / readelf / nm** | Free (binutils) | Static | Quick disassembly, symbol/section dumps, no project setup | No interactivity, no analysis |
| **Capstone / Keystone** | Free (libs) | Lib | Disassembly/assembly inside your own scripts | You build the workflow |
| **binwalk** | Free | Static | Firmware: find/extract embedded filesystems, compression, signatures | Not a code analyzer |
| **gdb (+pwndbg/gef)** | Free | Dynamic | Source/binary debugging on Linux, exploit dev | Linux-centric |
| **Frida** | Free | Dynamic | Hooking live processes (Android/iOS/desktop), tracing, runtime patching | Requires running the target |

## How to choose

- **No budget, want a decompiler →** Ghidra. It is the default free choice
  and the backend most AI-RE workflows lean on.
- **Live in the terminal / script everything / CTF →** radare2 or rizin
  (rizin = the community fork with a cleaner API; Cutter is its GUI).
- **Want a polished commercial tool, modest budget →** Binary Ninja; its
  API and intermediate languages (BNIL) make automation pleasant.
- **Top-tier, broadest target support, money no object →** IDA Pro.
- **Just need a disassembly dump or section/symbol list →** `objdump -d`,
  `readelf -a`, `nm` — no project, instant.
- **Firmware blob / router image →** `binwalk` first to carve it, then a
  disassembler on the extracted code.
- **Behavior at runtime, anti-static-analysis, packed code →** dynamic:
  gdb or Frida (`dynamic-analysis.md`).

## Companion utilities (almost always installed first)

- `file` — identify format/arch at a glance.
- `strings` (or `rabin2 -z`) — embedded text: URLs, paths, format strings,
  keys, version banners.
- `xxd` / `hexdump` — raw bytes, headers, entropy spotting by eye.
- `rabin2` (ships with r2) — format-aware: imports (`-i`), exports,
  sections (`-S`), strings (`-z`), info (`-I`), checksums.
- `nm`, `c++filt` — symbols and C++ demangling.
- `ldd` / `otool -L` — shared-library dependencies (Linux / macOS).
- `upx -d` — unpack UPX-packed binaries (common first obstacle).
- `yara` — match known-malware/family signatures during triage.

## Reproducible installs

Per repo convention, runtime deps come from Nix, not a global install.
Ad-hoc shells for one-off use:

```
nix shell nixpkgs#radare2 nixpkgs#ghidra nixpkgs#binwalk -c r2 ./target
nix shell nixpkgs#gdb -c gdb ./target
```

Rizin/Cutter, Frida, and yara are likewise in nixpkgs
(`rizin`, `cutter`, `frida-tools`, `yara`).
