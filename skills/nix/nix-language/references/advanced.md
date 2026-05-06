# Nix Language Advanced Reference

## Table of Contents

- [Builtins by Category](#builtins-by-category)
- [lib Functions Reference](#lib-functions-reference)
- [Type Coercion Rules](#type-coercion-rules)
- [Function Patterns](#function-patterns)

---

## Builtins by Category

### String Operations

| Builtin | Signature | Purpose |
|---------|-----------|---------|
| `builtins.substring` | `start: len: str:` | Extract substring |
| `builtins.stringLength` | `str:` | Length of string |
| `builtins.replaceStrings` | `from: to: str:` | Replace all occurrences |
| `builtins.match` | `regex: str:` | POSIX regex match, returns list of captures or null |
| `builtins.split` | `regex: str:` | Split by regex, returns list alternating non-matches and match groups |
| `builtins.concatStringsSep` | `sep: list:` | Join strings with separator |
| `builtins.toString` | `x:` | Coerce to string (booleans, ints, paths, derivations) |
| `builtins.hashString` | `algo: str:` | Hash a string (sha256, sha512, md5) |
| `builtins.convertHash` | `{ hash; toHashFormat; }:` | Convert between hash formats (base16/base32/base64/sri) |

### List Operations

| Builtin | Signature | Purpose |
|---------|-----------|---------|
| `builtins.map` | `f: list:` | Apply f to each element |
| `builtins.filter` | `pred: list:` | Keep elements where pred is true |
| `builtins.foldl'` | `f: init: list:` | Strict left fold |
| `builtins.length` | `list:` | Number of elements (does not evaluate elements) |
| `builtins.head` | `list:` | First element |
| `builtins.tail` | `list:` | All but first element |
| `builtins.elemAt` | `list: n:` | Element at index n |
| `builtins.elem` | `x: list:` | Check membership |
| `builtins.sort` | `cmp: list:` | Sort with comparator |
| `builtins.concatLists` | `lists:` | Flatten one level |
| `builtins.genList` | `f: n:` | Generate list of n elements |
| `builtins.groupBy` | `f: list:` | Group by key function → attrsOf list |
| `builtins.all` | `pred: list:` | True if all match |
| `builtins.any` | `pred: list:` | True if any matches |
| `builtins.concatMap` | `f: list:` | Map then flatten |
| `builtins.zipAttrsWith` | `f: listOfAttrs:` | Zip attrsets, f receives name and list of values |
| `builtins.partition` | `pred: list:` | Split into `{ right; wrong; }` |
| `builtins.listToAttrs` | `list:` | Convert `[{ name; value; }]` to attrset |

### Attribute Set Operations

| Builtin | Signature | Purpose |
|---------|-----------|---------|
| `builtins.attrNames` | `set:` | Sorted list of keys |
| `builtins.attrValues` | `set:` | Values sorted by key |
| `builtins.hasAttr` | `name: set:` | Check key exists |
| `builtins.getAttr` | `name: set:` | Get value by name (throws on missing) |
| `builtins.removeAttrs` | `set: names:` | Remove keys |
| `builtins.intersectAttrs` | `a: b:` | Keys in both, values from b |
| `builtins.catAttrs` | `name: listOfSets:` | Collect attr `name` from each set that has it |
| `builtins.mapAttrs` | `f: set:` | Transform values (f receives name and value) |
| `builtins.listToAttrs` | `list:` | `[{name; value;}]` → attrset |
| `builtins.functionArgs` | `f:` | Get argument names and defaults of a function |

### Type Checking

| Builtin | Purpose |
|---------|---------|
| `builtins.typeOf` | Returns type name string: "int", "bool", "string", "path", "null", "set", "list", "lambda", "float" |
| `builtins.isAttrs` | Is attribute set? |
| `builtins.isList` | Is list? |
| `builtins.isString` | Is string? |
| `builtins.isInt` | Is integer? |
| `builtins.isFloat` | Is float? |
| `builtins.isBool` | Is boolean? |
| `builtins.isNull` | Is null? |
| `builtins.isFunction` | Is function? |
| `builtins.isPath` | Is path? |

### Path and File Operations

| Builtin | Signature | Purpose |
|---------|-----------|---------|
| `builtins.readFile` | `path:` | Read file as string (eval time) |
| `builtins.readDir` | `path:` | List directory → attrset of name → type ("regular", "directory", "symlink") |
| `builtins.pathExists` | `path:` | Check if path exists |
| `builtins.path` | `{ path; name?; filter?; recursive?; sha256?; }:` | Copy to store with options |
| `builtins.toFile` | `name: content:` | Create file in store from string |
| `builtins.filterSource` | `pred: path:` | Copy to store filtering files (legacy, prefer lib.fileset) |
| `builtins.baseNameOf` | `path:` | Last component of path |
| `builtins.dirOf` | `path:` | Parent directory |
| `import` | `path:` | Evaluate .nix file at path |

### JSON / Serialization

| Builtin | Signature | Purpose |
|---------|-----------|---------|
| `builtins.toJSON` | `value:` | Serialize to JSON string |
| `builtins.fromJSON` | `str:` | Parse JSON to Nix value |
| `builtins.toXML` | `value:` | Serialize to XML |
| `builtins.fromTOML` | `str:` | Parse TOML to Nix value |

### Derivation and Store

| Builtin | Signature | Purpose |
|---------|-----------|---------|
| `builtins.derivation` | `attrs:` | Low-level derivation creation (prefer stdenv.mkDerivation) |
| `builtins.storePath` | `path:` | Reference existing store path |
| `builtins.placeholder` | `output:` | Placeholder for output path in derivation |
| `builtins.storeDir` | | The Nix store directory (usually `/nix/store`) |
| `builtins.currentSystem` | | The system type string (e.g., `x86_64-linux`) |
| `builtins.nixVersion` | | The Nix version string |

### Fetchers (block evaluation)

| Builtin | Signature | Purpose |
|---------|-----------|---------|
| `builtins.fetchurl` | `url:` | Download file (blocks eval) |
| `builtins.fetchTarball` | `{ url; sha256?; }` | Download and extract tarball |
| `builtins.fetchGit` | `{ url; ref?; rev?; }` | Clone git repo |
| `builtins.fetchTree` | `{ type; ... }` | Generic fetcher (experimental) |

### Debugging

| Builtin | Signature | Purpose |
|---------|-----------|---------|
| `builtins.trace` | `msg: value:` | Print msg, return value |
| `builtins.traceVerbose` | `msg: value:` | Print only when `--trace-verbose` |
| `builtins.seq` | `a: b:` | Force evaluation of a, return b |
| `builtins.deepSeq` | `a: b:` | Force deep evaluation of a, return b |
| `builtins.abort` | `msg:` | Abort evaluation with error |
| `builtins.throw` | `msg:` | Throw catchable error |
| `builtins.tryEval` | `expr:` | Returns `{ success; value; }` — catches throw but not abort |

---

## lib Functions Reference

### Attrset Operations

```nix
lib.filterAttrs (n: v: v != null) set      # Remove null values
lib.mapAttrs (n: v: v + 1) set              # Transform values
lib.mapAttrs' (n: v: { name = "prefix-${n}"; value = v; }) set  # Transform keys+values
lib.genAttrs [ "a" "b" ] (n: "${n}-value")  # Generate from name list
lib.attrByPath [ "a" "b" ] default set      # Deep access with default
lib.setAttrByPath [ "a" "b" ] value         # Create nested attrset
lib.recursiveUpdate a b                      # Deep merge (b wins on conflict)
lib.getAttrFromPath [ "a" "b" ] set          # Deep access (throws on missing)
lib.hasAttrByPath [ "a" "b" ] set            # Deep has-attribute check
lib.foldlAttrs f init set                    # Fold over attrset (name, value)
lib.nameValuePair name value                 # Create { name; value; } pair
lib.mapAttrsToList f set                     # Map to list (f receives name, value)
lib.concatMapAttrs f set                     # Map each attr to attrset, merge results
lib.mergeAttrsList [ a b c ]                 # Shallow merge list of attrsets (last wins)
```

### List Operations

```nix
lib.flatten [ [ 1 ] [ 2 [ 3 ] ] ]          # Deep flatten → [ 1 2 3 ]
lib.unique [ 1 2 1 3 ]                      # Deduplicate → [ 1 2 3 ]
lib.subtractLists a b                        # Elements in b not in a
lib.intersectLists a b                       # Elements in both
lib.zipListsWith f a b                       # Zip two lists with function
lib.imap0 (i: v: { inherit i v; }) list     # Map with 0-based index
lib.imap1 (i: v: { inherit i v; }) list     # Map with 1-based index
lib.range 1 5                                # Generate [ 1 2 3 4 5 ]
lib.take 3 list                              # First 3 elements
lib.drop 3 list                              # All after first 3
lib.last list                                # Last element
lib.init list                                # All except last
lib.findFirst pred default list              # First matching element
lib.count pred list                          # Count matching elements
lib.partition pred list                      # Split into { right; wrong; }
lib.groupBy f list                           # Group by key → attrsOf list
lib.naturalSort [ "a10" "a2" "a1" ]         # Natural sort → [ "a1" "a2" "a10" ]
```

### String Operations

```nix
lib.concatStrings [ "a" "b" "c" ]           # → "abc"
lib.concatStringsSep ", " [ "a" "b" ]       # → "a, b"
lib.concatMapStringsSep "\n" f list          # Map then join
lib.optionalString bool "value"              # "" or "value"
lib.strings.hasPrefix "foo" "foobar"         # true
lib.strings.hasSuffix ".nix" "file.nix"     # true
lib.strings.removeSuffix ".nix" "file.nix"  # "file"
lib.strings.removePrefix "lib/" "lib/foo"   # "foo"
lib.splitString "," "a,b,c"                 # [ "a" "b" "c" ]
lib.toLower "FOO"                            # "foo"
lib.toUpper "foo"                            # "FOO"
lib.escapeShellArg "hello world"             # "'hello world'"
lib.escapeShellArgs [ "a" "b c" ]            # "a 'b c'"
lib.replaceStrings [ "a" ] [ "b" ] "abc"    # "bbc"
lib.strings.fileContents ./file.txt          # Read file, trim trailing newline
```

### Trivial / Functional

```nix
lib.id x                    # Identity: returns x
lib.const x y                # Always returns x
lib.flip f a b               # f b a
lib.pipe value [ f1 f2 f3 ] # f3 (f2 (f1 value))
lib.fix f                    # Fixed point: let x = f x; in x
lib.extends overlay base     # Compose overlay on base function
lib.composeExtensions o1 o2  # Compose two overlays
lib.composeManyExtensions    # Compose list of overlays
lib.traceVal x               # trace x then return x
lib.traceValSeq x            # Deep-evaluate x, trace, return
lib.traceSeq x y             # Deep-evaluate and trace x, return y
```

### Version Comparison

```nix
lib.versionOlder "1.2" "1.3"    # true
lib.versionAtLeast "1.3" "1.2"  # true
lib.versions.major "1.2.3"      # "1"
lib.versions.minor "1.2.3"      # "2"
lib.versions.patch "1.2.3"      # "3"
```

### Platform

```nix
lib.systems.inspect.patterns.isDarwin   # { kernel = { name = "darwin"; }; }
stdenv.isDarwin                          # true on macOS
stdenv.isLinux                           # true on Linux
stdenv.hostPlatform.system               # "aarch64-darwin", "x86_64-linux", etc.
```

---

## Type Coercion Rules

### String Interpolation `"${expr}"`

| Input Type | Coercion |
|-----------|----------|
| String | Used as-is |
| Path | Copied to store, store path string returned |
| Derivation | Built, `outPath` (store path) used — creates runtime dependency |
| Integer | Converted to decimal string |
| Boolean | Error — use `lib.boolToString` |
| Null | Error |
| List | Error — use `builtins.concatStringsSep` |
| Attrset | Error unless it has `outPath` or `__toString` |

### Path Coercion

- Path + string = path: `./dir + "/file.nix"` → path
- String + path = string: `"prefix" + ./file` → string (copies to store)
- Path in interpolation copies to store: `"${./src}"` → `"/nix/store/...-src"`

### The `builtins.toString` Function

| Input | Result |
|-------|--------|
| String | Identity |
| Integer | Decimal |
| Float | Decimal |
| Boolean | `"1"` or `""` (not `"true"`/`"false"`) |
| Null | `""` |
| Path | Store path string |
| Derivation | Store path string |
| List | Space-separated toString of elements |
| Attrset with `__toString` | Calls `__toString self` |
| Attrset with `outPath` | `outPath` value |

---

## Function Patterns

### `@` Binding

```nix
# Capture named args AND the full attrset
{ pname, version, ... } @ args: {
  passthru = { inherit (args) pname version; };
}
```

The `@` can go on either side: `args @ { pname, ... }:` is equivalent.

### Default Arguments

```nix
{ enableFeature ? false, extraFlags ? [] }: ...
```

Default expressions can reference other arguments:

```nix
{ pname, version, name ? "${pname}-${version}" }: ...
```

### Checking if an Argument Was Passed

```nix
# builtins.functionArgs returns { argName = hasDefault; }
builtins.functionArgs ({ a, b ? 1 }: null)
# → { a = false; b = true; }
```

`callPackage` uses this to know which arguments to auto-fill vs which have defaults.
