---
name: jvm-security
description: >
  JVM security footguns and safe alternatives: JNDI (Log4Shell-class),
  Java serialization, XXE, SSRF, SQL injection, secrets, crypto APIs.
  Apply when reviewing any code that handles untrusted input or
  external services on the JVM.
---

# JVM security

Java and Kotlin share the JVM's security landscape. Some of these
footguns are famous (Log4Shell), others less so but still common in
real codebases.

## JNDI / Log4Shell class

**Never pass user input to JNDI lookups.** Log4j 2's `${jndi:...}`
substitution was the Log4Shell vulnerability — any logger on
pre-2.17.0 Log4j 2 could fetch and execute a remote class via LDAP.

```java
// DANGEROUS
logger.info("User-Agent: {}", request.getHeader("User-Agent"));
```

was enough to trigger RCE on vulnerable versions.

Mitigations:

- **Upgrade Log4j to 2.17.1 or later** (or switch to Logback, the
  default SLF4J implementation).
- **Never enable JNDI lookups** in log patterns, LDAP resolvers, or
  any library that accepts user input as a "resource name."
- Set `log4j2.formatMsgNoLookups=true` as a fallback defence in depth.

## Java serialization (ObjectInputStream)

**Never deserialize untrusted data with Java's built-in
serialization.** An attacker can construct a gadget chain that
executes arbitrary code on deserialization.

```java
// DANGEROUS
ObjectInputStream in = new ObjectInputStream(request.getInputStream());
Object obj = in.readObject();   // RCE risk
```

Safe alternatives:

- **JSON** with Jackson (`ObjectMapper.readValue`) — still audit for
  polymorphic deserialization config.
- **Protobuf** for structured binary data.
- **`ObjectInputFilter`** (Java 9+) whitelists allowed classes if you
  absolutely must use Java serialization.
- **Kryo** with class registration — safer than Java's default but
  still needs audit.

Disable Java serialization in new projects. Records (Java 16+) are
not auto-serializable unless you `implements Serializable` — take
advantage of that.

## XXE (XML External Entity)

Default Java XML parsers enable external entity resolution, which
allows attackers to read local files and perform SSRF via crafted
XML:

```java
// DANGEROUS — default parser, XXE enabled
DocumentBuilderFactory dbf = DocumentBuilderFactory.newInstance();
DocumentBuilder db = dbf.newDocumentBuilder();
Document doc = db.parse(userInput);
```

**Safe config:**

```java
DocumentBuilderFactory dbf = DocumentBuilderFactory.newInstance();
dbf.setFeature("http://apache.org/xml/features/disallow-doctype-decl", true);
dbf.setFeature("http://xml.org/sax/features/external-general-entities", false);
dbf.setFeature("http://xml.org/sax/features/external-parameter-entities", false);
dbf.setXIncludeAware(false);
dbf.setExpandEntityReferences(false);
```

Or use a safer library: **Jackson's `XmlMapper`** has saner defaults
for deserialization, **jsoup** for HTML, **StAX with security feature
set**.

## SQL injection

Always parameterize:

```java
// WRONG
stmt.executeQuery("SELECT * FROM users WHERE id = '" + userId + "'");

// RIGHT
PreparedStatement ps = conn.prepareStatement("SELECT * FROM users WHERE id = ?");
ps.setString(1, userId);
ResultSet rs = ps.executeQuery();
```

- **JDBC `PreparedStatement`** with `?` placeholders.
- **JPA `@Query`** with named parameters — never string concatenation
  inside `@Query`.
- **jOOQ / Exposed** — use the type-safe DSL, not `execute` with a
  string.
- **Spring Data JDBC `NamedParameterJdbcTemplate`** — parameterizes
  by default.
- Audit every `native query`, `createNativeQuery`, `execute`,
  `rawQuery` call.

## SSRF (Server-Side Request Forgery)

Validate user-supplied URLs before fetching:

```java
URI uri = URI.create(userUrl);
if (!"https".equals(uri.getScheme())) throw new IllegalArgumentException();

InetAddress addr = InetAddress.getByName(uri.getHost());
if (addr.isAnyLocalAddress() || addr.isLoopbackAddress()
    || addr.isLinkLocalAddress() || addr.isSiteLocalAddress()) {
    throw new IllegalArgumentException("blocked range");
}
```

- Block private ranges, metadata endpoints (169.254.169.254).
- Resolve once and fetch by IP to prevent DNS rebinding.
- Use a dedicated library like `guava-ext`'s URL validators when
  available.

## Secrets

- **Never commit secrets.** Use environment variables, secret
  managers (Vault, AWS Secrets Manager, Doppler), or `.env.local`
  with `.gitignore`.
- **Never log secrets.** Use Logback's `%mask` or Spring's
  `SanitizingMatcher`. Redact `Authorization`, `Cookie`, password
  fields.
- **`javax.crypto` password-based encryption** needs
  `PBKDF2WithHmacSHA256` with a **random salt**, **100k+ iterations**,
  and a properly-sized key.

## Password hashing

Never SHA-256 a password. Use:

- **Argon2** via `argon2-jvm`.
- **bcrypt** via Spring Security's `BCryptPasswordEncoder`.
- **PBKDF2** via `SecretKeyFactory.getInstance("PBKDF2WithHmacSHA256")`.

All three are tuneable (work factor, iterations). Use the library's
default parameters unless you benchmarked a different value.

## Crypto: avoid the footguns

- **Never roll your own crypto.**
- **ECB mode** — insecure. Use GCM for symmetric encryption.
- **`IvParameterSpec` with a fixed IV** — IV must be random per
  encryption.
- **`Cipher.getInstance("AES")`** — defaults to ECB. Use
  `"AES/GCM/NoPadding"`.
- **`SecureRandom.getInstance("SHA1PRNG")`** — don't specify,
  use `new SecureRandom()` which picks a good default.
- **RSA padding** — never `NoPadding` or `PKCS1`; use `OAEPWithSHA-256`.

Prefer higher-level libraries:

- **Tink** (Google) — a safe, easy-to-use crypto API.
- **Bouncy Castle** — extensive but requires care.
- **JWT:** `nimbus-jose-jwt` or `jjwt` — explicit algorithm choice,
  validation built in.

## Dependency audit

```bash
./gradlew dependencyCheckAnalyze     # OWASP Dependency Check plugin
```

For supply-chain scanning, use Snyk, Socket.dev, or GitHub's
Dependabot + CodeQL. Track vulnerabilities in your Gradle dependency
graph on every merge to main.

## Reflection and SecurityManager

- Java 17+ **deprecates the SecurityManager** (JEP 411). Do not rely
  on it for new code.
- **Reflection** can bypass access modifiers and is how many gadget
  chains exploit applications. Avoid in user-facing code; if you must
  reflect, validate class names against an allowlist.
- **`Unsafe` APIs** — internal, prone to breakage, and a red flag in
  code review.

## Anti-patterns

- `String sql = "SELECT * FROM " + table + " WHERE ..."` with any
  user-derived value.
- `ObjectInputStream` on untrusted bytes.
- `DocumentBuilderFactory.newInstance()` without disabling external
  entities.
- `Runtime.exec("/bin/sh -c " + userInput)` — use `ProcessBuilder`
  with an argv list.
- Catching `Exception` at a security boundary and returning a
  generic 500.
- Returning full stack traces to clients.
- **`System.setProperty` at runtime to weaken TLS settings.**

## Tool detection

```bash
for tool in java javac gradle gpg; do
  command -v "$tool" >/dev/null && echo "ok: $tool" || echo "MISSING: $tool"
done
```

## References

- OWASP top 10: https://owasp.org/www-project-top-ten/
- OWASP Java cheat sheet: https://cheatsheetseries.owasp.org/cheatsheets/Java_Security_Cheat_Sheet.html
- OWASP Dependency Check: https://owasp.org/www-project-dependency-check/
- Tink: https://developers.google.com/tink
- Spring Security: https://spring.io/projects/spring-security
