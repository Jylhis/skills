---
name: security
description: Use for code security review and safe alternatives across language ecosystems — Python (subprocess command injection, pickle / yaml.load deserialization, SSRF, SQL injection, path traversal, secrets, bcrypt/argon2, cryptography, TLS verify); TypeScript / Node (child_process exec/shell, prototype pollution, XSS via DOMPurify, SSRF, secrets handling, Zod validation, npm audit, Helmet, CSP); JVM (JNDI / Log4Shell, Java serialization, XXE, SSRF, SQL injection, secrets, crypto APIs). Read the matching reference before reviewing untrusted-input handlers.
---

# Security skill index

Pick the topic and read its reference before auditing or writing any
code that handles untrusted input or external services.

| Stack | When to read | Reference |
|---|---|---|
| Python | subprocess command injection, pickle / yaml.load, SSRF, SQL injection, path traversal, secrets, bcrypt / argon2, cryptography, TLS verify | `references/python.md` |
| TypeScript / Node | child_process exec, prototype pollution, XSS, SSRF, secrets, Zod validation, npm audit, Helmet, CSP / HSTS | `references/typescript.md` |
| JVM (Java / Kotlin) | JNDI / Log4Shell-class, Java serialization, XXE, SSRF, SQL injection, secrets, crypto APIs | `references/jvm.md` |

Cross-cutting references (not language-specific):

| Topic | When to read | Reference |
|---|---|---|
| Best practices | general secure-coding checklist applicable across stacks | `references/best-practices.md` |
| Threat modeling | enumerating assets, trust boundaries, attacker capabilities before a review or design | `references/threat-model.md` |
| Ownership map | who owns which security-sensitive area; routing findings and escalations | `references/ownership-map.md` |
| Static analysis (CodeQL) | running CodeQL: database build, data extensions, suite selection, result triage | `references/static-analysis-codeql.md` |

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
