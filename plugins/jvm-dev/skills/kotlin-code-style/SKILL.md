---
name: kotlin-code-style
description: >
  Kotlin 2.0+ idiomatic style: official Kotlin conventions, data
  classes, sealed hierarchies, extension functions, scope functions,
  null safety. Apply when writing or reviewing Kotlin code.
---

# Kotlin code style (2.0+)

Kotlin 2.0 uses the K2 compiler by default — faster compilation and
more consistent diagnostics. Write idiomatic Kotlin, not Java-in-Kotlin.

## Baseline

- **Formatter:** `ktlint` or IntelliJ's built-in formatter (they
  agree). Add a pre-commit hook.
- **Indent:** 4 spaces.
- **Line length:** 120 (IntelliJ default).
- **Official style guide:** https://kotlinlang.org/docs/coding-conventions.html
- **Target JVM:** 21 LTS unless you need 17 for compatibility.

## Naming

- `PascalCase` — classes, interfaces, objects, typealiases, enum entries.
- `camelCase` — functions, properties, parameters, variables.
- `UPPER_SNAKE_CASE` — `const val` compile-time constants.
- **Acronyms treated as words:** `HttpClient`, `xmlParser`.
- **Function names can contain spaces** (in backticks) for test names:
  `\`returns 404 when user not found\``.

## `val` over `var`

Default to immutable. Only use `var` when mutation is required.

```kotlin
val users = mutableListOf<User>()  // list is mutable, reference is not
var count = 0                      // reassignable
```

Prefer `List<T>` (read-only interface) over `MutableList<T>` in
public APIs. Convert internally as needed.

## Data classes

```kotlin
data class User(
    val id: String,
    val name: String,
    val age: Int,
) {
    init {
        require(age >= 0) { "age must be >= 0" }
    }
}
```

- Auto-generates `equals`, `hashCode`, `toString`, `copy`, and
  `componentN` destructuring accessors.
- **Use for value types.** Not for entities with identity-based
  equality.
- **`copy(...)`** gives you convenient immutable updates:
  `user.copy(name = "Bob")`.
- **Trailing comma** on the last parameter — allowed since Kotlin 1.4
  and makes diffs cleaner.

## Sealed hierarchies

```kotlin
sealed interface Result<out T> {
    data class Success<T>(val value: T) : Result<T>
    data class Failure(val error: Throwable) : Result<Nothing>
}

fun <T> Result<T>.getOrNull(): T? = when (this) {
    is Result.Success -> value
    is Result.Failure -> null
}
```

- `sealed interface` (1.5+) is preferred over `sealed class` unless
  you need state.
- Exhaustive `when` on sealed types — the compiler enforces.
- Use for result types, UI state, command/event hierarchies.

## Extension functions

```kotlin
fun String.toSlug(): String =
    lowercase().replace(Regex("[^a-z0-9]+"), "-").trim('-')
```

- Keep them in the package where the **extended type** is defined, or
  a package named after the feature (`StringExtensions.kt`).
- **Don't add extensions for the sake of chaining** — a plain function
  is fine.
- **Top-level** extensions over member functions when the logic is
  reusable and stateless.

## Scope functions (`let`, `apply`, `also`, `run`, `with`)

Only five functions but they confuse newcomers. Rule of thumb:

| Function | Receiver | Returns | Use for |
|---|---|---|---|
| `let`    | `it`      | lambda result | nullable chains, transformation |
| `apply`  | `this`    | object itself | builder-style config |
| `also`   | `it`      | object itself | side effects (logging) |
| `run`    | `this`    | lambda result | object-scoped computation |
| `with`   | `this`    | lambda result | grouped operations (no null) |

```kotlin
// let: nullable chain
val length = user?.name?.let { it.length } ?: 0

// apply: builder
val intent = Intent(context, MyActivity::class.java).apply {
    putExtra("key", "value")
    flags = Intent.FLAG_ACTIVITY_NEW_TASK
}

// also: side effect
val result = compute().also { log.debug("computed $it") }
```

**Don't nest scope functions.** If you find yourself using two `let`s
in a row, pull out intermediate variables instead.

## Null safety

- Use `?` for nullable types: `String?`.
- Use `?.` safe call, `?:` elvis operator, `!!` only at known-
  non-null boundaries.
- `!!` is a code smell — prefer `error("...")` or `requireNotNull()`.
- Platform types from Java come in as `String!` — wrap them at the
  boundary with annotations or explicit assertions.

## Top-level and `object`

- **Top-level functions** are fine — no need to wrap utilities in a
  class.
- **`object` declarations** for singletons — replaces Java's
  `enum Singleton { INSTANCE }` pattern.
- **Companion objects** for factory methods and type-scoped constants:
  ```kotlin
  class User private constructor(val id: String) {
      companion object {
          fun parse(raw: String): User = ...
      }
  }
  ```

## String templates and multiline strings

```kotlin
val greeting = "Hello, $name! You are ${age + 1} next year."

val json = """
    {
        "id": "$id",
        "name": "$name"
    }
""".trimIndent()
```

Use `trimIndent()` on multiline strings. For consistent inner
indentation, use `trimMargin("|")`.

## Collections

- `listOf(...)`, `mapOf(...)`, `setOf(...)` for immutable.
- `mutableListOf(...)` for mutable.
- `buildList { ... }` / `buildMap { ... }` for building up a
  collection imperatively then freezing.
- Prefer sequence operations (`asSequence().map { }.filter { }.toList()`)
  for long chains — avoids intermediate allocations.

## Anti-patterns

- `java.util.Optional<T>` — use nullable types instead.
- `ArrayList<T>()` — use `mutableListOf<T>()`.
- `Thread.sleep()` — use `delay()` in coroutines or a
  `ScheduledExecutorService`.
- **Companion object constants** — use top-level `const val` instead.
- **Custom `Result<T, E>` classes** — use `kotlin.Result` (stdlib)
  or a sealed hierarchy.
- **`lateinit var` everywhere** — usually means the DI or lifecycle
  isn't right. Use `by lazy` or constructor injection.
- **Forgetting `override` keyword** — not required in Kotlin but
  always include for clarity.

## Tool detection

```bash
for tool in kotlin kotlinc gradle ktlint kotlin-language-server; do
  command -v "$tool" >/dev/null && echo "ok: $tool" || echo "MISSING: $tool"
done
```

## References

- Kotlin coding conventions: https://kotlinlang.org/docs/coding-conventions.html
- Kotlin 2.0 release notes: https://kotlinlang.org/docs/whatsnew20.html
- Scope functions: https://kotlinlang.org/docs/scope-functions.html
- ktlint: https://pinterest.github.io/ktlint/
