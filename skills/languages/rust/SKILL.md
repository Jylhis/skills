---
name: rust
description: "Rust implementation contract: typed boundaries and newtypes, exhaustive enums as single source of truth, error discipline (typed public APIs, n0-error), deterministic testing via injected host context, and channel-first concurrency. Use when writing or reviewing Rust (bins, libs, build scripts)."
---

## Scope
- Applies to all Rust changes (bins, libs, build scripts).
- If repo-specific Rust docs conflict, repo docs win.

## Non-negotiables
- Use the edition and toolchain defined by the repo (Cargo.toml edition + rust-toolchain.toml). Do not assume 2024.
- No `unsafe` unless explicitly requested, no practical safe alternative exists, and the call site is justified with a precise `SAFETY:` proof plus tests.
- No stringly errors in public APIs.

## Build & lint loop (required)
For any meaningful change:
1) `cargo fmt`
2) `cargo test` (smallest scope that covers the change)
3) `cargo clippy` (smallest scope that covers the change)

If the repo requires it: run `cargo clippy --fix -p <crate>` first, then rerun clippy.

If you cannot run commands, say exactly which command to run and why you couldn’t.

In any change summary, explicitly list Cargo.toml changes (deps/features) and the reason.

## API design
- Document public APIs with `///` including:
  - side effects, blocking/async behavior
  - errors (what can fail and why)
  - invariants and ordering guarantees
- Make optionality explicit in types: `Option<T>` or enums; avoid prose-only “optional”.
- When a closed set of string keys/roles/selectors is used internally, model it as an enum and centralize string conversion via `Display`/`EnumString` (or `From`/`TryFrom`), using a single `#[strum(serialize_all = "...")]` scheme; keep raw strings at API boundaries.
- For any closed set of features/capabilities/toggles that drives Rust behavior, define a semantic enum and use it as the single source of truth for iteration, summaries, and dispatch.
  - Prefer this pattern:
    1. `enum FeatureKind { ... }`
    2. `FeatureKind::iter()`
    3. `match feature_kind { ... }`
  - If the wire/config shape is still a struct of booleans for serde or CLI reasons, add one accessor like `FeatureKind::is_enabled(&Config) -> bool`.
  - That accessor MUST destructure the source struct without `..` and MUST use an exhaustive `match`.
  - Goal: adding a new feature should fail compilation until all enum-driven behavior is updated. Do not allow silent omission from summaries, dispatch tables, or validation.
  - Do not maintain repeated `if cfg.foo { ... } if cfg.bar { ... }` lists across multiple functions when those flags form a closed set. Replace them with an enum-driven loop plus one exhaustive accessor.
- MUST keep branches pure (input shaping only) and execute shared side effects exactly once.
- MUST decompose multi-phase functions into named phase helpers with typed intermediate artifacts.
- MUST lift helper types to module scope when used by multi-phase orchestration; avoid ad-hoc local type declarations in large functions.
- MUST enforce function complexity limits via lint/CI; exceptions require explicit, documented justification.
- MUST NOT introduce pass-through abstraction layers that merely mirror lower-level APIs.
  - If an abstraction wraps lower-level primitives, it MUST add boundary value (policy, invariants, validation, orchestration, or domain semantics).
  - Keep storage/transport mechanics in the infrastructure layer and keep project-layer contracts focused on behavior and rules.
- When pulling multiple fields from a struct, prefer destructuring (`let Foo { a, b, .. } = foo;`) over repetitive `let a = foo.a;` bindings to reduce omissions and keep intent clear.

## Host Inputs And Testability
- Do not make core logic read process-global state directly when those values affect behavior.
  Examples include environment variables, current directory, runtime/config paths, wall clock, command paths, sockets, and host service locations.
- Prefer a shared typed context as the production and test interface.
  Production should build it once at the boundary, for example `HostContext::discover()`, and tests should construct the same type directly with deterministic values.
- Use plain structs for value snapshots captured at one point in time, such as env-derived paths, cwd, runtime dirs, config paths, command paths, and fixed timestamps.
- Use small semantic traits for behaviorful dependencies, such as command execution, filesystem mutation, clocks that advance, network calls, secret resolution, or session catalogs.
- Prefer domain traits over pass-through global wrappers.
  For example, prefer `SecretResolver::resolve(&grant)` over a generic `EnvProvider::get("KEY")` unless environment lookup is the actual domain contract.
- Keep production adapters thin and boring: read `std::env`, `std::env::current_dir`, wall clock, host paths, or process-global values once, map them into typed inputs, then call the shared core.
- In tests, do not mutate process-global state with `std::env::set_var`, `std::env::remove_var`, or `std::env::set_current_dir` to control core behavior.
  Use typed contexts, trait fakes, temp dirs, or child-process `Command::env` instead.
- Use `Command::env` and `Command::env_clear` for subprocess tests when validating CLI or process-boundary behavior.
- Avoid test-only global mock contexts as a first choice.
  They are acceptable only as a temporary compatibility bridge when extracting a shared production/test interface would be too large for the current change.
- If adding a trait introduces generic clutter through many call layers, move the trait to the boundary and pass a typed result/context inward instead.

## CLI + Error Discipline (canonical IDs)
- `R9 THIN_CLI_TYPED_CONTRACTS`: Keep business logic out of CLI crates and default to typed command/behavior tests.
  - Use argv parser tests sparingly as boundary contract checks for stable/documented CLI surfaces (for example, one smoke test per critical command shape/flag family).
  - Prefer `Command::debug_assert()` for command-shape sanity and integration-style tests (for example `trycmd`) for documented command examples.
  - Avoid broad stringly argv test matrices that duplicate typed behavior tests.
- `R10 STRUCTURED_ERROR_DISCIPLINE`: Preserve structured error chains with call-site/location metadata; avoid stringifying source errors and prefer structured `tracing` diagnostics.

## Concurrency
- Prefer channels (`mpsc`, `broadcast`, `watch`) over shared mutable state when feasible.
- Never block in async contexts. Use tokio primitives (`spawn_blocking`, async IO, `tokio::fs`).
- If an API is async end-to-end, keep it async; avoid hidden runtimes/blocking shims.

## Dependencies
- Prefer established crates for common tasks (tempfile, tracing, bytes).
- Minimize dependencies, but do not reinvent correctness.
- Run `cargo audit` when dependency changes are security-relevant.
- When changing Rust code that requires new deps or feature flags, update Cargo.toml and mention it in the change summary.

## Non-empty collections (type-level)
- When non-emptiness is a semantic requirement, represent it at the type level.
- Prefer the `mitsein` non-empty collection types (e.g., `mitsein::Vec1`, `mitsein::Slice1`) over `Vec`/`Option` when emptiness is invalid.
- When a field is optional but semantically non-empty when present, prefer an outer optional non-empty shape such as `Option<mitsein::vec1::Vec1<T>>` (or the repo's established equivalent) instead of `Vec<T>` plus emptiness conventions.
- When an outer optional non-empty collection already carries presence, do not re-encode absence inside nested selector/item variants with shapes like `Option<String>` or empty-capable inner vectors. Flatten the enum/item contract under the outer collection unless the nested grouping is itself semantically required.

Agent instruction (ask once):
- If the repo already depends on or consistently uses `mitsein` for non-empty semantics, treat that as the established default and do not ask again.
- Ask once only when the repo does not already establish a non-empty collection choice. If the user confirms `mitsein`, use it consistently for that repo from then on.

## Trait usage and testing pattern
Production/library code:
- Prefer generics / `impl Trait` for performance and clarity.

Test harnesses:
- Use trait objects (`Box<dyn Trait>`) when it reduces boilerplate or you need to swap implementations.

Contract tests:
- Contract test logic should be generic (`fn contract<S: Trait>(...)` or `async fn ...`).
- Fixtures should be thin and may return `Box<dyn Trait>`.

Decision signal:
- If you are threading many generic type parameters just to run tests, switch the fixture to `Box<dyn Trait>`.

## Error handling

### Error Stack Choice
- Follow the repo’s existing error strategy if one is already established.
- For new crates (or new major subsystems without an existing convention), prefer `n0-error` for typed errors with call-site location.

n0-error usage rules:
- Libraries: define concrete error enums/structs that participate in the stack error chain (via n0-error derive/macros) so call-site metadata is preserved through sources.
- Applications/tests: prefer `n0_error::AnyError` for ergonomic error propagation while preserving location when originating errors are stack errors.
- When converting plain std errors into `AnyError`, use the crate’s extension methods (e.g., std-context / anyerr) rather than relying on blanket `From`, which can lose stack metadata.
- Construct errors using `Meta::new()` or the crate’s constructor macro (e.g., `e!()`) so call-site location is recorded.

Do not refactor existing crates to n0-error unless:
- the repo explicitly requests it, or
- the change is already touching most error surfaces and the migration is low risk.

### Error boundaries (typed vs. AnyError / anyhow)
- Public library boundaries that callers may branch on MUST return a typed error (enum/struct).
  - Example: adapter ingress, domain command handlers, validation APIs.
- Internal helpers MAY return `n0_error::AnyError` (or `anyhow::Error` in legacy crates) for ergonomic context and propagation.
- Boundary rule: never let `AnyError`/`anyhow::Error` escape through a typed boundary.
  - Map at the boundary into the typed error:
    - Provide `TypedError::Other { source: AnyError }` (or an equivalent `other(source)` constructor).
    - Implement `From<AnyError> for TypedError` only if it maps unconditionally into `Other { source }` to keep `?` ergonomic.
- Prefer preserving a small set of semantic variants in typed errors (e.g., `Unmatched`, `InvalidInput`, `MissingMapping`), and funnel everything else into `Other { source }`.

Practical guidance:
- Inside a typed boundary, avoid `bail!()`/`anyhow!()` unless you immediately map into the typed error.
- If a dependency error is common (e.g., parse errors), add a targeted `From<DepError> for TypedError` so `?` stays ergonomic.


## Logging
- Use `tracing` with structured fields.
- Log: startup config summary, client connects/disconnects, auth/session events, and errors with context.
- Avoid logging secrets and raw payload bytes.

## Testing
- Test code only: MUST use `#[tokio::test(flavor = "multi_thread")]` for async tests unless the repo specifies otherwise.
- Test code only: MUST keep exactly one async test runner attribute on a test function (for example `tokio::test`).
- Test code only: MAY combine `test-case` with `tokio::test` on one async test function.
  - MUST place each `#[test_case(...)]` attribute before `#[tokio::test(...)]` so cases are discovered once and executed once.
- Test code only: SHOULD prefer one parameterized contract test over many near-identical tests.
  - Add cases only for new semantic branches/invariants.
- Test code only: MUST prefer deterministic tests and avoid timing-dependent sleeps.
- Keep tests in dedicated test modules rather than mixing test-only imports and helpers into production scope.
- For modules over 200 LOC, prefer a separate `tests.rs` sibling module with `#[cfg(test)] mod tests;` in the main module file.

## Bytes guideline (variable payloads vs fixed IDs)
Use `bytes::Bytes` for owned, variable-length payload bytes (network/file payloads, serialized messages, blob contents). `Bytes` clones are cheap and avoid copying.

Do not use `Bytes` for fixed-size identifiers; use `[u8; N]` newtypes (e.g., `[u8; 32]`) for hashes/keys/IDs. If serialized, encode as byte strings (e.g., via `serde_bytes` field attributes).

Serde:
- Enable bytes serde: `bytes = { version = "...", features = ["serde"] }`.
- Add a codec-specific test when necessary to ensure byte buffers encode as byte strings (not arrays of integers).

## CLI Contracts (Clap-Derive-First)

Use clap derive as the primary contract surface for Rust CLIs.

- Model each user-selectable domain as a typed enum deriving `clap::ValueEnum`.
- Prefer `#[arg(value_enum)]` + `default_value_t` over manual parsing.
- For list args, prefer clap-native tokenization (`value_delimiter`, `num_args`) over ad-hoc split logic.
- Do not parse raw strings to decide allowed values; let enum variants define the accepted set.
- Implement special list semantics (for example `all`) as typed post-parse normalization on enum values.
- Enforce cross-flag invariants in one typed validation step after clap parsing.
- Reuse the same enums/validators across handlers and tests to keep CLI behavior DRY and single-source.

## Typed Boundary Contracts (Single-Source)

Use typed structs/enums as the canonical contract surface for internal Rust boundaries.

- Map external/raw payloads into typed domain models exactly once at the boundary.
- Do not use `BTreeMap<String, ...>` (or equivalent string-key maps) as authoritative internal contracts.
- Do not round-trip enums through strings in Rust logic/tests when typed values are available.
- Build typed contract values directly in tests; only parse string-key maps when explicitly testing boundary interop.
- For persisted, cross-module, or branch-driving key namespaces (for example metadata keys, storage key prefixes, discriminator tags), MUST model the namespace as a typed enum and centralize wire conversion on that type (prefer `strum` derives for stable string forms). When a closed domain identity or selector in that role also needs typed payloads plus variant-kind introspection, MUST use one tagged data-carrying enum as the source of truth and derive the discriminant enum from it (for example via `EnumDiscriminants`) rather than maintaining parallel payload and kind enums by hand. Prefer derive-based `serde`/`strum` support over custom serialization when the wire shape permits it.
- If string-key interop is unavoidable, centralize keys in shared enums/discriminants and helpers; avoid inline magic strings.
- When a wire contract remains `BTreeMap<String, ...>`, MUST provide namespace-scoped map extension traits that accept typed keys; Rust logic MUST NOT use inline key literals for those namespaces.
- Persisted or cross-module composite tokens (for example anchors/keys/ids with structured segments) MUST use a single typed codec/newtype in a shared module. If the semantic source of truth is already a typed struct or enum, that typed contract SHOULD own the canonical string encoding and decoding used for routes, query params, DOM/data keys, and other boundary strings rather than introducing a second wrapper or helper type as the primary string surface.
- Producers and consumers MUST use that codec/newtype for all encode/decode/normalize behavior; ad-hoc `format!()`/`split`/`starts_with` parsing is not allowed.
- Legacy wire-format compatibility, when needed, MUST be implemented only inside that codec/newtype.
- Required tests for such codecs: producer-consumer roundtrip plus delimiter-collision and case-normalization contracts.
- Inline key literals are allowed only in boundary interop tests or one-off local debug output.
- Repeated semantic strings MUST NOT remain inline once they define stable behavior at a Rust boundary.
  - Any semantic tag/code/route/key that crosses a module, crate, API, persistence, or test boundary MUST have a single exported contract definition.
  - Prefer enums for closed vocabularies and public constants for raw wire values.
  - Consumers and tests MUST import that authority instead of duplicating literals.
  - If direct import is impossible due to feature or target constraints, define exactly one local shim at the boundary.
  - Cross-module or externally addressable strings such as route paths, persisted filenames, shared protocol field names, and stable test-facing contracts MUST live in one shared constant or module.
  - Surface-local URL or query keys SHOULD live as module-local `const` values next to that surface's parse and format logic rather than being duplicated inline.
  - Parseable UI or API state values SHOULD use typed enums with centralized parse and serialize behavior instead of repeated string matches.
  - Required operator-facing labels or copy that drive control flow MUST live in named constants or total typed methods, not panic-prone runtime metadata lookups.
  - Keep stringly handling at the boundary; keep the rest of the Rust code typed.
  - Integration tests SHOULD reuse exported canonical constants for stable app contracts when that keeps the contract single-sourced without widening the public API excessively.
- Example pattern to follow: a reserved-key enum plus a map-extension trait (for example `ReservedMetaKey` + `ReservedMetaMapExt`) that funnels all metadata reads/writes through typed keys, defined once in the crate that owns the namespace.

### Durable Guardrail (Application Discipline)
- When touching existing code, if a semantic key namespace is represented by inline string literals in internal Rust logic, you MUST opportunistically replace that touched namespace with typed keys/enums and centralized conversion.
- Do not defer this cleanup solely because tests pass; string-key drift is a correctness risk, not just style.
- Scope this to touched code paths to avoid unrelated broad refactors.
