# Nix-on-Droid

Nix-on-Droid brings the Nix package manager and a module system to
Android devices. It provides a bootstrap installer that installs the
Nix package manager on Android along with a `nix-on-droid` executable,
and a module system for configuring the local installation.

Tested with aarch64 (64-bit ARM). Not available for 32-bit ARM. It needs no
root, user namespaces or SELinux changes; it runs on `proot` inside a fork of
the Termux terminal-emulator app (unrelated to the Termux distro).

Release status (October 2026): the latest stable branch is `release-24.05`
(released July 2024). A `prerelease-25.11` branch exists but has not been
released; `master` is still active. The examples below use `24.05`,
matching that branch.

## Installation

Install the app from F-Droid (package `com.termux.nix`,
<https://f-droid.org/packages/com.termux.nix>), launch it and press OK.
The app then downloads a bootstrap zipball and builds the environment.
Expect several hundred MB of downloads on first run.

To use a custom bootstrap, build it on an x86_64 machine with
`nix build ".#bootstrapZip-aarch64" --impure` from the repo, serve the zip
over HTTP and enter its parent URL during installation.

Activate configuration changes on the device with `nix-on-droid switch`;
`nix-on-droid rollback` returns to the previous generation.

## Configuration

### Config File

Nix-on-Droid is managed through `~/.config/nixpkgs/nix-on-droid.nix`:

```nix
{ pkgs, ... }:

{
  environment.packages = [ pkgs.vim pkgs.git pkgs.curl ];
  system.stateVersion = "24.05";
}
```

### Alternative Location

Alternatively, `~/.config/nixpkgs/config.nix` with a `nix-on-droid` key:

```nix
{
  nix-on-droid =
    { pkgs, ... }:

    {
      environment.packages = [ pkgs.vim ];
      system.stateVersion = "24.05";
    };
}
```

## Flakes

```nix
{
  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-24.05";
    nix-on-droid = {
      url = "github:nix-community/nix-on-droid/release-24.05";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs = { self, nixpkgs, nix-on-droid }: {
    nixOnDroidConfigurations.default = nix-on-droid.lib.nixOnDroidConfiguration {
      pkgs = import nixpkgs { system = "aarch64-linux"; };   # mandatory since 24.05
      modules = [ ./nix-on-droid.nix ];
    };
  };
}
```

Apply with `nix-on-droid switch --flake path/to/flake#device` (expands to
`nixOnDroidConfigurations.device`; without `#device` it uses `default`).
Flake evaluation is always run with `--impure` because the proot store path
is hardcoded. Templates: `nix flake init --template github:nix-community/nix-on-droid#advanced`.

## Available Options

Key configuration options (see <https://nix-community.github.io/nix-on-droid/>
for the full list):

| Option | Purpose |
|--------|---------|
| `environment.packages` | Packages to install in the Nix-on-Droid environment |
| `system.stateVersion` | Nix-on-Droid release version (set once, don't change) |
| `user.shell` | Login shell for the user |
| `nixpkgs.config.allowUnfree` | Allow unfree packages |
| `nix.settings.experimental-features` | Experimental Nix features |
| `android-integration.*` | Termux-style helpers (`termux-open-url`, `termux-setup-storage`, `xdg-open`, ...) (24.05+) |

## Home Manager Integration

Nix-on-Droid integrates with home-manager for per-user dotfile
management. With channels, first add the matching home-manager channel
(`nix-channel --add https://github.com/nix-community/home-manager/archive/release-24.05.tar.gz home-manager && nix-channel --update`); with flakes, pass home-manager as an input.

```nix
{ pkgs, ... }:

{
  system.stateVersion = "24.05";

  environment.packages = [ pkgs.vim ];

  home-manager.config =
    { pkgs, ... }:
    {
      home.stateVersion = "24.05";
      programs.git = {
        enable = true;
        userName = "My Name";   # HM 25.11+: settings.user.name
      };
    };
}
```

`home-manager.config` also accepts a path, e.g. `home-manager.config = ./home.nix;`.

## Stylix Integration

Stylix supports Nix-on-Droid. Add its module in the flake and enable it in
the config; it themes the terminal colours and monospace font, and sets up
the Home Manager modules automatically when Home Manager integration is used:

```nix
# flake.nix (outputs)
nixOnDroidConfigurations.default = nix-on-droid.lib.nixOnDroidConfiguration {
  pkgs = nixpkgs.legacyPackages.aarch64-linux;
  modules = [
    stylix.nixOnDroidModules.stylix
    ./nix-on-droid.nix
  ];
};
```

```nix
# nix-on-droid.nix
{ pkgs, ... }:

{
  stylix.enable = true;   # required: Stylix does nothing until enabled
  stylix.base16Scheme = "${pkgs.base16-schemes}/share/themes/dracula.yaml";
}
```

## Limitations

- Only aarch64 is tested; i686 is no longer built
- No KVM — builds run on-device or via distributed builds
- The Nix store lives in the app's private data directory
- The terminal is the bundled Nix-on-Droid app (a Termux-app fork); do not
  report Nix-on-Droid issues to Termux
- `proot` cannot be built on the device; it comes from the
  `nix-on-droid.cachix.org` cache or the bootstrap zipball
- If the terminal freezes, use "Acquire wakelock" in the notification or
  relax Android power saving
