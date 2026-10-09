# statix.toml Configuration

Place at the repo root. Controls which lints are active project-wide.
Both keys are top-level lists: `disabled` takes lint names, `ignore`
takes path globs (`statix dump` prints the defaults).

```toml
# W20 (repeated_keys) fires on idiomatic flat-attribute module style:
#
#   nixpkgs.config.allowUnfree = true;
#   nixpkgs.hostPlatform = "aarch64-darwin";
#
# These are separate NixOS module options that happen to share a prefix,
# not duplicated keys. Disabling this avoids false positives in module
# configurations.
disabled = ["repeated_keys"]

# Generated, vendored, or documentation-only files that should not
# be linted.
ignore = [".direnv", "hardware-configuration.nix"]
```
