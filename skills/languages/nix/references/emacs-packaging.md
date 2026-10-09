# Nix-based Emacs Packaging

## emacsWithPackages

```nix
let
  myEmacs = pkgs.emacs.pkgs.withPackages (epkgs: with epkgs; [
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
- A package that installs `share/emacs/site-lisp/default.el` is loaded at startup, so a Nix-built config can ship as one more entry in the package list. On unstable (26.11), Emacs also loads an `early-default` library after `early-init.el`

### Choosing an Emacs variant

```nix
pkgs.emacs               # Default release: 30.2 on 26.05, Emacs 31 on unstable
pkgs.emacs-pgtk          # Pure GTK (Wayland-native)
pkgs.emacs-nox           # No GUI (terminal only)
pkgs.emacs-macport       # macOS port (fork of Mitsuharu Yamamoto's patches, Emacs 30), in nixpkgs
pkgs.emacs-git           # Git master (via emacs-overlay)
```

Prefer the unversioned attributes. `emacs30`, `emacs30-pgtk`, `emacs30-nox` and `emacs30-gtk3` exist on 26.05 but throw on unstable (superseded by `emacs`/`emacs-pgtk`/... in August 2026), where the versioned set is `emacs31*`. Emacs 28 and 29 were removed in 25.05. Use `emacsPackagesFor <emacs>` to get a package set for a custom Emacs build.

## Package Name Resolution

```bash
nix eval nixpkgs#emacsPackages.magit.pname
nix search nixpkgs "emacsPackages.*company"
```

### Resolution strategy

1. **Check if built-in** — many packages are built into Emacs 29+/30+. Do NOT add these.
2. **Try exact name** — `epkgs.magit`, `epkgs.vertico`, etc.
3. **Try name variations** — `epkgs.helm-projectile` vs `epkgs.projectile-helm`
4. **Special cases:**
   - `mu4e` -> from `pkgs.mu`
   - `vterm` -> `epkgs.vterm` (needs `cmake` at build time)
   - `pdf-tools` -> `epkgs.pdf-tools` (needs `poppler`)
   - `emacsql-sqlite` -> `epkgs.emacsql-sqlite-builtin` on Emacs 29+

### Packages that should NOT be added (built-in on Emacs 30)

`use-package`, `eglot`, `which-key`, `modus-themes`, `project`, `flymake`, `xref`, `eldoc`, `jsonrpc`, `seq`, `so-long`, `tab-bar`, `tab-line`, `tramp`, `org` (bundled version)

## trivialBuild

```nix
{ pkgs }:
let
  myPackage = pkgs.emacs.pkgs.trivialBuild {
    pname = "my-package";
    version = "0.1.0";
    src = ./lisp;

    packageRequires = with pkgs.emacs.pkgs; [
      dash
      s
    ];
  };
in
pkgs.emacs.pkgs.withPackages (epkgs: [
  myPackage
  epkgs.magit
])
```

`trivialBuild` byte-compiles every `*.el` in the source root and installs `*.el`/`*.elc` into `share/emacs/site-lisp`. The Emacs builders accept `finalAttrs:`, default to `strictDeps = true` and `__structuredAttrs = true` (structured attrs since 25.05), and take `turnCompilationWarningToError` and `ignoreCompilationError` flags.

### From a Git source

```nix
pkgs.emacs.pkgs.trivialBuild {
  pname = "some-package";
  version = "0-unstable-2024-01-15";
  src = pkgs.fetchFromGitHub {
    owner = "author";
    repo = "some-package";
    rev = "<full 40-char commit hash>";
    hash = "sha256-...";
  };
}
```

## melpaBuild

For packages with complex build steps (multiple files, data directories, `Package-Requires` metadata):

```nix
pkgs.emacs.pkgs.melpaBuild (finalAttrs: {
  pname = "complex-package";
  version = "1.0.0";
  src = pkgs.fetchFromGitHub {
    owner = "author";
    repo = "complex-package";
    tag = "v${finalAttrs.version}";
    hash = "sha256-...";
  };

  # Optional: a MELPA :files spec as a string. Omit to use MELPA's defaults.
  files = ''("*.el" "data")'';

  packageRequires = with pkgs.emacs.pkgs; [ dash ];
})
```

`recipe` is optional: when unset, melpaBuild writes a minimal recipe from `ename` (defaults to `pname`) and `files`. Pass `recipe` (a path or a string) only when you need other MELPA recipe properties. Unstable versions in Nix form (`1.2-unstable-2024-06-01`) are converted to MELPA's `YYYYMMDD.0` automatically.

## Tree-sitter Grammars

### Using nixpkgs grammars

```nix
pkgs.emacs.pkgs.withPackages (epkgs: [
  epkgs.treesit-grammars.with-all-grammars
  # or specific:
  # epkgs.treesit-grammars.with-grammars (grammars: [
  #   grammars.tree-sitter-rust
  #   grammars.tree-sitter-python
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
      tag = "v0.1.0";
      hash = "sha256-...";
    };
  };
in
# $out/parser is the shared library; treesit-grammars links it as
# lib/libtree-sitter-mylang.so for treesit-extra-load-path
pkgs.emacs.pkgs.withPackages (epkgs: [
  (epkgs.treesit-grammars.with-grammars (_: [ myGrammar ]))
])
```

### Elisp side

```elisp
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

```nix
(pkgs.emacs.override {
  withNativeCompilation = true;  # default when build can execute host binaries
  withTreeSitter = true;         # default
  withSQLite3 = true;            # default
  withWebP = true;               # default
  withImageMagick = true;        # default false
  withPgtk = true;               # default false; disables X (withX)
}).overrideAttrs (old: {
  patches = (old.patches or []) ++ [
    ./my-patch.patch
  ];
})
```

`libgccjit` is wired in automatically when `withNativeCompilation` is on, so don't add it to `buildInputs`. The X toolkit comes from the `toolkit` argument and only applies to X builds (`withPgtk = true` turns `withX` off); for a GTK3 X build use `pkgs.emacs-gtk` or `withGTK3 = true`. `withGcMarkTrace` (default `false` since 25.11) re-enables the GC mark trace buffer for debugging GC issues.

## emacs-overlay

```nix
{
  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    emacs-overlay.url = "github:nix-community/emacs-overlay";
  };

  outputs = { self, nixpkgs, emacs-overlay }: {
    packages.x86_64-linux.default = let
      pkgs = import nixpkgs {
        system = "x86_64-linux";
        overlays = [ emacs-overlay.overlays.default ];
      };
    in
    pkgs.emacs-git.pkgs.withPackages (epkgs: [
      epkgs.magit
    ]);
  };
}
```

### What the overlay provides

Two sub-overlays: `overlays.emacs` (Emacs builds) and `overlays.package` (package sets); `overlays.default` applies both.

- `emacs-git`, `emacs-git-pgtk`, `emacs-git-nox`: Emacs from Git master (updated daily)
- `emacs-unstable`, `emacs-unstable-pgtk`, `emacs-unstable-nox`: latest tag, including pretests
- `emacs-igc`, `emacs-igc-pgtk`: the IGC feature branch built `--with-mps=yes` (MPS garbage collector)
- `emacsWithPackagesFromUsePackage { config = ./init.el; ... }`: package list parsed from `use-package`/`leaf` forms (`alwaysEnsure`, `extraEmacsPackages`, `override`)
- `emacsWithPackagesFromPackageRequires`: package list from an `.el` file's `Package-Requires` header (handy for CI)
- Daily ELPA, NonGNU ELPA, MELPA and MELPA Stable snapshots, plus fresh EXWM

`emacs-pgtk` and `emacsPackagesFor` come from nixpkgs itself, not the overlay. Prebuilt binaries are on the nix-community cache (`https://nix-community.cachix.org`).

## Nix/Elisp Boundary

| Nix handles | Elisp handles |
|-------------|---------------|
| Package installation | Runtime configuration |
| Load-path setup | Hooks and keybindings |
| Native dependencies | Theme selection |
| Tree-sitter grammars | Mode settings |
| Byte/native compilation | Buffer-local variables |
| System library linking | Interactive commands |

## Common Issues

| Problem | Solution |
|---------|----------|
| Package not found after rebuild | Check name in `nix search nixpkgs "emacs.*pkg"` |
| Native-comp stale after update | Clear `~/.emacs.d/eln-cache/` |
| `vterm` build failure | Ensure `cmake` in build environment |
| `pdf-tools` build failure | Ensure `poppler` and `pkg-config` available |
| Tree-sitter mode not activating | Check `major-mode-remap-alist` and grammar |
| Package version too old | Use emacs-overlay for latest MELPA |
| Hash mismatch on update | Use `lib.fakeHash` to get correct hash |
