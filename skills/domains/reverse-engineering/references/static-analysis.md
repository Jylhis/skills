# Static analysis

Read the program without running it. Safe for untrusted samples (you still
shouldn't *execute* them — see `malware-safety.md`), and the right first
pass for almost everything.

## 1. Triage (always, before a disassembler)

```
file ./target                 # format, arch, bits, endianness, stripped?
sha256sum ./target            # identity — record it; check VT/known sets
rabin2 -I ./target            # r2's format-aware info (or: readelf -h / otool -hv)
rabin2 -z ./target            # strings in data sections (better than `strings`)
rabin2 -i ./target            # imports — the API surface it uses
rabin2 -S ./target            # sections + sizes + perms
```

Read the signal:

- **Stripped?** No symbols → expect more renaming work.
- **Packed?** High-entropy section, tiny import table, an `UPX!` magic, or
  `file` reporting an odd layout. Unpack first (`upx -d`) or dump from a
  debugger after the unpacker runs.
- **Imports** tell you capability fast: `socket`/`recv` (network),
  `CreateProcess`/`system` (exec), `crypt`/`EVP_` (crypto),
  `RegOpenKey`/`fopen` (persistence/config), `ptrace` (anti-debug).
- **Strings** point you straight at interesting code: error messages,
  format strings, URLs, file paths, command names, embedded keys.

## 2. Find where to look

Don't read top-to-bottom. Pivot from a known anchor to its uses:

- Xref **from an import** to its callers (where does it call `strcmp`,
  `recv`, `system`?).
- Xref **from a string** to the function that references it (the "Access
  denied" string leads to the check).
- Start at **`main`/entry** and follow only the branch you care about.

## 3. radare2 / rizin workflow

`r2` commands are terse and composable; `rizin` (`rz`) mirrors them.

```
r2 -A ./target          # open + run analysis (aaa). Use -AA for deeper.
> aaa                   # (re)analyze: functions, xrefs, strings
> afl                   # list functions
> iz                    # strings in data sections;  izz = whole binary
> ii                    # imports;  is = symbols
> axt @ sym.imp.strcmp  # who calls strcmp (xrefs TO)
> s main                # seek to main
> pdf                   # print disassembly of current function
> pdc                   # pseudo-decompile (or `ghidra` via r2ghidra: pdg)
> VV                    # visual graph (control-flow) mode
> afn newname           # rename current function
> afvn old new          # rename a local variable
> CC this is the check  # add a comment at current address
> q
```

Useful extras: `r2ghidra` plugin adds `pdg` (Ghidra decompiler inside r2);
`rz-ghidra` is the rizin equivalent. `ai`/`afi` give function info; `/`
searches bytes, `/c` searches code.

## 4. Ghidra workflow (GUI + headless)

GUI: import → let auto-analysis run → use the **Decompiler** window
alongside the listing. Rename (`L`), retype, define structs, and add
comments as you understand code; everything persists in the project.

Headless / batch (`analyzeHeadless`) for scripting and CI:

```
$GHIDRA_HOME/support/analyzeHeadless /path/to/proj ProjName \
  -import ./target \
  -postScript MyScript.java \
  -scriptPath ./scripts \
  -deleteProject          # omit to keep the project for the GUI
```

Post-scripts (Java or Python via Ghidrathon/Jython) can dump every
function's decompilation, auto-rename by heuristic, or export findings —
the same operations an MCP server exposes (`mcp-servers.md`).

## 5. objdump / binutils (no project, instant)

```
objdump -d -M intel ./target        # disassembly, Intel syntax
objdump -d --start-address=0x... --stop-address=0x... ./target
objdump -T ./target                 # dynamic symbols
readelf -a ./target                 # full ELF dump (see binary-formats.md)
nm -C ./target                      # symbols, C++ demangled
```

Good for a quick look, diffing two builds, or scripting around `grep`.

## 6. Reading decompiler output critically

Decompilation is a **reconstruction**, not the original source:

- Variable names/types are guesses; fix obvious ones to improve the rest.
- Compiler optimizations (inlining, loop unrolling, vectorization) make
  output diverge from any source that existed.
- A wrong function signature cascades into garbage args — set it right and
  re-decompile.
- When a claim matters, confirm it against the **disassembly** (ground
  truth) or with a **dynamic** check (`dynamic-analysis.md`).

## Practical patterns

- **Diff two versions** to find a patch/change: `radiff2 old new`, or BinDiff
  / Diaphora across Ghidra/IDA databases.
- **Identify library functions** in a stripped static binary: FLIRT (IDA),
  Ghidra's function-ID, or `sigkit` (Binary Ninja) so you don't reverse
  `memcpy` by hand.
- **Recover a struct** by watching field offsets used together, then define
  it once and apply — the decompile becomes readable everywhere.
