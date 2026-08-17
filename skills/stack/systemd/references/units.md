# Unit files: types, structure, dependencies, precedence

Everything systemd manages is a **unit**. Unit files are INI-style with
typed sections. Execution-environment options (`systemd.exec(5)`),
resource-control options (`systemd.resource-control(5)`), and kill options
(`systemd.kill(5)`) are shared by every unit type that spawns processes.

## The 11 unit types

| Suffix | Purpose |
|---|---|
| `.service` | A process/daemon. The workhorse type. |
| `.socket` | IPC/network socket or FIFO for socket activation; paired with a `.service`. |
| `.target` | Grouping/synchronization point (like SysV runlevels): `multi-user.target`, `graphical.target`. |
| `.device` | A kernel device exposed by udev. |
| `.mount` | A filesystem mount point (from a unit or generated from `/etc/fstab`). |
| `.automount` | On-demand mount point. |
| `.swap` | A swap device or file. |
| `.path` | Path-based activation via inotify (start a service when a file/dir changes). |
| `.timer` | Time/calendar-based activation (cron replacement). See `timers.md`. |
| `.slice` | A cgroup node for hierarchical resource management. See `resource-control.md`. |
| `.scope` | Externally created processes (not forked by systemd) placed under its management. |

## `[Unit]` section: metadata and dependencies

Common keys: `Description=`, `Documentation=` (accepts `man:`, `http(s)://`,
`file:`, `info:` URIs and feeds `systemctl help`/`status`),
`Condition*=`/`Assert*=` (e.g. `ConditionPathExists=`, `ConditionFirstBoot=`;
a failed Condition skips silently, a failed Assert fails the unit),
`DefaultDependencies=`, `RefuseManualStart=`/`RefuseManualStop=`.

### Dependency directives (the part people get wrong)

Requirement and ordering are **orthogonal**. Setting one does not imply the
other. Combine a requirement directive with an ordering directive.

| Directive | Meaning |
|---|---|
| `Requires=` | Hard requirement. If the named unit fails to start, this unit fails too. Does **not** imply ordering and does not keep the other active. |
| `Wants=` | Weaker/optional. This unit still starts if the wanted unit fails. Preferred for robustness. |
| `Requisite=` | Like `Requires=` but the named unit must **already** be active; otherwise this unit fails immediately (no start triggered). |
| `BindsTo=` | Like `Requires=` but also stops this unit if the bound unit stops unexpectedly. Use with `After=`. |
| `PartOf=` | One-way propagation of stop/restart only (stopping/restarting the named unit stops/restarts this one, not vice versa). |
| `Upholds=` | Continuously restarts the named unit while this one is active (stronger than `Wants=`). |
| `Conflicts=` | Negative dependency: starting this stops the named unit and vice versa. |
| `Before=` / `After=` | **Ordering only.** `After=b.service` means "start after b is up / stop before b goes down". Orthogonal to requirement. |
| `OnFailure=` / `OnSuccess=` | Units to start when this one enters failed / inactive state. |

Reverse dependencies (`WantedBy=`, `RequiredBy=`, `UpheldBy=`, `BoundBy=`)
are created by the target's `.wants/`/`.requires/` directories, which the
`[Install]` section populates on `systemctl enable`.

## `[Install]` section: enablement

Read only by `systemctl enable`/`disable` (not at runtime). Keys:
`WantedBy=` (the usual: `WantedBy=multi-user.target`), `RequiredBy=`,
`Alias=`, `Also=` (enable companion units together),
`DefaultInstance=` (default instance for a template).

Only `WantedBy=`/`RequiredBy=` create a reverse-start dependency, and only
after `enable`. A unit with no `[Install]` section is `static` and can only
be pulled in as a dependency of another unit.

## `[Service]` section

### `Type=`

| Type | Ready when | Notes |
|---|---|---|
| `simple` | immediately after fork (before exec completes) | default when `ExecStart=` is set. Weak for ordering. |
| `exec` | after `execve()` succeeds | like simple but catches exec failures. |
| `forking` | parent exits, child daemonizes | traditional daemons; set `PIDFile=`. Discouraged for new units. |
| `oneshot` | the command exits | default when no `ExecStart=`. Allows multiple/zero `ExecStart=`. Pair with `RemainAfterExit=yes` to stay "active". |
| `dbus` | it acquires `BusName=` on the bus | requires `BusName=`. |
| `notify` / `notify-reload` | it calls `sd_notify(READY=1)` | most correct readiness signal. |
| `idle` | like simple, delayed up to 5s | avoids interleaving console output at boot. |

### Exec and lifecycle keys

- `ExecStart=`, `ExecStartPre=`, `ExecStartPost=`, `ExecReload=`,
  `ExecStop=`, `ExecStopPost=`, `ExecCondition=`. Leading `-` ignores
  failure; leading `@` sets argv[0]. Only `oneshot` allows multiple
  `ExecStart=`.
- `Restart=` one of `no` (default), `on-success`, `on-failure`,
  `on-abnormal`, `on-watchdog`, `on-abort`, `always`. Tune with
  `RestartSec=`, `RestartSteps=`, `RestartMaxDelaySec=`.
- `RemainAfterExit=`, `PIDFile=`, `BusName=`, `WatchdogSec=`,
  `TimeoutStartSec=`, `TimeoutStopSec=`, `SuccessExitStatus=`,
  `KillMode=`/`KillSignal=` (from `systemd.kill(5)`).
- Start-rate limiting: `StartLimitIntervalSec=` + `StartLimitBurst=`. A
  service that restarts too fast enters a permanent failed state until
  `systemctl reset-failed UNIT`.

### Runtime environment (from `systemd.exec(5)`)

`Environment=`, `EnvironmentFile=` (leading `-` = optional),
`WorkingDirectory=`, `User=`, `Group=`, `Nice=`,
`StandardInput=`/`StandardOutput=`/`StandardError=` (`journal`, `null`,
`socket`, `tty`, `file:`, `append:`), and the managed state dirs:
`StateDirectory=`, `CacheDirectory=`, `LogsDirectory=`,
`RuntimeDirectory=`, `ConfigurationDirectory=` (auto-created under
`/var/lib`, `/var/cache`, `/var/log`, `/run`, `/etc` with correct
ownership; the safe way to give a hardened/DynamicUser service writable
storage).

## `[Socket]` section (socket activation)

`ListenStream=` (TCP or UNIX stream), `ListenDatagram=` (UDP),
`ListenSequentialPacket=`, `ListenFIFO=`. `Accept=`:

- `Accept=no` (default): one long-running service instance receives the
  listening fd (passed as fd 3, `SD_LISTEN_FDS_START`; `LISTEN_FDS`/
  `LISTEN_PID` are set). Pairs with `foo.service`.
- `Accept=yes`: one service instance per connection via a `@`-template
  `foo@.service` (inetd-style). Heavier; use only for low rate.

Other keys: `SocketUser=`, `SocketGroup=`, `SocketMode=`, `NonBlocking=`,
`Service=` (override the paired service name). Sockets default to
`WantedBy=sockets.target`. Enable the `.socket`, not the `.service`, for
lazy activation.

## Templates, instances, specifiers

A template has `@` before the suffix: `foo@.service`. Instantiate with an
argument: `systemctl start foo@bar.service` (instance name `bar`). If
`getty@tty3.service` is requested and no such file exists, systemd
instantiates from `getty@.service`.

Common specifiers (resolved at load time):

| Specifier | Value |
|---|---|
| `%i` / `%I` | instance name (escaped / unescaped) |
| `%n` / `%N` | full unit name (escaped / unescaped) |
| `%p` / `%P` | prefix (before `@`), escaped / unescaped |
| `%H` | hostname |
| `%m` | machine ID |
| `%b` | boot ID |
| `%v` | kernel release (`uname -r`) |
| `%u` / `%U` | user name / UID |
| `%h` | user home directory |
| `%t` | runtime dir (`/run` or `$XDG_RUNTIME_DIR`) |

Example: `ExecStart=/usr/local/bin/myapp --config /etc/myapp/%i.conf`. Use
`systemd-escape` to turn arbitrary strings (paths) into valid instance
names.

## File locations and precedence

Load path, **highest to lowest precedence**:

1. `/etc/systemd/system/`: admin (wins)
2. `/run/systemd/system/`: runtime/generated
3. `/usr/lib/systemd/system/`: vendor/package (`/lib/...` on non-merged-usr)

User units: `~/.config/systemd/user/` > `/etc/systemd/user/` >
`/usr/lib/systemd/user/`. Confirm the live list with
`systemctl show -p UnitPath --value`.

### Drop-ins vs full overrides

- **Drop-in:** a directory `<unit>.d/` holding `*.conf` fragments that
  override/extend specific keys without replacing the file. Applied in
  lexicographic order of filename across all directories combined, with
  `/etc` > `/run` > `/usr/lib` on name collisions. A type-wide
  `<type>.d/` (e.g. `service.d/`) applies to all units of that type at
  lower precedence than name-specific drop-ins.
- **Full override:** copy the file into `/etc/systemd/system/`. It shadows
  the vendor copy entirely.
- `systemctl edit UNIT` creates/edits a drop-in and reloads;
  `systemctl edit --full UNIT` forks the whole file; `systemctl revert UNIT`
  discards overrides. `systemd-delta` lists everything overridden or masked.

To **reset a single key** back to empty in a drop-in, assign it empty first
(`ExecStart=` on its own line) then set the new value, since list-valued
keys otherwise append rather than replace.

## Minimal service example

```ini
# /etc/systemd/system/myapp.service
[Unit]
Description=My application
Documentation=man:myapp(8)
After=network-online.target
Wants=network-online.target

[Service]
Type=notify
ExecStart=/usr/local/bin/myapp --config /etc/myapp/config.toml
Restart=on-failure
RestartSec=5s
User=myapp
StateDirectory=myapp

[Install]
WantedBy=multi-user.target
```

`systemctl daemon-reload && systemctl enable --now myapp.service`.
