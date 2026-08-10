---
name: security
description: Use for code security review and safe alternatives across language ecosystems — Python (subprocess command injection, pickle / yaml.load deserialization, SSRF, SQL injection, path traversal, secrets, bcrypt/argon2, cryptography, TLS verify); TypeScript / Node (child_process exec/shell, prototype pollution, XSS via DOMPurify, SSRF, secrets handling, Zod validation, npm audit, Helmet, CSP); JVM (JNDI / Log4Shell, Java serialization, XXE, SSRF, SQL injection, secrets, crypto APIs). Also covers framework-specific secure-by-default guidance (Django, FastAPI, Flask, Express, React, Next.js, Vue, Go), repository threat modeling, security ownership mapping, and CodeQL static analysis. Read the matching reference before reviewing untrusted-input handlers.
---

# Security skill index

Pick the topic and read its reference before auditing or writing any
code that handles untrusted input or external services.

| Stack | When to read | Reference |
|---|---|---|
| Python | subprocess command injection, pickle / yaml.load, SSRF, SQL injection, path traversal, secrets, bcrypt / argon2, cryptography, TLS verify | `references/python.md` |
| TypeScript / Node | child_process exec, prototype pollution, XSS, SSRF, secrets, Zod validation, npm audit, Helmet, CSP / HSTS | `references/typescript.md` |
| JVM (Java / Kotlin) | JNDI / Log4Shell-class, Java serialization, XXE, SSRF, SQL injection, secrets, crypto APIs | `references/jvm.md` |
| Best practices by framework | writing secure-by-default code or producing a prioritized vulnerability report; per-framework guidance under `references/best-practices/` (Django, FastAPI, Flask, Express, React, Next.js, Vue, jQuery, Go backend) | `references/best-practices.md` |
| Threat modeling | building an evidence-anchored AppSec threat model of a repo: trust boundaries, assets, entry points, abuse cases, prioritized risks | `references/threat-model.md` |
| Ownership map | mapping which team / owner is responsible for each security-relevant component | `references/ownership-map.md` |
| Static analysis (CodeQL) | running or authoring CodeQL queries for Python, JS/TS, Go, Java/Kotlin, C/C++, C#, Ruby, Swift | `references/static-analysis-codeql.md` |

Common rules across all stacks:

- Validate untrusted input at system boundaries (HTTP handlers,
  message queues, file uploads, env-var parsers).
- Never pass untrusted strings to a shell — use argv-array forms
  (`subprocess.run([...])`, `child_process.execFile(...)`).
- Block private / metadata IP ranges (e.g. `169.254.169.254`) on any
  outbound HTTP that takes a user-supplied URL.
- Treat secrets as inputs from a secret manager; never commit `.env`
  or hard-code credentials.

After reading the reference, follow its guidance for the task.
