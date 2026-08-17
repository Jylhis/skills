# Resource control (cgroup v2)

systemd places every service in a cgroup and exposes cgroup v2 (unified
hierarchy) limits as unit directives (`systemd.resource-control(5)`).
Controllers turn on automatically when a matching directive is set (setting
`CPUWeight=` enables the cpu controller; `TasksMax=` enables pids) or via
the `*Accounting=` switches. Set limits at runtime with
`systemctl set-property UNIT K=V` (persisted) or in a `[Service]`/`[Slice]`
section.

## CPU

- `CPUWeight=` (1-10000, default 100): proportional share under
  contention. Replaces the legacy `CPUShares=`. `StartupCPUWeight=` applies
  only during boot.
- `CPUQuota=` sets a hard ceiling as a percentage of **one core**: `100%` = one
  full core, `200%` = two cores, `50%` = half a core. `CPUQuotaPeriodSec=`
  tunes the enforcement window.
- `AllowedCPUs=`: pin to specific CPU cores (cpuset).

## Memory

Ordered from soft to hard:

- `MemoryMin=` / `MemoryLow=` give **protection**: memory reclaimed from this
  cgroup last, down to this floor.
- `MemoryHigh=` is a **soft throttle**: past this, the cgroup is aggressively
  reclaimed and stalled, but not killed. The recommended primary control.
- `MemoryMax=` is a **hard limit**: exceeding it triggers the cgroup OOM
  killer. The last line of defense, not the everyday knob.
- `MemorySwapMax=`, `MemoryZSwapMax=`, `AllowedMemoryNodes=`.

Values accept `K`/`M`/`G`/`T` (base 1024), a percentage of physical RAM
(`40%`), or `infinity`. Query the effective enforced value with
`systemctl show UNIT -p EffectiveMemoryMax`.

## IO (block layer)

- `IOWeight=` (1-10000, default 100), `StartupIOWeight=`.
- `IOReadBandwidthMax=` / `IOWriteBandwidthMax=`: per device:
  `IOWriteBandwidthMax=/dev/sda 50M`.
- `IOReadIOPSMax=` / `IOWriteIOPSMax=`: per device, IOPS cap.
- `IODeviceLatencyTargetSec=`. Requires a cgroup-v2-aware IO scheduler
  (bfq/none on the device) to take effect.

## Tasks and delegation

- `TasksMax=`: cap on the number of processes/threads (pids controller).
- `Delegate=yes`: hand the subtree to the service so it can manage its own
  sub-cgroups (needed by container runtimes running inside a unit).
- `Slice=`: place the unit in a specific slice.
- `*Accounting=`: `MemoryAccounting=`, `CPUAccounting=`, `IOAccounting=`,
  `TasksAccounting=` turn on measurement without setting a limit (visible in
  `systemctl status` and `systemd-cgtop`).

## Slices (the cgroup tree)

`.slice` units form the hierarchy: `-.slice` (root) contains
`system.slice` (system services), `user.slice` (per-user), and
`machine.slice` (containers/VMs). A limit on a slice bounds **all** its
members collectively, so grouping related services under a custom slice caps
them together:

```ini
# /etc/systemd/system/apps.slice
[Slice]
CPUQuota=400%
MemoryMax=8G
```

```ini
# in each member service
[Service]
Slice=apps.slice
```

## Introspection

- `systemd-cgls`: the cgroup tree with the processes in each node.
- `systemd-cgtop`: live CPU/memory/IO per cgroup (`-m` sorts by memory,
  `-c` by CPU).
- `systemctl show UNIT -p MemoryMax -p CPUQuotaPerSecUSec -p TasksMax`:
  normalized effective limits.
- `systemctl status UNIT`: shows current `Memory:`, `CPU:`, `Tasks:` when
  accounting is on.
- Raw cgroup fs: `/sys/fs/cgroup/system.slice/UNIT/memory.max`,
  `memory.current`, `cpu.max`, `io.max`, `pids.max`.

## Version / kernel notes

- These directives assume **cgroup v2 (unified)**. On a legacy cgroup-v1
  host some (`MemoryHigh=`, unified `IO*`) behave differently or are
  ignored; check `stat -fc %T /sys/fs/cgroup` (`cgroup2fs` = unified) and
  the host's systemd version.
- `MemoryMax=`/`MemoryHigh=` and the `IO*` family need reasonably modern
  systemd (v231+ for the `Memory*` names, v230+ for `IO*`). Older hosts used
  `MemoryLimit=`/`BlockIO*` on cgroup v1.
