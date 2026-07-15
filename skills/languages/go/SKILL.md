---
name: go
description: Use for modern Go work keyed to the project's Go version — `any` over `interface{}`, errors.Is / errors.Join, slices / maps / cmp packages (Contains, Index, SortFunc, Sorted, Collect, Clone, Copy, Keys, Values), sync.OnceFunc / OnceValue, context.AfterFunc / WithCancelCause, atomic.Bool / Int64 / Pointer[T], `for i := range n` loops, cmp.Or, http.ServeMux method-and-path patterns + r.PathValue, t.Context() in tests, omitzero JSON tags, b.Loop() benchmarks, strings.SplitSeq / FieldsSeq iterators, sync.WaitGroup wg.Go(fn), errors.AsType[T], `new(value)` pointer expressions. Read the matching reference before reviewing Go code for outdated patterns.
---

# Go skill index

Pick the topic and read its reference before writing or reviewing Go.

| Topic | When to read | Reference |
|---|---|---|
| Modern syntax & stdlib | any vs interface{}, errors.Is/Join, slices/maps/cmp, sync.OnceFunc, context.AfterFunc/WithCancelCause, atomic generics, range-over-int, cmp.Or, http.ServeMux method+path patterns, t.Context(), omitzero, b.Loop(), iter packages, wg.Go, errors.AsType, new(value) | `references/modern-syntax.md` |
| Code style | idiomatic formatting, package layout, comment and doc conventions | `references/code-style.md` |
| Naming | identifier, package, receiver, and interface naming conventions | `references/naming.md` |
| Error handling | wrap vs handle vs propagate, errors.Is/As, sentinel errors, avoiding silent or duplicate logging | `references/error-handling.md` |
| Concurrency | goroutine lifecycle, leak-freedom, channels, sync primitives, cancellation | `references/concurrency.md` |
| context.Context | passing, deadlines, cancellation, values, and context propagation | `references/context.md` |
| Structs & interfaces | small composable interfaces, concrete return types, type design for testability | `references/structs-interfaces.md` |
| Performance | profile-first optimization, allocation discipline, benchmarking | `references/performance.md` |
| Testing | table tests, subtests, fixtures, tests as executable specs | `references/testing.md` |
| gopls (semantic tooling) | navigating or refactoring Go via gopls: go-to-def, find references, rename, extract/inline, diagnostics, MCP vs native LSP vs CLI | `references/gopls.md` |
| pkg.go.dev lookups (godig) | published-ecosystem lookups: package docs, API signatures, versions, importers, licenses, CVEs via godig | `references/pkg-go-dev.md` |

After reading the reference, follow its guidance for the task.
