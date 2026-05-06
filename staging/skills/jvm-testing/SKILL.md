---
name: jvm-testing
description: >
  Testing on the JVM: JUnit 5 for Java, kotest for Kotlin, AssertJ,
  mockk / mockito, Testcontainers for integration. Apply when writing
  or reviewing JVM tests.
---

# JVM testing: JUnit 5 (Java) + kotest (Kotlin)

## Gradle dependencies

```kotlin
dependencies {
    testImplementation("org.junit.jupiter:junit-jupiter:5.11.3")
    testImplementation("org.assertj:assertj-core:3.26.3")
    testImplementation("io.kotest:kotest-assertions-core:5.9.1")
    testImplementation("io.mockk:mockk:1.13.13")             // Kotlin
    testImplementation("org.mockito:mockito-core:5.14.2")    // Java
    testRuntimeOnly("org.junit.platform:junit-platform-launcher")
}

tasks.test {
    useJUnitPlatform()
    testLogging {
        events("passed", "skipped", "failed")
        exceptionFormat = org.gradle.api.tasks.testing.logging.TestExceptionFormat.FULL
    }
}
```

## JUnit 5 basics (Java)

```java
import org.junit.jupiter.api.*;
import static org.assertj.core.api.Assertions.*;

class UserServiceTest {

    UserRepository repo;
    UserService service;

    @BeforeEach
    void setUp() {
        repo = new InMemoryUserRepository();
        service = new UserService(repo);
    }

    @Test
    void createUser_persistsName() {
        var user = service.create("Alice");
        assertThat(repo.findById(user.id())).isPresent();
        assertThat(user.name()).isEqualTo("Alice");
    }

    @Test
    void createUser_rejectsEmptyName() {
        assertThatThrownBy(() -> service.create(""))
            .isInstanceOf(IllegalArgumentException.class)
            .hasMessageContaining("name must not be empty");
    }
}
```

- **`@BeforeEach`** sets up fresh state per test.
- **AssertJ** (`assertThat`) — fluent, targeted matchers.
- **Nested tests** with `@Nested` group related cases.
- JUnit 5 creates a new instance per test method by default.

## kotest basics (Kotlin)

Pick one spec style per project. `StringSpec` is the most compact:

```kotlin
import io.kotest.core.spec.style.StringSpec
import io.kotest.matchers.shouldBe
import io.kotest.assertions.throwables.shouldThrow

class UserServiceTest : StringSpec({
    val repo = InMemoryUserRepository()
    val service = UserService(repo)

    "createUser persists name" {
        val user = service.create("Alice")
        repo.findById(user.id).shouldNotBeNull()
        user.name shouldBe "Alice"
    }

    "createUser rejects empty name" {
        shouldThrow<IllegalArgumentException> {
            service.create("")
        }.message shouldContain "name must not be empty"
    }
})
```

Alternative spec styles: `FunSpec`, `DescribeSpec`, `BehaviorSpec`,
`FreeSpec`.

## Parametrized tests

**JUnit 5:**

```java
@ParameterizedTest
@CsvSource({
    "foo@bar.com, foo@bar.com",
    "FOO@BAR.COM, foo@bar.com",
    "  foo@bar.com  , foo@bar.com"
})
void normalizeEmail(String input, String expected) {
    assertThat(normalize(input)).isEqualTo(expected);
}
```

Other sources: `@ValueSource`, `@MethodSource`, `@ArgumentsSource`.

**kotest:**

```kotlin
import io.kotest.data.forAll
import io.kotest.data.row

"normalizeEmail" {
    forAll(
        row("foo@bar.com",     "foo@bar.com"),
        row("FOO@BAR.COM",     "foo@bar.com"),
        row("  foo@bar.com  ", "foo@bar.com"),
    ) { input, expected ->
        normalize(input) shouldBe expected
    }
}
```

## Mocking

**mockk (Kotlin):**

```kotlin
val repo = mockk<UserRepository>()
every { repo.findById("42") } returns User("42", "Alice")
val service = UserService(repo)
service.getName("42") shouldBe "Alice"
verify { repo.findById("42") }
```

**mockito (Java):**

```java
UserRepository repo = mock(UserRepository.class);
when(repo.findById("42")).thenReturn(Optional.of(new User("42", "Alice")));
var service = new UserService(repo);
assertThat(service.getName("42")).isEqualTo("Alice");
verify(repo).findById("42");
```

Prefer **dependency injection** over mocks when you can — passing a
fake implementation keeps tests fast and honest.

## Integration tests with Testcontainers

```java
@Testcontainers
class UserRepositoryIT {

    @Container
    static PostgreSQLContainer<?> postgres = new PostgreSQLContainer<>("postgres:16")
        .withDatabaseName("test")
        .withUsername("test")
        .withPassword("test");

    @Test
    void savesUser() {
        // connect to postgres.getJdbcUrl() etc.
    }
}
```

## Coverage

Use **JaCoCo** for coverage:

```kotlin
plugins {
    jacoco
}

tasks.jacocoTestReport {
    dependsOn(tasks.test)
    reports {
        xml.required = true
        html.required = true
    }
}
```

## Running

```bash
./gradlew test                       # all tests
./gradlew test --tests "*.UserServiceTest"
./gradlew test --tests "*UserServiceTest.createUser_persistsName"
./gradlew test --info                # verbose output
./gradlew test --rerun-tasks         # force re-run (ignore cache)
./gradlew jacocoTestReport           # generate coverage
```

## Anti-patterns

- JUnit 4 in new projects.
- **Static mocks** (PowerMock) — refactor to inject the dependency.
- **Testing implementation details** (private methods, internal
  state) — test observable behaviour.
- **Shared mutable state** between tests (`static` fields without
  cleanup).
- **`Thread.sleep()`** to wait for async work — use `awaitility`.
- **Mocking value types** (records, data classes) — use real
  instances.
- **Ignoring flaky tests** instead of fixing them.

## Tool detection

```bash
for tool in java javac gradle kotlin; do
  command -v "$tool" >/dev/null && echo "ok: $tool" || echo "MISSING: $tool"
done
```

## References

- JUnit 5 user guide: <https://junit.org/junit5/docs/current/user-guide/>
- AssertJ: <https://assertj.github.io/doc/>
- kotest: <https://kotest.io>
- mockk: <https://mockk.io>
- Testcontainers: <https://java.testcontainers.org>
- awaitility: <https://github.com/awaitility/awaitility>
