# Security and sandboxing

systemd hardening is declarative: dozens of directives in `systemd.exec(5)`
apply namespacing, filesystem restrictions, capability dropping, and syscall
filtering per service, with no code changes. `systemd-analyze security UNIT`
scores the result 0-10 (lower is safer) and shows which directive would
close each gap.

## Workflow: harden incrementally

1. Baseline: `systemd-analyze security UNIT`.
2. Add hardening via a drop-in: `systemctl edit UNIT` (never edit the vendor
   file). Start with the high-value set below.
3. `systemctl daemon-reload && systemctl restart UNIT`.
4. Watch for breakage: `journalctl -u UNIT -b` (denied paths show as
   permission errors; blocked syscalls often show as `SIGSYS`/`EPERM`).
5. Re-widen the minimum needed (`ReadWritePaths=`, add a syscall group).
6. Re-score. **Stop when the score is acceptable for the role** rather than
   chasing 0.0; over-restriction causes silent breakage.

## High-value set (good default for a network daemon)

```ini
[Service]
# Filesystem
ProtectSystem=strict            # whole FS read-only except a few dirs
ProtectHome=yes                 # /home,/root,/run/user invisible
PrivateTmp=yes                  # private /tmp and /var/tmp
StateDirectory=myapp            # the writable dir it actually needs
ProtectProc=invisible
ProcSubset=pid

# Kernel / devices
PrivateDevices=yes
ProtectKernelTunables=yes
ProtectKernelModules=yes
ProtectKernelLogs=yes
ProtectControlGroups=yes
ProtectClock=yes
ProtectHostname=yes

# Privileges
NoNewPrivileges=yes
CapabilityBoundingSet=CAP_NET_BIND_SERVICE   # or empty: CapabilityBoundingSet=
AmbientCapabilities=CAP_NET_BIND_SERVICE
RestrictSUIDSGID=yes
LockPersonality=yes
MemoryDenyWriteExecute=yes

# Namespaces / network
PrivateUsers=yes
RestrictNamespaces=yes
RestrictAddressFamilies=AF_UNIX AF_INET AF_INET6
RestrictRealtime=yes

# Syscalls
SystemCallFilter=@system-service
SystemCallFilter=~@privileged @resources
SystemCallArchitectures=native
SystemCallErrorNumber=EPERM
```

## Directive groups

**Filesystem:** `ProtectSystem=` (`yes` = `/usr`+`/boot` read-only, `full`
adds `/etc`, `strict` = whole FS read-only), `ProtectHome=`
(`yes`/`read-only`/`tmpfs`), `PrivateTmp=`, `ReadOnlyPaths=`,
`ReadWritePaths=`, `InaccessiblePaths=`, `TemporaryFileSystem=`,
`BindPaths=`/`BindReadOnlyPaths=`, `ProtectProc=`/`ProcSubset=`.

**Kernel/devices:** `PrivateDevices=`, `DeviceAllow=`/`DevicePolicy=`,
`ProtectKernelTunables=`, `ProtectKernelModules=`, `ProtectKernelLogs=`,
`ProtectControlGroups=`, `ProtectClock=`, `ProtectHostname=`.

**Privileges:** `NoNewPrivileges=`, `CapabilityBoundingSet=`,
`AmbientCapabilities=`, `SecureBits=`, `User=`/`Group=`,
`SupplementaryGroups=`, `RestrictSUIDSGID=`, `LockPersonality=`,
`MemoryDenyWriteExecute=`, `RemoveIPC=`.

**Namespaces/network:** `PrivateNetwork=`, `PrivateUsers=`, `PrivateIPC=`,
`PrivateMounts=`, `RestrictNamespaces=`,
`RestrictAddressFamilies=` (`AF_UNIX AF_INET AF_INET6`),
`IPAddressAllow=`/`IPAddressDeny=` (BPF-based L3 filter),
`RestrictNetworkInterfaces=`, `SocketBindAllow=`/`SocketBindDeny=`.

**System calls:** `SystemCallFilter=` (predefined `@`-groups like
`@system-service`, `@privileged`, `@resources`, `@keyring`; `~` negates a
group, so `~@privileged` blocks it), `SystemCallArchitectures=native`,
`SystemCallErrorNumber=` (return this errno instead of killing),
`RestrictRealtime=`, `RestrictFileSystems=` (v250+; e.g. allow only `ext4`).

List available groups with `systemd-analyze syscall-filter` and
`systemd-analyze filesystems`.

## DynamicUser

`DynamicUser=yes` allocates a transient UID/GID for the service lifetime and
**implies** `ProtectSystem=strict`, `PrivateTmp=yes`,
`ProtectHome=read-only`, and `RemoveIPC=yes`. Because there is no persistent
home, any writable state must go through `StateDirectory=`/`RuntimeDirectory=`
etc. (which are chowned to the dynamic UID automatically). Ideal for
stateless daemons; avoid when the service must own files across reboots at a
fixed path outside the managed dirs.

## Caveats

- **Do not set `NoNewPrivileges=yes` on units that need a setuid helper**
  (ping, sudo, mount); it neutralizes the privilege gain and breaks them.
- Hardening options are version-gated ("Added in version N"). On older
  systemd some directives are silently ignored; confirm with the host's
  `man systemd.exec` and `systemd-analyze security` output.
- `RestrictAddressFamilies=` must include `AF_UNIX` if the service talks to
  the journal, D-Bus, or any local socket; omitting it is a common
  self-inflicted breakage.
- `MemoryDenyWriteExecute=yes` breaks JITs (Java, V8, LuaJIT, some Python
  extensions). Leave it off for runtimes that generate executable pages.
