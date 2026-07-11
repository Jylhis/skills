---
name: typescript
description: "Use for TypeScript 5.9+ on Node 22 LTS: code style (naming, ESM-first, import order), type system depth (generics, conditional types, infer, narrowing, satisfies, branded types), async (AbortController, async iterators), error handling (Error subclassing, Result types, AggregateError), Node patterns (fs/promises, child_process, streams, workers, pino), Zod validation at trust boundaries, Prettier, ESLint 9 flat config, packaging (pnpm workspaces, exports), and Vitest testing. Read the matching reference before acting."
---

# TypeScript skill index

Pick the topic and read its reference before writing or reviewing
TypeScript / Node.js code.

| Topic | When to read | Reference |
|---|---|---|
| Code style | naming, ESM-first ("type": "module"), import order, barrel-export avoidance, const/readonly | `references/code-style.md` |
| Type system | generics with extends, conditional types, infer, satisfies, branded/opaque types, NoInfer, mapped types | `references/type-system.md` |
| Async | Promise, async/await, AbortController, Promise.all/allSettled, async iterators, p-limit, AbortSignal.timeout | `references/async.md` |
| Error handling | Error subclassing with prototype chain, cause, Result/neverthrow, AggregateError, narrowing unknown in catch | `references/error-handling.md` |
| Zod validation | runtime validation at trust boundaries (HTTP, env, config), `safeParse`, `z.infer`, refinements, discriminated unions, coercion | `references/zod.md` |
| Node patterns | node:fs/promises, child_process spawn/execFile, streams pipeline, worker_threads, pino logging, graceful shutdown | `references/nodejs-patterns.md` |
| Formatting (Prettier) | .prettierrc, --check in CI, eslint-config-prettier, husky + lint-staged, Prettier 3 defaults | `references/formatting.md` |
| Linting (ESLint 9) | flat config (eslint.config.js), tseslint.config helper, typed linting (project: true), ignores, glob overrides | `references/linting.md` |
| Packaging | pnpm + workspaces, "type": "module", exports field, .ts extensions in imports, ESM-first publishing | `references/packaging.md` |
| Testing (Vitest) | describe/it/expect, vi.mock / vi.spyOn, test.extend fixtures, snapshots, watch mode, coverage, Jest migration | `references/testing.md` |

For TypeScript / Node **security** topics (command injection, prototype
pollution, XSS, SSRF, secrets, npm audit), use the `security` skill.

After reading the reference, follow its guidance for the task.
