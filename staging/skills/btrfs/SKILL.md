---
name: btrfs
description: "Use for Btrfs filesystem on Linux and NixOS including flat subvolume layout at subvolid=5 (root, home, nix, persist, log, swap), impermanence pattern with erase-your-darlings root rollback via boot.initrd.postDeviceCommands, nix-community/impermanence plus disko, mount options compress=zstd, compress-force=zstd:1 for /nix (NixOS/nix#3550), noatime, discard=async, space_cache=v2, autodefrag off on SSD, chattr +C NOCOW vs SQLite WAL mode journal_mode=WAL, bees deduplication daemon services.beesd with hashTableSizeMB, duperemove, cross-subvolume reflinks since kernel 5.17, cp --reflink=auto, FICLONE ioctl, Nix garbage collection interaction with Btrfs snapshots, or btrfs compsize compression ratio inspection."
user-invocable: false
---

# Btrfs (Linux / NixOS copy-on-write filesystem)

Btrfs uses extent-based CoW. Files are stored as extents (up to 128 MB)
with reference counts tracked in a dedicated extent tree. Reflinks via
`cp --reflink=auto` or the `FICLONE` ioctl are mature, stable, and
work **cross-subvolume** since kernel 5.17. Btrfs has the most complete
reflink story of the three CoW filesystems — use it freely.

## Subvolume layout for NixOS

The NixOS community has converged on a **flat subvolume layout** at
the btrfs top level (`subvolid=5`). Separate subvolumes for each
distinct backup/snapshot policy:

```text
@root      mounted at /
@home      mounted at /home
@nix       mounted at /nix
@persist   mounted at /persist       (impermanence)
@log       mounted at /var/log
@swap      mounted at /swap          (for swapfile with NOCOW)
```

**Why separate subvolumes:** snapshots don't cross subvolume
boundaries. Keeping `/nix` in its own subvolume prevents it from
bloating root snapshots, and `/nix` doesn't need backup at all — it is
reconstructible from `configuration.nix`. `/var/log` in its own
subvolume keeps journald churn out of your root snapshots.

## Impermanence pattern ("erase your darlings")

Take a read-only snapshot of a blank root during installation, then
roll back to it on every boot. Combined with `nix-community/impermanence`
(declarative persistence) and `disko` (declarative partitioning), this
eliminates configuration drift entirely — the running system matches
`configuration.nix` exactly.

```nix
boot.initrd.postDeviceCommands = lib.mkAfter ''
  mkdir -p /mnt
  mount -o subvol=/ /dev/mapper/cryptroot /mnt
  btrfs subvolume list -o /mnt/root |
    cut -f9 -d' ' |
    while read subvolume; do
      btrfs subvolume delete "/mnt/$subvolume"
    done &&
    btrfs subvolume delete /mnt/root
  btrfs subvolume snapshot /mnt/root-blank /mnt/root
  umount /mnt
'';
```

Layer `nix-community/impermanence` on top to whitelist `/etc/ssh/`,
`/var/lib/bluetooth`, user dotfiles, etc. into `/persist`.

## Mount options

Workstation on NVMe, per subvolume:

```nix
fileSystems."/".options = [
  "subvol=root" "compress=zstd:3" "noatime" "discard=async" "space_cache=v2"
];
fileSystems."/home".options = [
  "subvol=home" "compress=zstd:3" "noatime" "discard=async" "space_cache=v2"
];
fileSystems."/nix".options = [
  "subvol=nix" "compress-force=zstd:1" "noatime" "discard=async" "space_cache=v2"
];
```

**Critical:** use **`compress-force=zstd:1`** on `/nix`, not plain
`compress=zstd`. Btrfs's compression heuristic skips files it thinks
are incompressible, and it guesses wrong on Nix binary cache downloads
(the cache serves already-compressed data, which Btrfs sees, but Nix
unpacks it into the store as plain files that *are* compressible).
Documented in NixOS/nix#3550. The `force` variant overrides the
heuristic and consistently achieves the Nix-store compression ratio
(typically 2.5–3.5× with zstd).

`zstd:1` for `/nix` (not `:3`) because the Nix store is write-heavy
on rebuilds and level 1 is fast enough that compression cost is
invisible while still delivering strong ratios.

## SSD tuning

- **`autodefrag=off`** (the default — leave it off). Autodefrag
  detects small random writes and queues background defrag, which
  **breaks reflinks** and adds unnecessary SSD writes. Fragmentation
  has minimal penalty on SSDs.
- **`discard=async`** — queue TRIM asynchronously instead of synchronous
  `discard` (which blocks every delete).
- **`space_cache=v2`** — the modern free-space tree, required for large
  filesystems and significantly faster than v1.

## Databases and VMs: NOCOW vs app-level tuning

The textbook advice for database files and VM images on Btrfs is
`chattr +C` (NOCOW) on their directories to avoid CoW fragmentation.
But NOCOW **also disables data checksums**, which is a real cost.

For SQLite, a better alternative:

```sql
PRAGMA journal_mode=WAL;
```

WAL mode is append-only, which aligns naturally with CoW semantics
and delivers roughly **~300% performance improvement** vs a default
rollback journal on Btrfs — compared to ~25% from NOCOW. Prefer
application-level WAL over disabling filesystem checksums wherever
possible.

For PostgreSQL and qcow2 VM images, NOCOW is more defensible since
there is no equivalent in-app fix; if you use it, accept the loss of
checksums on those files.

## Deduplication: bees

`bees` (Best-Effort Extent-Same) is the recommended always-on
deduplication daemon. Fixed-size hash table (e.g., 256 MB for a
workstation) makes memory predictable, and it runs continuously in
the background.

```nix
services.beesd.filesystems.root = {
  spec = "LABEL=nixos";
  hashTableSizeMB = 256;
  verbosity = "crit";
};
```

One reported result: 70% dedup savings on glibc packages alone across
multiple Nix store versions. The alternative `duperemove` is
file-oriented and can be CPU-bound on large datasets — prefer `bees`
for continuous dedup on a desktop/server, `duperemove` only for
one-shot passes.

## Cross-subvolume reflinks

Stable since kernel 5.17. Use `cp --reflink=auto` freely across
subvolumes on the same Btrfs filesystem — no special flags, no
`EXDEV`. A shell alias is safe:

```bash
alias cp='cp --reflink=auto'
```

`reflink=auto` falls back to a full copy when the destination is on a
different filesystem, so the alias is non-destructive.

## Nix GC + Btrfs snapshots

**Important interaction:** if a Btrfs snapshot references store paths
that `nix-collect-garbage -d` deletes, the disk space is **not freed**
until the snapshots are also deleted. The GC decrements Nix's own
refcount but the snapshot still pins the extents.

Best practices:

- Rotate old Btrfs snapshots **before or after** running
  `nix-collect-garbage -d`.
- **Do not include `/nix`** in timeline-based snapshot policies
  (snapper, btrbk). Keep `/nix` unsnapshotted; it is reproducible from
  `configuration.nix` and from `nix-store --gc-roots`.
- Keep root snapshots short-lived so GC'd store paths are actually
  freed within a reasonable window.

## Tool detection

```bash
for tool in btrfs compsize duperemove beesd; do
  if command -v "$tool" >/dev/null 2>&1; then
    echo "ok: $tool"
  else
    echo "MISSING: $tool"
  fi
done

# Confirm we're actually on Btrfs
if stat -f -c %T / 2>/dev/null | grep -q btrfs; then
  echo "ok: / is btrfs"
  sudo btrfs filesystem usage / 2>/dev/null | head -5
else
  echo "note: / is not btrfs"
fi
```

## Quick reference

```bash
# Reflink copy across subvolumes (instant on same filesystem)
cp --reflink=auto -R /home/user/project /home/user/project-clone

# Inspect compression ratio on a path
sudo compsize /nix

# Manual dedup pass over a directory
sudo duperemove -rdh /home/user/big-directory

# Subvolume management
sudo btrfs subvolume list /
sudo btrfs subvolume snapshot -r /home /home/.snapshots/$(date +%Y%m%d)
sudo btrfs subvolume delete /home/.snapshots/20200101
```
