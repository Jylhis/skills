---
name: home-manager
description: "Use for Home Manager module patterns including home.nix, home.packages, home-manager programs modules, home.file, xdg configuration, declarative dotfiles, user configuration, home-manager switch, homeConfigurations, nix-darwin integration, programs.git, programs.zsh, programs.neovim, programs.direnv, home.stateVersion, or flake-based Home Manager."
user-invocable: false
---

# Home Manager

Home Manager manages user-level configuration and dotfiles declaratively with Nix.

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

  # Packages
  home.packages = with pkgs; [
    ripgrep
    fd
    bat
    jq
    htop
  ];

  # Let Home Manager manage itself
  programs.home-manager.enable = true;
}
```

## Programs Module

Most programs have dedicated modules with typed options:

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

  # Symlink (for mutable files)
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
    # These set XDG_CONFIG_HOME, XDG_DATA_HOME, etc.
    configHome = "${config.home.homeDirectory}/.config";
    dataHome = "${config.home.homeDirectory}/.local/share";
    cacheHome = "${config.home.homeDirectory}/.cache";

    # Manage XDG user directories
    userDirs = {
      enable = true;
      documents = "${config.home.homeDirectory}/Documents";
      download = "${config.home.homeDirectory}/Downloads";
    };
  };
}
```

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

```nix
{
  # Homebrew casks managed declaratively
  home.packages = with pkgs; [
    # Use nixpkgs for CLI tools
    ripgrep fd
  ];

  # macOS defaults via targets
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
```

## Querying Options

If the mcp-nixos MCP server is available, use it for Home Manager option lookups across all 5K+ options.
