---
name: python-async
description: >
  asyncio patterns for Python 3.12+: async/await, TaskGroup, structured
  concurrency, cancellation, timeouts, async iteration, asyncio.run.
  Apply when writing async code or debugging race conditions.
---

# Python asyncio (3.12+)

`asyncio` is the standard async runtime. Do not use gevent, eventlet,
or trio in new projects (anyio provides a portable layer if needed).

## Running an async program

```python
import asyncio

async def main() -> None:
    await do_work()

if __name__ == "__main__":
    asyncio.run(main())
```

- `asyncio.run(main())` creates the event loop, runs `main`, and
  cleans up. Use it once at the top of the program.
- Do **not** use `loop = asyncio.get_event_loop()` — deprecated.

## TaskGroup (structured concurrency, 3.11+)

```python
async def load_dashboard(user_id: str) -> Dashboard:
    async with asyncio.TaskGroup() as tg:
        user_task = tg.create_task(fetch_user(user_id))
        orders_task = tg.create_task(fetch_orders(user_id))
        prefs_task = tg.create_task(fetch_prefs(user_id))

    # All tasks guaranteed to have finished here
    return Dashboard(
        user=user_task.result(),
        orders=orders_task.result(),
        prefs=prefs_task.result(),
    )
```

- **Prefer TaskGroup over `asyncio.gather`** in new code.
- If any child task raises, TaskGroup cancels the others and raises an
  `ExceptionGroup` (use `except*` to filter).
- The TaskGroup scope dictates the lifetime of every child. No leaked tasks.

## `asyncio.gather` (legacy but still used)

```python
users, orders = await asyncio.gather(
    fetch_users(),
    fetch_orders(),
    return_exceptions=True,  # or omit to fail-fast
)
```

Use `gather` only when you cannot use TaskGroup (e.g. you need
`return_exceptions=True` or must support 3.10).

## Cancellation

```python
task = asyncio.create_task(long_running())
await asyncio.sleep(1)
task.cancel()
try:
    await task
except asyncio.CancelledError:
    pass  # expected
```

- **Never swallow `CancelledError`** except at the very top of a Task.
  If you catch it, re-raise.
- **Shielding:** `await asyncio.shield(critical_cleanup())` protects
  a coroutine from cancellation propagation.

## Timeouts (3.11+)

```python
async with asyncio.timeout(5.0):
    result = await fetch_slowly()
```

- Prefer `asyncio.timeout` over `asyncio.wait_for`.
- Absolute deadlines: `asyncio.timeout_at(loop.time() + 5.0)`.

## Async iteration

```python
async def process_users(source: AsyncIterable[User]) -> None:
    async for user in source:
        await process(user)
```

- `async for` iterates `AsyncIterator` / `AsyncIterable`.
- `async def` with `yield` creates an async generator:
  ```python
  async def stream_lines(path: Path) -> AsyncGenerator[str, None]:
      async with aiofiles.open(path) as f:
          async for line in f:
              yield line.rstrip()
  ```

## Concurrency limits

```python
sem = asyncio.Semaphore(10)

async def bounded_fetch(url: str) -> bytes:
    async with sem:
        return await fetch(url)
```

Use a `Semaphore` to bound concurrency. For worker-pool patterns, use
`asyncio.Queue` with a fixed number of consumers.

## Avoid blocking the event loop

- **CPU-bound work** blocks the loop. Use `asyncio.to_thread(fn, *args)`
  for short CPU tasks, or `ProcessPoolExecutor` for heavier work.
- **`time.sleep()`** — use `asyncio.sleep()`.
- **Blocking I/O libraries** (requests, psycopg2) block the loop. Use
  `httpx`, `asyncpg`, `aiofiles` instead.

## Debugging

```python
asyncio.run(main(), debug=True)
```

Enables warnings on unawaited coroutines, slow callbacks (>100 ms),
and full stack traces. Or set `PYTHONASYNCIODEBUG=1`.

## Anti-patterns

- Mixing sync and async via `loop.run_until_complete` inside an async
  function.
- Nested `asyncio.run` (e.g. inside an async test) — use
  `pytest-asyncio` or the test framework's runner.
- `create_task` without storing the reference — the task can be
  garbage collected mid-run. Use TaskGroup or keep the reference.
- `except Exception` swallowing `CancelledError` (3.8+:
  `CancelledError` inherits from `BaseException`).
- `asyncio.run` inside a long-running request handler — creates a new
  loop per call.
- Assuming `asyncio.gather(...)` is concurrent when all tasks hit the
  GIL on CPU work.

## Tool detection

```bash
for tool in python3 uv pyright; do
  command -v "$tool" >/dev/null && echo "ok: $tool" || echo "MISSING: $tool"
done
```

## References

- asyncio docs: https://docs.python.org/3/library/asyncio.html
- TaskGroup: https://docs.python.org/3/library/asyncio-task.html#asyncio.TaskGroup
- `asyncio.timeout`: https://docs.python.org/3/library/asyncio-task.html#asyncio.timeout
- anyio (portability layer): https://anyio.readthedocs.io
