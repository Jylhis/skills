---
name: nix-darwin
description: "Use for nix-darwin macOS system configuration including darwin-rebuild, system.defaults, Dock settings, Finder settings, trackpad settings, keyboard settings, launchd services, Homebrew cask integration via nix-homebrew, nix-darwin modules, environment.systemPackages, nix-darwin with home-manager, flake-based nix-darwin setup, or macOS declarative configuration."
user-invocable: false
---

# nix-darwin -- Declarative macOS Configuration

nix-darwin brings NixOS-style declarative configuration to macOS. It uses the same module system as NixOS: options, types, mkIf, mkMerge, mkDefault. It manages system settings, packages, services, and integrates with Home Manager for per-user configuration.

Repository: https://github.com/LnL7/nix-darwin

## Flake-Based Setup

A typical flake.nix with nix-darwin and home-manager:

```nix
{
  description = "macOS system configuration";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixpkgs-unstable";
    nix-darwin = {
      url = "github:LnL7/nix-darwin";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    home-manager = {
      url = "github:nix-community/home-manager";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs = { self, nixpkgs, nix-darwin, home-manager, ... }: {
    darwinConfigurations."my-mac" = nix-darwin.lib.darwinSystem {
      system = "aarch64-darwin";  # or "x86_64-darwin"
      modules = [
        ./configuration.nix
        home-manager.darwinModules.home-manager
        {
          home-manager.useGlobalPkgs = true;
          home-manager.useUserPackages = true;
          home-manager.users.myuser = import ./home.nix;
        }
      ];
    };
  };
}
```

## System Configuration

### Packages and Nix Settings

```nix
{ pkgs, ... }: {
  # System packages available to all users
  environment.systemPackages = with pkgs; [
    vim
    git
    curl
    ripgrep
    fd
  ];

  # Nix daemon and flake settings
  nix.settings = {
    experimental-features = [ "nix-command" "flakes" ];
    trusted-users = [ "root" "@admin" ];
  };

  # Required: set the state version
  system.stateVersion = 5;

  # Allow Touch ID for sudo
  security.pam.services.sudo_local.touchIdAuth = true;

  # Set primary user (required for some features)
  users.primaryUser = "myuser";
}
```

## system.defaults -- macOS Settings

nix-darwin exposes macOS defaults as typed Nix options. Changes apply on `darwin-rebuild switch`. See `references/defaults.md` for the complete reference.

### NSGlobalDomain

```nix
system.defaults.NSGlobalDomain = {
  AppleShowAllExtensions = true;
  AppleInterfaceStyle = "Dark";           # null for Light
  KeyRepeat = 2;                          # lower = faster (default 6)
  InitialKeyRepeat = 15;                  # lower = shorter delay (default 25)
  ApplePressAndHoldEnabled = false;       # false enables key repeat
  NSAutomaticCapitalizationEnabled = false;
  NSAutomaticSpellingCorrectionEnabled = false;
  NSDocumentSaveNewDocumentsToCloud = false;
};
```

### Dock

```nix
system.defaults.dock = {
  autohide = true;
  autohide-delay = 0.0;                  # no delay before showing
  autohide-time-modifier = 0.4;          # animation speed
  orientation = "bottom";                 # "left", "bottom", "right"
  show-recents = false;
  tilesize = 48;
  mru-spaces = false;                     # don't rearrange Spaces
  minimize-to-application = true;
  static-only = false;                    # true = only show running apps
  show-process-indicators = true;
  # Hot corners: 0=disabled, 2=Mission Control, 4=Desktop, 5=Screensaver
  wvous-bl-corner = 1;
  wvous-br-corner = 1;
  wvous-tl-corner = 1;
  wvous-tr-corner = 1;
};
```

### Finder

```nix
system.defaults.finder = {
  AppleShowAllExtensions = true;
  AppleShowAllFiles = true;               # show hidden files
  CreateDesktop = false;                  # hide desktop icons
  FXPreferredViewStyle = "clmv";          # "icnv", "Nlsv", "clmv", "Flwv"
  ShowPathbar = true;
  ShowStatusBar = true;
  _FXShowPosixPathInTitle = true;
  _FXSortFoldersFirst = true;
  FXDefaultSearchScope = "SCcf";          # search current folder
};
```

### Trackpad

```nix
system.defaults.trackpad = {
  Clicking = true;                        # tap to click
  TrackpadRightClick = true;              # two-finger right click
  TrackpadThreeFingerDrag = true;         # three-finger drag
};
```

### Other Defaults

```nix
# Login window
system.defaults.loginwindow = {
  GuestEnabled = false;
  SHOWFULLNAME = false;
};

# Screenshots
system.defaults.screencapture = {
  location = "~/Screenshots";
  type = "png";                           # "png", "jpg", "pdf"
  disable-shadow = true;
};

# Sonoma+ Stage Manager
system.defaults.WindowManager = {
  EnableStandardClickToShowDesktop = false;
};
```

## Services

### Launchd Services

nix-darwin can manage launchd daemons and agents:

```nix
# System-level daemon
launchd.daemons.my-daemon = {
  serviceConfig = {
    ProgramArguments = [ "/path/to/program" "--flag" ];
    RunAtLoad = true;
    KeepAlive = true;
    StandardOutPath = "/var/log/my-daemon.log";
    StandardErrorPath = "/var/log/my-daemon.err";
  };
};

# User-level agent
launchd.agents.my-agent = {
  serviceConfig = {
    ProgramArguments = [ "/path/to/agent" ];
    RunAtLoad = true;
    KeepAlive = false;
    StartInterval = 3600;  # run every hour
  };
};
```

### Window Management (yabai + skhd)

```nix
services.yabai = {
  enable = true;
  config = {
    layout = "bsp";
    window_gap = 10;
    top_padding = 10;
    bottom_padding = 10;
    left_padding = 10;
    right_padding = 10;
  };
  extraConfig = ''
    yabai -m rule --add app="System Settings" manage=off
  '';
};

services.skhd = {
  enable = true;
  skhdConfig = ''
    alt - h : yabai -m window --focus west
    alt - l : yabai -m window --focus east
    alt - j : yabai -m window --focus south
    alt - k : yabai -m window --focus north
  '';
};
```

### Karabiner-Elements

```nix
services.karabiner-elements.enable = true;
# Configuration still managed via ~/.config/karabiner/karabiner.json
# or home-manager xdg.configFile
```

## Homebrew Integration

Many GUI apps (casks) are not in nixpkgs. Use nix-homebrew or the homebrew-cask module to manage them declaratively:

```nix
# Using nix-darwin's built-in homebrew module
homebrew = {
  enable = true;
  onActivation = {
    autoUpdate = true;
    cleanup = "zap";          # remove unlisted casks/formulae
    upgrade = true;
  };
  casks = [
    "firefox"
    "1password"
    "raycast"
    "iterm2"
    "docker"
  ];
  brews = [
    # Formulae that aren't in nixpkgs or need macOS-specific builds
  ];
  taps = [
    "homebrew/cask"
  ];
};
```

For nix-homebrew (manages Homebrew installation itself via Nix):

```nix
# In flake inputs:
#   nix-homebrew.url = "github:zhaofengli/nix-homebrew";
# In modules list:
#   nix-homebrew.darwinModules.nix-homebrew

nix-homebrew = {
  enable = true;
  user = "myuser";
  autoMigrate = true;
};
```

## darwin-rebuild

```sh
# Build and activate the configuration
darwin-rebuild switch --flake .#my-mac

# Build without activating (dry run)
darwin-rebuild build --flake .#my-mac

# Check configuration for errors
darwin-rebuild check --flake .#my-mac

# Debug build failures
darwin-rebuild switch --flake .#my-mac --show-trace
```

After initial setup, the `darwin-rebuild` command is available system-wide.

## Hybrid Architecture Integration

In the npins + devenv + flake pattern, nix-darwin is a **module flake** -- it consumes nixpkgs and produces system configuration. The typical integration:

- **npins** pins nixpkgs and other inputs for non-flake evaluation
- **devenv** provides the development shell (orthogonal to system config)
- **flake.nix** is the thin wrapper that wires nix-darwin, home-manager, and nixpkgs together

The nix-darwin flake.nix is usually a separate repo from project devenv configs. It lives in a dedicated system-configuration repository.

See the `nix-hybrid` skill for the full npins + devenv + flake architecture pattern.

## Cross-References

- **home-manager** -- per-user dotfiles and program configuration (programs.*, home.file, xdg)
- **nixos-modules** -- shared module patterns (mkOption, mkIf, mkMerge) that apply identically in nix-darwin
- **nix-hybrid** -- the npins + devenv + flake architecture for combining multiple Nix tools
- **flakes** -- flake.nix structure, inputs, outputs, follows

## MCP Tooling

If the `mcp-nixos` MCP server is available, use it for nix-darwin option lookups. Query darwin options the same way you would NixOS options -- the server indexes nix-darwin options alongside NixOS options.
