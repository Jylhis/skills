---
name: nixos-modules
description: "Use for NixOS module system patterns including configuration.nix, writing modules, mkOption, mkIf, mkMerge, mkEnableOption, mkDefault, mkForce, mkPackageOption, services, systemd units, systemd hardening, networking, firewall, fileSystems, boot, option types, types.submodule, imports, or module arguments."
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
| `config` | The final merged configuration |
| `lib` | nixpkgs library functions |
| `pkgs` | The package set |
| `options` | All declared options (for introspection) |
| `modulesPath` | Path to NixOS modules directory |

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
services.foo.port = lib.mkDefault 8080;     # Low priority (overridable)
services.foo.port = lib.mkForce 9090;       # High priority (overrides everything)
services.foo.port = lib.mkOverride 50 9090; # Custom priority (lower number = higher priority)
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
    ReadWritePaths = [ "/var/lib/myapp" ];
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

## File Layout

A typical NixOS configuration:

```
/etc/nixos/
├── configuration.nix     # Main entry point
├── hardware-configuration.nix  # Auto-generated
├── modules/
│   ├── base.nix          # Common settings
│   ├── networking.nix
│   ├── services/
│   │   ├── nginx.nix
│   │   └── postgresql.nix
│   └── users.nix
```

Import modules:

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
# Search options online: search.nixos.org/options
# Or via CLI:
nixos-option services.nginx
```

If the mcp-nixos MCP server is available, use it for richer option lookups across NixOS, Home Manager, and nix-darwin.

## Testing

```bash
# Build without switching
nixos-rebuild build

# Build and switch
sudo nixos-rebuild switch

# Test in a VM
nixos-rebuild build-vm
```
