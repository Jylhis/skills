# Binary formats: ELF, PE, Mach-O

Knowing the container tells you where code, data, symbols, and imports
live, and how the loader will map and start the program. Read the header
during triage (`static-analysis.md`) before diving into disassembly.

## ELF (Linux, BSD, most Unix; firmware)

Layout: **ELF header → program headers (segments, used by the loader) →
sections (used by the linker/tools) → data**.

- **ELF header**: magic `\x7fELF`, class (32/64), endianness, type
  (`ET_EXEC` static, `ET_DYN` PIE/shared lib, `ET_REL` object), machine
  (arch), entry point.
- **Segments** (program headers): `PT_LOAD` (mapped), `PT_INTERP`
  (dynamic linker path), `PT_DYNAMIC` (dynamic-linking info),
  `PT_GNU_STACK` (NX).
- **Key sections**: `.text` (code), `.rodata` (constants/strings),
  `.data`/`.bss` (writable/zeroed), `.plt`/`.got` (lazy-bound imports),
  `.dynsym`/`.dynstr` (dynamic symbols), `.symtab` (full symbols — gone if
  stripped), `.rela.*` (relocations), `.init_array`/`.fini_array`
  (constructors/destructors run around `main`).
- **Imports** resolve through PLT→GOT; xref `sym.imp.*` to find API use.
- **Hardening to note**: PIE (`ET_DYN`), RELRO (full/partial), NX, stack
  canaries (`__stack_chk_fail`) — `checksec` or `rabin2 -I` reports these.

Tools: `readelf -a`, `readelf -d` (dynamic), `objdump`, `rabin2 -I/-S/-i`,
`patchelf` (edit interpreter/rpath), `nm -C`.

## PE / PE32+ (Windows; also .NET, drivers)

Layout: **DOS stub → PE signature `PE\0\0` → COFF header → Optional header
(+ data directories) → section table → sections**.

- **Optional header**: `AddressOfEntryPoint`, `ImageBase`, subsystem
  (GUI/console/driver), DLL characteristics (ASLR/DEP/CFG flags).
- **Data directories**: **Import** (IAT — the DLLs/functions it calls),
  **Export** (what a DLL provides), Resources (`.rsrc` — icons, version
  info, often embedded payloads), Relocations, TLS (callbacks run *before*
  the entry point — a classic anti-debug/early-exec spot), Debug
  (PDB path/GUID).
- **Sections**: `.text` code, `.rdata` consts/imports, `.data`,
  `.rsrc` resources, `.reloc`. Odd/extra sections or `UPX0/UPX1` ⇒ packed.
- **.NET**: a PE with a COR20 (CLI) header → it's managed IL, not native.
  Decompile with **ILSpy / dnSpy / dotPeek**, not Ghidra.
- **Authenticode** signature: check whether it's signed and valid; malware
  sometimes carries stolen/invalid certs.

Tools: `rabin2`, `pefile` (Python), CFF Explorer / PE-bear, `dumpbin`,
Detect-It-Easy (`die`) for packer/compiler ID, Ghidra/IDA/Binary Ninja.

## Mach-O (macOS, iOS)

Layout: **header → load commands → segments → sections**.

- **Header**: magic (`feedface`/`feedfacf` 32/64, `cafebabe` = **fat/
  universal** = multiple arch slices in one file), CPU type, file type
  (executable, dylib, bundle).
- **Load commands** drive everything: `LC_SEGMENT_64` (map a segment),
  `LC_MAIN` (entry), `LC_LOAD_DYLIB` (linked dylibs), `LC_CODE_SIGNATURE`,
  `LC_ENCRYPTION_INFO` (FairPlay-encrypted — iOS App Store binaries need a
  decrypted dump before static analysis), `LC_RPATH`.
- **Segments/sections**: `__TEXT,__text` (code), `__TEXT,__cstring`
  (strings), `__DATA`/`__DATA_CONST` (`__objc_*` sections hold Objective-C
  class/method metadata — rich symbol info even when "stripped"), `__LINKEDIT`.
- **Objective-C / Swift**: method names survive in metadata; use
  `class-dump` / Ghidra's Obj-C analyzer / Hopper to recover class and
  selector structure. Swift mangled names: `swift-demangle`.
- **Fat binaries**: extract one slice with `lipo -thin arm64 in -output out`.

Tools: `otool -hv/-l/-L`, `nm`, `lipo`, `codesign -dv`, `class-dump`,
`dyld_info`, Hopper, Ghidra, Binary Ninja.

## Cross-format triage cheats

- `file` names the format and arch in one line — start there.
- Entropy ~7.9+ across a whole section ⇒ packed/encrypted/compressed.
- Tiny import table + one big section ⇒ likely packed; unpack before
  reading (`dynamic-analysis.md`).
- Match the decompiler to the format: native → Ghidra/IDA/BN; **.NET →
  dnSpy/ILSpy**; **JVM → CFR/Procyon/Fernflower**; **Obj-C/Swift →
  class-dump + Ghidra**. Using a native disassembler on managed bytecode
  wastes time.
