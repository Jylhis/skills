# NixOS Module Type System Reference

## Table of Contents

- [Basic Types](#basic-types)
- [Integer Subtypes](#integer-subtypes)
- [String Subtypes](#string-subtypes)
- [Container Types](#container-types)
- [Composite Types](#composite-types)
- [Module Types](#module-types)
- [Sum Types (attrTag)](#sum-types-attrtag)
- [Serialization Types](#serialization-types)
- [Special Types](#special-types)
- [Priority System](#priority-system)
- [Merge Function Reference](#merge-function-reference)
- [Type Creation with mkOptionType](#type-creation-with-mkoptiontype)
- [freeformType Pattern](#freeformtype-pattern)

## Basic Types

All types live under `lib.types` (usually accessed as `types` via `with lib;`).

| Type | Nix values | Merge behavior | Example |
|------|-----------|----------------|---------|
| `types.bool` | `true`, `false` | All definitions must agree after priorities (error on conflict) | `enable = mkOption { type = types.bool; default = false; };` |
| `types.boolByOr` | `true`, `false` | Logical OR of all definitions | `wantFoo = mkOption { type = types.boolByOr; default = false; };` |
| `types.int` | Any integer | Single definition only | `count = mkOption { type = types.int; default = 0; };` |
| `types.float` | Any float | Single definition only | `ratio = mkOption { type = types.float; default = 1.0; };` |
| `types.str` | Any string (empty allowed; use `nonEmptyStr` to forbid) | Single definition only | `name = mkOption { type = types.str; };` |
| `types.path` | Absolute path (path value or string starting with `/`) | Single definition only | `configFile = mkOption { type = types.path; };` |
| `types.package` | A top-level store path (derivation, flake input) | Single definition only | `package = mkOption { type = types.package; default = pkgs.hello; };` |
| `types.port` | Integer 0..65535 (alias of `ints.u16`) | Single definition only | `port = mkOption { type = types.port; default = 8080; };` |

`types.string` (the old merging string type) was removed in 25.11. Use `str`, or `lines`/`commas`/`separatedString` when you want concatenation.

### Path types

| Type | Constraint |
|------|-----------|
| `types.pathInStore` | Must be in the Nix store (`pkgs.hello`, `"${pkgs.hello}/bin/hello"`) |
| `types.externalPath` | Must not be in the store: secrets, password files |
| `types.pathWith { inStore ? null; absolute ? null; }` | General form; `null` means "don't care" |

```nix
passwordFile = mkOption {
  # Absolute and outside the store. This only checks the value: interpolating it
  # into a derivation or "${...}" can still copy the file into the store.
  type = types.pathWith { inStore = false; absolute = true; };
};
```

## Integer Subtypes

All under `types.ints`:

| Type | Range | Description |
|------|-------|-------------|
| `ints.between min max` | `min` .. `max` | Arbitrary bounded integer |
| `ints.unsigned` | 0 .. +inf | Non-negative integers |
| `ints.positive` | 1 .. +inf | Strictly positive integers |
| `ints.u8` | 0 .. 255 | Unsigned 8-bit |
| `ints.u16` | 0 .. 65535 | Unsigned 16-bit |
| `ints.u32` | 0 .. 4294967295 | Unsigned 32-bit |
| `ints.s8` | -128 .. 127 | Signed 8-bit |
| `ints.s16` | -32768 .. 32767 | Signed 16-bit |
| `ints.s32` | -2147483648 .. 2147483647 | Signed 32-bit |

```nix
timeout = mkOption {
  type = types.ints.between 1 3600;
  default = 30;
  description = "Timeout in seconds (1-3600).";
};
```

## String Subtypes

| Type | Constraint | Use case |
|------|-----------|----------|
| `types.nonEmptyStr` | Must be non-empty | Names, identifiers |
| `types.singleLineStr` | No newlines | Single config values |
| `types.strMatching pattern` | Must match regex | Constrained formats |
| `types.separatedString sep` | Strings joined by `sep` on merge | Aggregated values |
| `types.lines` | `separatedString "\n"` | Multi-line config blocks |
| `types.commas` | `separatedString ","` | Comma-separated lists |
| `types.envVar` | `separatedString ":"` | PATH-style variables |

```nix
# strMatching: only accept valid IPv4
address = mkOption {
  type = types.strMatching "[0-9]+\\.[0-9]+\\.[0-9]+\\.[0-9]+";
};

# lines: multiple modules can append lines, merged with newlines
extraConfig = mkOption {
  type = types.lines;
  default = "";
  description = "Extra configuration lines appended to the config file.";
};

# envVar: modules can extend PATH-like variables
path = mkOption {
  type = types.envVar;
  default = "";
};
```

## Container Types

### `types.listOf elemType`

A list where every element matches `elemType`. Multiple definitions are **concatenated**.

```nix
packages = mkOption {
  type = types.listOf types.package;
  default = [];
  description = "Packages to install.";
};
# Module A: packages = [ pkgs.git ];
# Module B: packages = [ pkgs.vim ];
# Result:   [ pkgs.git pkgs.vim ]
```

### `types.attrsOf elemType`

An attribute set where every value matches `elemType`. Multiple definitions are **recursively merged** (values at the same key are merged according to `elemType`).

```nix
users = mkOption {
  type = types.attrsOf (types.submodule {
    options.shell = mkOption { type = types.str; default = "/bin/sh"; };
  });
  default = {};
};
# Module A: users.alice.shell = "/bin/bash";
# Module B: users.bob.shell = "/bin/zsh";
# Result:   { alice.shell = "/bin/bash"; bob.shell = "/bin/zsh"; }
```

### `types.lazyAttrsOf elemType`

Like `attrsOf` but **defers evaluation** of values. Useful when values are expensive or self-referential.

**Caveat:** `lazyAttrsOf` breaks `mkIf` on individual attributes. Because the attribute names must be known before values are evaluated, wrapping a single attr in `mkIf` does not conditionally omit the key -- it evaluates the key unconditionally and only conditionally evaluates the value. With `foo.attr = mkIf false 10`, `foo ? attr` is `true` and reading it throws, unless the element type has an `emptyValue` (`lazyAttrsOf (nullOr int)` yields `null`). Use `mkIf` at the level of the entire attrset instead, or use `attrsOf` when conditional attrs are needed.

```nix
vhosts = mkOption {
  type = types.lazyAttrsOf (types.submodule { ... });
  default = {};
};
```

### `types.attrsWith { elemType; lazy ? false; placeholder ? "name"; }`

General form behind both: `attrsWith { elemType = t; }` is `attrsOf t`, `lazy = true` gives `lazyAttrsOf t`. `placeholder` changes the name shown in generated docs (`foo.<id>` instead of `foo.<name>`).

```nix
hosts = mkOption {
  type = types.attrsWith { elemType = types.submodule hostModule; placeholder = "host"; };
  default = {};
};
```

## Composite Types

### `types.nullOr elemType`

Value is either `null` or matches `elemType`. Default can be `null`.

```nix
logFile = mkOption {
  type = types.nullOr types.path;
  default = null;
  description = "Log file path, or null to disable file logging.";
};
```

### `types.either t1 t2`

Value matches `t1` or `t2`.

The choice is made eagerly with each type's shallow `check`, so for attrsets the first composite type always wins: `either (attrsOf int) (submodule { ... })` treats every attrset as `attrsOf int`. When you need to distinguish shapes, use `attrTag` (below). `oneOf` has the same behaviour.

```nix
port = mkOption {
  type = types.either types.port types.str;
  description = "Port number or a systemd socket path.";
};
```

### `types.oneOf [ t1 t2 t3 ... ]`

Value matches any of the listed types. Shorthand for nested `either`.

```nix
value = mkOption {
  type = types.oneOf [ types.int types.str types.bool ];
};
```

### `types.coercedTo fromType coerceFunc toType`

Accepts `fromType`, applies `coerceFunc` to convert it, then checks `toType`. Useful for backward-compatible option changes.

```nix
# Accept a plain string and coerce it to a list with one element
packages = mkOption {
  type = types.coercedTo types.str (s: [ s ]) (types.listOf types.str);
};
```

### `types.enum [ values... ]`

Value must be one of the listed literal values.

```nix
level = mkOption {
  type = types.enum [ "debug" "info" "warn" "error" ];
  default = "info";
};
```

## Module Types

### `types.submodule`

A nested module with its own options. Accepts either an attrset or a function.

**Attrset form:**

```nix
database = mkOption {
  type = types.submodule {
    options = {
      host = mkOption { type = types.str; default = "localhost"; };
      port = mkOption { type = types.port; default = 5432; };
    };
  };
};
```

**Function form** -- receives `{ name, config, lib, pkgs, ... }` where `name` is the attribute name when used inside `attrsOf`:

```nix
vhosts = mkOption {
  type = types.attrsOf (types.submodule ({ name, config, ... }: {
    options = {
      serverName = mkOption { type = types.str; default = name; };
      root = mkOption { type = types.path; };
      enableSSL = mkOption { type = types.bool; default = false; };
    };
    config = mkIf config.enableSSL {
      # Set defaults based on other submodule options
    };
  }));
};
```

### `types.deferredModule`

Stores a module definition without evaluating it. The stored module is later imported into a submodule evaluation. Useful for letting users pass entire modules to be composed elsewhere.

```nix
extraModules = mkOption {
  type = types.listOf types.deferredModule;
  default = [];
  description = "Additional NixOS modules to include in the VM.";
};
```

### `types.functionTo resultType`

A function that returns `resultType`. Useful for lazy or parameterized config.

```nix
mkConfig = mkOption {
  type = types.functionTo types.attrs;
  description = "Function that receives arguments and returns config attrs.";
};
```

## Sum Types (attrTag)

### `types.attrTag { tag1 = option1; tag2 = option2; ... }`

A tagged union: the value is an attrset with exactly one attribute, whose name selects the option (and therefore the type) used for its value. Prefer it over `either`/`oneOf` when the alternatives are all attrsets.

```nix
rules = mkOption {
  type = types.attrsOf (types.attrTag {
    forward = mkOption {
      description = "Forward the packet.";
      type = types.submodule { options.destination = mkOption { type = types.str; }; };
    };
    drop = mkOption {
      description = "Drop the packet.";
      type = types.submodule { };
    };
  });
};
# rules.ssh = { drop = { }; };
# rules.web = { forward.destination = "10.0.0.2"; };
```

## Serialization Types

### `types.json` / `types.toml`

Value types for data that will be serialized. `types.json` accepts null, booleans, integers, floats, strings, paths, lists and attrsets, nested arbitrarily. `types.toml` is the same minus null (TOML has no null), so a null anywhere fails type checking. Use `types.nullOr` at the option level and filter nulls before serialization.

For a config file, use the matching `pkgs.formats.<format> { }` instead: its `.type` is the option type and `.generate` writes the file:

```nix
let
  jsonFormat = pkgs.formats.json {};
  tomlFormat = pkgs.formats.toml {};
in {
  options.settings = mkOption {
    type = jsonFormat.type;
    default = {};
  };
  config.environment.etc."myapp/config.json".source =
    jsonFormat.generate "config.json" config.settings;
}
```

## Special Types

| Type | Description |
|------|-------------|
| `types.fileset` | A lib.fileset value (set of paths with inclusion rules) |
| `types.optionType` | An option type as a value; used for `_module.freeformType` |
| `types.luaInline` | A `lib.mkLuaInline` string embedded verbatim in generated Lua |
| `types.pkgs` | A nixpkgs instance (the entire package set) |
| `types.shellPackage` | A package that provides `shellPath` attr (valid login shells) |
| `types.attrs` | Untyped attribute set -- no checking on values, silently drops earlier definitions and does not discharge `mkIf`/`mkDefault`. Slated for deprecation; use `attrsOf types.anything` or a specific element type. |
| `types.anything` | Accepts any value. Merges recursively for attrsets, concatenates lists, requires single definition for scalars. |
| `types.unspecified` | Deprecated. Do not use in new code. |
| `types.raw` | Accepts any value, no merge. Use for options that receive opaque Nix values. |

## Priority System

When multiple modules define the same option, the priority system resolves conflicts. **Lower number = higher priority.**

| Function | Priority value | Description |
|----------|---------------|-------------|
| `mkOptionDefault value` | 1500 | Priority of an option's `default` |
| `mkDefault value` | 1000 | Low priority, easily overridden |
| (no wrapper) | 100 | Default priority for bare values |
| `mkForce value` | 50 | High priority, overrides most definitions |
| `mkVMOverride value` | 10 | Used by `nixos-rebuild build-vm`; beats `mkForce` |
| `mkOverride n value` | `n` | Custom priority |

```nix
# Module A (provides a sensible default)
services.nginx.enable = mkDefault true;   # priority 1000

# Module B (user config, bare value overrides mkDefault)
services.nginx.enable = true;             # priority 100

# Module C (force, overrides everything above)
services.nginx.enable = mkForce false;    # priority 50

# Custom priority
services.nginx.enable = mkOverride 75 true;  # priority 75 (between default and force)
```

Multiple definitions at the **same priority** trigger a merge (for mergeable types) or an error (for single-value types like `int` or `str`).

## Merge Function Reference

Merge functions control how multiple definitions of the same option combine.

### `mergeOneOption`

Only one definition is allowed. If two modules define the option (at the same priority), evaluation fails. Used by `types.int`, `types.str`, `types.path`, `types.package`, and others.

### `mergeEqualOption`

Multiple definitions are allowed, but they must all produce the same value. If any differ, evaluation fails. Used when you want to catch conflicting definitions without forcing a single source.

### Default merge behaviors

- **bool**: Accepts multiple definitions via priority resolution (not logical AND/OR -- highest priority wins).
- **listOf**: Concatenates all definitions into a single list.
- **attrsOf**: Recursively merges attribute sets; values at the same key are merged by the element type's merge function.
- **lines/commas/envVar**: Concatenates all string definitions with the separator.

### Merge function signature

When writing `mkOptionType`, the merge function signature is:

```nix
merge = loc: defs:
  # loc: option path as list of strings, e.g. ["services" "foo" "port"]
  # defs: list of { file: string; value: any; }
  ...;
```

Built-in composite types (`listOf`, `attrsWith`, `either`, `coercedTo`, ...) also carry an internal `merge.v2` that returns the value plus metadata. Its coherence check throws when a type was patched with `baseType // { check = ...; }`. Add validation with `types.addCheck baseType (v: ...)` instead of overriding `check`.

## Type Creation with mkOptionType

Create custom types with `lib.mkOptionType`:

```nix
myType = lib.mkOptionType {
  name = "myType";
  description = "a value satisfying my custom constraint";
  # Check whether a value is valid
  check = value: lib.isString value && builtins.stringLength value <= 64;
  # Merge multiple definitions
  merge = loc: defs:
    let values = map (d: d.value) defs;
    in if lib.allUnique values
       then builtins.head values
       else throw "Conflicting definitions for ${lib.showOption loc}";
  # Optional: value when no definitions exist (enables optional-like behavior)
  emptyValue = { value = ""; };
  # Optional: functor for type composition (how the type transforms when nested)
  functor = lib.defaultFunctor "myType";
};
```

**Fields:**

| Field | Required | Description |
|-------|----------|-------------|
| `name` | Yes (the only required field) | Short type name for error messages |
| `description` | No | Longer human-readable description |
| `check` | No (defaults to accepting anything) | `value -> bool` -- validates a single value |
| `merge` | No | `loc -> defs -> value` -- combines multiple definitions |
| `emptyValue` | No | `{ value = ...; }` -- default when no definitions exist |
| `functor` | No | Controls type composition behavior (for `attrsOf myType`, etc.) |

## freeformType Pattern

Combines explicitly typed options with a fallback type for any untyped attributes. Useful for modules that wrap config files where you want to type-check known settings but still allow arbitrary pass-through keys.

```nix
{ lib, ... }:
let
  types = lib.types;
in {
  options.services.myapp.settings = {
    freeformType = with types; attrsOf (oneOf [ bool int str ]);

    enable = lib.mkOption {
      type = types.bool;
      default = false;
      description = "Whether to enable myapp.";
    };

    port = lib.mkOption {
      type = types.port;
      default = 3000;
      description = "Port to listen on.";
    };
  };
}
```

How it works:

- **Explicitly typed options** (`enable`, `port`) are checked against their declared type as usual.
- **Everything else** assigned under `settings` falls through to the `freeformType`. For example, `settings.logLevel = "debug";` is checked against `attrsOf (oneOf [ bool int str ])`.
- If a value fails both the explicit option type and the freeform type, evaluation errors.
- Before 25.11, `either` (and so `oneOf`, `number`, `numbers.*`) silently accepted mismatching values inside a `freeformType`. Now they error; wrapping the union in `attrsOf` usually fixes old modules.

This pattern is common in modules wrapping INI/JSON/TOML config files via `pkgs.formats.*`:

```nix
let
  format = pkgs.formats.json {};
in {
  options.services.myapp.settings = {
    freeformType = format.type;

    port = lib.mkOption {
      type = types.port;
      default = 8080;
    };
  };

  config.environment.etc."myapp/config.json".source =
    format.generate "config.json" config.services.myapp.settings;
}
```
