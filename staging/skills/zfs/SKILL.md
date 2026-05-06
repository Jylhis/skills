---
name: zfs
description: "Use for ZFS and OpenZFS on NixOS and Linux including zpool, dataset layout with tank/local/nix and tank/system and tank/user tiers, recordsize semantics, ashift=12 or ashift=13 at pool creation, compression lz4 vs zstd, atime=off, xattr=sa, acltype=posixacl, dnodesize=auto, mountpoint=legacy, sync=disabled on build datasets, zfs_arc_max ARC sizing, zfs_txg_timeout, zfs_bclone_enabled block cloning reflink, OpenZFS 2.2 and 2.3 block cloning maturity, mirrors vs RAIDZ for homelab, Hetzner NixOS ZFS, sanoid and syncoid automated snapshots and replication, zfs send -c incremental, NixOS generations paired with ZFS snapshots, pre-rebuild snapshot hook, pool utilization under 80%, or PostgreSQL recordsize 128K + compression guidance."
user-invocable: false
---

# ZFS (OpenZFS on NixOS)

ZFS operates at the block level with a Merkle tree of checksummed
blocks. Every write produces a new block, updates parent pointers up
to the überblock, and batches everything into transaction groups
(TXGs) flushed every ~5 seconds. Snapshots are free. Block cloning
(reflink via `cp --reflink`) arrived in OpenZFS 2.2 and is more
mature in 2.3, though **cross-dataset reflinks still fail with
`EXDEV`**.

## Dataset layout (Graham Christensen 3-tier)

Group datasets by **backup/snapshot policy, not FHS path**. This is
the canonical NixOS-on-ZFS pattern:

```text
tank/local/nix                 # /nix           — never backed up, reproducible
tank/system/root               # /              — periodic snapshots
tank/system/var                # /var           — includes journals, state
tank/system/var/lib/docker     # /var/lib/docker — separate tuning for containers
tank/system/var/lib/postgres   # PG data        — separate recordsize for DB
tank/user/home                 # /home          — frequent snapshots + offsite
```

- `tank/local/*` — never snapshotted, never backed up. Reproducible
  from `configuration.nix`.
- `tank/system/*` — moderate retention, local snapshots.
- `tank/user/*` — aggressive retention + offsite replication via syncoid.

Every dataset inherits pool-level defaults unless explicitly overridden.

## Pool-level defaults

Set at the pool root so every dataset inherits them:

```ini
compression=lz4
atime=off
xattr=sa
acltype=posixacl
dnodesize=auto
mountpoint=legacy
```

- `xattr=sa` stores extended attributes inline in dnodes instead of in
  hidden files — required for sane SELinux/POSIX ACL performance.
- `mountpoint=legacy` is **required for NixOS boot ordering** — NixOS
  manages mounts via `fileSystems.*` in configuration, not ZFS's
  built-in mount logic.
- `atime=off` avoids a write on every read. `relatime` is not needed
  on ZFS.

## ashift

`ashift=12` for 4K-sector drives, `ashift=13` for certain NVMe devices
with 8K internal pages. **Must be set at pool creation — it cannot be
changed later.** Always pass it explicitly on `zpool create` rather
than relying on auto-detection, which sometimes reads 512 from drives
that lie about their sector size.

## recordsize — a max, not a fixed allocation

This is the most-misunderstood ZFS knob. `recordsize` is the **maximum**
block size for a file, not a fixed allocation. A 16 KB file on a 128K
dataset uses 16 KB of disk, not 128 KB. Where it matters is **random
writes into large files** — a database writing 8 KB pages into a 128 KB
record triggers read-modify-write amplification.

**Modern consensus:**

- **PostgreSQL: keep `recordsize=128K` + compression enabled** (not
  the old 8K advice). Smaller recordsize kills compression ratios, and
  compression more than offsets the write amplification on modern
  hardware.
- **QEMU/KVM with qcow2 (64 KB cluster size): `recordsize=64K`** on
  the VM dataset to align with qcow2's own block size.
- Everything else: 128K default is correct.

## Compression — always on

LZ4 has early-abort on incompressible data, so the overhead is
negligible even on already-compressed files. At ~660 MB/s compress
speed, LZ4 is the safe universal default.

**Upgrade to zstd for specific datasets:**

- **`zstd` (level 3, default)** on Nix store, Docker layers, logs.
  Ratios: Nix store ~2.5–3.5×, logs 5–10×, source code similar.
- **`zstd-9`** only for cold/archival data where write speed is
  irrelevant.

ARC caches compressed blocks, so ARC effectively covers 2.5–3× the raw
byte count when zstd is on.

## ARC sizing

ARC shares RAM with application workloads. On a 64 GB Hetzner server
with PostgreSQL and Docker, a practical split:

| Slice | Size |
|---|---|
| ZFS ARC | 32 GB |
| PostgreSQL `shared_buffers` | 16 GB |
| Docker / apps | 14 GB |
| OS | 2 GB |

```nix
boot.extraModprobeConfig = ''
  options zfs zfs_arc_max=34359738368 zfs_txg_timeout=10 zfs_bclone_enabled=1
'';
```

Monitor with `arc_summary`. A hit ratio >95% means you're well-tuned.
With zstd compression on, 32 GB of ARC effectively covers ~96 GB of
data.

**Skip L2ARC on NVMe-only pools** — the pool itself is already as fast
as the L2ARC device would be. A **special vdev (metadata on NVMe)**
makes `ls`/`find`/`stat` NVMe-speed on HDD pools, but it **must be
mirrored** — losing the special vdev loses the pool.

## Pool topology for homelab

**Mirrors are strongly preferred over RAIDZ** on homelab and small
servers:

- ~2× IOPS advantage vs RAIDZ for the same drive count.
- Resilver is **minutes to hours**, not hours to days.
- Incremental capacity: add another mirror pair anytime.
- Simpler: the math is "n-way mirror, lose n-1 drives".

For a 2-disk Hetzner server, a mirror is the only redundant option. For
4 disks, use 2×2-disk striped mirrors (RAID10-equivalent).

## Build-workload tuning

Two transformative settings for Nix/CI workloads:

- **`sync=disabled` on `/nix` and CI datasets.** Converts synchronous
  writes to async. **2–10× write throughput improvement**, at the cost
  of losing up to 5 seconds of writes on power loss. Acceptable for
  `/nix` because the store is reproducible from configuration.
- **`zfs_txg_timeout=10`** (or up to 30) batches writes more
  efficiently for compilation workloads that emit many small files.
  Default is 5.

## Block cloning (ZFS reflink)

`zfs_bclone_enabled=1` enables reflink-style cloning via
`cp --reflink=auto` on OpenZFS 2.2+. Early 2.2 releases had stability
issues, so it shipped disabled by default; 2.3.x is more mature and
enables it by default on new pools. **Cross-dataset reflinks still
return `EXDEV`** — plan dataset boundaries so reflink-heavy workloads
(git worktrees, CI clones) stay inside one dataset.

## NixOS generations paired with ZFS snapshots

Two independent rollback axes — one semantic (Nix generations), one
physical (ZFS snapshots) — are stronger together. Tag each snapshot
with the NixOS generation number via a pre-rebuild hook:

```bash
#!/usr/bin/env bash
NEXT_GEN=$(( $(nixos-rebuild list-generations --json | jq '.[-1].generation') + 1 ))
zfs snapshot -r tank/system@gen-${NEXT_GEN}-pre-$(date +%Y%m%d-%H%M%S)
```

Run this before `nixos-rebuild switch`. If a rebuild produces a broken
system that the Nix rollback can't fix (e.g., a filesystem-level data
change), `zfs rollback` gets you back.

## Sanoid / Syncoid for automation

Standard tooling for retention + offsite replication on NixOS. Both
have native modules. **Sanoid** handles retention policies (hourly /
daily / monthly). **Syncoid** performs incremental `zfs send -c`
(compressed, raw) to a remote host.

```nix
services.sanoid = {
  enable = true;
  datasets."tank/user/home" = {
    hourly = 48;
    daily = 30;
    monthly = 12;
    autosnap = true;
    autoprune = true;
  };
};
```

For Hetzner → offsite backup:

```nix
services.syncoid = {
  enable = true;
  commands."tank/user/home" = {
    target = "backup@offsite.example.com:backup/home";
    sendOptions = "c";  # compressed send
    recursive = true;
  };
};
```

## CI/CD: clone-per-test pattern

Snapshot a known-good database state, `zfs clone` it for each CI run
(instant, isolated), run tests, then `zfs destroy` the clone after
(instant cleanup):

```bash
zfs snapshot tank/system/var/lib/postgres@ci-baseline
zfs clone tank/system/var/lib/postgres@ci-baseline tank/system/var/lib/postgres-ci-$$
# ... run tests against the clone ...
zfs destroy tank/system/var/lib/postgres-ci-$$
```

Eliminates per-test database seeding entirely.

## Capacity and fragmentation

- **Keep pool utilization under 80%** (ideally 70%). ZFS has no
  in-place defrag, CoW inherently scatters modified blocks, and the
  allocator changes behavior above ~80% full to prioritize space over
  speed.
- **Long-lived snapshots lock blocks in place**, forcing new writes
  elsewhere. Prune old snapshots regularly.
- **For severe fragmentation**, the effective defrag is
  `zfs send | zfs recv` to a fresh pool. OpenZFS 2.3+ introduced
  `zfs rewrite` for selective per-file rewriting; verify maturity in
  the release notes for your version before relying on it.

## Tool detection

```bash
for tool in zfs zpool arc_summary zdb sanoid syncoid; do
  if command -v "$tool" >/dev/null 2>&1; then
    echo "ok: $tool"
  else
    echo "MISSING: $tool"
  fi
done

# Show pool health if any pools exist
if command -v zpool >/dev/null 2>&1; then
  zpool list 2>/dev/null || echo "note: no zpools imported"
fi
```

## Quick reference

```bash
# Create a mirrored pool with correct defaults
sudo zpool create -o ashift=12 \
  -O compression=lz4 -O atime=off -O xattr=sa \
  -O acltype=posixacl -O dnodesize=auto -O mountpoint=legacy \
  tank mirror /dev/nvme0n1 /dev/nvme1n1

# Create the 3-tier dataset layout
sudo zfs create -o mountpoint=legacy tank/local
sudo zfs create -o mountpoint=legacy -o sync=disabled tank/local/nix
sudo zfs create -o mountpoint=legacy tank/system
sudo zfs create -o mountpoint=legacy tank/system/root
sudo zfs create -o mountpoint=legacy -o recordsize=128K tank/system/var/lib/postgres
sudo zfs create -o mountpoint=legacy -o recordsize=64K  tank/system/var/lib/qemu
sudo zfs create -o mountpoint=legacy -o compression=zstd tank/user
sudo zfs create -o mountpoint=legacy tank/user/home

# Enable block cloning at runtime
echo 1 | sudo tee /sys/module/zfs/parameters/zfs_bclone_enabled

# Snapshot + clone for CI
sudo zfs snapshot tank/system/var/lib/postgres@baseline
sudo zfs clone tank/system/var/lib/postgres@baseline tank/system/var/lib/postgres-ci

# Monitor ARC
arc_summary | head -30
```
