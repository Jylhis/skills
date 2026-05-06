---
name: apfs
description: "Use for APFS filesystem on macOS including clonefile(2), cp -c copy-on-write, copyfile COPYFILE_CLONE, NSFileManager copyItem CoW, ditto vs cp CoW behavior, same-volume clone constraint, case-sensitive dev volume via diskutil apfs addVolume, Spotlight exclusion with .metadata_never_index or mdutil -i off, Nix on macOS synthetic /nix mount via /etc/synthetic.conf, dedicated Nix Store APFS volume with nobrowse fstab option, Time Machine hourly APFS snapshots, APFS lack of data checksums, APFS on spinning disks performance, or APFS container and volume sharing semantics."
user-invocable: false
---

# APFS (macOS copy-on-write filesystem)

APFS implements copy-on-write via `clonefile(2)`. Clones duplicate only
metadata — data extents are shared between source and destination and
diverge lazily as writes land. Clones are **same-volume only**: you
cannot clone across APFS volumes, even volumes in the same container.
There is no `--reflink=auto` equivalent in macOS coreutils, so CoW must
be invoked explicitly.

## CoW behavior by tool

| Tool / API | CoW? | Notes |
|---|---|---|
| `cp` | No | full data copy |
| `cp -c` | Yes | CoW via `clonefile`, errors if unsupported |
| `cp -c -R` | Yes | CoW recursive clone |
| `ditto` | No | full data copy |
| `rsync` | No | full data copy |
| Finder copy / paste / duplicate | Yes | CoW with fallback |
| `NSFileManager.copyItem` | Yes | CoW with fallback |
| `copyfile(…, COPYFILE_CLONE)` | Yes | CoW with fallback |
| `clonefile(2)` | Yes | direct syscall, no fallback |

**Rule of thumb:** for copies that could be multi-GB directories on the
same volume (`target/`, `node_modules/`, build outputs), use
`cp -c -R src dst` and the copy becomes instant. Plain `cp -R` walks
every byte.

## Case-sensitive developer volume

APFS volumes share free space inside a container, so adding a dedicated
dev volume is cheap. Creating a **case-sensitive** volume catches
cross-platform bugs that would only surface on Linux — critical for
anything you deploy or build on Linux CI.

```bash
diskutil apfs addVolume disk3 "APFS (Case-sensitive, Encrypted)" DevCS
```

Then symlink or mount your `~/Developer` work onto that volume. **Never
make your boot volume case-sensitive** — several macOS applications
break on case-sensitive roots (Adobe suite is the canonical example).

## Spotlight exclusion for dev directories

Spotlight indexing is the single biggest performance drain on
development directories. Every file create/delete inside `node_modules`,
`target/`, `.git/`, or a build tree gets indexed by `mds_stores`,
compounded by Time Machine's hourly APFS snapshots that also track the
same churn. Community reports consistently show `git clean`,
`npm install`, and similar operations running significantly slower on
macOS than on Linux for this reason.

Three mechanisms, in order of scope:

1. **Per-directory sentinel** — drop an empty file named
   `.metadata_never_index` in the directory. Spotlight skips the tree.
2. **Per-volume disable** — `sudo mdutil -i off /Volumes/DevCS` turns
   indexing off for an entire volume. Pair with the case-sensitive dev
   volume above for a clean split.
3. **Privacy list** — System Settings → Spotlight → Search Privacy,
   add paths. Works globally but is per-path, not pattern-based.

## Nix on macOS architecture

The official Nix installer sets up an elegant APFS layout. Understand
it before touching it:

- `/etc/synthetic.conf` creates the synthetic `/nix` mountpoint at boot
  (bypasses the read-only system volume restriction).
- A dedicated **"Nix Store"** APFS volume inside the boot container
  holds the actual store, sharing free space dynamically with the boot
  volume.
- `/etc/fstab` mounts the Nix Store volume at `/nix` with the
  `nobrowse` option, which hides it from Finder and prevents Spotlight
  from indexing it.

If `/nix` is missing after a macOS upgrade, re-running the Nix
installer or re-applying `synthetic.conf` + an `fstab` entry rebuilds
it. Do **not** try to make `/nix` a symlink on macOS — the synthetic
mount is the supported path.

## Integrity gap vs Btrfs/ZFS

APFS checksums **metadata only**, not data. Silent bit rot on user
data would not be detected by the filesystem — APFS relies entirely on
SSD ECC and the underlying storage controller. This is a real
difference from Btrfs and ZFS, which both checksum user data. If you
need end-to-end integrity on macOS (archival storage, media
preservation), layer it at the application level (e.g., par2, BLAKE3
manifests) or keep that data on a ZFS/Btrfs host.

## Footguns

- **APFS on spinning disks is catastrophic.** Carbon Copy Cloner's
  testing showed 15–20× slowdown vs HFS+ after ~20 write cycles. If
  you have an external HDD for backups or media, format it **HFS+**,
  not APFS.
- **Clones are same-volume only.** Copying to another APFS volume —
  even in the same container — is a full data copy. `clonefile(2)`
  returns `EXDEV` across volumes.
- **`cp` default is a full copy.** The most common mistake is
  forgetting `-c`. Consider a shell alias if you copy within a single
  APFS volume often.
- **Time Machine amplifies small-file workloads.** Hourly local
  snapshots mean every transient file in a git checkout gets tracked.
  Excluding dev directories from Time Machine backups (System Settings
  → General → Time Machine → Options) reduces snapshot churn.
- **No user-accessible defragmentation.** The `apfsd` daemon does some
  passive work, but there is no `fsck`-style defrag. On SSDs
  fragmentation is largely irrelevant; on spinning disks, the prior
  footgun applies instead.

## Tool detection

```bash
for tool in diskutil mdutil cp clonefile; do
  if command -v "$tool" >/dev/null 2>&1; then
    echo "ok: $tool"
  else
    echo "MISSING: $tool"
  fi
done

# Verify cp supports -c (clonefile)
if cp -c /dev/null /tmp/apfs-cp-c-test 2>/dev/null; then
  echo "ok: cp -c supported"
  rm -f /tmp/apfs-cp-c-test
else
  echo "MISSING: cp -c (not on APFS or wrong cp?)"
fi

# Verify /nix is a synthetic mount (Nix-on-macOS)
if mount | grep -q "on /nix "; then
  echo "ok: /nix mounted"
  mount | grep "on /nix "
else
  echo "note: /nix not mounted (Nix not installed?)"
fi
```

## Quick reference

```bash
# Instant CoW clone of a build tree on the same APFS volume
cp -c -R ~/Developer/project/target ~/Developer/project-feature/target

# Exclude a directory from Spotlight (sentinel file)
touch ~/Developer/project/node_modules/.metadata_never_index

# Disable indexing on an entire dev volume
sudo mdutil -i off /Volumes/DevCS

# Create a case-sensitive, encrypted dev volume in the main container
diskutil apfs addVolume disk3 "APFS (Case-sensitive, Encrypted)" DevCS
```
