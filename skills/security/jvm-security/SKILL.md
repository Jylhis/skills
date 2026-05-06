---
name: jvm-security
description: >
  JVM security footguns and safe alternatives: JNDI (Log4Shell-class),
  Java serialization, XXE, SSRF, SQL injection, secrets, crypto APIs.
  Apply when reviewing any code that handles untrusted input or
  external services on the JVM.
---

# JVM security

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

- **Upgrade Log4j to 2.17.1 or later** (or switch to Logback).
- **Never enable JNDI lookups** in log patterns, LDAP resolvers, or
  any library that accepts user input as a "resource name."
- Set `log4j2.formatMsgNoLookups=true` as defence in depth.

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
  must use Java serialization.
- **Kryo** with class registration — safer but still needs audit.

## XXE (XML External Entity)

Default Java XML parsers enable external entity resolution:

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

Or use Jackson's `XmlMapper`, **jsoup** for HTML, **StAX with
security feature set**.

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
- **JPA `@Query`** with named parameters — never string concatenation.
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

## Secrets

- **Never commit secrets.** Use environment variables, secret
  managers (Vault, AWS Secrets Manager, Doppler), or `.env.local`
  with `.gitignore`.
- **Never log secrets.** Redact `Authorization`, `Cookie`, password
  fields.
- **`javax.crypto` password-based encryption** needs
  `PBKDF2WithHmacSHA256` with a **random salt**, **100k+ iterations**,
  and a properly-sized key.

## Password hashing

Never SHA-256 a password. Use:

- **Argon2** via `argon2-jvm`.
- **bcrypt** via Spring Security's `BCryptPasswordEncoder`.
- **PBKDF2** via `SecretKeyFactory.getInstance("PBKDF2WithHmacSHA256")`.

## Crypto: avoid the footguns

- **Never roll your own crypto.**
- **ECB mode** — insecure. Use GCM for symmetric encryption.
- **`IvParameterSpec` with a fixed IV** — IV must be random per
  encryption.
- **`Cipher.getInstance("AES")`** — defaults to ECB. Use
  `"AES/GCM/NoPadding"`.
- **`SecureRandom.getInstance("SHA1PRNG")`** — don't specify,
  use `new SecureRandom()`.
- **RSA padding** — never `NoPadding` or `PKCS1`; use `OAEPWithSHA-256`.

Prefer higher-level libraries: **Tink** (Google), **Bouncy Castle**,
**nimbus-jose-jwt** or **jjwt** for JWT.

## Dependency audit

```bash
./gradlew dependencyCheckAnalyze     # OWASP Dependency Check plugin
```

For supply-chain scanning, use Snyk, Socket.dev, or GitHub's
Dependabot + CodeQL.

## Reflection and SecurityManager

- Java 17+ **deprecates the SecurityManager** (JEP 411). Do not rely
  on it.
- **Reflection** can bypass access modifiers — avoid in user-facing
  code; validate class names against an allowlist.
- **`Unsafe` APIs** — internal, prone to breakage, red flag in review.

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

- OWASP top 10: <https://owasp.org/www-project-top-ten/>
- OWASP Java cheat sheet: <https://cheatsheetseries.owasp.org/cheatsheets/Java_Security_Cheat_Sheet.html>
- OWASP Dependency Check: <https://owasp.org/www-project-dependency-check/>
- Tink: <https://developers.google.com/tink>
- Spring Security: <https://spring.io/projects/spring-security>
