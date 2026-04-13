# Home Manager programs.* Module Reference

Concise configuration examples for the most commonly used Home Manager program modules. Each example shows the most useful options to get started -- not exhaustive.

Full option docs: https://nix-community.github.io/home-manager/options.xhtml

## Table of Contents

1. [programs.git](#programsgit)
2. [programs.zsh](#programszsh)
3. [programs.bash](#programsbash)
4. [programs.fish](#programsfish)
5. [programs.starship](#programsstarship)
6. [programs.direnv](#programsdirenv)
7. [programs.neovim](#programsneovim)
8. [programs.emacs](#programsemacs)
9. [programs.tmux](#programstmux)
10. [programs.alacritty](#programsalacritty)
11. [programs.kitty](#programskitty)
12. [programs.firefox](#programsfirefox)
13. [programs.vscode](#programsvscode)
14. [programs.gpg](#programsgpg)
15. [programs.ssh](#programsssh)
16. [programs.fzf](#programsfzf)
17. [programs.bat](#programsbat)
18. [programs.eza](#programseza)
19. [programs.ripgrep](#programsripgrep)
20. [programs.fd](#programsfd)

---

## programs.git

```nix
programs.git = {
  enable = true;
  userName = "Your Name";
  userEmail = "you@example.com";
  extraConfig = {
    init.defaultBranch = "main";
    push.autoSetupRemote = true;
    pull.rebase = true;
    rerere.enabled = true;
  };
  delta = {
    enable = true;
    options.navigate = true;
  };
  signing = {
    key = "ABCDEF1234567890";
    signByDefault = true;
  };
};
```

## programs.zsh

```nix
programs.zsh = {
  enable = true;
  autosuggestion.enable = true;
  syntaxHighlighting.enable = true;
  shellAliases = {
    ll = "ls -la";
    gs = "git status";
    gd = "git diff";
  };
  initExtra = ''
    bindkey -e  # emacs keybindings
  '';
  oh-my-zsh = {
    enable = true;
    plugins = [ "git" "docker" "kubectl" ];
    theme = "robbyrussell";
  };
};
```

## programs.bash

```nix
programs.bash = {
  enable = true;
  shellAliases = {
    ll = "ls -la";
    ".." = "cd ..";
  };
  initExtra = ''
    export HISTSIZE=10000
  '';
  bashrcExtra = ''
    # Additional .bashrc content
  '';
};
```

## programs.fish

```nix
programs.fish = {
  enable = true;
  shellAliases = {
    ll = "ls -la";
    gs = "git status";
  };
  shellInit = ''
    set -g fish_greeting ""
  '';
  plugins = [
    {
      name = "z";
      src = pkgs.fishPlugins.z.src;
    }
  ];
};
```

## programs.starship

```nix
programs.starship = {
  enable = true;
  enableZshIntegration = true;  # or enableBashIntegration, enableFishIntegration
  settings = {
    add_newline = false;
    character.success_symbol = "[>](bold green)";
    directory.truncation_length = 3;
    git_status.disabled = false;
    nix_shell.format = "via [$symbol$state]($style) ";
  };
};
```

## programs.direnv

```nix
programs.direnv = {
  enable = true;
  nix-direnv.enable = true;  # faster nix integration, caches eval
  enableZshIntegration = true;
  config.global = {
    warn_timeout = "30s";
    hide_env_diff = true;
  };
};
```

## programs.neovim

```nix
programs.neovim = {
  enable = true;
  defaultEditor = true;
  viAlias = true;
  vimAlias = true;
  plugins = with pkgs.vimPlugins; [
    telescope-nvim
    nvim-treesitter.withAllGrammars
    nvim-lspconfig
    gruvbox-nvim
  ];
  extraLuaConfig = ''
    vim.opt.number = true
    vim.opt.relativenumber = true
    vim.opt.shiftwidth = 2
  '';
};
```

## programs.emacs

```nix
programs.emacs = {
  enable = true;
  package = pkgs.emacs29;  # or pkgs.emacs-nox, pkgs.emacs29-pgtk
  extraPackages = epkgs: with epkgs; [
    magit
    use-package
    which-key
    nix-mode
    markdown-mode
  ];
};
```

## programs.tmux

```nix
programs.tmux = {
  enable = true;
  terminal = "tmux-256color";
  keyMode = "vi";
  baseIndex = 1;
  escapeTime = 0;
  historyLimit = 10000;
  mouse = true;
  plugins = with pkgs.tmuxPlugins; [
    sensible
    yank
    resurrect
    continuum
  ];
  extraConfig = ''
    bind | split-window -h -c "#{pane_current_path}"
    bind - split-window -v -c "#{pane_current_path}"
  '';
};
```

## programs.alacritty

```nix
programs.alacritty = {
  enable = true;
  settings = {
    font = {
      normal.family = "JetBrains Mono";
      size = 14;
    };
    window = {
      padding = { x = 8; y = 8; };
      opacity = 0.95;
    };
    keyboard.bindings = [
      { key = "N"; mods = "Command"; action = "CreateNewWindow"; }
    ];
  };
};
```

## programs.kitty

```nix
programs.kitty = {
  enable = true;
  theme = "Gruvbox Dark";
  font = {
    name = "JetBrains Mono";
    size = 14;
  };
  settings = {
    scrollback_lines = 10000;
    enable_audio_bell = false;
    window_padding_width = 8;
    confirm_os_window_close = 0;
    macos_option_as_alt = true;
  };
};
```

## programs.firefox

```nix
programs.firefox = {
  enable = true;
  profiles.default = {
    isDefault = true;
    settings = {
      "browser.startup.homepage" = "about:blank";
      "browser.newtabpage.enabled" = false;
      "privacy.trackingprotection.enabled" = true;
    };
    search = {
      default = "DuckDuckGo";
      force = true;
    };
    extensions.packages = with pkgs.nur.repos.rycee.firefox-addons; [
      ublock-origin
      bitwarden
    ];
  };
};
```

## programs.vscode

```nix
programs.vscode = {
  enable = true;
  extensions = with pkgs.vscode-extensions; [
    vscodevim.vim
    jnoortheen.nix-ide
    esbenp.prettier-vscode
    ms-python.python
  ];
  userSettings = {
    "editor.fontSize" = 14;
    "editor.fontFamily" = "JetBrains Mono";
    "editor.formatOnSave" = true;
    "nix.enableLanguageServer" = true;
    "nix.serverPath" = "nil";
  };
};
```

## programs.gpg

```nix
programs.gpg = {
  enable = true;
  settings = {
    default-key = "ABCDEF1234567890";
    no-emit-version = true;
    no-comments = true;
    keyserver = "hkps://keys.openpgp.org";
  };
};
# Often paired with:
# services.gpg-agent.enable = true;
# services.gpg-agent.pinentryPackage = pkgs.pinentry-curses;
```

## programs.ssh

```nix
programs.ssh = {
  enable = true;
  addKeysToAgent = "yes";
  matchBlocks = {
    "github.com" = {
      hostname = "github.com";
      user = "git";
      identityFile = "~/.ssh/id_ed25519";
    };
    "dev-server" = {
      hostname = "192.168.1.100";
      user = "deploy";
      port = 2222;
      forwardAgent = true;
    };
    "*.internal" = {
      user = "admin";
      proxyJump = "bastion";
    };
  };
};
```

## programs.fzf

```nix
programs.fzf = {
  enable = true;
  enableZshIntegration = true;
  defaultCommand = "fd --type f --hidden --follow --exclude .git";
  defaultOptions = [ "--height 40%" "--layout=reverse" "--border" ];
  changeDirWidgetCommand = "fd --type d --hidden --follow --exclude .git";
  fileWidgetCommand = "fd --type f --hidden --follow --exclude .git";
};
```

## programs.bat

```nix
programs.bat = {
  enable = true;
  config = {
    theme = "gruvbox-dark";
    style = "numbers,changes,header";
    pager = "less -FR";
  };
};
```

## programs.eza

```nix
programs.eza = {
  enable = true;
  enableZshIntegration = true;  # aliases ls to eza
  icons = "auto";
  git = true;
  extraOptions = [
    "--group-directories-first"
    "--header"
  ];
};
```

## programs.ripgrep

```nix
programs.ripgrep = {
  enable = true;
  arguments = [
    "--smart-case"
    "--hidden"
    "--glob=!.git/*"
    "--max-columns=200"
    "--max-columns-preview"
  ];
};
```

## programs.fd

```nix
programs.fd = {
  enable = true;
  hidden = true;
  ignores = [
    ".git/"
    "node_modules/"
    "target/"
    ".direnv/"
  ];
  extraOptions = [
    "--follow"
  ];
};
```
