---
name: nixos-modules
description: "Use for NixOS module system patterns including configuration.nix, writing modules, mkOption, mkIf, mkMerge, mkEnableOption, mkDefault, mkForce, mkPackageOption, services, systemd units, systemd hardening, networking, firewall, fileSystems, boot, option types, types.submodule, types.freeformType, evalModules, imports, module arguments, specialArgs, secrets management, agenix, sops-nix, impermanence, or NixOS testing."
user-invocable: false
---

# NixOS Module System

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

See `references/type-system.md` for the complete type reference (30+ types, merge functions, freeformType, priority system, mkOptionType).

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

Default priority is 100. `mkDefault` is 1000. `mkForce` is 50.

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

## Secrets Management

Secrets (passwords, API tokens, keys) must NOT go in Nix files — they end up world-readable in `/nix/store`. Use dedicated tools:

### agenix (recommended for simplicity)

Encrypts secrets with age using SSH public keys. Decrypts at system activation to `/run/agenix/`.

```nix
# secrets.nix — maps secret files to authorized keys
let keys = [ "ssh-ed25519 AAAA..." ]; in {
  "db-password.age".publicKeys = keys;
}

# configuration.nix
age.secrets.db-password.file = ./secrets/db-password.age;
# Available at config.age.secrets.db-password.path → /run/agenix/db-password
```

### sops-nix (recommended for teams)

Supports age, PGP, and cloud KMS. Integrates with sops for multi-user editing.

```nix
sops.secrets.db-password = {
  sopsFile = ./secrets/secrets.yaml;
  owner = "myapp";
};
# Available at config.sops.secrets.db-password.path
```

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

## File Layout

```
/etc/nixos/
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

See `references/testing.md` for the NixOS VM integration test framework.

## Related Skills

- **nix-darwin** — macOS equivalent using the same module system
- **home-manager** — user-level configuration with the same module patterns
- **nix-testing** — comprehensive guide to NixOS VM tests
