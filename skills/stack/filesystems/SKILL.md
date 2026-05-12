---
name: filesystems
description: Use for low-level filesystem topics on macOS, Linux, and NixOS — APFS (clonefile, copy-on-write, Spotlight exclusion, Time Machine snapshots, /nix synthetic mounts, dedicated APFS volumes), Btrfs (flat subvolume layout, impermanence + erase-your-darlings root rollback, compress=zstd, NOCOW vs SQLite WAL, bees deduplication, cross-subvolume reflinks), and ZFS / OpenZFS (pool / dataset layout, recordsize, ashift, compression, ARC sizing, block cloning, mirrors vs RAIDZ, sanoid / syncoid replication, NixOS generations + ZFS snapshots). Read the matching reference before recommending filesystem changes.
---

# Filesystems skill index

Pick the topic and read its reference before recommending filesystem
configuration or layout changes.

| Topic | When to read | Reference |
|---|---|---|
| APFS (macOS) | clonefile(2), cp -c CoW, Spotlight exclusion, Time Machine snapshots, /nix synthetic mount, dedicated APFS volume, case sensitivity | `references/apfs.md` |
| Btrfs (Linux / NixOS) | flat subvolume layout, impermanence + erase-your-darlings, compress=zstd / compress-force, NOCOW (chattr +C) vs SQLite WAL, bees / duperemove, cross-subvolume reflinks | `references/btrfs.md` |
| ZFS / OpenZFS | pool / dataset layout, recordsize, ashift, lz4 / zstd compression, atime=off, ARC sizing, block cloning (2.2/2.3), mirrors vs RAIDZ, sanoid / syncoid, NixOS generations + ZFS snapshots | `references/zfs.md` |

After reading the reference, follow its guidance for the task.
