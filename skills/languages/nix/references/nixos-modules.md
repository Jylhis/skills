# NixOS Module System

## Modern Module Idioms

Three RFCs define canonical patterns for any module you write today:

- **RFC 42 — `settings` over `extraConfig`.** Generate config files from typed attrsets using `pkgs.formats.<format>.generate`, not stringly-typed `extraConfig` options.
- **RFC 52 — Dynamic IDs.** New service modules use `isSystemUser = true` (auto-assigned persistent id) or `serviceConfig.DynamicUser = true` (ephemeral id). Do not add to `ids.nix`.
- **RFC 72 — CommonMark descriptions.** Option `description` is Markdown, not DocBook. Pass plain strings: `lib.mdDoc` was deprecated in 24.05 and removed in 24.11, so old code that still calls it fails to evaluate. The same goes for `lib.mkPackageOptionMD` (removed in 25.11, use `lib.mkPackageOption`).

See `language/rfcs.md` for the authoritative RFC index.

## Module Structure

Every NixOS module is a function returning an attrset with `options` and/or `config`:

```nix
{ config, lib, pkgs, ... }:

let
  cfg = config.services.myservice;
in {
  options.services.myservice = {
    enable = lib.mkEnableOption "my service";

    port = lib.mkOption {
      type = lib.types.port;
      default = 8080;
      description = "Port to listen on";
    };

    package = lib.mkPackageOption pkgs "myservice" { };
  };

  config = lib.mkIf cfg.enable {
    systemd.services.myservice = {
      description = "My Service";
      wantedBy = [ "multi-user.target" ];
      serviceConfig = {
        ExecStart = "${cfg.package}/bin/myservice --port ${toString cfg.port}";
        DynamicUser = true;
        Restart = "on-failure";
      };
    };

    networking.firewall.allowedTCPPorts = [ cfg.port ];
  };
}
```

## Module Arguments

| Argument | Purpose |
|----------|---------|
| `config` | The final merged configuration (result of evaluating all modules) |
| `lib` | nixpkgs library functions |
| `pkgs` | The package set |
| `options` | All declared options (for introspection) |
| `modulesPath` | Path to NixOS modules directory |

**`config` argument vs `config` attribute:** The `config` argument is the fully evaluated result of ALL modules. The `config` attribute in your module's return value is YOUR module's contribution. They are not the same.

### specialArgs

Extra arguments can be passed via `specialArgs` in `nixpkgs.lib.nixosSystem`:

```nix
nixpkgs.lib.nixosSystem {
  specialArgs = { inherit inputs; };
  modules = [ ./configuration.nix ];
};
```

**Caveat:** `specialArgs` breaks flake composition — modules using custom specialArgs cannot be reused in other flakes that don't provide the same args. Prefer inline modules with lexical closures instead:

```nix
modules = [
  ./configuration.nix
  ({ ... }: { _module.args.myInput = inputs.foo; })
];
```

## Option Types

```nix
lib.types.bool
lib.types.int
lib.types.str
lib.types.path
lib.types.port                          # 0-65535
lib.types.package
lib.types.enum [ "a" "b" "c" ]
lib.types.listOf lib.types.str          # List of strings
lib.types.attrsOf lib.types.int         # Attrset of ints
lib.types.nullOr lib.types.str          # String or null
lib.types.either lib.types.str lib.types.int
lib.types.submodule { options = { ... }; }  # Nested module
```

See `nixos-modules/type-system.md` for the complete type reference (30+ types, merge functions, freeformType, priority system, mkOptionType).

### freeformType

Combines typed options with a fallback for untyped attributes — useful for settings attrsets where you want to type-check some keys but allow arbitrary others:

```nix
options.services.foo.settings = lib.mkOption {
  type = lib.types.submodule {
    freeformType = with lib.types; attrsOf (oneOf [ bool int str ]);
    options.port = lib.mkOption {
      type = lib.types.port;
      default = 8080;
    };
  };
};
# settings.port is type-checked as port; settings.anything-else passes through freeformType
```

## evalModules Internals

The module system is powered by `lib.evalModules`, which:

1. Collects all modules (from `modules` list and all `imports`)
2. Evaluates all `options` declarations to build the option tree
3. Evaluates all `config` definitions and merges them per option type
4. Returns the merged `config` through lazy evaluation

Lazy evaluation allows circular references: module A can read `config.services.foo` which is set by module B, and module B can read `config.services.bar` set by module A — as long as there's no actual infinite recursion.

## Merge Functions

```nix
# Conditional config — most common
config = lib.mkIf cfg.enable { /* ... */ };

# Merge multiple config fragments
config = lib.mkMerge [
  (lib.mkIf cfg.enable { /* base config */ })
  (lib.mkIf cfg.enableTLS { /* TLS config */ })
];

# Priority control
services.foo.port = lib.mkDefault 8080;     # Low priority (1000, overridable)
services.foo.port = lib.mkForce 9090;       # High priority (50, overrides almost everything)
services.foo.port = lib.mkOverride 50 9090; # Custom priority (lower = higher)
```

Default priority is 100. `mkDefault` is 1000. `mkForce` is 50. Option `default` values sit at 1500 (`mkOptionDefault`), so even `mkDefault` beats them.

### Renaming and Removing Options

When you rename or drop an option in a module you maintain, leave a shim so users get a clear error or warning instead of "option does not exist":

```nix
{ lib, ... }:
{
  imports = [
    (lib.mkRenamedOptionModule [ "services" "foo" "port" ] [ "services" "foo" "settings" "port" ])
    (lib.mkRemovedOptionModule [ "services" "foo" "extraConfig" ] "Use services.foo.settings instead.")
  ];
}
```

## The `settings` Pattern (RFC 42)

Canonical pattern for any module that generates a config file. Instead of a stringly-typed `extraConfig` option, expose a structured `settings` attrset and serialize it with `pkgs.formats.<format>`:

```nix
{ config, lib, pkgs, ... }:

let
  cfg = config.services.myservice;
  settingsFormat = pkgs.formats.toml { };  # also .json, .yaml, .ini, .keyValue, .libconfig
in {
  options.services.myservice = {
    enable = lib.mkEnableOption "myservice";

    settings = lib.mkOption {
      type = settingsFormat.type;
      default = { };
      description = ''
        Configuration written to `myservice.toml`.
        See <https://example.com/docs> for the full schema.
      '';
      example = lib.literalExpression ''
        {
          port = 8080;
          log_level = "info";
        }
      '';
    };
  };

  config = lib.mkIf cfg.enable {
    environment.etc."myservice.toml".source =
      settingsFormat.generate "myservice.toml" cfg.settings;

    systemd.services.myservice.serviceConfig.ExecStart =
      "${cfg.package}/bin/myservice --config /etc/myservice.toml";
  };
}
```

Users then write:

```nix
services.myservice = {
  enable = true;
  settings = {
    port = 9090;
    log_level = "debug";
  };
};
```

**Benefits over `extraConfig`:**

- Structured, type-checked, introspectable via `nixos-option`
- Properly merged across multiple modules via `//`-semantics
- Declarative overrides with `lib.mkForce` / `lib.mkDefault`
- Serialized once, no manual escaping

**Don't shadow every upstream key with its own NixOS option.** Expose the full settings attrset, optionally with `freeformType` for typed subsets. Only add dedicated options for keys that need NixOS-specific handling (e.g., paths that should be substituted with `$RUNTIME_DIRECTORY`, or secrets that must be loaded at activation time).

## Common Configuration Patterns

### Services

```nix
{
  services.nginx = {
    enable = true;
    virtualHosts."example.com" = {
      forceSSL = true;
      enableACME = true;
      root = "/var/www/example";
    };
  };

  services.postgresql = {
    enable = true;
    ensureDatabases = [ "myapp" ];
    ensureUsers = [{
      name = "myapp";
      ensureDBOwnership = true;
    }];
  };
}
```

### Systemd Units

```nix
systemd.services.myapp = {
  description = "My Application";
  after = [ "network.target" "postgresql.service" ];
  wants = [ "postgresql.service" ];
  wantedBy = [ "multi-user.target" ];

  serviceConfig = {
    ExecStart = "${pkgs.myapp}/bin/myapp";
    WorkingDirectory = "/var/lib/myapp";
    User = "myapp";
    Group = "myapp";
    Restart = "on-failure";
    RestartSec = 5;

    # Hardening
    ProtectSystem = "strict";
    ProtectHome = true;
    NoNewPrivileges = true;
    PrivateTmp = true;
    PrivateDevices = true;
    ReadWritePaths = [ "/var/lib/myapp" ];
    CapabilityBoundingSet = "";
    SystemCallFilter = [ "@system-service" ];
  };

  environment = {
    DATABASE_URL = "postgresql:///myapp";
  };
};
```

### Users and Groups

```nix
users.users.myapp = {
  isSystemUser = true;
  group = "myapp";
  home = "/var/lib/myapp";
  createHome = true;
};
users.groups.myapp = { };
```

### Networking

```nix
networking = {
  hostName = "myserver";
  firewall = {
    enable = true;
    allowedTCPPorts = [ 80 443 22 ];
  };
};
```

For servers, systemd-networkd is the usual backend. `networking.useNetworkd = true` translates the `networking.interfaces` options to networkd; native units go under `systemd.network` (26.05 tracks networkd 259 options):

```nix
{
  networking.useNetworkd = true;
  systemd.network.networks."10-lan" = {
    matchConfig.Name = "en*";
    networkConfig.DHCP = "yes";
  };
}
```

### State Version

`system.stateVersion` records the NixOS release a machine was **first installed** with. Modules use it to keep stateful defaults stable (for example `stateVersion >= 25.11` selects PostgreSQL 17, and the in-development 26.11 selects 18 for `>= 26.11`). Never bump it just because you upgraded the channel or flake input; it does not choose the Nixpkgs version. Since 25.05 it is validated and must be `"YY.MM"`.

## Boot and Activation Changes (25.05 to 26.05)

NixOS has been removing Bash and Perl from boot and activation. Expect these when upgrading older configs:

| Release | Change |
|---------|--------|
| 25.05 | `nixos-rebuild-ng` (Python rewrite) available via `system.rebuild.enableNg`; new `nixos-rebuild build-image` |
| 25.11 | `nixos-rebuild-ng` is the default; Perl `switch-to-configuration` removed (Rust version only, drop `system.switch.enableNg`); opt-in `system.nixos-init.enable` (Rust, bashless init for systemd initrd); `systemd.extraConfig` became RFC 42 `systemd.settings.Manager` |
| 26.05 | systemd stage 1 is the default (`boot.initrd.systemd.enable`); the scripted initrd is deprecated and scheduled for removal in 26.11. The Bash `nixos-rebuild` is removed, so drop any `system.rebuild.enableNg`. Restarting or reloading units from activation scripts is deprecated (removal planned for 26.11). New `system.nix` entry point as a channel-free alternative to `configuration.nix` |

systemd stage 1 gotchas:

- `boot.initrd.postDeviceCommands`, `postResumeCommands`, `preLVMCommands`, `postMountCommands` and `boot.initrd.network.postCommands` fail evaluation. Port them to `boot.initrd.systemd.services.<name>` units ordered against initrd targets (see `bootup(7)`).
- `/dev/root` no longer exists; use `/dev/disk/by-*` or `/dev/mapper/*` in `fileSystems`.
- With LUKS, set `fileSystems."/".device = "/dev/mapper/<name>"` matching `boot.initrd.luks.devices.<name>`. `cryptsetup-askpass` is gone; use `systemctl default` to answer passphrase prompts.
- `boot.initrd.systemd.enable = false` reverts temporarily, but upstream discourages it.

For a fully Perl-free system, import `"${modulesPath}/profiles/perlless.nix"`. It turns on systemd stage 1, `system.etc.overlay.enable` (`/etc` as an overlay mount instead of the Perl activation script) and `services.userborn.enable`. Userborn (24.11+) creates users declaratively and is recommended over `systemd.sysusers` for Perl-less systems because it also handles normal users and password changes.

## Secrets Management

Secrets (passwords, API tokens, keys) must NOT go in Nix files — they end up world-readable in `/nix/store`. Use dedicated tools:

### agenix (recommended for simplicity)

Encrypts secrets with age using SSH public keys. Decrypts at system activation to `/run/agenix/`. Import `agenix.nixosModules.default`.

```nix
# agenix-rules.nix: maps secret files to authorized keys
# (the CLI looks for agenix-rules.nix, then secrets.nix in the current directory, or $AGENIX_RULES)
let keys = [ "ssh-ed25519 AAAA..." ]; in {
  "db-password.age".publicKeys = keys;
}

# configuration.nix
age.secrets.db-password.file = ./secrets/db-password.age;
# Available at config.age.secrets.db-password.path → /run/agenix/db-password
```

### sops-nix (recommended for teams)

Decrypts on the host with age or GPG. SSH Ed25519 host keys work as age keys (`sops.age.sshKeyPaths`, convert public keys with `ssh-to-age`). Secrets live in YAML, JSON, dotenv, INI or binary sops files and are edited with the `sops` CLI.

```nix
sops.defaultSopsFile = ./secrets/secrets.yaml;
sops.age.sshKeyPaths = [ "/etc/ssh/ssh_host_ed25519_key" ];

sops.secrets.db-password = {
  owner = "myapp";
  restartUnits = [ "myapp.service" ];
};
# Available at config.sops.secrets.db-password.path (under /run/secrets)

# Render a config file that embeds secrets at activation time
sops.templates."myapp.toml".content = ''
  password = "${config.sops.placeholder.db-password}"
'';
# Use config.sops.templates."myapp.toml".path in ExecStart
```

Set `neededForUsers = true` on a secret used by `users.users.<name>.hashedPasswordFile`; it is then decrypted to `/run/secrets-for-users` before users are created.

## Impermanence Pattern

The "erase your darlings" approach: root filesystem (`/`) is tmpfs or reset on every boot. Only explicitly declared state persists.

```nix
# With nix-community/impermanence module
environment.persistence."/persist" = {
  directories = [
    "/var/lib/postgresql"
    "/var/lib/acme"
    "/etc/NetworkManager/system-connections"
  ];
  files = [
    "/etc/machine-id"
    "/etc/ssh/ssh_host_ed25519_key"
  ];
};
```

Benefits: forces you to declare all state, keeps system clean, any undeclared state is gone on reboot.

- Mark every persistent and ephemeral filesystem with `neededForBoot = true`. Set `hideMounts = true` to keep the bind mounts out of file managers.
- Persist `/var/lib/nixos` so uid/gid allocations survive reboots.
- Keep the sops-nix or agenix decryption key (host SSH key or `sops.age.keyFile`) on a persisted path.
- Root-wipe recipes that use `boot.initrd.postDeviceCommands` or `postResumeCommands` (including the btrfs example in the impermanence README) are rejected by systemd stage 1, the default since 26.05. Run the wipe as an initrd unit instead:

```nix
{
  boot.initrd.systemd.services.rollback-root = {
    description = "Reset the root filesystem";
    wantedBy = [ "initrd.target" ];
    before = [ "sysroot.mount" ];
    unitConfig.DefaultDependencies = "no";
    serviceConfig.Type = "oneshot";
    script = ''
      # e.g. mount the btrfs top level, recreate the root subvolume, unmount
    '';
  };
}
```

Order it after the unit that unlocks or exposes the root device (for example `systemd-cryptsetup@<name>.service` or the `.device` unit).

## File Layout

```text
/etc/nixos/
├── system.nix            # Optional (26.05+): pins Nixpkgs, evaluates to the system; replaces nix-channel
├── configuration.nix     # Main entry point
├── hardware-configuration.nix  # Auto-generated
├── modules/
│   ├── base.nix
│   ├── networking.nix
│   ├── services/
│   │   ├── nginx.nix
│   │   └── postgresql.nix
│   └── users.nix
```

```nix
# configuration.nix
{ ... }: {
  imports = [
    ./hardware-configuration.nix
    ./modules/base.nix
    ./modules/networking.nix
    ./modules/services/nginx.nix
  ];
}
```

## Querying Options

```bash
nixos-option services.nginx
```

If the mcp-nixos MCP server is available, use it for richer option lookups across NixOS, Home Manager, and nix-darwin.

## Testing

```bash
nixos-rebuild build        # Build without switching
sudo nixos-rebuild switch  # Build and switch
nixos-rebuild build-vm     # Test in a VM
```

See `nixos-modules/testing.md` for the NixOS VM integration test framework.

## Related Skills

- **nix-darwin** — macOS equivalent using the same module system
- **home-manager** — user-level configuration with the same module patterns
- **nix-testing** — comprehensive guide to NixOS VM tests

## disko (Declarative Disk Partitioning)

disko lets you define disk layouts (partitions, filesystems, LUKS, LVM, mdadm) declaratively in Nix and apply them reproducibly. Useful for unattended installations, server provisioning, and rebuilding after disk failures.

### Basic Configuration

```nix
{
  disko.devices = {
    disk = {
      my-disk = {
        device = "/dev/sda";
        type = "disk";
        content = {
          type = "gpt";
          partitions = {
            ESP = {
              type = "EF00";
              size = "500M";
              content = {
                type = "filesystem";
                format = "vfat";
                mountpoint = "/boot";
                mountOptions = [ "umask=0077" ];
              };
            };
            root = {
              size = "100%";
              content = {
                type = "filesystem";
                format = "ext4";
                mountpoint = "/";
              };
            };
          };
        };
      };
    };
  };
}
```

### Supported Layouts

- Disk types: GPT, MBR, mixed
- Filesystems: ext4, btrfs, ZFS, bcachefs, vfat, tmpfs
- Advanced: LVM, mdadm, LUKS, recursive layouts

### Usage

```bash
# Apply a disko config to a machine (destructive: formats disks)
sudo nix run github:nix-community/disko/latest -- --mode destroy,format,mount /tmp/disk-config.nix

# Partition and install in one step from an installer or another machine
sudo nix run 'github:nix-community/disko/latest#disko-install' -- --flake .#myhost --disk main /dev/sda

# Or with nixos-anywhere for remote provisioning
nix run github:nix-community/nixos-anywhere -- --flake .#myhost --target-host root@host
```

The `latest` ref tracks the newest release (v1.13.0 at the time of writing). `disko-install` combines disko with `nixos-install`; `--disk <name> <device>` overrides `disko.devices.disk.<name>.device`. It also has a mount-only mode for repairing an existing install.

### Flake Integration

```nix
{
  inputs.disko.url = "github:nix-community/disko/latest";
  inputs.disko.inputs.nixpkgs.follows = "nixpkgs";
  # ...
  nixosConfigurations.myhost = nixpkgs.lib.nixosSystem {
    modules = [
      inputs.disko.nixosModules.disko
      ./hosts/myhost/disk-config.nix  # disko.devices.* config
      ./hosts/myhost/configuration.nix
    ];
  };
}
```

## SrvOS (Server Profiles)

SrvOS provides opinionated, reusable NixOS profiles for server deployments — shared modules for common server patterns (SSH hardening, terminfo, hardware-specific profiles).

### Available Profiles

| Module | Purpose |
|--------|---------|
| `srvos.nixosModules.server` | Common server baseline (minimal, no GUI, hardened defaults) |
| `srvos.nixosModules.desktop` | Desktop baseline |
| `srvos.nixosModules.hardware-hetzner-online-amd` | Hetzner AMD dedicated server (also `-intel`, `-arm`, `-ex101`) |
| `srvos.nixosModules.hardware-hetzner-cloud` | Hetzner Cloud VM (also `-arm`) |
| `srvos.nixosModules.hardware-amazon` | AWS EC2 |
| `srvos.nixosModules.mixins-terminfo` | Extra terminfo for SSH from various terminals |
| `srvos.nixosModules.mixins-systemd-boot` | systemd-boot defaults |
| `srvos.nixosModules.roles-github-actions-runner` | GitHub Actions runner setup |
| `srvos.nixosModules.roles-nix-remote-builder` | Nix remote builder |

Module names are the file path under `nixos/` with `/` replaced by `-`. The README still shows `hardware-hetzner-amd`, which does not exist; use `hardware-hetzner-online-amd`. nix-darwin profiles are under `srvos.darwinModules`.

### Usage

```nix
{
  inputs.srvos.url = "github:nix-community/srvos";
  # Use the nixpkgs version tested with SrvOS (latest stable and unstable also work)
  inputs.nixpkgs.follows = "srvos/nixpkgs";

  outputs = { self, nixpkgs, srvos }: {
    nixosConfigurations.myhost = nixpkgs.lib.nixosSystem {
      system = "x86_64-linux";
      modules = [
        srvos.nixosModules.server
        srvos.nixosModules.hardware-hetzner-online-amd
        srvos.nixosModules.mixins-terminfo
        ./myhost.nix
      ];
    };
  };
}
```

## nix-ld (Unpatched Dynamic Binaries)

nix-ld provides a shim that lets you run unpatched precompiled dynamic binaries on NixOS. It places a linker at the standard Linux path (`/lib64/ld-linux-x86-64.so.2`) that delegates to the Nix store linker via `NIX_LD` and `NIX_LD_LIBRARY_PATH`.

### When to use nix-ld

- Running binaries downloaded via third-party package managers (vscode extensions, pip, npm) without patching each update
- Running games or proprietary software that verifies its integrity
- Running programs too large for the Nix store (e.g. FPGA IDEs)

### Enable on NixOS

```nix
{ pkgs, ... }:
{
  programs.nix-ld.enable = true;
  # Extra libraries on top of the default set (systemd, nix and common libs)
  programs.nix-ld.libraries = with pkgs; [ zlib openssl ];
}
```

The module installs the shim as the system `ld.so` and sets `NIX_LD` and `NIX_LD_LIBRARY_PATH` as session variables pointing at `/run/current-system/sw/share/nix-ld/lib`, so unpatched binaries work in login sessions without extra setup. Set `NIX_LD_LOG=debug` to troubleshoot.

### Comparison with buildFHSEnv

nix-ld is lighter than `buildFHSEnv` (the old `buildFHSUserEnv` name is gone), which creates a full FHS sandbox. It works with direnv and doesn't break setuid binaries or other sandbox tools like bwrap.

## Stylix (System-Wide Theming)

Stylix is a theming framework for NixOS, Home Manager, nix-darwin, and Nix-on-Droid that applies a single color scheme, wallpaper, and font set across all supported applications. Unlike nix-colors or base16.nix which just provide color palettes, Stylix automatically applies themes to each application.

### Basic Configuration

```nix
{ pkgs, ... }:
{
  # Required: Stylix does nothing until enabled
  stylix.enable = true;

  # Pick a base16 color scheme
  stylix.base16Scheme = "${pkgs.base16-schemes}/share/themes/dracula.yaml";

  # Or use a built-in scheme
  # stylix.base16Scheme = "${pkgs.base16-schemes}/share/themes/gruvbox-dark-hard.yaml";

  # Set a wallpaper
  stylix.image = ./wallpaper.png;

  # Targets are auto-enabled when the app is installed (stylix.autoEnable = true).
  # Opt out per target, or set stylix.autoEnable = false and enable them one by one.
  stylix.targets.gnome.enable = false;

  # Fonts
  stylix.fonts = {
    monospace = {
      name = "JetBrains Mono";
      package = pkgs.jetbrains-mono;
    };
    sansSerif = {
      name = "Inter";
      package = pkgs.inter;
    };
  };
}
```

### Flake Integration

```nix
{
  # master is rolling and tracks nixos-unstable; on stable NixOS use the matching
  # branch, e.g. "github:nix-community/stylix/release-26.05"
  inputs.stylix.url = "github:nix-community/stylix";
  inputs.stylix.inputs.nixpkgs.follows = "nixpkgs";

  outputs = { self, nixpkgs, stylix }: {
    nixosConfigurations.myhost = nixpkgs.lib.nixosSystem {
      modules = [
        stylix.nixosModules.stylix
        ./configuration.nix
      ];
    };
  };
}
```

Stylix supports NixOS (`nixosModules.stylix`), Home Manager (`homeModules.stylix`; the old `homeManagerModules` output only warns and is dropped after 26.05), nix-darwin (`darwinModules.stylix`), and Nix-on-Droid (`nixOnDroidModules.stylix`). The NixOS and darwin modules wire up the Home Manager module automatically when Home Manager is imported as a module. Stylix warns when its release does not match NixOS, Home Manager or nix-darwin (`stylix.enableReleaseChecks`), so keep all inputs on the same release and update them together.

## nixos-generators (Deprecated — use nixos-rebuild build-image)

As of NixOS 25.05, most of nixos-generators has been upstreamed into nixpkgs, and the nixos-generators repository is now archived. Use `nixos-rebuild build-image` instead:

```bash
# Build an ISO image (replaces nixos-generate --format iso)
nixos-rebuild build-image --image-variant iso

# From a flake
nixos-rebuild build-image --image-variant iso --flake .#myhost
```

Supported image variants in nixpkgs (26.05) include: `iso`, `iso-installer`, `sd-card`, `kexec`, `qemu`, `qemu-efi`, `raw`, `raw-efi`, `amazon`, `azure`, `digital-ocean`, `google-compute`, `hyperv`, `kubevirt`, `linode`, `lxc`, `lxc-metadata`, `oci`, `openstack`, `openstack-zfs`, `proxmox`, `proxmox-lxc`, `cloudstack`, `virtualbox`, `vagrant-virtualbox`, `vmware`. The names differ from nixos-generators formats (for example `do` is now `digital-ocean`, `gce` is `google-compute`, `qcow` is `qemu`).

For custom image configurations, expose the image as a flake output:

```nix
packages.x86_64-linux.myhost-iso =
  self.nixosConfigurations.myhost.config.system.build.images.iso;
```
