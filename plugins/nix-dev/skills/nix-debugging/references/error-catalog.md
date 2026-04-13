# Nix Error Catalog

Complete reference of common Nix errors, causes, and fixes.

## Table of Contents

- [Evaluation Errors](#evaluation-errors)
- [Build Errors](#build-errors)
- [Flake Errors](#flake-errors)
- [Store Errors](#store-errors)
- [Configuration Errors](#configuration-errors)

---

## Evaluation Errors

### `error: infinite recursion encountered`

**Causes:**
- `rec { x = x + 1; }` — attribute references itself
- Overlay: `final: prev: { foo = final.foo.override { ... }; }` — use `prev.foo`
- NixOS module reads and sets same option without `mkIf` guard
- `with` introduces shadowing that creates circular reference

**Debug:** Add `builtins.trace` before suspected attributes. In overlays, check every `final.X` — should it be `prev.X`?

### `error: attribute 'foo' missing`

**Causes:**
- Typo in package/option name
- Package renamed or removed in newer nixpkgs
- Missing `inherit` or `with` for the attribute set containing `foo`
- Function called without required argument

**Debug:** `nix eval nixpkgs#foo 2>&1` or search with mcp-nixos MCP tools.

### `error: undefined variable 'foo'`

**Causes:**
- Typo in variable name
- Missing `let` binding or function argument
- Variable from `with` scope was removed
- File not imported

### `error: value is a function while a set was expected`

**Cause:** You imported a `.nix` file that defines a function, but used it without calling it. Common with `callPackage`-style files.

**Fix:** Call the function: `(import ./foo.nix) { inherit lib; }` or use `callPackage ./foo.nix {}`.

### `error: value is a set while a function was expected`

**Cause:** Used `import ./file.nix args` but `file.nix` returns an attrset, not a function.

### `error: cannot coerce a set to a string`

**Cause:** String interpolation `"${attrset}"` only works if the attrset has `outPath` or `__toString`. Regular attrsets cannot be interpolated.

**Fix:** Use `builtins.toJSON`, access a specific attribute, or add `__toString`.

### `error: function 'anonymous lambda' called without required argument 'foo'`

**Cause:** `callPackage` or direct call missing a required argument that has no default.

**Fix:** Add the argument to the calling attrset, or add a default in the function: `{ foo ? null }:`.

### `error: cannot build during evaluation (import from derivation)`

**Cause:** Evaluation depends on a build result. Blocked when `--no-allow-import-from-derivation` is set (default in some contexts).

**Fix:** Pre-generate files, use builtin fetchers, or pass `--allow-import-from-derivation`.

---

## Build Errors

### `error: hash mismatch in fixed-output derivation`

```
  specified: sha256-AAAA...
  got:       sha256-BBBB...
```

**Fix:** Copy the `got:` hash into your source. During development, use `lib.fakeHash` or `""` to discover the correct hash.

### `error: builder for '...' failed with exit code N`

**Cause:** The build script (bash) exited non-zero. Could be compilation error, test failure, missing dependency.

**Debug:**
1. `nix log /nix/store/...-foo.drv` — read the build log
2. `nix build --keep-failed` — inspect the build directory
3. `nix develop` then run phases manually

### `error: collision between '/nix/store/...-A/bin/x' and '/nix/store/...-B/bin/x'`

**Cause:** Two packages provide the same file path.

**Fix:** `lib.hiPrio pkgs.preferred` or remove one package. For environments: `lib.lowPrio` on the less-preferred one.

### `error: Package 'foo' has an unfree license`

**Fix:** `nixpkgs.config.allowUnfree = true;` or per-package: `allowUnfreePredicate`.
CLI: `NIXPKGS_ALLOW_UNFREE=1 nix build --impure`.

### `error: Package 'foo' is marked as insecure`

**Fix:** `nixpkgs.config.permittedInsecurePackages = [ "foo-1.0" ];`

### `error: Package 'foo' is not available on the requested hostPlatform`

**Cause:** Package's `meta.platforms` doesn't include your system.

**Fix:** Override if you know it works: `.overrideAttrs { meta.platforms = lib.platforms.all; }`

---

## Flake Errors

### `error: getting status of '/path/to/file': No such file or directory`

**Cause:** File exists on disk but is not tracked by git. Flakes only see staged/committed files.

**Fix:** `git add <file>` (staging is enough).

### `error: access to absolute path '/...' is forbidden in pure eval mode`

**Cause:** Flake evaluation is pure — no `builtins.getEnv`, no absolute paths outside the flake, no `<nixpkgs>`.

**Fix:** Pass data through flake inputs. Or use `--impure` as escape hatch.

### `error: experimental Nix feature 'flakes' is disabled`

**Fix:** Add to `nix.conf`: `experimental-features = nix-command flakes`

Or per-command: `nix --experimental-features 'nix-command flakes' build`

### `error: input 'foo' has an unsupported input type`

**Cause:** Flake input URL format is wrong or the referenced repo has no `flake.nix`.

**Fix:** Check URL format. For non-flake inputs: `inputs.foo.flake = false;`

### `error: cached failure of attribute '...'`

**Cause:** A previous evaluation failed and Nix cached the failure.

**Fix:** `nix build --rebuild` or remove the eval cache: `rm -rf ~/.cache/nix/eval-cache-v*`

---

## Store Errors

### `error: path '/nix/store/...' is not valid`

**Cause:** Store path was garbage collected or the store is corrupted.

**Fix:** Rebuild the package. If widespread: `nix store verify --all` then `nix store repair --all`.

### `error: cannot link '/nix/store/...' to '/nix/store/...': File exists`

**Cause:** Store corruption or interrupted optimisation.

**Fix:** `nix store verify --all --repair`

### `error: writing to file: No space left on device`

**Cause:** `/nix/store` is full.

**Fix:** `nix-collect-garbage -d` then `nix store optimise`.

---

## Configuration Errors

### `error: The option 'services.foo' does not exist`

**Cause:** Module providing that option is not imported, or the option was renamed/removed.

**Debug:** Search with mcp-nixos MCP tools or `nixos-option services.foo`.

### `error: The option 'foo' is used but not defined`

**Cause:** Setting an option that no imported module declares.

### `error: A definition for option 'foo' is not of type 'str'`

**Cause:** Type mismatch between the option declaration and your definition.

**Debug:** Check the option's declared type with mcp-nixos or `nixos-option`.

### Reading `--show-trace` Output

```
error: A definition for option 'services.nginx.enable' is not of type 'boolean'.

       … while evaluating the attribute 'value'
       at /nix/store/...-source/lib/modules.nix:809:9:

       … while evaluating definitions from '/etc/nixos/configuration.nix':

       … while calling the 'head' builtin
       at /nix/store/...-source/lib/attrsets.nix:1003:11:
```

**Read bottom-up:** The error is at the top. Each `… while` frame is one step deeper in the call stack. Look for frames referencing YOUR files (e.g., `/etc/nixos/configuration.nix`) — that's where the bug is. Ignore `lib/modules.nix` and `lib/attrsets.nix` frames unless you're debugging the module system itself.
