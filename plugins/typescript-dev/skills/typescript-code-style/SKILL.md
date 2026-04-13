---
name: typescript-code-style
description: >
  Idiomatic TypeScript style: naming, file layout, import order, no barrel
  exports, ESM-first, minimal globals. Apply when writing or reviewing
  TypeScript 5.9+ code on Node 22 LTS.
---

# TypeScript code style (5.9+)

## File & module layout

- **ESM only.** Use `"type": "module"` in `package.json`. Avoid CJS unless
  you are publishing a library that must support both — in that case use
  `tsup` with `format: ['esm', 'cjs']`.
- **One concept per file.** Keep files focused; avoid grab-bag
  `utils.ts` files. Name files after their default export when there
  is one, otherwise by feature.
- **No barrel files for apps.** `index.ts` re-export files create
  cyclic imports and defeat tree-shaking. Libraries may use a single
  top-level `index.ts` as the public entry point, but do not chain
  sub-barrels.
- **Extensions in imports.** Node ESM requires explicit `.js` extensions
  at runtime even though source is `.ts`. Configure `tsconfig.json`
  with `"moduleResolution": "bundler"` or `"nodenext"`.

## Naming

- `PascalCase` — types, interfaces, classes, React components, enums.
- `camelCase` — variables, functions, methods, properties.
- `UPPER_SNAKE_CASE` — module-level constants only (not config objects).
- No `I`-prefix on interfaces. No `T`-prefix on type aliases.
- Event handlers: `onFoo` for props, `handleFoo` for local implementations.
- Booleans: prefix with `is`, `has`, `should`, `can`.

## Imports

Order (enforce via `eslint-plugin-import` / `perfectionist`):

1. Node built-ins (`node:fs`, `node:path`)
2. Third-party packages
3. Internal absolute (`@/app/...`)
4. Relative (`../foo`, `./bar`)
5. Type-only imports at the end of each group

Use `import type { Foo } from './foo.js'` for types to keep them erased
at runtime. In TypeScript 5.0+ prefer `import { type Foo, bar }` for
mixed imports.

## Functions

- Prefer arrow functions for callbacks and module-scope utilities.
- Use `function` declarations when you need hoisting or clearer stack
  traces.
- Return types are optional for short functions but **required on
  exported functions**.
- Avoid default exports. Named exports make refactors and IDE tooling
  easier.

## Objects & collections

- Prefer `Record<K, V>` over `{ [key: string]: V }`.
- Use `ReadonlyArray<T>` / `readonly T[]` for function parameters you
  don't mutate.
- Use `satisfies` to validate a literal against a type without widening:
  ```ts
  const routes = {
    home: '/',
    about: '/about',
  } as const satisfies Record<string, string>;
  ```

## Nullability

- Enable `strict` and `noUncheckedIndexedAccess` in `tsconfig.json`.
- Prefer `undefined` over `null`. Use `null` only when interfacing with
  APIs (JSON, databases) that already use it.
- Use optional chaining (`?.`) and nullish coalescing (`??`) instead of
  manual guards.

## Anti-patterns

- `any` without a comment explaining why — use `unknown` instead.
- `as` casts that hide real type errors — prefer type narrowing.
- Complex conditional types solving problems a runtime check would
  solve better.
- `enum` — use `as const` objects and union types instead; `const enum`
  is incompatible with `isolatedModules`.
- Namespace (`namespace Foo {}`) — use ES modules.

## Tool detection

```bash
for tool in node pnpm tsc typescript-language-server eslint prettier; do
  command -v "$tool" >/dev/null && echo "ok: $tool" || echo "MISSING: $tool"
done
```

## References

- TypeScript handbook: https://www.typescriptlang.org/docs/handbook/intro.html
- tsconfig reference: https://www.typescriptlang.org/tsconfig
- typescript-eslint style guide: https://typescript-eslint.io/rules/
