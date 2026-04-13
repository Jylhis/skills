---
name: nix-language
description: "Use when working with Nix expression language fundamentals including syntax, expressions, functions, builtins, let-in bindings, with expressions, inherit, rec, attrsets, attribute sets, string interpolation, derivations, import, fetchurl, fixed-point patterns, nixpkgs lib functions, lambdas, operators, lazy evaluation, callPackage pattern, string context, path coercion, lib.fileset, or Nix type system."
user-invocable: false
---

# Nix Language

## Core Data Types

| Type | Example | Notes |
|------|---------|-------|
| String | `"hello ${name}"` | Interpolation with `${}`, multiline with `''` |
| Integer | `42` | No overflow — arbitrary precision |
| Float | `1.0`, `3.14` | Rarely used in nixpkgs |
| Boolean | `true` / `false` | |
| Null | `null` | |
| Path | `./foo.nix`, `/etc/nix` | Resolved relative to the containing file |
| List | `[ 1 2 3 ]` | Space-separated, heterogeneous |
| Attribute set | `{ a = 1; b = 2; }` | Key-value map, semicolons required |
| Function | `x: x + 1` | Single-argument, curried |

## Operators

| Op | Meaning | Example |
|----|---------|---------|
| `//` | Shallow merge (right wins) | `{ a = 1; } // { b = 2; }` → `{ a = 1; b = 2; }` |
| `?` | Has attribute | `attrs ? "key"` → bool |
| `or` | Default on access | `attrs.key or "fallback"` |
| `++` | List concatenation | `[ 1 ] ++ [ 2 ]` → `[ 1 2 ]` |
| `==` / `!=` | Equality (deep) | |
| `&&` / `\|\|` / `!` | Boolean logic | Short-circuit evaluation |

**`//` is shallow** — nested attrsets are replaced, not merged. Use `lib.recursiveUpdate` for deep merge.

## Functions

```nix
# Curried
add = a: b: a + b;

# Attrset pattern (most common in nixpkgs)
mkDerivation = { pname, version, src, ... }: { /* ... */ };

# With defaults
mkDerivation = { pname, version, src, buildInputs ? [], ... }: { /* ... */ };
```

The `@` pattern captures the full attrset: `{ pname, ... } @ args:`.

## Key Constructs

### let-in

```nix
let
  x = 1;
  y = x + 1;
in x + y
```

### with

```nix
with pkgs; [ git curl wget ]
# equivalent to: [ pkgs.git pkgs.curl pkgs.wget ]
```

### inherit

```nix
{ inherit src version; }
# equivalent to: { src = src; version = version; }

{ inherit (pkgs) git curl; }
# equivalent to: { git = pkgs.git; curl = pkgs.curl; }
```

### rec (recursive attrsets)

```nix
rec {
  x = 1;
  y = x + 1;  # works because of rec
}
```

### Conditionals

```nix
if condition then valueA else valueB
```

## String Patterns

```nix
# Multiline (strips leading whitespace)
''
  line 1
  line 2
''

# Escape interpolation in multiline
''
  literal ''${not-interpolated}
''

# String interpolation
"Hello ${name}, you have ${toString count} items"
```

### String Context

When you interpolate a derivation into a string (`"${pkg}"`), Nix records it as a runtime dependency. This is how Nix knows what a package needs at runtime — the string carries invisible context tracking every store path referenced.

`builtins.unsafeDiscardStringContext` strips this tracking. Only use it when you are certain the dependency is not needed at runtime (e.g., extracting a version string for display).

## Path Handling

Bare paths (`./src`, `../lib`) are resolved relative to the file containing them and copied to the Nix store on evaluation. This means `src = ./.;` copies the entire directory — and the store path name derives from the parent directory name, causing impure rebuilds if you rename the directory.

**Reproducible source paths:**

```nix
src = builtins.path { path = ./.; name = "my-project"; };
```

**Modern source filtering with `lib.fileset`:**

```nix
let
  fs = lib.fileset;
in {
  src = fs.toSource {
    root = ./.;
    fileset = fs.unions [
      ./src
      ./Cargo.toml
      ./Cargo.lock
    ];
  };
}
```

This replaces the older `cleanSource` / `cleanSourceWith` patterns. Only files in the fileset enter the store.

## Derivations

```nix
stdenv.mkDerivation {
  pname = "hello";
  version = "1.0";
  src = ./src;
  nativeBuildInputs = [ pkg-config ];  # tools for the build machine
  buildInputs = [ openssl ];           # libraries for the host machine
  buildPhase = ''
    make
  '';
  installPhase = ''
    mkdir -p $out/bin
    cp hello $out/bin/
  '';
}
```

`$out` is the Nix store path where the build output goes. `nativeBuildInputs` vs `buildInputs` matters for cross-compilation — see the nixpkgs skill.

## Lazy Evaluation

Nix is lazy: values are not computed when bound — only when referenced. Each binding creates a "thunk" (a deferred computation) that executes on first access. Nix evaluates to Weak Head Normal Form (WHNF) — only the outermost structure is evaluated.

**Consequences:**
- `builtins.length [ (1/0) (2/0) ]` returns `2` without error — list elements are never evaluated
- `if true then "ok" else (throw "never")` succeeds — the else branch stays unevaluated
- nixpkgs (300K+ packages) loads instantly — only requested packages evaluate
- `throw` in unused option branches does not fire

**Infinite recursion detection:** Nix uses "blackholing" — when a thunk is entered, it is marked. If evaluation re-enters the same thunk before it completes, Nix immediately raises `error: infinite recursion encountered`.

## Fixed-Point Recursion

`lib.fix` enables self-referencing attribute sets:

```nix
lib.fix (self: {
  x = 1;
  y = self.x + 10;
  z = self.y + 100;
})
# → { x = 1; y = 11; z = 111; }
```

This works because lazy evaluation lets `self` reference the result before it is fully computed. The function is called only once.

**Overlays use this pattern.** An overlay is `final: prev: { ... }` where `final` is the fixed point of all overlays composed together, and `prev` is the package set before the current overlay. See the nixpkgs skill for overlay composition rules.

`lib.extends` composes two overlay-style functions:

```nix
composed = lib.extends overlay2 overlay1;
result = lib.fix composed;
```

## The `callPackage` Pattern

`callPackage` is the core composition mechanism in nixpkgs. It auto-fills function arguments from the package set:

```nix
# package.nix
{ lib, stdenv, fetchFromGitHub, openssl }:
stdenv.mkDerivation { /* uses openssl */ }

# In an overlay or top-level
myPkg = callPackage ./package.nix {};
# callPackage inspects the function's argument names and supplies
# lib, stdenv, fetchFromGitHub, openssl from pkgs automatically.
# The second arg {} provides manual overrides.
```

**Why `callPackage` matters:**
- **Overridable:** `myPkg.override { openssl = openssl_1_1; }` swaps one dependency
- **Cross-compilation:** `callPackage` resolves `nativeBuildInputs` from `buildPackages` automatically through "splicing"
- **Upstreamable:** Packages in `callPackage` form are directly submittable to nixpkgs

Always write packages as functions in separate files and use `callPackage` to instantiate them.

## Important Builtins

| Builtin | Purpose |
|---------|---------|
| `builtins.map` | Transform list elements |
| `builtins.filter` | Filter list by predicate |
| `builtins.attrNames` | Get attrset keys as sorted list |
| `builtins.attrValues` | Get attrset values (sorted by key) |
| `builtins.hasAttr` | Check if key exists |
| `builtins.elem` | Check if element in list |
| `builtins.toString` | Convert to string |
| `builtins.toJSON` / `fromJSON` | JSON serialization |
| `builtins.readFile` | Read file contents at eval time |
| `builtins.path` | Copy path to store with options |
| `builtins.fetchurl` | Fetch URL at eval time (blocks evaluation) |
| `builtins.trace` | Debug print during evaluation |
| `import` | Load and evaluate a `.nix` file |

Read `references/advanced.md` for the full builtins and lib reference.

## nixpkgs `lib` Essentials

```nix
lib.mkIf condition value          # Conditional config (NixOS modules)
lib.mkMerge [ a b ]               # Merge multiple configs
lib.optionals bool list            # Conditional list items
lib.optional bool value            # Conditional single item as list
lib.filterAttrs pred set           # Filter attrset by predicate
lib.mapAttrs f set                 # Transform attrset values
lib.mapAttrs' f set                # Transform attrset keys and values
lib.genAttrs names f               # Generate attrset from name list
lib.concatMapStringsSep sep f l    # Map + join strings
lib.recursiveUpdate a b            # Deep merge attrsets
lib.fix f                          # Fixed-point of f
lib.extends overlay base           # Compose overlay on top of base
lib.pipe value [ f1 f2 f3 ]       # Pipeline: f3 (f2 (f1 value))
lib.flip f                         # Flip first two arguments
lib.const x                        # Always return x
```

## Anti-Patterns

- **Always quote URLs** — `"https://..."` not bare `https://...` (RFC 45 deprecated unquoted URLs)
- **Avoid `rec`** when `let-in` works — `rec` makes the whole attrset self-referential, risking infinite recursion on name shadowing
- **Avoid `with pkgs;` in large scopes** — breaks static analysis, doesn't shadow let-bindings, makes name origins unclear. Prefer `inherit (pkgs) git curl;`
- **Don't use lookup paths** (`<nixpkgs>`) — depends on `$NIX_PATH` environment variable, breaks reproducibility. Pin nixpkgs explicitly.
- **Set config and overlays explicitly** when importing nixpkgs:
  ```nix
  import nixpkgs { config = {}; overlays = []; }
  ```
  Without this, impure filesystem reads (`~/.config/nixpkgs/config.nix`) can change results.
- **Don't use `builtins.toPath`** — deprecated
- **Don't read secrets at eval time** — `builtins.readFile` embeds content in the store (world-readable)
- **Don't use `src = ./.`** without `builtins.path` or `lib.fileset` — directory name leaks into store path, causing unnecessary rebuilds
