---
name: typescript-testing
description: >
  Vitest testing patterns for TypeScript: file layout, fixtures, mocks,
  snapshot strategy, coverage, watch mode, running a single test. Apply
  when writing tests or debugging failing ones.
---

# TypeScript testing with Vitest

## Project layout

- Co-locate `*.test.ts` next to source files, or keep them under
  `tests/` — pick one and be consistent.
- Name: `foo.test.ts` (not `foo.spec.ts`).
- Integration tests: `tests/integration/` with a separate
  `vitest.config.integration.ts`.

## Minimal config

```ts
// vitest.config.ts
import { defineConfig } from 'vitest/config';

export default defineConfig({
  test: {
    globals: false,
    environment: 'node',     // or 'happy-dom' / 'jsdom' for UI
    coverage: {
      provider: 'v8',
      reporter: ['text', 'html'],
      thresholds: { lines: 80, functions: 80 },
    },
  },
});
```

Use explicit imports (`import { describe, it, expect } from 'vitest'`).

## Test structure

```ts
import { describe, it, expect, beforeEach } from 'vitest';
import { makeCart } from './cart.js';

describe('cart', () => {
  let cart: ReturnType<typeof makeCart>;

  beforeEach(() => {
    cart = makeCart();
  });

  it('starts empty', () => {
    expect(cart.total()).toBe(0);
  });

  it('adds items', () => {
    cart.add({ id: '1', price: 100 });
    expect(cart.total()).toBe(100);
  });
});
```

- One `describe` per unit under test.
- `it` names read as "it does X" sentences.
- Arrange / Act / Assert — one logical action per test.

## Running

```bash
pnpm vitest                  # watch mode
pnpm vitest run              # CI / one-shot
pnpm vitest run src/foo.test.ts
pnpm vitest run -t "adds items"     # filter by name
pnpm vitest --coverage
pnpm vitest --ui
```

## Mocks

- **`vi.fn()`** — spy. `expect(fn).toHaveBeenCalledWith(...)`.
- **`vi.mock('./module.js')`** — replaces a whole module.
- **`vi.spyOn(obj, 'method')`** — patches a method, cleanup with
  `mockRestore()`.
- **`vi.useFakeTimers()`** — paired with `vi.advanceTimersByTime(ms)`.

Prefer dependency injection over module mocks.

## Assertions

Use the targeted matcher:

- `toBe` — referential equality (`===`)
- `toEqual` — structural equality
- `toStrictEqual` — stricter (catches extra keys, undefined)
- `toMatchObject` — partial match
- `toMatchInlineSnapshot()` — inline snapshot for complex values
- `toThrow(Error, 'message substring')` — error assertions

## Async

```ts
it('fetches', async () => {
  await expect(fetchUser('42')).resolves.toMatchObject({ id: '42' });
});

it('rejects on 404', async () => {
  await expect(fetchUser('missing')).rejects.toThrow(NotFoundError);
});
```

Always `await` the assertion. Unawaited async assertions silently pass.

## Snapshots

- **Inline snapshots** (`toMatchInlineSnapshot`) for small outputs.
- **File snapshots** only for large fixtures reviewable in PRs.
- Delete snapshots when they become noise.

## Anti-patterns

- Global `beforeEach` that resets module state across unrelated tests.
- `expect(result).toBeTruthy()` — specify the exact expected value.
- Tests that assert on implementation details instead of observable
  behavior.
- Shared mutable fixtures between tests.
- `vi.mock` for the module you're actually testing.

## Tool detection

```bash
for tool in node pnpm vitest; do
  command -v "$tool" >/dev/null && echo "ok: $tool" || echo "MISSING: $tool"
done
```

## References

- Vitest docs: https://vitest.dev
- Vitest API: https://vitest.dev/api/
- Vitest config: https://vitest.dev/config/
