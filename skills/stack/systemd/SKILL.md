---
name: systemd
description: |
  Use for systemd, the Linux init system and service manager (PID 1) and
  its tooling. Covers writing and debugging unit files (.service, .socket,
  .timer, .target, .mount, .path, .slice, .scope), systemctl / journalctl /
  systemd-analyze, drop-in overrides and precedence, service dependencies
  and ordering, socket activation, timers as a cron replacement, security
  sandboxing (Protect*/Private*/Restrict*, DynamicUser, SystemCallFilter),
  cgroup v2 resource control (MemoryMax, CPUQuota, slices), user services,
  journald/logind/networkd/resolved, credentials, and boot performance.
  Trigger on "systemd", "systemctl", "journalctl", "unit file", "daemon
  won't start", "enable a service", "systemd timer", "harden a service",
  "limit CPU/memory of a process", "socket activation", or debugging a
  failed/looping Linux service. Read the matching reference before editing
  units or advising changes.
license: MIT
---

# systemd

systemd is the service manager running as PID 1 on nearly every mainstream
Linux distribution. It boots and supervises the system from declarative
**unit** files, tracks processes with cgroup v2, and ships a large tool
suite (systemctl, journalctl, systemd-analyze, and more).

## The core reflex: query the installed system, don't guess

systemd's self-documentation is its strongest feature and the safest
source of truth. Directive availability, defaults, and behavior drift
across versions (roughly one major release every 6 months), so **confirm
against the running system rather than memory**:

- **What does directive X do?** `man systemd.directives` is a reverse
  index mapping every directive to its man page. Look up the directive,
  then open the referenced page (e.g. `RestartSec=` to `systemd.service(5)`).
- **What tools/pages exist?** `man systemd.index` lists every systemd man
  page with a one-line description.
- **What is the effective config right now?** `systemctl cat UNIT` (on-disk
  file + all drop-ins), `systemctl show UNIT` (normalized runtime
  properties + state), `systemd-analyze cat-config NAME` (merged config
  files with compile-time defaults).
- **Which version am I on?** `systemctl --version`. Man pages tag features
  with "Added in version N"; match the host before recommending anything
  version-gated (run0 v256, soft-reboot v254, SysV-script removal v260).
- **Is systemd even present?** `systemctl --version` or `pidof systemd`.
  A few distros (Devuan, Alpine default, containers) do not use it.

See `references/self-documentation.md` for the full introspection toolkit,
including `busctl` D-Bus queries and `systemd-analyze verify/security`.

## Router: read the reference before acting

| Task | Reference |
|---|---|
| Write/understand a unit file: types, `[Unit]`/`[Install]`/`[Service]`/`[Socket]` directives, dependencies (`Requires=`/`Wants=`/`After=`), templates `foo@.service`, specifiers, file locations, precedence, drop-ins | `references/units.md` |
| Drive units and read logs: `systemctl` verbs, `journalctl` filtering, `systemd-analyze`, the full tool inventory | `references/commands.md` |
| Schedule work: `.timer` units, `OnCalendar=`/`OnBootSec=`, `Persistent=`, cron replacement, user timers | `references/timers.md` |
| Harden a service: `ProtectSystem=`, `PrivateTmp=`, `NoNewPrivileges=`, `DynamicUser=`, `SystemCallFilter=`, `RestrictAddressFamilies=`, scoring with `systemd-analyze security` | `references/security.md` |
| Limit resources: cgroup v2, `MemoryMax=`/`MemoryHigh=`, `CPUQuota=`/`CPUWeight=`, `IOWeight=`, `TasksMax=`, slices | `references/resource-control.md` |
| Query systemd for help / introspect the live manager: `man systemd.directives`, `systemctl show/cat`, `systemd-analyze verify`, `busctl` | `references/self-documentation.md` |
| Subsystems: journald, logind, networkd/resolved/timesyncd, udev, credentials, sysext, portable services, homed, oomd, coredump | `references/subsystems.md` |

## Non-negotiable rules

1. **Always `systemctl daemon-reload` after editing any unit file** (or the
   manager keeps the stale copy). `systemctl edit` reloads for you.
2. **Prefer drop-ins over editing vendor files.** `systemctl edit UNIT`
   creates `/etc/systemd/system/UNIT.d/override.conf`; a package update then
   cannot clobber your change. `systemctl edit --full` forks the whole file;
   `systemctl revert UNIT` undoes overrides.
3. **`enable` != `start`.** `enable` sets boot-time autostart via the
   `[Install]` section; `start` runs it now. Use `enable --now` for both.
   `WantedBy=`/`RequiredBy=` only take effect after `enable`.
4. **Ordering and requirement are orthogonal.** `Requires=` pulls a unit in
   but does not order it; add `After=` for ordering. This pair is the single
   most common real-world mistake.
5. **Validate before shipping.** `systemd-analyze verify ./unit.service`
   lints for unknown keys/sections and missing deps. For timers,
   `systemd-analyze calendar "SPEC"` confirms the next elapse.
6. **Precedence: `/etc` > `/run` > `/usr/lib`.** Admin overrides beat
   runtime beat vendor. `systemd-delta` shows what is overridden.

## Troubleshooting loop

1. `systemctl status UNIT`: active/failed state, recent log tail, PID, cgroup.
2. `journalctl -u UNIT -b`: this-boot logs; add `-e` (jump to end), `-f`
   (follow), `-p err` (errors only), `--since "10 min ago"`.
3. `systemctl cat UNIT`: see the effective file + drop-ins you are actually
   running. `systemctl show UNIT -p PROP` for one normalized property.
4. Fix the file, `systemctl daemon-reload`, `systemctl restart UNIT`.
5. Recurring restarts: check `Restart=`, `RestartSec=`, and
   `StartLimitIntervalSec=`/`StartLimitBurst=` (a unit that trips the start
   limit stays down until `systemctl reset-failed UNIT`).

## Gotchas

- `Type=simple` (the default when `ExecStart=` is set) considers the service
  "started" the instant it forks, before the program is ready. Use
  `Type=notify` (with `sd_notify()`) or `Type=exec`/`Type=forking` +
  readiness for correct ordering. Avoid `Type=forking` for new services.
- `Type=oneshot` needs `RemainAfterExit=yes` to show as active after the
  command exits (common for setup/config units).
- A leading `-` on an `ExecStart=` line ignores its failure
  (`ExecStartPre=-/bin/rm ...`). Only `oneshot` allows multiple `ExecStart=`.
- `DynamicUser=yes` implies `ProtectSystem=strict`, `PrivateTmp=yes`,
  `ProtectHome=read-only`, and `RemoveIPC=`, so state must live under
  `StateDirectory=`/`/var/lib/<name>`, not an arbitrary path.
- `systemd-tmpfiles --purge` is dangerous (historically could delete `/home`
  before the v256.1 fix). Treat destructive maintenance commands with care.
- Do not blanket-set `NoNewPrivileges=yes` on a unit that relies on a setuid
  helper (e.g. `ping`, `sudo`); it breaks the privilege gain.
