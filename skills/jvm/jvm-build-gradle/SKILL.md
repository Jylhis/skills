---
name: jvm-build-gradle
description: "Use for Gradle with Kotlin DSL on Gradle 8.10+ and Java 21 LTS including build.gradle.kts and settings.gradle.kts, gradle/libs.versions.toml version catalogs with libs.* type-safe accessors, java.toolchain JavaLanguageVersion.of(21), kotlin.jvmToolchain(21), allWarningsAsErrors, useJUnitPlatform() on tasks.test, buildSrc/ and build-logic/ convention plugins, multi-project include() builds, configuration-cache, build-cache, parallel builds, build scans (--scan / Develocity), incremental @InputFiles/@OutputFiles tasks, dependencyInsight, or migrating from Groovy DSL or the deprecated compile/runtime configurations to implementation/api."
---

# Gradle with Kotlin DSL

Use the **Kotlin DSL** (`build.gradle.kts`) — type-safe accessors,
IDE autocompletion, better error messages. Target **Gradle 8.10+**
and **Java 21 LTS**.

## Single-project layout

```text
my-project/
├── settings.gradle.kts
├── build.gradle.kts
├── gradle/
│   ├── libs.versions.toml         # version catalog
│   └── wrapper/
│       ├── gradle-wrapper.jar
│       └── gradle-wrapper.properties
├── gradlew                         # wrapper script
├── gradlew.bat
└── src/
    ├── main/
    │   ├── java/
    │   ├── kotlin/
    │   └── resources/
    └── test/
        ├── java/
        ├── kotlin/
        └── resources/
```

Always commit the **wrapper** (`gradle/wrapper/*` + `gradlew`). It
pins the Gradle version per-project.

## `settings.gradle.kts`

```kotlin
rootProject.name = "my-project"

pluginManagement {
    repositories {
        gradlePluginPortal()
        mavenCentral()
    }
}

dependencyResolutionManagement {
    repositories {
        mavenCentral()
    }
}
```

## `build.gradle.kts` (Java + Kotlin)

```kotlin
plugins {
    alias(libs.plugins.kotlin.jvm)
    `java-library`
    `maven-publish`
}

group = "com.example"
version = "0.1.0"

java {
    toolchain {
        languageVersion = JavaLanguageVersion.of(21)
    }
    withSourcesJar()
    withJavadocJar()
}

kotlin {
    jvmToolchain(21)
    compilerOptions {
        allWarningsAsErrors = true
    }
}

dependencies {
    implementation(libs.kotlinx.coroutines.core)
    implementation(libs.slf4j.api)

    testImplementation(libs.junit.jupiter)
    testImplementation(libs.kotest.assertions.core)
    testImplementation(libs.mockk)

    testRuntimeOnly(libs.junit.platform.launcher)
}

tasks.test {
    useJUnitPlatform()
}
```

Key points:

- **`java.toolchain`** — Gradle downloads the specified JDK if not
  present.
- **`allWarningsAsErrors = true`** — catches deprecations early.
- **`useJUnitPlatform()`** is required on `tasks.test` for JUnit 5.
- **`libs.*`** accessors come from the version catalog (below).

## Version catalog (`gradle/libs.versions.toml`)

```toml
[versions]
kotlin = "2.0.21"
coroutines = "1.9.0"
junit = "5.11.3"
kotest = "5.9.1"
mockk = "1.13.13"
slf4j = "2.0.16"

[libraries]
kotlinx-coroutines-core = { module = "org.jetbrains.kotlinx:kotlinx-coroutines-core", version.ref = "coroutines" }
slf4j-api = { module = "org.slf4j:slf4j-api", version.ref = "slf4j" }
junit-jupiter = { module = "org.junit.jupiter:junit-jupiter", version.ref = "junit" }
junit-platform-launcher = { module = "org.junit.platform:junit-platform-launcher" }
kotest-assertions-core = { module = "io.kotest:kotest-assertions-core", version.ref = "kotest" }
mockk = { module = "io.mockk:mockk", version.ref = "mockk" }

[plugins]
kotlin-jvm = { id = "org.jetbrains.kotlin.jvm", version.ref = "kotlin" }
```

- **One source of truth** for versions.
- **Type-safe accessors** in `build.gradle.kts` (`libs.junit.jupiter`).
- Bumping `kotlin` updates the plugin too.

## Multi-project build

```kotlin
// settings.gradle.kts
rootProject.name = "my-mono"
include("core", "api", "cli")
```

```text
my-mono/
├── settings.gradle.kts
├── build.gradle.kts              # shared config via convention plugin
├── buildSrc/                      # or build-logic for better isolation
│   └── src/main/kotlin/
│       └── my.convention.gradle.kts
├── core/
│   └── build.gradle.kts
├── api/
│   └── build.gradle.kts
└── cli/
    └── build.gradle.kts
```

Use **convention plugins** in `buildSrc/` or a composite build in
`build-logic/`. Shared config via `subprojects { ... }` is a legacy
pattern.

## Common tasks

```bash
./gradlew build                  # compile + test + package
./gradlew test                   # just run tests
./gradlew :core:test             # tests in one module
./gradlew test --tests "*.UserServiceTest"
./gradlew test --tests "*.UserServiceTest.returns404*"
./gradlew clean
./gradlew dependencies           # resolved dependency tree
./gradlew :core:dependencyInsight --dependency slf4j-api
./gradlew --scan build           # build scan with Develocity
```

## Build cache and scans

```bash
# ~/.gradle/gradle.properties
org.gradle.caching=true
org.gradle.parallel=true
org.gradle.configuration-cache=true
```

- **Configuration cache** — skips the configuration phase on repeat builds.
- **Parallel** — runs independent tasks in parallel across modules.
- **Build cache** — shares outputs between projects and CI.
- **Build scans** (`./gradlew build --scan`) — detailed report to scans.gradle.com.

## Incremental + up-to-date checks

Gradle skips unchanged tasks. Make tasks incremental-friendly:

- Declare `@InputFiles`, `@OutputFiles`, `@InputDirectory` on custom
  task classes.
- Avoid `doLast { }` and `doFirst { }` for logic — use typed tasks.
- Don't use `System.currentTimeMillis()` inside task actions — it
  makes tasks always-out-of-date.

## Anti-patterns

- Using Groovy DSL (`build.gradle`) in new projects — Kotlin DSL is
  the default in Gradle 9.
- Not committing the wrapper.
- Pinning plugin versions in each module instead of the version
  catalog.
- `gradle clean build` as the standard command — `clean` defeats the
  cache.
- `compile` configuration — deprecated, use `implementation` or `api`.
- Mixing `implementation` and `api` randomly — `api` for transitive
  exposure (libraries), `implementation` for internal (most things).
- Rolling your own publishing config — use `maven-publish` or
  `com.gradleup.nmcp` for Maven Central.

## Tool detection

```bash
for tool in java javac gradle kotlin; do
  command -v "$tool" >/dev/null && echo "ok: $tool" || echo "MISSING: $tool"
done
```

## References

- Gradle user manual: <https://docs.gradle.org/current/userguide/userguide.html>
- Kotlin DSL primer: <https://docs.gradle.org/current/userguide/kotlin_dsl.html>
- Version catalogs: <https://docs.gradle.org/current/userguide/platforms.html>
- Build scans: <https://scans.gradle.com>
- Gradle inception wrapper: <https://docs.gradle.org/current/userguide/gradle_wrapper.html>
