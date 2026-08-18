# Timers (the cron replacement)

A `.timer` unit activates a target unit on a schedule. By default it starts
the `.service` of the same basename (`backup.timer` to `backup.service`);
override with `Unit=` in `[Timer]`. Enable the **timer**, not the service:
`systemctl enable --now backup.timer`.

Why prefer timers over cron: unit logging in the journal, dependency
ordering, resource control and sandboxing on the target service, `Persistent=`
catch-up, randomized jitter, and per-user timers under `systemctl --user`.

## Two families of trigger

### Realtime / wall-clock (`OnCalendar=`)

```ini
[Timer]
OnCalendar=*-*-* 02:30:00        # daily at 02:30
OnCalendar=Mon *-*-* 06:00:00    # Mondays at 06:00
OnCalendar=*-*-01 00:00:00       # first of every month
OnCalendar=hourly                # shorthand: minutely/hourly/daily/weekly/monthly/quarterly/yearly
```

Calendar syntax is `DOW YYYY-MM-DD HH:MM:SS`. Fields accept `*`, lists
(`Mon,Wed`), ranges (`9..17`), and steps (`*/15` in the minute field, or
`0/15`). Multiple `OnCalendar=` lines accumulate. **Always validate**:

```bash
systemd-analyze calendar "Mon *-*-* 06:00:00" --iterations=3
```

### Monotonic (relative to an event)

| Key | Fires relative to |
|---|---|
| `OnBootSec=` | system boot |
| `OnStartupSec=` | the service manager (PID 1, or the user manager) starting |
| `OnActiveSec=` | the timer itself being activated |
| `OnUnitActiveSec=` | the target unit last **activating** (repeats: builds interval schedules) |
| `OnUnitInactiveSec=` | the target unit last **deactivating** |

Example: run 15 min after boot, then every hour:

```ini
[Timer]
OnBootSec=15min
OnUnitActiveSec=1h
```

## Modifier keys

- `Persistent=true`: if the machine was off when a **calendar** trigger
  should have fired, run it once immediately after boot. No effect on
  monotonic timers. State is stored under `/var/lib/systemd/timers`.
- `RandomizedDelaySec=`: spread firing over a window to avoid a thundering
  herd across many hosts (e.g. `RandomizedDelaySec=1h`).
- `AccuracySec=`: how loosely systemd may batch this timer with others to
  save wakeups (default `1min`; set `1us` for exact firing).
- `WakeSystem=true`: wake the machine from suspend to fire (needs RTC
  support).
- `OnClockChange=` / `OnTimezoneChange=`: fire when the clock/timezone jumps.

## Complete example

```ini
# /etc/systemd/system/backup.timer
[Unit]
Description=Nightly backup

[Timer]
OnCalendar=*-*-* 02:30:00
Persistent=true
RandomizedDelaySec=20min
AccuracySec=1min

[Install]
WantedBy=timers.target
```

```ini
# /etc/systemd/system/backup.service
[Unit]
Description=Run the backup
[Service]
Type=oneshot
ExecStart=/usr/local/bin/backup.sh
```

`systemctl daemon-reload && systemctl enable --now backup.timer`.

## Operating timers

- `systemctl list-timers [--all]`: next elapse, last trigger, and target
  for every timer.
- `systemctl start backup.service`: run the job now, out of band, to test
  it (does not disturb the schedule).
- `journalctl -u backup.service -b`: see what the last run did.
- Status of the timer object: `systemctl status backup.timer`.

## User timers

Under `systemctl --user`, units live in `~/.config/systemd/user/`. They run
only while the user has a session **unless** you enable lingering:
`loginctl enable-linger <user>` lets the user's manager (and its timers) run
without an active login. Validate and manage exactly as system timers but
with the `--user` flag.
