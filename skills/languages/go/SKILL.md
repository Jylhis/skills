---
name: go
description: Use for modern Go work keyed to the project's Go version — `any` over `interface{}`, errors.Is / errors.Join, slices / maps / cmp packages (Contains, Index, SortFunc, Sorted, Collect, Clone, Copy, Keys, Values), sync.OnceFunc / OnceValue, context.AfterFunc / WithCancelCause, atomic.Bool / Int64 / Pointer[T], `for i := range n` loops, cmp.Or, http.ServeMux method-and-path patterns + r.PathValue, t.Context() in tests, omitzero JSON tags, b.Loop() benchmarks, strings.SplitSeq / FieldsSeq iterators, sync.WaitGroup wg.Go(fn), errors.AsType[T], `new(value)` pointer expressions. Read the matching reference before reviewing Go code for outdated patterns.
---

# Go skill index

Pick the topic and read its reference before writing or reviewing Go.

| Topic | When to read | Reference |
|---|---|---|
| Modern syntax & stdlib | any vs interface{}, errors.Is/Join, slices/maps/cmp, sync.OnceFunc, context.AfterFunc/WithCancelCause, atomic generics, range-over-int, cmp.Or, http.ServeMux method+path patterns, t.Context(), omitzero, b.Loop(), iter packages, wg.Go, errors.AsType, new(value) | `references/modern-syntax.md` |
| Code style | gofmt, init scope, complex conditions, value vs pointer args, file/declaration organization, early returns | `references/code-style.md` |
| Concurrency | goroutine leaks, ctx.Done() in select, channels/select, sync primitives, errgroup, singleflight, pipelines, worker pools | `references/concurrency.md` |
| Context | WithCancel/WithTimeout/WithDeadline, ctx.Done(), AfterFunc, WithoutCancel, context values, tracing, HTTP/DB context propagation | `references/context.md` |
| Error handling | sentinel vs custom errors, %w wrapping, errors.Is/As/Join, log-or-return rule, panic/recover, slog integration | `references/error-handling.md` |
| Naming | package/file naming, identifier scope, receivers, acronym casing, getters/options, types/constants/errors, test naming | `references/naming.md` |
| Performance | pprof-driven optimization, allocation/CPU/GC/I-O bottlenecks, http.Client transport, GOMEMLIMIT, caching, observability | `references/performance.md` |
| Structs & interfaces | struct layout, embedding, interface design, accept-interfaces-return-structs, method sets | `references/structs-interfaces.md` |
| Testing | table-driven tests, httptest, goleak, testing/synctest, timeouts, benchmarks, mocking, integration tests | `references/testing.md` |

After reading the reference, follow its guidance for the task.
