# Querying systemd for help (self-documentation)

systemd documents itself thoroughly and the running manager is queryable.
This is the most reliable way to answer "what does X do / what is X set to"
because it survives version drift: you read the installed version's truth,
not a memorized (and possibly stale) option list.

## The two master indexes

- **`man systemd.directives`** (`systemd.directives(7)`) is the **reverse
  index**: every configuration directive, kernel command-line option,
  environment variable, journal field, D-Bus method/property, and specifier,
  mapped to the man page that documents it. To learn what a directive does,
  find it here first, then open the referenced page. Examples: `After=` to
  `systemd.unit(5)`, `Accept=` to `systemd.socket(5)`, `AccuracySec=` to
  `systemd.timer(5)`, `AmbientCapabilities=` to `systemd.exec(5)`,
  `AllowedCPUs=` to `systemd.resource-control(5)`.
- **`man systemd.index`** (`systemd.index(7)`) is the master alphabetical
  list of every systemd man page with a one-line description. Use it to
  discover which tool or page exists.

## Per-topic man pages worth knowing

| Page | Covers |
|---|---|
| `systemd.unit(5)` | `[Unit]`/`[Install]`, dependencies, load path, drop-ins, specifiers |
| `systemd.service(5)` | `[Service]` options |
| `systemd.exec(5)` | execution environment + all sandboxing directives; also "Process Exit Codes" |
| `systemd.resource-control(5)` | cgroup/resource directives |
| `systemd.socket/timer/mount/automount/path/target/slice/scope/swap/device(5)` | per-type options |
| `systemd.kill(5)` | `KillMode=`/`KillSignal=` |
| `systemd.special(7)` | the standard targets/units (`default.target`, `sysinit.target`, …) |
| `systemd.syntax(7)` | general config-file syntax |
| `systemd.time(7)` | time and calendar spec |
| `daemon(7)` | writing/packaging daemons (incl. `sd_notify` protocol) |
| `bootup(7)` | the boot process and target ordering |
| `systemctl(1)`, `journalctl(1)`, `systemd-analyze(1)`, `busctl(1)` | tools |
| `org.freedesktop.systemd1(5)`, `org.freedesktop.login1(5)` | D-Bus interfaces |

## Command-line help

- `--help` / `-h` and `--version` on every tool.
- `systemctl help UNIT` opens the man pages listed in the unit's
  `Documentation=` field (which supports `man:` URIs). Passing a PID shows
  the owning unit's docs.
- Shell completion (bash + zsh) completes unit names and even property
  names (via `systemd --dump-bus-properties`).

## Runtime introspection (the live manager)

- **`systemctl cat UNIT`**: the exact on-disk unit file plus every drop-in,
  each preceded by its path. This is what you are *actually* running. First
  stop when a change "isn't taking".
- **`systemctl show [UNIT]`**: dump all properties. These are the
  normalized, low-level forms of the settings plus runtime state (note
  `USec`-suffixed property names vs `Sec`-suffixed config keys, e.g.
  `RestartUSec` for `RestartSec=`). `-p NAME` selects one property; `-P NAME`
  prints just the value. With no unit, shows manager-wide defaults
  (`DefaultTimeoutStartUSec`, `UnitPath`, …).
- **`systemd-analyze cat-config NAME|PATH`**: merged view of a config file
  and its drop-ins including compile-time defaults (e.g. `cat-config
  systemd/journald.conf`).
- **`systemd-analyze verify FILE`**: lint a unit for unknown
  sections/keys, bad references, missing dependencies. Run it in CI on unit
  files.
- **`systemd-analyze dump [PATTERN]`**: full manager state (unstable
  format; for eyeballing, not parsing).
- **`systemctl list-unit-files [PATTERN]`**: every installed unit file with
  its enablement state.
- **`systemctl show -p UnitPath --value`**: the manager's live unit load
  path (more authoritative than `systemd-analyze unit-paths`, which is
  compiled in).

## D-Bus introspection with busctl

The manager's bus name is `org.freedesktop.systemd1` at object
`/org/freedesktop/systemd1`, interface `org.freedesktop.systemd1.Manager`.

```bash
busctl list                                  # peers on the bus
busctl tree org.freedesktop.systemd1         # object tree (--list for flat)
busctl introspect org.freedesktop.systemd1 /org/freedesktop/systemd1
  # methods (StartUnit, StopUnit, GetUnit, GetUnitByPID), properties, signals

busctl get-property org.freedesktop.systemd1 /org/freedesktop/systemd1 \
  org.freedesktop.systemd1.Manager LogLevel

busctl call org.freedesktop.systemd1 /org/freedesktop/systemd1 \
  org.freedesktop.systemd1.Manager StartUnit ss "cups.service" "replace"
```

`busctl get-property ... ActiveState` is roughly
`systemctl show -P ActiveState UNIT`.

## Online docs and mirrors

- Canonical man pages:
  `https://www.freedesktop.org/software/systemd/man/latest/<PAGE>.html`
  (e.g. `systemd.unit.html`, `systemd.directives.html`, `index.html`).
  Versioned paths: `/man/devel/...` (main) and numeric `/man/257/...`.
- Project docs / design specs: `https://systemd.io/` (ARCHITECTURE,
  PORTABLE_SERVICES, CREDENTIALS, Boot Loader Spec, Discoverable Partitions).
- Source + changelog: `https://github.com/systemd/systemd` (`NEWS`,
  `docs/`, `man/`).
- Design essays (Lennart Poettering, 0pointer): "Rethinking PID 1", "The
  Biggest Myths", the "systemd for Administrators" series.
- Mirrors when freedesktop.org bot-blocks automated fetches: `man7.org`,
  `man.archlinux.org`, `manpages.debian.org`, `manpages.ubuntu.com`. The
  Arch Wiki systemd pages are the best practical secondary reference; treat
  the freedesktop.org man page as canonical over any tutorial.
