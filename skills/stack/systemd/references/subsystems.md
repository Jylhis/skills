# Subsystems and components

systemd is a suite, not just an init. These daemons ship with it and are
managed like any other unit. Reach for this reference when a task touches
logging, sessions, networking, devices, secrets, or images rather than a
plain service.

## journald (systemd-journald)

Structured, indexed binary logging of the kernel, service stdout/stderr, and
syslog. Queried via `journalctl` (see `commands.md`). Config:
`/etc/systemd/journald.conf` (view merged with `systemd-analyze cat-config
systemd/journald.conf`). Key knobs: `Storage=` (`persistent`/`volatile`/
`auto`), `SystemMaxUse=`, `MaxRetentionSec=`, `ForwardToSyslog=`. Make logs
survive reboot by creating `/var/log/journal` and restarting the daemon.

## logind (systemd-logind)

Manages logins, sessions, and seats; backs `loginctl`. Handles
suspend/reboot policy, lid/power-key actions (`/etc/systemd/logind.conf`:
`HandleLidSwitch=`, `IdleAction=`), inhibitor locks, and **lingering**
(`loginctl enable-linger USER` lets a user's services/timers run with no
active session).

## networkd / resolved / timesyncd

- **systemd-networkd** + `networkctl`: declarative networking via
  `.network`/`.netdev`/`.link` files in `/etc/systemd/network/`.
- **systemd-resolved** + `resolvectl`: DNS with a stub resolver at
  `127.0.0.53`, DNSSEC and DNS-over-TLS support; provides
  `/etc/resolv.conf` via symlink to a stub file.
- **systemd-timesyncd** + `timedatectl`: lightweight SNTP client and clock/
  timezone control (`timedatectl set-timezone`, `set-ntp true`).

## udev (systemd-udevd)

Device manager. Rules in `/etc/udev/rules.d/` (and `/usr/lib/...`); hardware
database in `hwdb.d/`. Drive it with `udevadm info /dev/sdX`,
`udevadm trigger`, `udevadm monitor`, `udevadm settle`.

## systemd-boot / Boot Loader Spec

UEFI boot manager (formerly gummiboot), managed by `bootctl` (`bootctl
install`, `bootctl status`, `bootctl list`). Entries follow the Boot Loader
Specification under the ESP.

## Credentials

Pass secrets to services without env vars or world-readable files:
`LoadCredential=name:path`, `SetCredential=name:value`,
`ImportCredential=`, and encrypted variants `LoadCredentialEncrypted=`/
`SetCredentialEncrypted=` (sealed with `systemd-creds encrypt`, optionally to
the TPM). The service reads them from `$CREDENTIALS_DIRECTORY/name`. VMs can
receive credentials via SMBIOS Type 11 or qemu `fw_cfg`. Docs:
systemd.io/CREDENTIALS.

## System extensions (sysext) and confext

OverlayFS images merged into `/usr/` (+`/opt/`) for sysext, or `/etc/` for
confext, at runtime without modifying the base image. Each image carries an
`extension-release` file that must match the host (`SYSEXT_LEVEL=`/
`VERSION_ID=` for sysext, `CONFEXT_LEVEL=` for confext). Managed by
`systemd-sysext merge|unmerge|status`. Good for immutable/image-based OSes.

## Portable services (v239+)

Bundle a service plus its dependencies in an image and attach it to the host
with `portablectl attach IMAGE` / `portablectl detach`. Runs directly on the
host (not a container) under generated, sandboxed units. Docs:
systemd.io/PORTABLE_SERVICES.

## machined / nspawn

`systemd-nspawn` runs a lightweight container from a directory or image;
`machinectl` registers and controls local containers/VMs/images (`list`,
`login`, `shell`, `pull-tar`, `import-raw`).

## systemd-oomd

Userspace OOM killer driven by cgroup v2 PSI pressure (acts before the
kernel OOM killer). Configure per-unit with `ManagedOOMSwap=` and
`ManagedOOMMemoryPressure=` (`kill`/`auto`); inspect with `oomctl`.

## systemd-homed

Portable, self-contained, encrypted home directories described by JSON user
records; managed with `homectl` (`create`, `activate`, `update`). Decouples
the account from `/etc/passwd` for roaming/LUKS-backed homes.

## coredump handling

`systemd-coredump` captures crashing processes; `coredumpctl list`,
`coredumpctl info PID`, and `coredumpctl gdb PID` retrieve and debug them.
Config in `/etc/systemd/coredump.conf` (`Storage=`, `ProcessSizeMax=`).

## tmpfiles / sysusers

- `systemd-tmpfiles`: declarative creation/cleanup of files, dirs, and
  symlinks from `tmpfiles.d/` snippets (also runs periodically to clean
  `/tmp`). **`--purge` is destructive** (historically could delete `/home`
  before v256.1); never run it casually.
- `systemd-sysusers`: declaratively create system users/groups from
  `sysusers.d/` snippets at install time (the modern replacement for
  `useradd` in package post-install).
