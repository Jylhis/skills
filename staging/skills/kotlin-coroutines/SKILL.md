---
name: kotlin-coroutines
description: >
  Kotlin coroutines: structured concurrency, CoroutineScope, Job,
  supervisor jobs, Flow, dispatcher choice, cancellation, exception
  handling. Apply when writing async Kotlin code with kotlinx.coroutines.
---

# Kotlin coroutines

Target `kotlinx.coroutines` 1.9+.

## Dependencies

```kotlin
dependencies {
    implementation("org.jetbrains.kotlinx:kotlinx-coroutines-core:1.9.0")
}
```

For tests: `kotlinx-coroutines-test`. For platform integrations:
`-android` or `-javafx`.

## Suspending functions

```kotlin
suspend fun fetchUser(id: String): User {
    return httpClient.get("/users/$id").body()
}
```

- Only callable from other suspend functions or coroutine builders.

## Coroutine builders

```kotlin
// launch — fire-and-forget, returns Job
val job = scope.launch {
    doWork()
}

// async — returns Deferred<T>, awaitable result
val deferred = scope.async {
    fetchUser(id)
}
val user = deferred.await()

// runBlocking — bridge from blocking code; use only in main() and
// tests, never in library code
fun main() = runBlocking {
    launch { doWork() }
}
```

## Structured concurrency

Every coroutine is a child of a `CoroutineScope`. When the scope is
cancelled, all children are cancelled.

```kotlin
coroutineScope {
    launch { task1() }
    launch { task2() }
}  // returns after both tasks finish; cancels both if either fails
```

- **`coroutineScope`** — fails fast: any child failure cancels
  siblings and the scope.
- **`supervisorScope`** — child failures do **not** cancel siblings.

```kotlin
suspend fun loadDashboard(userId: String): Dashboard = coroutineScope {
    val user = async { fetchUser(userId) }
    val orders = async { fetchOrders(userId) }
    val prefs = async { fetchPrefs(userId) }
    Dashboard(user.await(), orders.await(), prefs.await())
}
```

## Dispatchers

- **`Dispatchers.Default`** — CPU-bound work. Fork-join pool sized to
  CPU count.
- **`Dispatchers.IO`** — I/O-bound work. Expandable pool up to 64
  threads.
- **`Dispatchers.Main`** — UI thread (Android, JavaFX). Requires the
  platform-specific dependency.
- **`Dispatchers.Unconfined`** — caller's thread; don't use in
  production.

```kotlin
suspend fun readFile(path: Path): ByteArray = withContext(Dispatchers.IO) {
    Files.readAllBytes(path)
}
```

- **`withContext`** switches dispatcher for a block and switches back.
- **Always wrap blocking JVM APIs** in `withContext(Dispatchers.IO)`.

## Cancellation

Cancellation is **cooperative** — only takes effect at suspension points.

```kotlin
suspend fun process(items: List<Item>) {
    for (item in items) {
        yield()          // suspension point — check for cancellation
        compute(item)
    }
}
```

- Call `yield()` inside long loops.
- `ensureActive()` throws `CancellationException` if cancelled.
- Catch `CancellationException` **only to clean up**, then re-throw:

  ```kotlin
  try {
      doWork()
  } catch (e: CancellationException) {
      cleanup()
      throw e
  }
  ```

## Flow

`Flow<T>` is cold, async sequences:

```kotlin
fun readLines(path: Path): Flow<String> = flow {
    path.toFile().useLines { lines ->
        lines.forEach { emit(it) }
    }
}.flowOn(Dispatchers.IO)

// Consumer
readLines(path)
    .filter { it.isNotBlank() }
    .map { it.trim() }
    .collect { line -> process(line) }
```

- **Cold** — nothing runs until a terminal operator (`.collect`,
  `.toList`, `.first`, etc.).
- **`flowOn(dispatcher)`** changes the dispatcher upstream.
- **`StateFlow`** and **`SharedFlow`** are hot variants for state
  management and event buses.

## Exception handling

```kotlin
supervisorScope {
    val results = jobs.map { job ->
        async {
            try {
                processJob(job)
            } catch (e: Exception) {
                log.error("job failed", e)
                null
            }
        }
    }
    results.awaitAll().filterNotNull()
}
```

- **`try`/`catch`** inside `async` blocks — `async` rethrows on
  `.await()`, but with `supervisorScope` it doesn't propagate to
  siblings.
- **`CoroutineExceptionHandler`** for uncaught top-level errors:

  ```kotlin
  val handler = CoroutineExceptionHandler { _, ex ->
      log.error("uncaught", ex)
  }
  val scope = CoroutineScope(Dispatchers.Default + handler)
  ```

## Testing coroutines

```kotlin
import kotlinx.coroutines.test.*

@Test
fun fetchesUsers() = runTest {
    val service = UserService(fakeHttpClient)
    val users = service.list()
    users.size shouldBe 3
}
```

- **`runTest`** provides a test dispatcher that controls virtual time.
- **`advanceTimeBy(ms)`** skips ahead for delay-based tests.
- **`StandardTestDispatcher`** vs **`UnconfinedTestDispatcher`** —
  eager vs deferred execution.

## Anti-patterns

- **`GlobalScope.launch`** — no structure. Use a specific scope.
- **`runBlocking` in production code** — blocks a platform thread.
- **Calling blocking JVM code without `withContext(Dispatchers.IO)`**.
- **Ignoring `CancellationException`** — swallowing it breaks
  cancellation.
- **Launching children but not waiting** — they may be cancelled
  when the outer scope ends.
- **Using `Dispatchers.Default` for I/O** — use `IO`, which has a
  much larger pool.

## Tool detection

```bash
for tool in kotlin kotlinc gradle; do
  command -v "$tool" >/dev/null && echo "ok: $tool" || echo "MISSING: $tool"
done
```

## References

- kotlinx.coroutines guide: <https://kotlinlang.org/docs/coroutines-guide.html>
- Structured concurrency: <https://elizarov.medium.com/structured-concurrency-722d765aa952>
- Coroutine context and dispatchers: <https://kotlinlang.org/docs/coroutine-context-and-dispatchers.html>
- Flow: <https://kotlinlang.org/docs/flow.html>
