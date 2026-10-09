# Home Manager

## Setup Modes

| Mode | Entry point | Command |
|------|-------------|---------|
| Standalone | `~/.config/home-manager/home.nix` | `home-manager switch` |
| NixOS module | Inside `nixosConfigurations` | `nixos-rebuild switch` |
| Flake standalone | `flake.nix` → `homeConfigurations` | `home-manager switch --flake .` |
| nix-darwin module | Inside `darwinConfigurations` | `sudo darwin-rebuild switch` |

Standalone is the only option outside NixOS and nix-darwin, and is also the choice when the home directory should be updated independently of the system.

## Releases

Home Manager `master` targets `nixpkgs-unstable`. Release branches follow NixOS releases (`release-25.11`, `release-26.05`) and get fixes but usually no new modules. Match the branches: `home-manager/release-26.05` with `nixos-26.05` / `nixpkgs-26.05-darwin`, `master` with unstable. A mismatch triggers a version warning and can break on renamed options.

```nix
inputs.home-manager = {
  url = "github:nix-community/home-manager/release-26.05";
  inputs.nixpkgs.follows = "nixpkgs";
};
```

Run `home-manager news` after updating; it lists new modules, renames and behaviour changes that apply to your configuration.

## Basic Configuration

```nix
{ config, pkgs, lib, ... }:

{
  home.username = "markus";
  home.homeDirectory = "/home/markus";
  home.stateVersion = "26.05";  # Pin to the release in use at first activation; don't change afterward

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

See `home-manager/programs.md` for the top 20 programs with config examples.

```nix
{
  programs.git = {
    enable = true;
    settings = {  # was userName / userEmail / extraConfig before 25.11
      user.name = "Markus";
      user.email = "markus@example.com";
      init.defaultBranch = "main";
      pull.rebase = true;
    };
  };

  programs.delta = {  # was programs.git.delta
    enable = true;
    enableGitIntegration = true;
  };

  # Shell-agnostic aliases, applied to bash, zsh, fish, ...
  home.shellAliases.g = "git";

  programs.zsh = {
    enable = true;
    autosuggestion.enable = true;
    syntaxHighlighting.enable = true;
    shellAliases.ll = "ls -la";
    initContent = ''
      # Custom zsh config (initExtra is deprecated)
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
    initLua = builtins.readFile ./nvim/init.lua;  # extraLuaConfig before 26.05
  };
}
```

### Recent Renames

Old names still evaluate through rename shims, with a warning. Fix them when you see the warning:

| Old | New | Since |
|-----|-----|-------|
| `programs.git.userName` / `userEmail` / `aliases` | `programs.git.settings.user.name` / `.user.email` / `.alias` | 25.11 |
| `programs.git.extraConfig` | `programs.git.settings` | 25.11 |
| `programs.git.delta.*` | `programs.delta.*` + `programs.delta.enableGitIntegration = true` | 25.11 |
| `programs.zsh.initExtra` / `initExtraFirst` / `initExtraBeforeCompInit` | `programs.zsh.initContent` (with `lib.mkBefore` / `lib.mkOrder 550`) | 25.05 |
| `programs.ssh.matchBlocks` | `programs.ssh.settings` (upstream directive names) | 26.05 |
| `programs.neovim.extraLuaConfig` | `programs.neovim.initLua` | 26.05 |
| `programs.vscode.userSettings` / `extensions` / `keybindings` | `programs.vscode.profiles.default.*` | 25.05 |
| `programs.kitty.theme` | `programs.kitty.themeFile` | 24.11 |
| `services.gpg-agent.pinentryPackage` | `services.gpg-agent.pinentry.package` | 25.05 |

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
      # setSessionVariables = true;  # XDG_*_DIR env vars; default false from stateVersion 26.05
    };
  };

  # Ask modules to write config under XDG dirs instead of ~/.foo where supported
  home.preferXdgDirectories = true;
}
```

`xdg.userDirs` also works on non-Linux platforms; set `xdg.userDirs.package = null` to skip installing `xdg-user-dirs`. In `xdg.userDirs.extraConfig`, use bare names (`DESKTOP`) rather than `XDG_DESKTOP_DIR`.

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

With the impermanence Home Manager module, declare which user files persist across reboots. The module only works through the Home Manager NixOS module together with `impermanence.nixosModules.impermanence` (it is loaded automatically then). The attribute name is the persistent storage root; paths are relative to the home directory:

```nix
{
  home.persistence."/persist" = {
    directories = [
      "Projects"
      { directory = ".ssh"; mode = "0700"; }
      { directory = ".gnupg"; mode = "0700"; }
      ".local/share/direnv"
    ];
    files = [
      ".zsh_history"
    ];
  };
}
```

Real bind mounts replaced bindfs, so the old `allowOther` option and per-user `"/persist/home/<user>"` roots are gone.

See the nixos-modules skill for the system-level impermanence pattern.

## Services (Linux)

```nix
{
  services.syncthing.enable = true;

  services.gpg-agent = {
    enable = true;
    enableSshSupport = true;
    pinentry.package = pkgs.pinentry-curses;
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

On macOS, Home Manager usually runs as a nix-darwin module (standalone also works). See the nix-darwin skill for system-level configuration. With `home.stateVersion` 25.11 or later, `targets.darwin.copyApps` is on by default: apps are copied to `~/Applications/Home Manager Apps` instead of symlinked, so Spotlight finds them.

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
home-manager switch -b backup        # Move conflicting unmanaged files to <file>.backup
home-manager generations             # List generations
home-manager packages                # List installed packages
home-manager news                    # Show news/changelog
home-manager expire-generations -7   # Remove generations older than 7 days
```

## Troubleshooting

- **`stateVersion` errors**: Never change `home.stateVersion` after initial setup. It controls migration behavior, not the version of packages.
- **PATH issues**: Ensure `programs.home-manager.enable = true;` is set. If using with nix-darwin/NixOS, set `home-manager.useGlobalPkgs = true;`.
- **Service not starting**: On Linux, check `systemctl --user status <service>`. Ensure the service's `WantedBy` target is correct.
- **File conflicts**: If a managed file already exists and wasn't created by Home Manager, activation fails rather than overwrite it. Move it, run `home-manager switch -b backup`, or set `home-manager.backupFileExtension = "backup";` in the NixOS/nix-darwin module. `home-manager.backupCommand` runs a custom command (for example a move to trash) instead.
- **Slow builds**: Use `home-manager switch --show-trace` to diagnose. Large `programs.neovim.plugins` or `programs.emacs.extraPackages` lists are common culprits.

## Querying Options

If the mcp-nixos MCP server is available, use it for Home Manager option lookups across all 5K+ options.

## Related Skills

- **nix-darwin** — macOS system-level configuration
- **nixos-modules** — shares the same module system patterns
