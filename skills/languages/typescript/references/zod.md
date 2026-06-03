# Zod runtime validation

Zod (`zod`) validates untrusted data at runtime and infers a static
TypeScript type from the same schema, so the type and the validator
never drift. Use it at **trust boundaries** — HTTP request bodies,
environment variables, config files, `JSON.parse` of untrusted strings,
CLI arguments, message-queue payloads. Do **not** wrap already-typed
internal data in schemas; that adds runtime cost for no safety gain.

## Schemas and inferred types

Define the schema once, derive the type from it:

```ts
import { z } from 'zod';

export const UserSchema = z.object({
  id: z.string().uuid(),
  email: z.string().email(),
  age: z.number().int().nonnegative(),
});

export type User = z.infer<typeof UserSchema>;
```

Never hand-write a parallel `interface User` — the two will drift. If
external consumers need the type without `zod` as a dependency, export
the inferred type from a separate barrel.

## parse vs safeParse

`parse` throws `z.ZodError` on failure; `safeParse` returns a tagged
union. Prefer `safeParse` at boundaries — see the existing patterns in
[`error-handling.md`](./error-handling.md) §"Zod validation errors".

```ts
const result = UserSchema.safeParse(input);
if (!result.success) return badRequest(result.error.issues);
const user = result.data;
```

Reach for `parse` only when a failure should crash startup (env / config
parsing in `index.ts`) — there an uncaught throw is the desired
behaviour.

## Primitive validators

```ts
z.string().min(1).max(255).email();
z.string().regex(/^[a-z][a-z0-9-]+$/);
z.string().url();
z.string().uuid();
z.number().int().gt(0).lte(100);
z.number().positive().finite();
z.date();
z.literal('admin');
z.enum(['draft', 'published', 'archived']);
z.boolean();
z.unknown();   // accept anything; narrow later with refine
```

`z.any()` and `z.unknown()` disable validation for that field — use them
sparingly, and only when downstream code narrows the value.

## Field modifiers

The four modifiers produce different inferred types — pick the one that
matches the JSON wire format:

| Modifier        | Accepts        | Inferred type             |
|-----------------|----------------|---------------------------|
| `.optional()`   | value or `undefined` | `T \| undefined`     |
| `.nullable()`   | value or `null`     | `T \| null`           |
| `.nullish()`    | value, `null`, `undefined` | `T \| null \| undefined` |
| `.default(v)`   | value or absent     | `T` (default applied) |

```ts
z.object({
  name: z.string(),
  bio: z.string().optional(),         // may be missing
  deletedAt: z.date().nullable(),     // explicit null when active
  pageSize: z.number().int().default(20),
});
```

## Object operations

```ts
const Base = z.object({ id: z.string(), name: z.string(), age: z.number() });

Base.partial();                       // all fields optional
Base.deepPartial();                   // recursive partial (nested objects)
Base.pick({ id: true, name: true });  // narrow to subset
Base.omit({ age: true });             // drop fields
Base.extend({ email: z.string().email() });
Base.merge(OtherSchema);              // combine two object schemas
```

Unknown-key handling — pick deliberately per boundary:

- **Default**: strips unknown keys silently. Safe for most HTTP input.
- `.strict()`: rejects unknown keys. Use for config files where typos
  must surface.
- `.passthrough()`: keeps unknown keys on the parsed value. Avoid; it
  defeats the schema's role as an allow-list.

## Collections

```ts
z.array(z.string()).min(1).max(100);
z.array(z.number()).nonempty();              // inferred as [T, ...T[]]
z.tuple([z.string(), z.number()]);           // fixed shape
z.tuple([z.string()]).rest(z.number());      // variadic tail
z.record(z.string(), z.number());            // { [k: string]: number }
z.map(z.string(), UserSchema);
z.set(z.string());
```

## Unions and discriminated unions

`z.union([...])` tries each option and reports issues from all of them
on failure — slow and the error paths are noisy. When the variants
share a literal tag field, prefer `z.discriminatedUnion`:

```ts
const Event = z.discriminatedUnion('kind', [
  z.object({ kind: z.literal('click'), x: z.number(), y: z.number() }),
  z.object({ kind: z.literal('keydown'), key: z.string() }),
]);
```

The parser jumps straight to the matching branch and errors point at
the right shape.

## Refinements and transforms

`.refine()` adds a predicate; `.superRefine()` can attach multiple
issues at once; `.transform()` reshapes the value after validation.
They run in chain order, so put narrowing checks before transforms.

```ts
const Password = z
  .string()
  .min(8)
  .refine(v => /[A-Z]/.test(v), { message: 'needs uppercase' })
  .refine(v => /\d/.test(v),   { message: 'needs digit' });

const SignUp = z.object({
  password: Password,
  confirm: z.string(),
}).superRefine((val, ctx) => {
  if (val.password !== val.confirm) {
    ctx.addIssue({ code: 'custom', path: ['confirm'], message: 'mismatch' });
  }
});

const Slug = z.string().trim().toLowerCase().transform(s => s.replace(/\s+/g, '-'));
```

## Coercion

`z.coerce.*` wraps the value in the constructor before validating
(`Number(x)`, `new Date(x)`, etc). Acceptable for sources that are
inherently stringly typed — env vars, query strings, CLI flags.
Use explicit string parsing for booleans: `z.coerce.boolean()` follows
JavaScript truthiness (`"false"`, `"0"`, `"no"` become `true`).
Do **not** use coercion on JSON request bodies: `JSON.parse` already
gave you the right types, and silent coercion (`"7" → 7`,
`"true" → true`) hides client bugs.

```ts
const Env = z.object({
  PORT: z.coerce.number().int().positive(),
  DEBUG: z
    .enum(['true', 'false'])
    .default('false')
    .transform(v => v === 'true'),
  RELEASED_AT: z.coerce.date(),
});
```

## Anti-patterns

- Hand-writing `interface User` next to `UserSchema` — derive with
  `z.infer<typeof UserSchema>`.
- Calling `.parse()` in hot paths and catching the throw to branch —
  use `.safeParse()` and check `result.success`.
- Wrapping internal, already-typed data in a schema "for safety" — it
  costs CPU and adds no signal.
- `.passthrough()` on user input — re-exposes the prototype-pollution
  / mass-assignment surface the schema was meant to close.
- Swallowing `result.error.issues` into a generic `400 Bad Request` —
  return field paths (`issue.path`) so clients can map errors to UI
  fields. `zod-validation-error` formats them readably.
- Using `z.any()` to silence a TypeScript error — narrow the source
  type instead, or use `z.unknown()` and refine.

## Tool detection

```bash
for tool in node pnpm tsc; do
  command -v "$tool" >/dev/null && echo "ok: $tool" || echo "MISSING: $tool"
done
test -f package.json && grep -q '"zod"' package.json && echo "ok: zod" || echo "MISSING: zod"
```

## References

- Zod docs: <https://zod.dev>
- Error formatting: <https://github.com/causaly/zod-validation-error>
- Discriminated unions: <https://zod.dev/?id=discriminated-unions>
- Local: [`error-handling.md`](./error-handling.md) for `ZodError`
  catch patterns; [`type-system.md`](./type-system.md) for the
  discriminated-union TS idiom Zod mirrors.
