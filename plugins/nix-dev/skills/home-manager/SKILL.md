---
name: home-manager
description: "Use for Home Manager module patterns including home.nix, home.packages, home-manager programs modules, home.file, xdg configuration, declarative dotfiles, user configuration, home-manager switch, homeConfigurations, nix-darwin integration, programs.git, programs.zsh, programs.neovim, programs.direnv, home.stateVersion, flake-based Home Manager, home.activation, impermanence, or overlay usage in Home Manager."
user-invocable: false
---

# Home Manager

## Setup Modes

| Mode | Entry point | Command |
|------|-------------|---------|
| Standalone | `~/.config/home-manager/home.nix` | `home-manager switch` |
| NixOS module | Inside `nixosConfigurations` | `nixos-rebuild switch` |
| Flake standalone | `flake.nix` → `homeConfigurations` | `home-manager switch --flake .` |
| nix-darwin module | Inside `darwinConfigurations` | `darwin-rebuild switch` |

## Basic Configuration

```nix
{ config, pkgs, lib, ... }:

{
  home.username = "markus";
  home.homeDirectory = "/home/markus";
  home.stateVersion = "24.05";  # Don't change after initial setup

  home.packages = with pkgs; [
    ripgrep
    fd
    bat
    jq
    htop
  ];

  programs.home-manager.enable = true;
}
```

## Programs Modules

See `references/programs.md` for the top 20 programs with config examples.

```nix
{
  programs.git = {
    enable = true;
    userName = "Markus";
    userEmail = "markus@example.com";
    extraConfig = {
      init.defaultBranch = "main";
      pull.rebase = true;
    };
    delta.enable = true;
  };

  programs.zsh = {
    enable = true;
    autosuggestion.enable = true;
    syntaxHighlighting.enable = true;
    shellAliases = {
      ll = "ls -la";
      g = "git";
    };
    initExtra = ''
      # Custom zsh config
    '';
  };

  programs.starship = {
    enable = true;
    settings = {
      add_newline = false;
      character.success_symbol = "[➜](bold green)";
    };
  };

  programs.direnv = {
    enable = true;
    nix-direnv.enable = true;
  };

  programs.neovim = {
    enable = true;
    defaultEditor = true;
    plugins = with pkgs.vimPlugins; [
      telescope-nvim
      nvim-treesitter.withAllGrammars
    ];
    extraLuaConfig = builtins.readFile ./nvim/init.lua;
  };
}
```

## File Management

```nix
{
  # Copy file to ~/.config/foo/config.toml
  xdg.configFile."foo/config.toml".source = ./config/foo.toml;

  # Write inline content
  home.file.".sqliterc".text = ''
    .mode column
    .headers on
  '';

  # Symlink (for mutable files that need to be edited in place)
  xdg.configFile."foo/state".source =
    config.lib.file.mkOutOfStoreSymlink
      "${config.home.homeDirectory}/.local/share/foo/state";
}
```

## XDG Directories

```nix
{
  xdg = {
    enable = true;
    configHome = "${config.home.homeDirectory}/.config";
    dataHome = "${config.home.homeDirectory}/.local/share";
    cacheHome = "${config.home.homeDirectory}/.cache";

    userDirs = {
      enable = true;
      documents = "${config.home.homeDirectory}/Documents";
      download = "${config.home.homeDirectory}/Downloads";
    };
  };
}
```

## Activation Scripts

Run custom commands when Home Manager activates:

```nix
{
  home.activation = {
    setupDirs = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
      mkdir -p $HOME/Projects
      mkdir -p $HOME/.local/bin
    '';
  };
}
```

`writeBoundary` is the activation step that writes Home Manager's managed files. Use `entryAfter [ "writeBoundary" ]` for scripts that should run after files are placed, `entryBefore [ "writeBoundary" ]` for scripts that should run before.

## Overlay Usage

Apply overlays to the package set used by Home Manager:

```nix
# In a standalone Home Manager flake
homeConfigurations."markus" = home-manager.lib.homeManagerConfiguration {
  pkgs = import nixpkgs {
    system = "x86_64-linux";
    overlays = [ (import ./overlay.nix) ];
  };
  modules = [ ./home.nix ];
};
```

Within a NixOS/nix-darwin module, overlays are applied at the system level and Home Manager inherits them via `useGlobalPkgs`.

## Impermanence Integration

With the impermanence Home Manager module, declare which user files persist across reboots:

```nix
{
  home.persistence."/persist/home/markus" = {
    directories = [
      "Projects"
      ".ssh"
      ".gnupg"
      ".local/share/direnv"
    ];
    files = [
      ".zsh_history"
    ];
    allowOther = true;
  };
}
```

See the nixos-modules skill for the system-level impermanence pattern.

## Services (Linux)

```nix
{
  services.syncthing.enable = true;

  services.gpg-agent = {
    enable = true;
    enableSshSupport = true;
    pinentryPackage = pkgs.pinentry-curses;
  };

  systemd.user.services.myservice = {
    Unit.Description = "My background service";
    Service = {
      ExecStart = "${pkgs.myapp}/bin/myapp";
      Restart = "on-failure";
    };
    Install.WantedBy = [ "default.target" ];
  };
}
```

## macOS (nix-darwin) Specifics

On macOS, Home Manager runs as a nix-darwin module. See the nix-darwin skill for system-level configuration.

```nix
{
  home.packages = with pkgs; [ ripgrep fd ];

  targets.darwin.defaults = {
    "com.apple.dock" = {
      autohide = true;
      mru-spaces = false;
    };
  };
}
```

## Flake Integration

```nix
# flake.nix
{
  outputs = { nixpkgs, home-manager, ... }: {
    homeConfigurations."markus" = home-manager.lib.homeManagerConfiguration {
      pkgs = nixpkgs.legacyPackages.x86_64-linux;
      modules = [
        ./home.nix
        {
          home.username = "markus";
          home.homeDirectory = "/home/markus";
        }
      ];
    };
  };
}
```

## CLI Commands

```bash
home-manager switch                  # Apply configuration
home-manager switch --flake .#markus # Apply from flake
home-manager generations             # List generations
home-manager packages                # List installed packages
home-manager news                    # Show news/changelog
home-manager expire-generations -7   # Remove generations older than 7 days
```

## Troubleshooting

- **`stateVersion` errors**: Never change `home.stateVersion` after initial setup. It controls migration behavior, not the version of packages.
- **PATH issues**: Ensure `programs.home-manager.enable = true;` is set. If using with nix-darwin/NixOS, set `home-manager.useGlobalPkgs = true;`.
- **Service not starting**: On Linux, check `systemctl --user status <service>`. Ensure the service's `WantedBy` target is correct.
- **File conflicts**: If a managed file already exists and wasn't created by Home Manager, move it first. Home Manager refuses to overwrite unmanaged files.
- **Slow builds**: Use `home-manager switch --show-trace` to diagnose. Large `programs.neovim.plugins` or `programs.emacs.extraPackages` lists are common culprits.

## Querying Options

If the mcp-nixos MCP server is available, use it for Home Manager option lookups across all 5K+ options.

## Related Skills

- **nix-darwin** — macOS system-level configuration
- **nixos-modules** — shares the same module system patterns
