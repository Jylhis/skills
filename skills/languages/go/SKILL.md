---
name: go
description: "Use for modern Go work keyed to the project's Go version: any over interface{}, errors.Is / errors.Join, slices / maps / cmp packages, sync.OnceFunc / OnceValue, context.AfterFunc / WithCancelCause, atomic.Bool / Pointer[T], range-over-int loops, cmp.Or, http.ServeMux method-and-path patterns with r.PathValue, t.Context() in tests, omitzero JSON tags, b.Loop() benchmarks, strings.SplitSeq / FieldsSeq iterators, wg.Go(fn), errors.AsType[T], new(value). Read the matching reference before reviewing Go code for outdated patterns."
---

# Go skill index

Pick the topic and read its reference before writing or reviewing Go.

| Topic | When to read | Reference |
|---|---|---|
| Modern syntax & stdlib | any vs interface{}, errors.Is/Join, slices/maps/cmp, sync.OnceFunc, context.AfterFunc/WithCancelCause, atomic generics, range-over-int, cmp.Or, http.ServeMux method+path patterns, t.Context(), omitzero, b.Loop(), iter packages, wg.Go, errors.AsType, new(value) | `references/modern-syntax.md` |

After reading the reference, follow its guidance for the task.
