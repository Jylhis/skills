---
name: emacs-nix-packaging
description: "Use for Nix-based Emacs packaging including emacsWithPackages, emacs overlay, trivialBuild, building Emacs from source with Nix, tree-sitter grammar packaging, MELPA/ELPA to nixpkgs package resolution, emacsPackagesFor, melpaBuild, withPackages, Emacs native compilation in Nix, pgtk builds, wrapping Emacs with Nix, or when the user asks about packaging Emacs packages with Nix, adding Emacs packages to a Nix expression, or building custom Emacs distributions."
user-invocable: false
---

# Nix-based Emacs Packaging

Patterns for building and packaging Emacs with Nix.

## emacsWithPackages

The primary way to get Emacs with packages in Nix:

```nix
# In a flake, overlay, or NixOS/home-manager config
let
  myEmacs = pkgs.emacs30.pkgs.withPackages (epkgs: with epkgs; [
    magit
    vertico
    orderless
    consult
    corfu
    org
    use-package
  ]);
in
{
  home.packages = [ myEmacs ];
}
```

### How it works

- `withPackages` wraps Emacs with `site-lisp` pointing to the selected packages
- Packages come from `emacs-overlay` or nixpkgs `emacsPackages`
- Native dependencies (libvterm, sqlite, etc.) are automatically handled
- Packages are byte-compiled (and optionally native-compiled) during the Nix build

### Choosing an Emacs variant

```nix
# Stable release
pkgs.emacs30

# With pure GTK (Wayland-native)
pkgs.emacs30-pgtk

# No GUI (terminal only)
pkgs.emacs30-nox

# Git master (via emacs-overlay)
pkgs.emacs-git

# macOS native (via emacs-overlay)
pkgs.emacs-macport
```

## Package Name Resolution

Nix package names sometimes differ from MELPA/ELPA names:

```bash
# Check if a package exists in nixpkgs
nix eval nixpkgs#emacs30Packages.magit.pname

# Search for packages
nix search nixpkgs "emacs.*Packages.*company"
```

### Resolution strategy

1. **Check if built-in** — many packages are built into Emacs 29+/30+ (use-package, eglot, which-key, modus-themes, project.el, flymake, xref, eldoc, etc.). Do NOT add these.
2. **Try exact name** — `epkgs.magit`, `epkgs.vertico`, etc.
3. **Try name variations** — `epkgs.helm-projectile` vs `epkgs.projectile-helm`
4. **Check special cases** — some packages have unique names in Nix:
   - `mu4e` → comes from `pkgs.mu` (not an Emacs package)
   - `notmuch` → `epkgs.notmuch` or from `pkgs.notmuch`
   - `vterm` → `epkgs.vterm` (needs `cmake` at build time)
   - `pdf-tools` → `epkgs.pdf-tools` (needs `poppler`)
   - `emacsql-sqlite` → `epkgs.emacsql-sqlite-builtin` on Emacs 29+

### Packages that should NOT be added (built-in on Emacs 30)

`use-package`, `eglot`, `which-key`, `modus-themes`, `project`, `flymake`, `xref`, `eldoc`, `jsonrpc`, `seq`, `so-long`, `tab-bar`, `tab-line`, `tramp`, `org` (bundled version)

## trivialBuild

For packages not in nixpkgs, or for your own Elisp:

```nix
{ pkgs }:
let
  myPackage = pkgs.emacs30Packages.trivialBuild {
    pname = "my-package";
    version = "0.1.0";
    src = ./lisp;

    # If it depends on other Emacs packages
    packageRequires = with pkgs.emacs30Packages; [
      dash
      s
    ];
  };
in
pkgs.emacs30.pkgs.withPackages (epkgs: [
  myPackage
  epkgs.magit
])
```

### From a Git source

```nix
pkgs.emacs30Packages.trivialBuild {
  pname = "some-package";
  version = "unstable-2024-01-15";
  src = pkgs.fetchFromGitHub {
    owner = "author";
    repo = "some-package";
    rev = "abc123";
    hash = "sha256-...";
  };
}
```

## melpaBuild

For packages with complex build steps (byte-compilation, recipe files):

```nix
pkgs.emacs30Packages.melpaBuild {
  pname = "complex-package";
  version = "1.0.0";
  src = pkgs.fetchFromGitHub {
    owner = "author";
    repo = "complex-package";
    rev = "v1.0.0";
    hash = "sha256-...";
  };

  recipe = pkgs.writeText "recipe" ''
    (complex-package :repo "author/complex-package"
                     :fetcher github
                     :files ("*.el" "data"))
  '';

  packageRequires = with pkgs.emacs30Packages; [ dash ];
}
```

## Tree-sitter Grammars

### Using nixpkgs grammars

```nix
pkgs.emacs30.pkgs.withPackages (epkgs: [
  epkgs.treesit-grammars.with-all-grammars
  # or specific grammars:
  # epkgs.treesit-grammars.with-grammars (grammars: [
  #   grammars.tree-sitter-rust
  #   grammars.tree-sitter-python
  #   grammars.tree-sitter-go
  # ])
])
```

### Building a grammar from source

```nix
let
  myGrammar = pkgs.tree-sitter.buildGrammar {
    language = "mylang";
    version = "0.1.0";
    src = pkgs.fetchFromGitHub {
      owner = "tree-sitter";
      repo = "tree-sitter-mylang";
      rev = "...";
      hash = "sha256-...";
    };
  };
in
# Then add to treesit-extra-load-path in your Elisp config
```

### Elisp side

```elisp
;; Remap built-in modes to tree-sitter variants
(setopt major-mode-remap-alist
        '((python-mode . python-ts-mode)
          (rust-mode . rust-ts-mode)
          (go-mode . go-ts-mode)
          (javascript-mode . js-ts-mode)
          (typescript-mode . typescript-ts-mode)
          (json-mode . json-ts-mode)
          (yaml-mode . yaml-ts-mode)
          (toml-mode . toml-ts-mode)
          (css-mode . css-ts-mode)
          (bash-mode . bash-ts-mode)))

;; AVOID: (treesit-install-language-grammar 'rust)
;; Nix already provides the grammars
```

## Building Emacs from Source

For custom Emacs builds (patches, configure flags, etc.):

```nix
(pkgs.emacs30.override {
  # Configure flags
  withNativeCompilation = true;
  withTreeSitter = true;
  withSQLite3 = true;
  withWebP = true;
  withImageMagick = true;

  # For pgtk (pure GTK, Wayland)
  withPgtk = true;
}).overrideAttrs (old: {
  # Apply patches
  patches = (old.patches or []) ++ [
    ./my-patch.patch
  ];

  # Additional build inputs
  buildInputs = (old.buildInputs or []) ++ [
    pkgs.libgccjit   # for native-comp
  ];

  # Custom configure flags
  configureFlags = (old.configureFlags or []) ++ [
    "--with-x-toolkit=gtk3"
  ];
})
```

## emacs-overlay

The [nix-community/emacs-overlay](https://github.com/nix-community/emacs-overlay) provides bleeding-edge Emacs and packages:

```nix
# In flake.nix
{
  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    emacs-overlay.url = "github:nix-community/emacs-overlay";
  };

  outputs = { self, nixpkgs, emacs-overlay }: {
    # Apply the overlay
    packages.x86_64-linux.default = let
      pkgs = import nixpkgs {
        system = "x86_64-linux";
        overlays = [ emacs-overlay.overlays.default ];
      };
    in
    pkgs.emacs-git.pkgs.withPackages (epkgs: [
      epkgs.magit
      # emacs-overlay provides latest MELPA versions
    ]);
  };
}
```

### What the overlay provides

- `emacs-git` — Emacs from Git master (rebuilt nightly)
- `emacs-pgtk` — pure GTK build from master
- `emacs-unstable` — latest release branch
- `emacsPackagesFor` — create package sets for any Emacs variant
- Updated MELPA/ELPA/NonGNU ELPA package snapshots

## Nix/Elisp Boundary

Clear separation of concerns:

| Nix handles | Elisp handles |
|-------------|---------------|
| Package installation | Runtime configuration |
| Load-path setup | Hooks and keybindings |
| Native dependencies | Theme selection |
| Tree-sitter grammars | Mode settings |
| Byte/native compilation | Buffer-local variables |
| System library linking | Interactive commands |

**Rule of thumb:** if it touches the filesystem or system libraries, it belongs in Nix. If it configures behavior at runtime, it belongs in Elisp.

## Common Issues

| Problem | Solution |
|---------|----------|
| Package not found after rebuild | Check package name in `nix search nixpkgs "emacs.*pkg"` |
| Native-comp stale after update | Clear `~/.emacs.d/eln-cache/` |
| `vterm` build failure | Ensure `cmake` is in the Nix build environment |
| `pdf-tools` build failure | Ensure `poppler` and `pkg-config` are available |
| Tree-sitter mode not activating | Check `major-mode-remap-alist` and grammar availability |
| Package version too old | Use emacs-overlay for latest MELPA versions |
| Hash mismatch on update | Use `lib.fakeHash` to get the correct hash from the error |
