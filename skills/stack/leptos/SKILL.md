---
name: leptos
description: "Leptos UI contract: fine-grained reactivity, SSR/hydrate safety, performance guardrails, and agent workflow (file fences, cancellable effects, lint targets)."
---

# Leptos 0.8 UI Skill (Contract)

## Scope
- Applies to all UI code using Leptos 0.8.
- This document is the authoritative contract for Leptos work in the current codebase.

Primary references (for human lookup):
- Leptos Book
- The project's own Leptos common-bugs notes, if any.


## Non-negotiable invariants (MUST)

- LPT-0001 (Imports): Always use `use leptos::prelude::*;` (never `use leptos::*;`).
- LPT-0002 (Cancelable scheduling): Any `requestAnimationFrame`, timeout/interval, or global listener work MUST be cancelable and tied to component cleanup to avoid disposed-signal panics/leaks. For RAF specifically, use `CleanupRaf` or an equivalent helper.

## Core principles
- LPT-0101 (Fine-grained reactivity): Updates must affect only the smallest dependent UI region; avoid broad invalidations.
- LPT-0102 (Derivation over mutation): What can be derived should be derived.
- LPT-0103 (Side-effects are explicit): Effects are for side-effects, not ordinary state propagation.
- LPT-0104 (Reduce degrees of freedom): Prefer conventions, helper APIs, and file/module boundaries that make the correct reactive pattern the easiest one (especially for agents).

## Standard workflow for any Leptos change

### Step 0: Preflight checklist (MUST)
- Confirm Leptos version assumptions (0.8) and import rule (LPT-0001).
- Identify shared/global UI signals used by lists/rows (selection, open menu, filters).
- Identify any global handlers (outside-click, hotkeys, scroll, RAF) and ensure:
  - untracked reads (LPT-0310)
  - no-op set guards (LPT-0301)
  - cleanup exists (LPT-0002)
- Identify any scrollable selectable collections and verify whether scroll reveal is truly required:
  - pointer selection must not imply scroll (LPT-0362)
  - external/programmatic reveal must be explicit-intent driven (LPT-0363)
  - ordinary selection/detail-state changes must not remount or key-reset the collection root or scroll container (LPT-0364)
- Identify any user-triggered mutation that will cause follow-up loads and ensure:
  - immediate local visible state can be patched before slower derived data returns,
  - duplicate shell/detail/route refresh fanout is avoided,
  - and repeated related focused reads can reuse revision/focus hints or be batched.

### Step 1: Choose the smallest reactive representation
- Prefer signals for local state (LPT-0201).
- Prefer memos/selectors for derived state (LPT-0202, LPT-0320/0321).
- Use effects only for imperative side-effects (LPT-0203).

### Step 2: Implement with performance guardrails
- Never do no-op sets (LPT-0301).
- Handlers must not subscribe accidentally (LPT-0310).
- Memoize row-level dependencies (LPT-0320..0323).
- Avoid cloning large collections in hot paths (LPT-0330).

### Step 3: SSR/Hydrate correctness
- Avoid hydrate-unsafe branching (LPT-0350).
- Keep DOM shape stable across SSR and initial hydrate; prefer `class:hidden` toggles.

### Step 4: Validate
- Run clippy for SSR and hydrate targets per the project’s build configuration.
- If changing server_fn payloads with nested data, add a wasm roundtrip test (LPT-0904).

## Reactivity management

### Signals, memos, effects
- LPT-0201 (Signals): Use `signal(...)` / `create_signal` / `create_rw_signal` for local state.
- LPT-0202 (Derived state): Use `Memo`, `Signal::derive`, or computed closures for derived values.
- LPT-0203 (Effects): Use `Effect` only for:
  - imperative DOM operations (scroll, focus),
  - bridging non-reactive APIs,
  - kicking off async work in response to dependencies (when `Resource` is not right),
  - logging/telemetry.
- LPT-0204 (No "effect writes" for derived flags): Do not write to a signal from an effect just to mirror another signal.

### Batch updates
- LPT-0210 (Batching): Wrap multi-signal updates in `batch(|| { ... })` to avoid nested borrows/panics and intermediate rerenders.

### Read vs write separation
- LPT-0220: Prefer passing `ReadSignal<T>` and `WriteSignal<T>` (or callbacks) rather than sharing mutable state broadly.
- LPT-0225: UI actions MUST capture a stable, typed target from the render context that produced them. Do not resolve mutation targets by re-reading ambient selection, global state, or current route state in a parent callback.
  - If follow-up UI state is deferred and later consumed (for example focus, open/edit state, confirmation state, or post-action retargeting), it MUST carry enough identity to remain unambiguous at consumption time.
  - Interactive controls MUST be disabled when their executable target cannot be resolved.

## Preventing broad redraws (critical performance contract)

### No-op sets are forbidden
- LPT-0301: Never call `set(x)` or `update` if the logical value would not change.
  - Use `get_untracked()` or `with_untracked` to guard equality before setting.

### Handlers must not subscribe accidentally
- LPT-0310: In `on:*` handlers, document/window listeners, RAF callbacks, timeouts:
  - use `get_untracked()` / `with_untracked(...)` unless you explicitly want reactivity.

### Per-row dependencies must be memoized
- LPT-0320: Per-row comparisons against a shared signal must be memoized.
- LPT-0321: Use `Selector` for "exactly one active item" patterns so only old/new items update.
- LPT-0322: Any derived value gating a view branch must be a `Memo` or `Selector`.
- LPT-0323: Hover/active row patterns should use `Selector<Option<Id>>` + per-row memo.

### Avoid cloning large collections in hot paths
- LPT-0330: Avoid `.get()` cloning maps/sets inside each row render; use `.with(|m| ...)`.

### Outside-click closers
- LPT-0340: Outside-click closers must:
  - avoid reactive subscriptions (untracked reads),
  - avoid spamming `set(None)` when already `None`,
  - clean up listeners.

### Hydration-safe branching
- LPT-0350: Do not add/remove DOM nodes based on signals that can differ between SSR and initial hydrate.
  - Prefer stable DOM + `class:hidden`.

### Flex height chain
- LPT-0360: Scroll/zoom panels must sit inside a continuous flex height chain (`flex` + `min-h-0` ancestors; panel `flex-1 min-h-0`).
- LPT-0361: In split panes and workbench sidebars, do not cap interactive lists with viewport-relative `max-h-*` hacks. The pane itself must join the flex height chain, and the actual list region must be the bounded `flex-1 min-h-0 overflow-*` scroll container so the last item remains fully visible and clickable.
- LPT-0362: For scrollable selectable collections, follow general Web UI quality guidance; in Leptos, do not couple pointer selection directly to scroll mutation.
  - Do not couple `current_*` / `selected_*` state changes directly to `scrollIntoView`, centering, or `scroll_top` mutation.
  - A click or row-button navigation inside a page-thumbnail strip, records list, queue rail, account rail, or similar collection must preserve the current local scroll position.
- LPT-0363: Reveal-scroll MUST be modeled as explicit Leptos state, not inferred from generic active-selection state.
  - Only external or programmatic navigation such as route restore, keyboard roving, jump-to-item, or cross-surface drillthrough may request reveal-scroll.
  - Model this as a narrow reveal token, target, or callback at the collection boundary; do not scatter ad-hoc suppression flags through row components.
- LPT-0364: Ordinary selection or adjacent detail-route changes MUST NOT remount, replace, or key-reset a scrollable local-navigation collection or its scroll container.
  - Preserve one stable component/DOM identity for the collection across adjacent queue/detail states when the collection semantics are unchanged.
  - If local scroll is lost on click or row-button navigation, fix the structural remount or reactive identity boundary first; do not add compensating scroll-preservation logic unless explicit reveal intent is part of the contract.

### Composed control surfaces and overlays
- LPT-0370: For composed control surfaces and overlay quality, follow general Web UI quality guidance; in Leptos, keep layout ownership and overlay state at the component boundary that owns the whole control cluster.
- LPT-0371: Use reactive breakpoint/layout state only to choose intentional variants such as rows, disclosures, drawers, or dialogs; do not patch clipping, overlap, or z-order problems with one-off CSS hacks.
- LPT-0372: Floating surfaces must render in a Leptos layer that is not clipped by scroll containers or surrounding panels. If that cannot be guaranteed, use an inline disclosure, drawer, or dialog surface instead.
- LPT-0373: Open overlay state should be modeled at the owning control-cluster boundary. Avoid scattering independent open-state flags across trigger rows when one cluster invariant controls layering and placement.
- LPT-0374: Overlay positioning, outside-click handling, resize handling, and focus behavior must use cleanup-safe listeners and untracked reads.
- LPT-0375: Browser proof for composed-control or overlay changes SHOULD exercise opened state at constrained width, desktop width, long labels, selected values, empty state, and keyboard focus.

## View macro & DOM bindings
- LPT-0401: Keep UI declarative; reactive expressions inside `{}`.
- LPT-0402: Controlled inputs must use property bindings (`prop:value`, `prop:checked`). Do not use `value=`/`checked=` for reactive state.
- LPT-0403: Use NodeRef sparingly; delayed DOM work must re-check node existence and avoid reactive subscriptions.

## Lists and iteration
- LPT-0501: Use `<For/>` for dynamic lists; always provide a stable `key`.
- LPT-0502: Keys must be stable IDs (not indices unless index is the identity).
- LPT-0503: Avoid `.map()` for reactive lists (use `<For/>`).
- LPT-0504: Avoid unmounting interactive lists via `<Suspense>`; keep lists mounted and show inline loading.

## Components & props
- LPT-0601: Use `#[component]`.
- LPT-0602: Prefer small, granular props; avoid mega prop structs that reduce reactivity precision.
- LPT-0603: Treat props as inputs; manage state locally via signals, share via context when needed.

## Resources & async work
- LPT-0701: Key `Resource::new` on the smallest stable dependency set.
- LPT-0702: Cache consciously (store last good value if you need to keep UI visible during refetch).
- LPT-0703: Avoid cascading fetches from resource-driven effects unless required.
- LPT-0704: For user-triggered mutations on interaction-critical paths, show immediate visible pending state first. Do not present command-side state as committed before command success. After a successful command, patch the smallest immediate user-visible state from authoritative response data and backfill slower derived data reactively. Do not make the UI appear idle until the full round-trip settles if the target state is already known locally.
- LPT-0705: One mutation SHOULD trigger one coordinated refresh per affected surface. Avoid duplicate refresh fanout where page shell, detail component, and route-resolution logic each independently refetch the same semantic target.
- LPT-0706: When multiple related focused reads are needed after one interaction, batch them or resolve them against one shared snapshot or revision context rather than issuing serial equivalent "changed" reads.
- LPT-0707: Browser proof for latency-sensitive mutation flows SHOULD prove immediate visible pending and no duplicate loading churn; final settled state alone is insufficient.
- LPT-0708: Data-backed result surfaces follow general Web UI quality guidance; in Leptos, represent the result state as one explicit enum or equivalent closed-set signal rather than independent loading/data/empty booleans.
- LPT-0709: Pending result surfaces should render through a shared component or helper so the busy, empty, ready, and error branches stay mutually exclusive and visually consistent.

## SSR/Hydrate modes & workspace config
- LPT-0801: Enable one mode per target: `csr`, `hydrate`, or `ssr`.
- LPT-0802: Workspaces must use resolver v2:
  - `[workspace] resolver = "2"`

## Server functions (full-stack)
- LPT-0901: Use `#[server]`, return `Result<_, _>`, keep inputs/outputs serializable and minimal.
- LPT-0902: Keep server fns small; push heavy work into backend services/modules.
- LPT-0903: For nested payloads, use body encoding (`#[server(input = Json)]` or `Cbor`) instead of URL encoding.
- LPT-0904: When changing nested payloads, add a wasm integration test covering a non-trivial roundtrip.

## Tooling and lint workflow (SSR + Hydrate)
Preferred commands (adjust crate/features per build configuration):
- SSR/native:
  - `cargo clippy -p <crate> --no-default-features --features "ssr ..."`
- Hydrate/WASM:
  - `cargo clippy -p <crate> --target wasm32-unknown-unknown --no-default-features --features "hydrate"`

Notes:
- Use `--no-default-features` for WASM unless defaults are known wasm-safe.
- `cargo leptos build` is an integration build, not a replacement for clippy per target.

## Code organization for reliability (MUST)
- LPT-1201: Modules > ~450 lines should be split.
- LPT-1202: One "smart" component per file (signals/memos/resources/effects) + multiple "dumb" components (pure props -> view).
  - Smart component (container):
    - Owns signals/resources/effects, calls server_fns, and performs side-effects.
    - Derives memos/selectors and passes data + callbacks down.
    - Encapsulates business/UI state transitions.
  - Dumb component (presentational):
    - Renders from props only; no server_fns or effects.
    - No global/shared signals; accepts `ReadSignal`/callbacks as props if needed.
    - May hold minimal local UI-only state (e.g., input text), but no data fetching or cross-component coordination.

  Recommended component internal order (SHOULD):
  1) props/inputs
  2) signals & memos (derived)
  3) resources
  4) effects
  5) view!
- LPT-1203: Prefer minimal diffs; reconsider boundaries if a change touches many UI files.

## Domain-Driven-Design Principles (MUST)
- LPT-1250 (DDD Mapping for Leptos)
  - Treat each UI domain (feature/workflow) as an ownership boundary: it owns state, invariants, and side-effects.
  - In Leptos, a domain boundary is modeled as `*Ctx` (signals/memos/selectors/resources/effects/node refs) + adjacent `*Actions` (methods/`Callback`s; the only write path; may call server_fns).
  - Composition roots are thin providers: construct/provide contexts and mount the view subtree; containers read context and pass minimal `ReadSignal`/callbacks to presentational children.
  - Boundary rule of thumb: state lives where its invariants and resource/effect keys (including reload tokens) live; actions live next to the state they mutate.
- LPT-1251 (Feature contexts): Any large composition root that exists primarily to wire shared state between many components MUST be decomposed into multiple domain-scoped context modules (`*Ctx`) + typed actions (`*Actions`). The composition root provides contexts and mounts the view subtree; shared state MUST NOT be threaded as mega-props. Specifically:
  - LPT-1251-1 Applicability: use this for page roots, feature roots, routed shells, and any "wiring harness" component coordinating siblings/deep descendants.
  - LPT-1251-2 Scope: provide each context at the smallest subtree that needs it (feature-level by default); do not promote to app-global unless multiple routes/features require it.
  - LPT-1251-3 Ownership: each `*Ctx` owns its domain's reactive state (signals/memos/selectors/resources/effects/node refs) and enforces its invariants; do not keep cross-cutting glue state in the composition root.
  - LPT-1251-4 Boundaries: choose contexts by invariants + key space. If a state variable participates in a `Resource`/effect key, reload token, or domain invariant, it belongs to that domain context.
  - LPT-1251-5 Public surface: prefer exposing read handles (selectors/`Signal`/`ReadSignal`) from contexts; mutations MUST go through `*Actions` (avoid exporting writable `RwSignal` broadly).
  - LPT-1251-6 Actions: define `*Actions` adjacent to the owning `*Ctx`; actions are the only write path and may call server_fns/perform side-effects for that domain. Avoid ad-hoc closures in the composition root.
  - LPT-1251-7 Actions scoping: do not introduce an `ActionsCtx` that merely groups callbacks. Create a separate context only if the workflow has its own independent lifecycle/state machine and is reused across multiple domains/routes; otherwise keep the state in the owning domain `*Ctx` with `DomainActions`.
  - LPT-1251-8 Dependencies: contexts MUST NOT store other context structs directly or create cycles. Depend only on narrow inputs (read signals, ids, tokens) + typed actions; break cycles via an explicit `Inputs` struct or by moving derived state/resources to the true owner.
  - LPT-1251-9 Resources/effects: a `Resource`/effect MUST be constructed in the context that owns its key signals (including explicit reload tokens). Refresh MUST be via those keys/tokens, not incidental UI writes from unrelated state.
  - LPT-1251-10 Migration rule: any component receiving a large prop bundle of shared state/actions (or spanning multiple domains) MUST be migrated to context access. Prefer: container reads context -> passes minimal `ReadSignal`/callbacks to presentational children; context reads in leaf components are allowed only to avoid deep prop threading and must remain side-effect-free.
  - LPT-1251-11 Presentational components MUST NOT own shared state/resources/effects or perform side-effects/server_fns; they may accept `ReadSignal`/callbacks and may read context only when used as the "leaf consumer" of shared state.
  - LPT-1251-12 Preserve reactivity guardrails (LPT-0301/0310/032x) during refactors; no behavior changes.
  - LPT-1251-13 Shared inputs + extraction style: If a value is consumed across domains, it MUST live in the domain that owns its invariant (e.g., URL/query-derived selection -> `RoutingCtx`), and other domains depend on it via narrow inputs/actions. In composition roots, extract only the needed handles (Copy/Clone fields) or pass an explicit `Inputs`/`Port` struct; avoid cloning entire `*Ctx`/`*Actions` just to pull out one member.

## Agent operation mode (how to prompt and validate AI changes)
- LPT-1301 (File fence, MUST): Prompts must specify which files may be edited (ideally one file).
- LPT-1302 (Rule citation, SHOULD): Prompts should cite relevant LPT rule IDs.
- LPT-1303 (Minimal diff, MUST): Prefer minimal diffs preserving semantics unless explicitly requested.
- Add a rerender smoke alarm (SHOULD) when debugging redraw issues (debug counter/log per row).

## Known-good snippets

No-op guarded set (LPT-0301):
```rust
let set_open = move |next: Option<u32>| {
    if open.get_untracked() != next {
        set_open.set(next);
    }
};
```

Row memo (LPT-0320):

```rust
let is_open = Memo::new(move |_| open.get() == Some(row_id));
view! { <Show when=move || is_open.get()> ... </Show> }
```

Untracked reads in global handlers (LPT-0310, LPT-0340):

```rust
let current = open.get_untracked();
if current.is_none() { return; }
// compute outside click...
set_open.set(None);
```

## Enforcement (MUST)

Changes that violate MUST rules (LPT-0001/0002/0301/0310/0320/0402/0501/0802/120X/125X/1301) must be revised before merging.
