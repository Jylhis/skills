---
name: typescript-security
description: >
  Security patterns for TypeScript / Node.js: injection, XSS, SSRF,
  secrets, dep audit, SSR hydration risks, prototype pollution. Apply
  when reviewing or writing any code that handles untrusted input or
  external services.
---

# TypeScript / Node.js security

## Injection

**SQL injection.** Never build SQL with string concatenation. Use
parameter binding:

```ts
// WRONG
await db.query(`SELECT * FROM users WHERE id = '${id}'`);

// RIGHT
await db.query('SELECT * FROM users WHERE id = $1', [id]);
```

For ORMs (Drizzle, Prisma, Kysely), audit any code that calls `raw()`
or `$queryRaw`.

**Shell injection.** Use `spawn` or `execFile` with an argv array, not
`exec`:

```ts
// WRONG
exec(`git log --author=${author}`);

// RIGHT
spawn('git', ['log', `--author=${author}`]);
```

## XSS

- Never render user input as HTML without escaping.
- **React** escapes children automatically. `dangerouslySetInnerHTML` is
  the only footgun — sanitize with `DOMPurify`.
- **URL attributes** (`href`, `src`) need scheme checks. Reject
  `javascript:` URIs:
  ```ts
  if (/^\s*javascript:/i.test(url)) throw new Error('bad scheme');
  ```

## SSRF

Server-side code that fetches URLs from user input must:

1. Parse with `new URL(input)` and inspect `hostname`.
2. Reject private IP ranges (10/8, 172.16/12, 192.168/16, 127/8,
   169.254/16, ::1, fc00::/7).
3. Resolve hostname to IP once, check it, then fetch — prevents DNS
   rebinding.

Use `ssrf-req-filter` or `ipaddr.js` rather than writing this by hand.

## Secrets

- Never commit secrets. Use `.env` in dev, a secrets manager in prod.
- Never log secrets. Use logger serializers that strip `authorization`,
  `cookie`, `set-cookie`.
- Rotate immediately on suspected leak.

`git-secrets`, `gitleaks`, or `trufflehog` in pre-commit hooks catches
accidental commits.

## Dependency audit

```bash
pnpm audit --prod              # known CVEs
pnpm outdated                  # stale deps
pnpm dedupe                    # collapse duplicates
```

## Prototype pollution

`Object.assign({}, userInput)` and `lodash.merge` can walk prototype
chains if `__proto__` is set. Use:

```ts
const safe = structuredClone(userInput);
// or
Object.assign(Object.create(null), userInput);
```

Validate with Zod before merging — it strips unknown keys by default.

## Cookies and sessions

- Set `httpOnly: true`, `secure: true`, `sameSite: 'lax'` (or `strict`).
- Short `maxAge`, refresh on activity.
- Store session IDs (not user data) in cookies.

## SSR hydration risks (React / Next.js)

- Do not render server-only secrets in the HTML payload.
- Sanitize any HTML in `dangerouslySetInnerHTML` on the server.

## CORS and CSRF

- CORS is not a security feature — it's a browser same-origin escape
  hatch.
- For cookie-auth APIs, use CSRF tokens or `sameSite=strict`.
- For token-auth APIs, use `Authorization` headers, not cookies.

## JWT pitfalls

- Verify the `alg` header — reject `alg: none` and algorithm confusion.
- Use a library with safe defaults (`jose`, `@auth/core`).
- Short expiry + refresh tokens beats long-lived access tokens.

## Tool detection

```bash
for tool in node pnpm; do
  command -v "$tool" >/dev/null && echo "ok: $tool" || echo "MISSING: $tool"
done
```

## References

- OWASP Top 10: https://owasp.org/www-project-top-ten/
- Node.js security best practices: https://nodejs.org/en/learn/getting-started/security-best-practices
- `jose` JWT library: https://github.com/panva/jose
- `DOMPurify`: https://github.com/cure53/DOMPurify
