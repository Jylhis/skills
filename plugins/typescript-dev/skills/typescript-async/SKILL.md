---
name: typescript-async
description: >
  Async patterns for TypeScript: Promises, async/await, AbortController,
  structured concurrency, parallel execution, timeouts, backpressure.
  Apply when writing async code or debugging race conditions.
---

# TypeScript async patterns

Prefer native primitives (Node 22+) over third-party async helpers.

## Promises

- **Never construct a new Promise when `async`/`await` will do.** The
  `new Promise` pattern is only for wrapping callback APIs.
- **Never nest** `.then(...)`. Use `async`/`await`.
- **Always `await` or return** every promise. ESLint
  `no-floating-promises` enforces this.

## Parallel vs sequential

```ts
// Sequential — each waits for the previous
for (const id of ids) {
  await processUser(id);
}

// Parallel — all start at once
await Promise.all(ids.map((id) => processUser(id)));

// Parallel with limit — use p-limit for backpressure
const limit = pLimit(10);
await Promise.all(ids.map((id) => limit(() => processUser(id))));
```

`Promise.all` fails fast on first rejection. `Promise.allSettled` runs
all to completion — use for independent tasks where you want partial
success.

## Cancellation with AbortController

```ts
const ac = new AbortController();
setTimeout(() => ac.abort(), 5000);

const res = await fetch(url, { signal: ac.signal });
```

- Pass `signal` through your API surface: `function work(input: T, opts: { signal?: AbortSignal })`.
- Check `signal.aborted` before expensive work.
- Use `AbortSignal.timeout(ms)` (Node 17.3+) as a one-liner for timeouts:
  ```ts
  const res = await fetch(url, { signal: AbortSignal.timeout(5000) });
  ```
- Combine signals with `AbortSignal.any([sig1, sig2])` (Node 20+).

## Structured concurrency

Group related async work so that if the scope fails, everything is
cancelled:

```ts
async function withTimeout<T>(
  task: (signal: AbortSignal) => Promise<T>,
  ms: number,
): Promise<T> {
  const ac = new AbortController();
  const timer = setTimeout(() => ac.abort(), ms);
  try {
    return await task(ac.signal);
  } finally {
    clearTimeout(timer);
  }
}
```

For complex coordination use `effection` or `@effection/core`.

## Timeouts

Use `AbortSignal.timeout` for fetch. For async tasks that don't accept
a signal:

```ts
function withDeadline<T>(p: Promise<T>, ms: number): Promise<T> {
  return Promise.race([
    p,
    new Promise<never>((_, rej) =>
      setTimeout(() => rej(new Error('deadline')), ms),
    ),
  ]);
}
```

This does not cancel the underlying work — it only rejects the wrapper.
Prefer AbortController-aware APIs.

## Retries with backoff

```ts
async function retry<T>(
  fn: () => Promise<T>,
  attempts = 3,
  baseMs = 100,
): Promise<T> {
  for (let i = 0; i < attempts; i++) {
    try {
      return await fn();
    } catch (err) {
      if (i === attempts - 1) throw err;
      await new Promise((r) => setTimeout(r, baseMs * 2 ** i));
    }
  }
  throw new Error('unreachable');
}
```

For anything more sophisticated use `p-retry`.

## Async iteration

- **`for await (const x of stream)`** — use for async iterables
  (Node streams, async generators, `AsyncIterable`).
- **Async generators (`async function*`)** — produce backpressured
  streams with simple code.
- **`Readable.toWeb()` / `Readable.fromWeb()`** — bridge to web streams.

```ts
async function* chunks(stream: Readable): AsyncGenerator<Buffer> {
  for await (const chunk of stream) yield chunk;
}
```

## Anti-patterns

- `await` inside `Array.prototype.forEach` — `forEach` doesn't await.
- `await` inside a `map` without `Promise.all` — runs sequentially.
- `Promise.race` with a setTimeout for cancellation (does not cancel
  the underlying task).
- Wrapping `fetch` in a custom Promise constructor.
- Building retry/queue/throttle infra from scratch every project.

## Tool detection

```bash
for tool in node pnpm; do
  command -v "$tool" >/dev/null && echo "ok: $tool" || echo "MISSING: $tool"
done
```

## References

- AbortController: https://developer.mozilla.org/en-US/docs/Web/API/AbortController
- `AbortSignal.timeout`: https://developer.mozilla.org/en-US/docs/Web/API/AbortSignal/timeout_static
- Structured concurrency proposal: https://github.com/tc39/proposal-async-context
- `p-limit`, `p-retry`: https://github.com/sindresorhus/p-limit
