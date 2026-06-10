# Dynamic analysis

Run the program (or part of it) and observe. Reveals what static analysis
can't cheaply prove: decrypted strings, runtime config, packed code after
it unpacks, actual control flow through opaque predicates, real syscall
behavior.

**Only run code you are authorized to run, in isolation.** Untrusted
samples go in a disposable VM/sandbox with no network or a controlled
fake-net — see `malware-safety.md`. Dynamic analysis *executes* the
target; treat it as detonation.

## Tracing (cheapest dynamic signal)

```
ltrace ./target              # library calls + args (Linux)
strace ./target              # syscalls + args; -f follows children, -e trace=
ltrace -e 'strcmp+strncmp' ./target
strace -f -e trace=network,file ./target
```

macOS: `dtruss` / `dtrace` (needs SIP considerations). Windows: API Monitor,
Procmon. Tracing often answers "what file/registry key/host does it touch?"
without opening a debugger.

## gdb + pwndbg / gef

Plain gdb is serviceable; **pwndbg** or **gef** add register/stack/heap
views, `telescope`, and exploit-dev helpers. Install one and it loads via
`~/.gdbinit`.

```
gdb ./target
> starti                 # stop at the very first instruction (before libc init)
> break main             # or:  break *0x401234   (absolute address)
> run arg1 arg2
> info functions         # symbols;  info registers
> x/16xw $rsp            # examine 16 words of hex at rsp
> x/s $rdi               # the string in rdi (1st SysV arg)
> disassemble            # current function
> stepi / nexti          # single-step instruction
> finish                 # run to return of current frame
> set $rax = 1           # patch a register (force a check to pass)
> p $eax                 # read a value
> watch *0x404060        # break when a memory location changes
> continue
```

Calling convention reminders (x86-64 System V): args in
`rdi, rsi, rdx, rcx, r8, r9`; return in `rax`. Windows x64: `rcx, rdx, r8,
r9`. Knowing this lets you read args at a breakpoint without the source.

Patching to bypass a check: at the comparison, either flip the register
(`set $rax=...`), jump over the branch (`set $rip=...`), or write the bytes
(`set {char}0x401234 = 0x90` to NOP). For a permanent patch, edit the file
with r2 (`r2 -w`, `wa nop`) or Ghidra's byte patcher.

## Frida — instrument a live process

Frida injects a JS agent to hook functions in a running app — no recompile,
no source. Excellent for mobile (Android/iOS), packed desktop apps, and
confirming a static hypothesis.

```js
// hook a native export: log args and tamper the return
const f = Module.getExportByName(null, 'check_license');
Interceptor.attach(f, {
  onEnter(args) { this.key = args[0].readUtf8String(); console.log('key=', this.key); },
  onLeave(retval) { console.log('ret=', retval); retval.replace(1); } // force success
});
```

```
frida-trace -i 'recv*' -p <pid>      # auto-generate + run hooks for matching fns
frida -U -f com.app.id -l hook.js     # spawn an Android app with your script
```

Frida needs `frida-server` on the target (USB device `-U`, or local). Driven
by an agent, this is what `frida-mcp` exposes (`mcp-servers.md`).

## Dumping unpacked / decrypted code

For packed binaries: set a breakpoint after the unpacker stub finishes
(often right before the jump to the real entry / OEP), then dump the now-
plaintext memory region (gdb `dump memory out.bin $start $end`, or Frida
`Memory.readByteArray`). Reconstruct a runnable file or just feed the dump
to the static tools.

## Anti-debugging — expect resistance

Samples detect debuggers and change behavior or bail:

- **`ptrace(PTRACE_TRACEME)`** self-attach (Linux) — a debugger can't attach
  if the process already traces itself; patch the call or use a gdb that
  intercepts it.
- **Timing checks** (rdtsc deltas) — single-stepping is slow; they notice.
- **`IsDebuggerPresent` / PEB BeingDebugged / NtQueryInformationProcess**
  (Windows).
- **`/proc/self/status` TracerPid**, breakpoint-byte (`0xCC`) scans,
  exception-based tricks.

Counters: patch the check to always return "no debugger," hook the API to
lie (Frida/gdb), or use anti-anti-debug plugins. When dynamic gets too
costly, fall back to static (`static-analysis.md`).

## When to use dynamic vs static

- **Static first** for untrusted code, overall structure, and anything you
  can read directly.
- **Go dynamic** when: strings/config are decrypted at runtime, the binary
  is packed/obfuscated, control flow is data-dependent, you need real
  network/file behavior, or you want to *confirm* a static hypothesis fast.
- Best results come from **bouncing between them**: map statically, verify a
  hot path dynamically, feed runtime-revealed addresses back into the
  disassembler.
