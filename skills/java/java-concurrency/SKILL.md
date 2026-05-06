---
name: java-concurrency
description: "Use for Java 21 concurrency including virtual threads (JEP 444) via Thread.ofVirtual().start and Executors.newVirtualThreadPerTaskExecutor, structured concurrency with StructuredTaskScope.ShutdownOnFailure and ShutdownOnSuccess, CompletableFuture chains (.thenApply / .thenCompose / .thenCombine / .allOf / .anyOf), platform thread pools (newFixedThreadPool, newScheduledThreadPool) for CPU-bound work, ReentrantLock and ReadWriteLock over synchronized on virtual-thread hot paths, ConcurrentHashMap and concurrent collections, AtomicReference / AtomicLong / LongAdder atomics, AutoCloseable executors via try-with-resources, or thread-safety review of shared mutable state."
---

# Java concurrency (Java 21)

## Virtual threads

Lightweight JVM-managed threads (JEP 444) — millions fit in a process,
and blocking calls park the virtual thread without blocking the OS
thread.

```java
// Run a task on a virtual thread
Thread.ofVirtual().start(() -> doWork());

// An executor that creates one virtual thread per task
try (var executor = Executors.newVirtualThreadPerTaskExecutor()) {
    for (int i = 0; i < 10_000; i++) {
        final int id = i;
        executor.submit(() -> handle(id));
    }
}  // executor close blocks until all tasks finish
```

**Rules of thumb:**

- Use virtual threads for **I/O-bound** tasks: HTTP handlers, DB
  queries, file reads, inter-service calls.
- Use **platform threads** (the classic `ForkJoinPool`,
  `Executors.newFixedThreadPool`) for **CPU-bound** work.
- `synchronized` blocks still pin virtual threads to carriers — use
  `ReentrantLock` instead in hot paths.
- Don't pool virtual threads — they are cheap to create.

## Structured concurrency (preview in 21, stabilizing)

```java
try (var scope = new StructuredTaskScope.ShutdownOnFailure()) {
    Future<User> user = scope.fork(() -> fetchUser(id));
    Future<List<Order>> orders = scope.fork(() -> fetchOrders(id));
    scope.join().throwIfFailed();

    return new Dashboard(user.resultNow(), orders.resultNow());
}
```

- All forked tasks are children of the scope.
- `ShutdownOnFailure` cancels siblings when any task fails.
- `ShutdownOnSuccess` returns the first successful result and cancels
  the rest.
- Scope close blocks until all children complete — no leaked tasks.

## CompletableFuture (pre-21 idiom, still used)

```java
CompletableFuture<String> future = CompletableFuture
    .supplyAsync(() -> fetchRemote(), executor)
    .thenApply(String::toUpperCase)
    .exceptionally(ex -> {
        log.error("remote fetch failed", ex);
        return "fallback";
    });

String result = future.get();
```

- **Chain** with `.thenApply`, `.thenCompose`, `.thenCombine`.
- **Compose** multiple futures with `CompletableFuture.allOf` or
  `anyOf`.
- Always pass an **explicit executor** — the common pool is shared
  with the JVM.
- **`.get()`** blocks. Virtual threads make this less painful.

## Executors

```java
// Fixed thread pool — for CPU-bound work
ExecutorService cpuPool = Executors.newFixedThreadPool(
    Runtime.getRuntime().availableProcessors()
);

// Scheduled executor — for delayed or periodic tasks
ScheduledExecutorService scheduler = Executors.newScheduledThreadPool(2);
scheduler.scheduleAtFixedRate(this::cleanup, 0, 1, TimeUnit.MINUTES);

// Virtual-thread-per-task — for I/O-bound work
ExecutorService ioPool = Executors.newVirtualThreadPerTaskExecutor();
```

- **Always shut down executors** via `try (var pool = ...)`. They
  implement `AutoCloseable` as of Java 19.
- **Don't use `Executors.newCachedThreadPool()`** in production —
  unbounded growth. Use virtual threads or a bounded `ThreadPoolExecutor`.

## Locks and synchronization

Order of preference:

1. **No shared state** — pass data via channels / futures / immutable
   messages.
2. **Immutable data** — records, `List.of`, `Map.of`.
3. **Concurrent collections** — `ConcurrentHashMap`, `CopyOnWriteArrayList`,
   `ConcurrentLinkedQueue`.
4. **`AtomicReference` / `AtomicInteger` / `AtomicLong`** — for single
   fields.
5. **`ReentrantLock` / `ReadWriteLock`** — for coarser critical
   sections; interoperates with virtual threads.
6. **`synchronized`** — only when the above don't fit and you're
   not on the virtual-thread hot path.

```java
// Prefer this...
private final Map<String, User> users = new ConcurrentHashMap<>();
users.computeIfAbsent(id, this::loadUser);

// ...over this
private final Map<String, User> users = new HashMap<>();
synchronized (users) {
    users.computeIfAbsent(id, this::loadUser);
}
```

## Atomic operations

```java
AtomicLong counter = new AtomicLong();
long next = counter.incrementAndGet();

AtomicReference<Config> config = new AtomicReference<>(loadDefault());
config.updateAndGet(old -> merge(old, overrides));
```

- **`AtomicLong`** for counters.
- **`LongAdder`** for high-contention counters (optimized for writes).
- **`AtomicReference`** for atomic updates to object references.
- **`VarHandle`** for lower-level atomic access when needed.

## Thread safety checklist

1. Is this field accessed from multiple threads?
2. If yes, is it `final` + immutable, atomic, or protected by a lock?
3. Is the lock's scope the minimum necessary?
4. Are you acquiring locks in a consistent order to avoid deadlock?
5. Are there any blocking operations inside critical sections?
6. Does the code do work inside `synchronized` that should be
   outside?

## Anti-patterns

- `Thread.stop()` — deprecated forever, undefined behaviour.
- `Thread.sleep()` for synchronization — use `CountDownLatch`,
  `Phaser`, or `await` primitives.
- **`new Thread()` scattered throughout the code** — use an
  executor.
- **`synchronized` on a mutable public field** — clients can bypass
  the lock.
- **Double-checked locking with plain fields** — use `volatile` or
  `AtomicReference`.
- **Catching `InterruptedException` and swallowing it** — always
  re-set `Thread.currentThread().interrupt()` if you can't propagate.
- **Unbounded queues** on executors — can cause OOM under load.
- **Pooling virtual threads** — they are cheap, pooling defeats the
  purpose.

## Tool detection

```bash
for tool in java javac gradle; do
  command -v "$tool" >/dev/null && echo "ok: $tool" || echo "MISSING: $tool"
done
```

## References

- JEP 444 (Virtual threads): <https://openjdk.org/jeps/444>
- JEP 480 (Structured Concurrency, preview): <https://openjdk.org/jeps/480>
- `java.util.concurrent`: <https://docs.oracle.com/en/java/javase/21/docs/api/java.base/java/util/concurrent/package-summary.html>
- Java Concurrency in Practice (book): still the definitive reference
