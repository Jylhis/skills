# Commands and tools

Read-only verbs (`status`, `cat`, `show`, `is-active`, `list-*`) work
without root. State-changing verbs need root (or polkit). Many verbs accept
a glob: `systemctl restart 'nginx*'`.

## systemctl

**Lifecycle:** `start`, `stop`, `restart`, `reload`,
`reload-or-restart`, `try-restart`, `kill` (send a signal:
`systemctl kill -s SIGHUP UNIT`), `reset-failed` (clear failed state /
start-limit counter).

**Enablement:** `enable`, `disable`, `enable --now`, `disable --now`,
`reenable` (re-apply `[Install]` after edits), `preset` (apply
distro/vendor default enablement), `mask` (symlink to `/dev/null` so it
**cannot** be started, even as a dependency), `unmask`, `link` (pull an
out-of-tree file into the load path), `revert`.

**Inspection:** `status`, `is-active`, `is-enabled`, `is-failed`,
`list-units` (running/loaded), `list-unit-files` (installed +
enablement state: enabled/disabled/static/masked/generated/transient/
indirect/alias), `list-dependencies [--reverse] [--all]`, `list-sockets`,
`list-timers`, `list-jobs`, `cat`, `show [-p PROP] [-P PROP]`,
`help UNIT` (open its `Documentation=` man pages).

**Editing/config:** `edit`, `edit --full`, `daemon-reload` (reparse unit
files), `daemon-reexec` (re-exec PID 1 itself), `set-property UNIT K=V`
(runtime, persisted), `set-default TARGET`, `get-default`.

**System state:** `isolate TARGET` (switch to a target, stopping others),
`rescue`, `emergency`, `default`, `reboot`, `poweroff`, `halt`, `suspend`,
`hibernate`, `hybrid-sleep`, `soft-reboot` (restart user space, keep the
kernel; v254+).

**Key flags:** `--user` (the caller's per-user manager), `--system`
(default), `--global` (defaults for all users' managers), `--now`,
`--runtime` (non-persistent, lost on reboot), `--no-block`, `--wait`,
`--type=service`, `--state=failed`, `--all`, `--failed`,
`-H user@host` / `-M machine` (operate over SSH / on a container).

Fast triage: `systemctl --failed` lists everything in a failed state.

## journalctl

Queries the binary journal. Persistent logs live in `/var/log/journal`;
volatile in `/run/log/journal` (create the former + `systemctl restart
systemd-journald` to make logs survive reboot).

| Flag | Effect |
|---|---|
| `-u UNIT` | filter by unit (repeatable; `.service` optional) |
| `--user-unit UNIT` | filter by a user-manager unit |
| `-b [N]` | current boot, or boot N (`-b -1` = previous); `--list-boots` |
| `-p PRIO` | priority `0`(emerg)…`7`(debug); ranges like `warning..err` |
| `-S` / `--since`, `-U` / `--until` | `"1 hour ago"`, `today`, `yesterday`, ISO timestamps |
| `-f` | follow (tail) |
| `-e` | jump to end |
| `-n N` | last N lines |
| `-r` | reverse (newest first) |
| `-k` | kernel messages only (dmesg) |
| `-x` | append catalog explanations |
| `-t IDENT` | filter by syslog identifier |
| `-o FORMAT` | `short`, `short-iso`, `cat`, `json`, `json-pretty`, `verbose` |
| `-g` / `--grep=` | regex match on MESSAGE (v237+) |
| `-F FIELD` | list all values of a journal field |
| `_COMM=`, `_PID=`, `_UID=`, `_SYSTEMD_UNIT=` | field-match filters |
| `--disk-usage` | journal size on disk |
| `--vacuum-size=`, `--vacuum-time=` | prune old logs |
| `--verify` | check journal integrity |

Example: `journalctl -u nginx -p err -b --since "1 hour ago"`.

## systemd-analyze

Boot performance and offline/online introspection.

- `time` (default): total boot time by phase (firmware/loader/kernel/
  userspace).
- `blame`: units sorted by initialization time (misleading for
  parallel/socket-activated units; cross-check with critical-chain).
- `critical-chain [UNIT]`: the time-critical dependency chain.
- `plot > boot.svg`: a timeline SVG.
- `dot | dot -Tsvg > deps.svg`: dependency graph.
- `dump [PATTERN]`: full manager state serialization (unstable format,
  not for parsing).
- `verify FILE`: lint a unit file (unknown keys/sections, missing deps).
- `security [UNIT]`: per-unit exposure table + 0-10 score (lower safer).
- `cat-config NAME|PATH`: merged config file incl. compile defaults.
- `calendar "SPEC" [--iterations=N]`: validate `OnCalendar=`, show elapses.
- `timestamp "..."`, `timespan "..."`: parse/normalize time strings.
- `syscall-filter [SET]`, `filesystems [SET]`: list the `@`-groups usable
  in `SystemCallFilter=` / `RestrictFileSystems=`.
- `condition '...'`, `exit-status CODE`, `capability`: evaluate
  `Condition*=`, decode exit codes, decode capabilities.
- `unit-files`, `unit-paths`: load-path introspection.
- `--offline=true --root=DIR --image=IMG`: analyze/verify an image or root
  without booting it (great for CI on unit files or `security` scoring).

## Tool inventory (one line each)

| Tool | Role |
|---|---|
| `systemd-cgls` | show the cgroup tree |
| `systemd-cgtop` | live per-cgroup CPU/mem/IO (`-m` to sort by memory) |
| `systemd-run` | run a command as a transient service/scope/timer (`--scope`, `--user`, `--on-calendar=`, `-p Prop=Val`) |
| `systemd-nspawn` | lightweight container manager |
| `machinectl` | control local containers/VMs/images (machined) |
| `networkctl` / `systemd-networkd` | network config and status |
| `resolvectl` / `systemd-resolved` | DNS (stub resolver at 127.0.0.53) |
| `timedatectl` / `systemd-timesyncd` | clock, timezone, SNTP sync |
| `bootctl` / `systemd-boot` | UEFI boot manager (Boot Loader Spec) |
| `hostnamectl`, `localectl` | hostname / locale + keymap |
| `loginctl` | sessions, seats, users, lingering (logind) |
| `busctl` | D-Bus introspection (see self-documentation.md) |
| `coredumpctl` | list/inspect saved core dumps |
| `systemd-tmpfiles` | create/clean volatile & temp files (tmpfiles.d) |
| `systemd-sysusers` | declaratively create system users (sysusers.d) |
| `udevadm` | udev control/query (`info`, `trigger`, `monitor`, `settle`) |
| `systemd-escape` | escape strings into valid unit/instance names |
| `systemd-detect-virt` | report VM/container type (or `none`) |
| `systemd-creds` | encrypt/inspect service credentials |
| `systemd-sysext` | manage system-extension images |
| `portablectl` | attach/detach portable service images |
| `homectl` | manage homed home areas |
| `oomctl` | inspect systemd-oomd state |

## Transient units with systemd-run

Run one-off work under full systemd supervision without writing a file:

```bash
# resource-limited transient service
systemd-run --unit=backup -p MemoryMax=500M -p CPUQuota=50% /usr/local/bin/backup

# ad-hoc timer
systemd-run --on-calendar="*-*-* 02:00:00" --unit=nightly /usr/local/bin/job

# put an already-running shell command in its own scope
systemd-run --scope --user -p MemoryHigh=2G ./heavy-task
```
