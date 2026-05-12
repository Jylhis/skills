---
name: jvm
description: Use for JVM build, packaging, and testing — Gradle 8.10+ with Kotlin DSL, libs.versions.toml version catalogs, java/kotlin toolchains, convention plugins (buildSrc / build-logic), configuration cache + parallel builds; publishing libraries to Maven Central via maven-publish + nmcp + JReleaser, signing with useInMemoryPgpKeys, JPMS module-info, GitHub Actions release-on-tag; testing with JUnit 5 (Jupiter), AssertJ, kotest (Kotlin), mockk / mockito, Testcontainers, JaCoCo, awaitility. Read the matching reference before acting.
---

# JVM build / packaging / testing skill index

Pick the topic and read its reference before writing or reviewing
JVM build files or tests.

| Topic | When to read | Reference |
|---|---|---|
| Gradle build | build.gradle.kts, libs.versions.toml, java/kotlin toolchains, allWarningsAsErrors, convention plugins, configuration-cache, build-cache, dependencyInsight | `references/build-gradle.md` |
| Maven Central publishing | maven-publish, com.gradleup.nmcp, JReleaser, signing (useInMemoryPgpKeys + env vars), withSourcesJar/withJavadocJar, POM metadata, JPMS module-info, semver release tagging, GitHub Actions release-on-tag | `references/packaging.md` |
| Testing | JUnit 5 (Jupiter) for Java (@Nested, @ParameterizedTest, @CsvSource), AssertJ, kotest for Kotlin (StringSpec / FunSpec / etc.), mockk / mockito, Testcontainers, JaCoCo, useJUnitPlatform(), awaitility, migrating from PowerMock | `references/testing.md` |

For JVM **security** topics, use `security`.

After reading the reference, follow its guidance for the task.
