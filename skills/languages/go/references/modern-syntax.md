# Modern Go Guidelines

## Detected Go Version

Read the `go` directive from the project's `go.mod` (or any nested `go.mod` in a workspace) before applying this skill. That single line — for example `go 1.24` — is the target version. Do not pick a higher version than what the module declares.

```bash
grep -h '^go ' go.mod 2>/dev/null
```

## How to Use This Skill

**If a `go` directive is found:**

- Say: "This project is using Go X.XX, so I'll stick to modern Go best practices and freely use language features up to and including this version. If you'd prefer a different target version, just let me know."
- Do NOT list features, do NOT ask for confirmation

**If no `go.mod` exists or the directive is missing:**

- Say: "Could not detect Go version in this repository"
- Ask the user which Go version to target (e.g. 1.23 / 1.24 / 1.25 / 1.26)

**When writing Go code**, use ALL features from this document up to the target version:

- Prefer modern built-ins and packages (`slices`, `maps`, `cmp`) over legacy patterns
- Never use features from newer Go versions than the target
- Never use outdated patterns when a modern alternative is available

---

## Features by Go Version

### Go 1.0+

- `time.Since`: `time.Since(start)` instead of `time.Now().Sub(start)`

### Go 1.8+

- `time.Until`: `time.Until(deadline)` instead of `deadline.Sub(time.Now())`

### Go 1.13+

- `errors.Is`: `errors.Is(err, target)` instead of `err == target` (works with wrapped errors)

### Go 1.18+

- `any`: Use `any` instead of `interface{}`
- `bytes.Cut`: `before, after, found := bytes.Cut(b, sep)` instead of Index+slice
- `strings.Cut`: `before, after, found := strings.Cut(s, sep)`

### Go 1.19+

- `fmt.Appendf`: `buf = fmt.Appendf(buf, "x=%d", x)` instead of `[]byte(fmt.Sprintf(...))`
- `atomic.Bool`/`atomic.Int64`/`atomic.Pointer[T]`: Type-safe atomics instead of `atomic.StoreInt32`

```go
var flag atomic.Bool
flag.Store(true)
if flag.Load() { ... }

var ptr atomic.Pointer[Config]
ptr.Store(cfg)
```

### Go 1.20+

- `strings.Clone`: `strings.Clone(s)` to copy string without sharing memory
- `bytes.Clone`: `bytes.Clone(b)` to copy byte slice
- `strings.CutPrefix/CutSuffix`: `if rest, ok := strings.CutPrefix(s, "pre:"); ok { ... }`
- `errors.Join`: `errors.Join(err1, err2)` to combine multiple errors
- `context.WithCancelCause`: `ctx, cancel := context.WithCancelCause(parent)` then `cancel(err)`
- `context.Cause`: `context.Cause(ctx)` to get the error that caused cancellation

### Go 1.21+

**Built-ins:**

- `min`/`max`: `max(a, b)` instead of if/else comparisons
- `clear`: `clear(m)` to delete all map entries, `clear(s)` to zero slice elements

**slices package:**

- `slices.Contains`: `slices.Contains(items, x)` instead of manual loops
- `slices.Index`: `slices.Index(items, x)` returns index (-1 if not found)
- `slices.IndexFunc`: `slices.IndexFunc(items, func(item T) bool { return item.ID == id })`
- `slices.SortFunc`: `slices.SortFunc(items, func(a, b T) int { return cmp.Compare(a.X, b.X) })`
- `slices.Sort`: `slices.Sort(items)` for ordered types
- `slices.Max`/`slices.Min`: `slices.Max(items)` instead of manual loop
- `slices.Reverse`: `slices.Reverse(items)` instead of manual swap loop
- `slices.Compact`: `slices.Compact(items)` removes consecutive duplicates in-place
- `slices.Clip`: `slices.Clip(s)` removes unused capacity
- `slices.Clone`: `slices.Clone(s)` creates a copy

**maps package:**

- `maps.Clone`: `maps.Clone(m)` instead of manual map iteration
- `maps.Copy`: `maps.Copy(dst, src)` copies entries from src to dst
- `maps.DeleteFunc`: `maps.DeleteFunc(m, func(k K, v V) bool { return condition })`

**sync package:**

- `sync.OnceFunc`: `f := sync.OnceFunc(func() { ... })` instead of `sync.Once` + wrapper
- `sync.OnceValue`: `getter := sync.OnceValue(func() T { return computeValue() })`

**context package:**

- `context.AfterFunc`: `stop := context.AfterFunc(ctx, cleanup)` runs cleanup on cancellation
- `context.WithTimeoutCause`: `ctx, cancel := context.WithTimeoutCause(parent, d, err)`
- `context.WithDeadlineCause`: Similar with deadline instead of duration

### Go 1.22+

**Loops:**

- `for i := range n`: `for i := range len(items)` instead of `for i := 0; i < len(items); i++`
- Loop variables are now safe to capture in goroutines (each iteration has its own copy)

**cmp package:**

- `cmp.Or`: `cmp.Or(flag, env, config, "default")` returns first non-zero value

```go
// Instead of:
name := os.Getenv("NAME")
if name == "" {
    name = "default"
}
// Use:
name := cmp.Or(os.Getenv("NAME"), "default")
```

**reflect package:**

- `reflect.TypeFor`: `reflect.TypeFor[T]()` instead of `reflect.TypeOf((*T)(nil)).Elem()`

**net/http:**

- Enhanced `http.ServeMux` patterns: `mux.HandleFunc("GET /api/{id}", handler)` with method and path params
- `r.PathValue("id")` to get path parameters

### Go 1.23+

- `maps.Keys(m)` / `maps.Values(m)` return iterators
- `slices.Collect(iter)` not manual loop to build slice from iterator
- `slices.Sorted(iter)` to collect and sort in one step

```go
keys := slices.Collect(maps.Keys(m))       // not: for k := range m { keys = append(keys, k) }
sortedKeys := slices.Sorted(maps.Keys(m))  // collect + sort
for k := range maps.Keys(m) { process(k) } // iterate directly
```

#### time package

- `time.Tick`: Use `time.Tick` freely — as of Go 1.23, the garbage collector can recover unreferenced tickers, even if they haven't been stopped. The Stop method is no longer necessary to help the garbage collector. There is no longer any reason to prefer NewTicker when Tick will do.

### Go 1.24+

- `t.Context()` not `context.WithCancel(context.Background())` in tests.
  ALWAYS use t.Context() when a test function needs a context.

Before:

```go
func TestFoo(t *testing.T) {
    ctx, cancel := context.WithCancel(context.Background())
    defer cancel()
    result := doSomething(ctx)
}
```

After:

```go
func TestFoo(t *testing.T) {
    ctx := t.Context()
    result := doSomething(ctx)
}
```

- `omitzero` not `omitempty` in JSON struct tags.
  ALWAYS use omitzero for time.Duration, time.Time, structs, slices, maps.

Before:

```go
type Config struct {
    Timeout time.Duration `json:"timeout,omitempty"` // doesn't work for Duration!
}
```

After:

```go
type Config struct {
    Timeout time.Duration `json:"timeout,omitzero"`
}
```

- `b.Loop()` not `for i := 0; i < b.N; i++` in benchmarks.
  ALWAYS use b.Loop() for the main loop in benchmark functions.

Before:

```go
func BenchmarkFoo(b *testing.B) {
    for i := 0; i < b.N; i++ {
        doWork()
    }
}
```

After:

```go
func BenchmarkFoo(b *testing.B) {
    for b.Loop() {
        doWork()
    }
}
```

- `strings.SplitSeq` not `strings.Split` when iterating.
  ALWAYS use SplitSeq/FieldsSeq when iterating over split results in a for-range loop.

Before:

```go
for _, part := range strings.Split(s, ",") {
    process(part)
}
```

After:

```go
for part := range strings.SplitSeq(s, ",") {
    process(part)
}
```

Also: `strings.FieldsSeq`, `bytes.SplitSeq`, `bytes.FieldsSeq`.

### Go 1.25+

- `wg.Go(fn)` not `wg.Add(1)` + `go func() { defer wg.Done(); ... }()`.
  ALWAYS use wg.Go() when spawning goroutines with sync.WaitGroup.

Before:

```go
var wg sync.WaitGroup
for _, item := range items {
    wg.Add(1)
    go func() {
        defer wg.Done()
        process(item)
    }()
}
wg.Wait()
```

After:

```go
var wg sync.WaitGroup
for _, item := range items {
    wg.Go(func() {
        process(item)
    })
}
wg.Wait()
```

### Go 1.26+

- `new(val)` not `x := val; &x` — returns pointer to any value.
  Go 1.26 extends new() to accept expressions, not just types.
  Type is inferred: new(0) → *int, new("s") →*string, new(T{}) → *T.
  DO NOT use `x := val; &x` pattern — always use new(val) directly.
  DO NOT use redundant casts like new(int(0)) — just write new(0).
  Common use case: struct fields with pointer types.

Before:

```go
timeout := 30
debug := true
cfg := Config{
    Timeout: &timeout,
    Debug:   &debug,
}
```

After:

```go
cfg := Config{
    Timeout: new(30),   // *int
    Debug:   new(true), // *bool
}
```

- `errors.AsType[T](err)` not `errors.As(err, &target)`.
  ALWAYS use errors.AsType when checking if error matches a specific type.

Before:

```go
var pathErr *os.PathError
if errors.As(err, &pathErr) {
    handle(pathErr)
}
```

After:

```go
if pathErr, ok := errors.AsType[*os.PathError](err); ok {
    handle(pathErr)
}
```

### Go 1.27+

- Generic methods: a method may now declare its own type parameters, so a helper
  scoped to one type no longer needs a package-scope generic function. Interface
  methods still cannot declare type parameters, and a generic method cannot
  satisfy an interface; keep the package-level function when the operation must
  be part of an interface contract.
  Reference example: `(*rand.Rand).N[Int intType](n Int) Int` in `math/rand/v2`.

- `strings.CutLast` / `bytes.CutLast` instead of `LastIndex` slicing.

Before:

```go
if i := strings.LastIndex(path, "/"); i >= 0 {
    dir, file := path[:i], path[i+1:]
}
```

After:

```go
if dir, file, ok := strings.CutLast(path, "/"); ok {
    // dir, file
}
```

- `url.Values.Clone()` and `url.URL.Clone()` instead of manual shallow copies
  (`Values` is `map[string][]string`; a shallow copy shares the slices).
- `big.Int.Divide(x, y, r, big.Floor)` for rounding-mode division instead of the
  sign-correction dance around `QuoRem` (modes: `big.Trunc`, `big.Floor`,
  `big.Round`, `big.Ceil`).
- Stdlib `uuid` instead of `github.com/google/uuid` (or `gofrs/uuid`). The
  stdlib generators (`uuid.New()`, `uuid.NewV4()`, `uuid.NewV7()`) return values
  without errors; prefer `uuid.NewV7()` for database primary keys where index
  locality matters. Check `go mod why -m github.com/google/uuid` first: v3/v5
  namespace UUIDs and SQL `Scanner`/`driver.Valuer` integration are not yet
  covered by the stdlib package.
- `encoding/json/v2` is stable and the default since Go 1.27 (`encoding/json`
  becomes a thin wrapper over it; unmarshal is significantly faster). Prefer the
  v2 API for new code; use `encoding/json/jsontext` for syntactic streaming
  work. Migrate deliberately, not blindly:
  - Duplicate object member names are now rejected (v1 silently kept the last).
  - Invalid UTF-8 in JSON strings is now rejected (v1 replaced it silently).
  - The `format` and `unknown` struct tags, `DiscardUnknownMembers`, and
    `SkipFunc` are gone; the `inline` tag is renamed `embed`.
  - `GOEXPERIMENT=nojsonv2` is a temporary compatibility bridge, not a stance.
- `synctest.Sleep(d)` advances the bubble's fake clock directly; and
  `httptest.NewTestServer()` is an in-memory fake-network server that composes
  with `synctest` (see the testing reference).
- `runtime/pprof` goroutineleak profile is generally available (experimental in
  Go 1.26): served at `/debug/pprof/goroutineleak`, no build flag required (see
  the concurrency reference).
- `go fix` gains `atomictypes`, `embedlit`, `slicesbackward`, `unsafefuncs`
  modernizers (`waitgroup` renamed `waitgroupgo`, `fmtappendf` removed); run
  `go fix ./...` after a toolchain upgrade.
- `go test` runs the `stdversion` vet check by default: uses of stdlib symbols
  newer than the module's `go` directive fail CI. Bump the directive or gate
  the API behind build tags; don't silence the check.
- `go mod tidy` merges duplicate `require` blocks into the standard two-block
  layout for `go 1.27` modules; run it once after bumping the directive.

Version-bump risk checklist (verify, don't rewrite) before shipping `go 1.27`:

- Removed `GODEBUG` settings (`asynctimerchan`, `tlsunsafeekm`, `tlsrsakex`,
  `tls3des`, `tls10server`, `x509keypairleaf`, `gotypesalias`): a `godebug`
  line in `go.mod` or `//go:debug` comment still pinning one to its old value
  now fails the build. Search with
  `grep -rn 'go:debug\|godebug' go.mod **/*.go`.
- json/v2 default strictness: re-run integration tests against real-world
  payloads, not just unit tests, before the bump ships.
- Size-specialized allocator on by default (up to 30% faster allocations under
  80 bytes, ~1% overall, ~60 KB binary cost); `GOEXPERIMENT=nosizespecializedmalloc`
  is scheduled for removal in Go 1.28, not a long-term setting.
- Darwin floor raised to macOS 13 (Ventura); `linux/ppc64` builds ELFv2 and
  needs kernel 3.13+; `bzr` support removed from the `go` command.
- Tracebacks include `runtime/pprof` goroutine labels by default; disable with
  `GODEBUG=tracebacklabels=0` if labels leak sensitive data into crash logs.
