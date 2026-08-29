# Nix-on-Droid

Nix-on-Droid brings the Nix package manager and a module system to
Android devices. It provides a bootstrap installer that installs the
Nix package manager on Android along with a `nix-on-droid` executable,
and a module system for configuring the local installation.

Tested with aarch64 (64-bit ARM). Not available for 32-bit ARM.

## Installation

Install from F-Droid or build from source:

```bash
# From F-Droid
# Search for "Nix" in F-Droid, or:
nix run github:nix-community/nix-on-droid -- install
```

After installation, the app bootstraps the Nix environment. Expect several
hundred MB of downloads on first run.

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

## Home Manager Integration

Nix-on-Droid integrates with home-manager for per-user dotfile
management:

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
        userName = "My Name";
      };
    };
}
```

## Stylix Integration

Stylix supports Nix-on-Droid for system-wide theming:

```nix
{ stylix, ... }:

{
  imports = [ stylix.nixOnDroidModules.stylix ];

  stylix.base16Scheme = "${pkgs.base16-schemes}/share/themes/dracula.yaml";
  stylix.image = ./wallpaper.png;
}
```

## Limitations

- Only aarch64 is tested; i686 is no longer built
- No KVM — builds run on-device or via distributed builds
- The Nix store lives in the app's private data directory
- Terminal emulators: use Termux as the host terminal
