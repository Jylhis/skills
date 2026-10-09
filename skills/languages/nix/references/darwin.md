# nix-darwin -- Declarative macOS Configuration

nix-darwin brings NixOS-style declarative configuration to macOS. It uses the same module system as NixOS: options, types, mkIf, mkMerge, mkDefault. It manages system settings, packages, services, and integrates with Home Manager for per-user configuration.

Repository: <https://github.com/nix-darwin/nix-darwin> (moved from `LnL7/nix-darwin`; the old URL redirects, but update flake inputs to the new owner).

Release branches track Nixpkgs releases: `nix-darwin-25.05`, `nix-darwin-25.11`, `nix-darwin-26.05`. Pair `nix-darwin-26.05` with `nixpkgs-26.05-darwin`, and `master` with `nixpkgs-unstable`. Do not mix a release branch of one with the unstable branch of the other.

## Flake-Based Setup

A typical flake.nix with nix-darwin and home-manager:

```nix
{
  description = "macOS system configuration";

  inputs = {
    # Stable: github:NixOS/nixpkgs/nixpkgs-26.05-darwin
    nixpkgs.url = "github:NixOS/nixpkgs/nixpkgs-unstable";
    nix-darwin = {
      # Stable: github:nix-darwin/nix-darwin/nix-darwin-26.05
      url = "github:nix-darwin/nix-darwin/master";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    home-manager = {
      url = "github:nix-community/home-manager";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs = { self, nixpkgs, nix-darwin, home-manager, ... }: {
    darwinConfigurations."my-mac" = nix-darwin.lib.darwinSystem {
      modules = [
        ./configuration.nix
        { nixpkgs.hostPlatform = "aarch64-darwin"; }  # or "x86_64-darwin" (Intel)
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

Intel Macs: Nixpkgs 26.05 is the last release that supports `x86_64-darwin`. Binaries are built until 26.05 goes out of support at the end of 2026; Nixpkgs 26.11 drops the platform. Keep Intel machines on the 26.05 branches (`nixpkgs-26.05-darwin`, `nix-darwin-26.05`) until they are retired.

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

  # Pin at first install, then leave it. nix-darwin 26.05 accepts up to 7;
  # run `darwin-rebuild changelog` before raising it.
  system.stateVersion = 6;

  # Allow Touch ID for sudo
  security.pam.services.sudo_local.touchIdAuth = true;

  # User that per-user options apply to (activation itself runs as root).
  # Transitional: upstream plans to remove it once those options move under
  # users.users.* or to Home Manager.
  system.primaryUser = "myuser";
}
```

### Root Activation and `system.primaryUser`

Since May 2025 (pinned announcement: nix-darwin/nix-darwin#1457), the whole activation runs as root. `darwin-rebuild switch`, `activate`, `check` and `--rollback` refuse to run without root, so use `sudo darwin-rebuild switch`. `darwin-rebuild build` still works unprivileged. `system.activationScripts.{preUserActivation,extraUserActivation,postUserActivation}` were removed; every activation script now runs as root, so move per-user setup to Home Manager (`home.activation`).

Options that used to act on "the user running darwin-rebuild" now act on `system.primaryUser`. Evaluation fails with a list of the offending options when one is set and `system.primaryUser` is not. The set includes:

- the per-user `system.defaults.*` domains: `NSGlobalDomain`, `.GlobalPreferences`, `dock`, `finder`, `trackpad`, `screencapture`, `screensaver`, `spaces`, `menuExtraClock`, `hitoolbox`, `magicmouse`, `universalaccess`, `ActivityMonitor`, `LaunchServices`, `WindowManager`, `controlcenter`, and `CustomUserPreferences`
- `launchd.user.agents.*` and `launchd.user.envVariables.*`
- `homebrew.enable` (unless `homebrew.user` is set) and `programs.mas.enable` (unless `programs.mas.user` is set)

System-scope domains (`loginwindow`, `smb`, `SoftwareUpdate`, `CustomSystemPreferences`) do not need it.

### Determinate Nix

Determinate Nix manages the Nix installation with its own daemon, which conflicts with nix-darwin's native Nix management. nix-darwin aborts activation when it detects `determinate-nixd`; opt out of nix-darwin's Nix management:

```nix
{
  nix.enable = false;  # nix-darwin stops managing the Nix install, daemon and nix.conf
}
```

With `nix.enable = false`, the `nix.*` options that manage the installation (`nix.settings`, `nix.linux-builder`, `nix.gc.automatic`, ...) are unavailable; configure Nix through Determinate instead and upgrade it yourself.

## system.defaults -- macOS Settings

nix-darwin exposes macOS defaults as typed Nix options. Changes apply on `sudo darwin-rebuild switch`; the per-user domains are written for `system.primaryUser`. See `darwin/defaults.md` for the complete reference.

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
# System-level daemon (/Library/LaunchDaemons, runs as root)
launchd.daemons.my-daemon = {
  serviceConfig = {
    ProgramArguments = [ "/path/to/program" "--flag" ];
    RunAtLoad = true;
    KeepAlive = true;
    StandardOutPath = "/var/log/my-daemon.log";
    StandardErrorPath = "/var/log/my-daemon.err";
  };
};

# Agent for every user's login session (/Library/LaunchAgents)
launchd.agents.my-agent = {
  serviceConfig = {
    ProgramArguments = [ "/path/to/agent" ];
    RunAtLoad = true;
    KeepAlive = false;
    StartInterval = 3600;  # run every hour
  };
};

# Agent in the primary user's ~/Library/LaunchAgents (requires system.primaryUser)
launchd.user.agents.my-user-agent = {
  serviceConfig = {
    ProgramArguments = [ "/path/to/agent" ];
    RunAtLoad = true;
  };
};
```

Per-user agents for other users belong in Home Manager (`launchd.agents` in a Home Manager config).

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
  # user = "myuser";          # defaults to system.primaryUser
  onActivation = {
    autoUpdate = true;
    cleanup = "zap";          # "none" | "check" | "uninstall" | "zap"
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
    # Third-party taps only. homebrew/core and homebrew/cask have not needed
    # tapping since Homebrew 4.0.
  ];
};
```

Recent `homebrew` module changes (nix-darwin CHANGELOG, 2026-02-10):

- `homebrew.brewPrefix` was replaced by `homebrew.prefix`, which points at the prefix (`/opt/homebrew`, as `brew --prefix` prints), not the `bin` directory.
- `homebrew.whalebrews` was removed (Homebrew Bundle dropped Whalebrew in 4.7.0). `homebrew.global.lockfiles`/`noLock` no longer do anything.
- `onActivation.cleanup = "check"` aborts activation when unlisted packages are installed, without removing them.
- New entry types `homebrew.goPackages`, `homebrew.cargoPackages`, `homebrew.vscode`, and shell integration via `homebrew.enable{Bash,Zsh,Fish}Integration`.

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
# First install (darwin-rebuild is not on PATH yet)
sudo nix run nix-darwin/master#darwin-rebuild -- switch --flake .#my-mac
# or, for the stable branch: nix-darwin/nix-darwin-26.05#darwin-rebuild

# Build and activate the configuration (activation requires root)
sudo darwin-rebuild switch --flake .#my-mac

# Build without activating (no root needed)
darwin-rebuild build --flake .#my-mac

# Check configuration for errors (runs activation checks, needs root)
sudo darwin-rebuild check --flake .#my-mac

# Debug build failures
sudo darwin-rebuild switch --flake .#my-mac --show-trace

# Show stateVersion-gated changes
darwin-rebuild changelog
```

After initial setup, the `darwin-rebuild` command is available system-wide. Without `--flake`, it uses `/etc/nix-darwin/flake.nix` if present (the default configuration location for new installs).

## Hybrid Architecture Integration

In the flake-compat + devenv pattern, nix-darwin is a **module flake** -- it consumes nixpkgs and produces system configuration. The typical integration:

- **flake.lock** is the single source of truth for all pinned inputs
- **devenv** provides the development shell (orthogonal to system config)
- **flake.nix** is the thin wrapper that wires nix-darwin, home-manager, and nixpkgs together
- **default.nix** is a flake-compat shim for non-flake consumers

The nix-darwin flake.nix is usually a separate repo from project devenv configs. It lives in a dedicated system-configuration repository.

See the `nix-hybrid` skill for the full flake-compat + devenv architecture pattern.

## Cross-References

- **home-manager** -- per-user dotfiles and program configuration (programs.*, home.file, xdg)
- **nixos-modules** -- shared module patterns (mkOption, mkIf, mkMerge) that apply identically in nix-darwin
- **nix-hybrid** -- the flake-compat + devenv architecture for combining multiple Nix tools
- **flakes** -- flake.nix structure, inputs, outputs, follows

## MCP Tooling

If the `mcp-nixos` MCP server is available, use it for nix-darwin option lookups. Query darwin options the same way you would NixOS options -- the server indexes nix-darwin options alongside NixOS options.
