---
name: jvm-packaging
description: >
  Packaging and publishing JVM artifacts: Gradle publish, Maven
  Central via nmcp or JReleaser, JPMS modules, sources/Javadoc jars,
  signing. Apply when preparing a JVM library for release or
  maintaining an existing published artifact.
---

# JVM packaging and publishing

Publishing a JVM library to Maven Central is fiddly. Since the 2024
Central migration to `central.sonatype.com`, the old `ossrh` staging
API is being replaced by a new portal API. Use a modern Gradle plugin
that supports it.

## Plugins to use

- **`maven-publish`** (built-in) — generates a local Maven
  repository and handles POM metadata.
- **`com.gradleup.nmcp`** (nmcp) — publishes to the new Maven Central
  portal. Simple, direct.
- **`org.jreleaser`** (JReleaser) — more features (multiple targets,
  GitHub releases, changelogs) at the cost of more config.

For simple libraries use nmcp. For multi-target releases with
GitHub Releases integration, use JReleaser.

## Gradle build config

```kotlin
plugins {
    `java-library`
    `maven-publish`
    signing
    id("com.gradleup.nmcp") version "0.0.9"
}

java {
    toolchain {
        languageVersion = JavaLanguageVersion.of(21)
    }
    withSourcesJar()
    withJavadocJar()
}

publishing {
    publications {
        create<MavenPublication>("maven") {
            from(components["java"])

            pom {
                name = "My Library"
                description = "Does the thing"
                url = "https://github.com/you/my-library"
                licenses {
                    license {
                        name = "Apache-2.0"
                        url = "https://www.apache.org/licenses/LICENSE-2.0.txt"
                    }
                }
                developers {
                    developer {
                        id = "you"
                        name = "Your Name"
                        email = "you@example.com"
                    }
                }
                scm {
                    connection = "scm:git:github.com/you/my-library.git"
                    developerConnection = "scm:git:ssh://github.com/you/my-library.git"
                    url = "https://github.com/you/my-library"
                }
            }
        }
    }
}

signing {
    useInMemoryPgpKeys(
        System.getenv("SIGNING_KEY"),
        System.getenv("SIGNING_PASSWORD")
    )
    sign(publishing.publications["maven"])
}

nmcp {
    centralPortal {
        username = System.getenv("MAVEN_CENTRAL_USERNAME")
        password = System.getenv("MAVEN_CENTRAL_PASSWORD")
        publishingType = "AUTOMATIC"
    }
}
```

Key points:

- **`withSourcesJar()` + `withJavadocJar()`** — Maven Central requires
  both.
- **POM metadata** — Central requires name, description, url,
  licenses, developers, scm.
- **Signing** — every artifact must be GPG-signed. Use
  `useInMemoryPgpKeys` in CI with env vars, never commit keys.
- **`publishingType = "AUTOMATIC"`** — auto-promotes to Central after
  validation. Use `USER_MANAGED` if you want a manual review step.

## POM requirements (Maven Central)

Central rejects POMs missing:

- `name`
- `description`
- `url`
- at least one `license`
- at least one `developer`
- `scm` block

Plus:

- `groupId` must be a domain you own or a reverse-DNS namespace you
  control (verified by Sonatype).
- `artifactId` must be unique within your `groupId`.
- `version` must not end in `-SNAPSHOT` for release builds.
- Javadoc JAR and sources JAR must accompany the main JAR.
- All artifacts must be GPG signed.

## Version strategy

- **Semantic versioning**: `MAJOR.MINOR.PATCH` with optional
  `-alpha.N`, `-beta.N`, `-rc.N` pre-release suffixes.
- **No `-SNAPSHOT` on Maven Central** — snapshots go to a separate
  repo if needed.
- **Tag the release** in git as `vX.Y.Z` and publish from the tagged
  commit.

## JPMS modules (`module-info.java`)

If your library wants to support the Java Platform Module System:

```java
// src/main/java/module-info.java
module com.example.mylib {
    requires java.base;
    requires transitive org.slf4j;

    exports com.example.mylib;
    exports com.example.mylib.spi;
}
```

- **`requires`** — modules you use.
- **`requires transitive`** — modules that leak into your public API
  (consumers need them too).
- **`exports`** — packages visible to consumers.
- `module-info.java` adds cost and complexity. For libraries not
  targeting modular apps, an auto-module (no `module-info`) is fine.

## Publishing workflow

Typical CI-based release:

```yaml
# .github/workflows/release.yml
on:
  push:
    tags: ['v*']

jobs:
  release:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - uses: actions/setup-java@v4
        with: { distribution: 'temurin', java-version: '21' }
      - uses: gradle/actions/setup-gradle@v4
      - run: ./gradlew publishToCentralPortal
        env:
          SIGNING_KEY: ${{ secrets.SIGNING_KEY }}
          SIGNING_PASSWORD: ${{ secrets.SIGNING_PASSWORD }}
          MAVEN_CENTRAL_USERNAME: ${{ secrets.MAVEN_CENTRAL_USERNAME }}
          MAVEN_CENTRAL_PASSWORD: ${{ secrets.MAVEN_CENTRAL_PASSWORD }}
```

## Pre-release checklist

Before tagging a release:

1. All tests pass (`./gradlew test`).
2. No deprecation warnings (`allWarningsAsErrors = true`).
3. `CHANGELOG.md` updated.
4. `README.md` install snippet uses the new version.
5. POM metadata correct (license, scm, developers).
6. Version bumped in `build.gradle.kts`.
7. git tag matches the version.

## Anti-patterns

- **Publishing a `-SNAPSHOT`** to Maven Central (rejected).
- **Hardcoded credentials** in `build.gradle.kts`.
- **No GPG signing** — Central rejects.
- **Missing Javadoc/sources JAR**.
- **Publishing from a dirty working tree** (uncommitted changes).
- **`groupId` on a domain you don't own** — Sonatype rejects.
- **Using the old `ossrh` staging** in 2026 — use the new portal.
- **Releasing without a changelog** — users can't tell what changed.

## Tool detection

```bash
for tool in java javac gradle gpg; do
  command -v "$tool" >/dev/null && echo "ok: $tool" || echo "MISSING: $tool"
done
```

## References

- Maven Central portal: https://central.sonatype.com
- `com.gradleup.nmcp`: https://github.com/GradleUp/nmcp
- JReleaser: https://jreleaser.org
- POM reference: https://maven.apache.org/pom.html
- Semantic versioning: https://semver.org
