---
name: java-code-style
description: >
  Modern Java 21 LTS style: Google Java Style baseline, records, sealed
  classes, pattern matching, switch expressions, var keyword, text
  blocks. Apply when writing or reviewing Java code.
---

# Java code style (Java 21 LTS)

Java 21 is the current LTS (2026). Use its features — records, sealed
types, pattern matching, switch expressions, text blocks, virtual
threads. Legacy Java-8-style code should be modernized when touched,
not held sacred.

## Baseline: Google Java Style

The Google Java Style Guide is the closest thing to a community
standard. Differences from Oracle's old conventions:

- **2-space indent** (not 4).
- **100-column line length** (not 80).
- **`google-java-format`** is the canonical formatter — run it in
  pre-commit hooks and CI.
- **Braces required** for all `if`/`for`/`while` bodies, even single
  statements.

Install `google-java-format` via `jbang install google-java-format@google/google-java-format`
or the Gradle / Maven plugin (`com.diffplug.spotless`).

## Naming

- `PascalCase` — classes, interfaces, enums, records, sealed types.
- `camelCase` — methods, variables, parameters, fields.
- `UPPER_SNAKE_CASE` — `static final` constants.
- `packageName.subpackage` — lowercase, single-word segments preferred.
- **No `I`-prefix** on interfaces. No `Impl` suffix on implementations
  unless there is genuinely only one and the interface matters more.
- Acronyms treated as words: `HttpClient` not `HTTPClient`,
  `xmlParser` not `xMLParser`.

## Records (Java 16+)

```java
public record User(String id, String name, int age) {
    public User {
        if (age < 0) throw new IllegalArgumentException("age must be >= 0");
    }
}
```

- **Compact constructor** (`public User { ... }`) for validation.
- Auto-generates `equals`, `hashCode`, `toString`, accessors.
- Use for **value types** — DTOs, immutable data, configuration.
- Don't use for entities that need identity semantics beyond the
  fields.

## Sealed classes and pattern matching (Java 17+)

```java
public sealed interface Shape permits Circle, Square, Triangle {}
public record Circle(double radius) implements Shape {}
public record Square(double side) implements Shape {}
public record Triangle(double base, double height) implements Shape {}

double area(Shape shape) {
    return switch (shape) {
        case Circle c -> Math.PI * c.radius() * c.radius();
        case Square s -> s.side() * s.side();
        case Triangle t -> 0.5 * t.base() * t.height();
    };
}
```

- Sealed + records + pattern-matching switch is the modern Java take
  on discriminated unions. Use it.
- **Exhaustive** switch expressions require all permitted subtypes —
  the compiler enforces this.
- Use `case X x when cond ->` for guards.

## `var` for local variables (Java 10+)

```java
var users = userRepository.findAll();
var config = new HashMap<String, Object>();
```

- Use `var` when the type is obvious from the right-hand side.
- Do **not** use `var` for primitives or when the type is non-obvious
  (`var result = compute()` — what does `compute()` return?).
- `var` is not allowed on fields — only local variables.

## Text blocks (Java 15+)

```java
String sql = """
    SELECT id, name, age
    FROM users
    WHERE active = true
    """;
```

Three `"""` fences. Indentation is relative to the closing fence —
everything left of it is stripped. Use for SQL, JSON, HTML, and any
multi-line literal.

## Streams vs loops

- **Loops** for simple iteration — clearer, shorter, faster in tight
  hot paths.
- **Streams** for transformations, filtering, and aggregation where
  the result is a new collection.
- Avoid mixing `forEach` with side effects — streams are meant for
  functional transformations.
- `Collectors.toList()` → `.toList()` (Java 16+) for unmodifiable
  results.

## Null handling

- Use `Optional<T>` for return values that may be absent. Do not use
  `Optional` as a field or parameter.
- Use `@Nullable` / `@NonNull` annotations from JSpecify for null
  analysis — the upcoming standard.
- Never return `null` for collections — return an empty collection.
- Use `Objects.requireNonNull(x, "x")` for constructor args.

## Modern classes: records, sealed, immutable by default

The Java ethos is shifting toward immutability and value-oriented
types. Prefer:

1. **Records** over `@Data` POJOs.
2. **Sealed interfaces** over abstract classes with package-private
   constructors.
3. **Factory methods** (`static of(...)`) over public constructors
   that need validation.
4. **`List.of(...)`, `Map.of(...)`, `Set.of(...)`** for immutable
   collections.

## Anti-patterns

- **Getters/setters for records** — records have accessors named
  after the component (`user.name()`, not `user.getName()`).
- **`public class ...` with just fields + getters + setters** — use
  a record.
- **Checked exceptions in modern code** — annoying, propagate up as
  unchecked (`RuntimeException` subclass).
- **`@SuppressWarnings` without a comment** explaining why.
- **`System.out.println` for logging** — use SLF4J.
- **`new Date()` / `SimpleDateFormat`** — use `java.time` (`Instant`,
  `LocalDate`, `DateTimeFormatter`).
- **`Thread.sleep()` in async code** — use a scheduled executor or
  virtual thread.

## Tool detection

```bash
for tool in java javac gradle jdtls; do
  command -v "$tool" >/dev/null && echo "ok: $tool" || echo "MISSING: $tool"
done
```

## References

- Google Java Style: https://google.github.io/styleguide/javaguide.html
- Java 21 features: https://openjdk.org/projects/jdk/21/
- JEP 395 (records): https://openjdk.org/jeps/395
- JEP 409 (sealed): https://openjdk.org/jeps/409
- JEP 441 (pattern matching for switch): https://openjdk.org/jeps/441
- JSpecify: https://jspecify.dev
