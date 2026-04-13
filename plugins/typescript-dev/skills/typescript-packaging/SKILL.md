---
name: typescript-packaging
description: >
  Package management with pnpm + workspaces, publishing TypeScript
  libraries with tsup, building apps with Vite. Apply when setting up a
  new repo, converting a monorepo, or publishing to npm.
---

# TypeScript packaging: pnpm, tsup, Vite

## Single package setup

```bash
pnpm init
pnpm add -D typescript @types/node
pnpm tsc --init
```

`package.json` essentials:

```json
{
  "name": "@me/thing",
  "version": "0.1.0",
  "type": "module",
  "main": "./dist/index.js",
  "types": "./dist/index.d.ts",
  "exports": {
    ".": {
      "import": "./dist/index.js",
      "types": "./dist/index.d.ts"
    }
  },
  "files": ["dist"],
  "engines": { "node": ">=22" }
}
```

Always set `"type": "module"`, `"engines.node"`, and restrict `"files"`
to what you publish.

## Workspaces (monorepo)

```yaml
# pnpm-workspace.yaml
packages:
  - apps/*
  - packages/*
```

```bash
pnpm add lodash --filter @me/web         # add dep to one package
pnpm --filter @me/web run build          # run script in one package
pnpm -r run build                        # run in all packages
pnpm -r --workspace-concurrency=1 run build    # serialize
```

Use `workspace:*` for internal package references:

```json
{
  "dependencies": {
    "@me/shared": "workspace:*"
  }
}
```

## Building libraries with tsup

```bash
pnpm add -D tsup
```

```ts
// tsup.config.ts
import { defineConfig } from 'tsup';

export default defineConfig({
  entry: ['src/index.ts'],
  format: ['esm', 'cjs'],
  dts: true,
  sourcemap: true,
  clean: true,
  target: 'node22',
});
```

```json
{
  "scripts": {
    "build": "tsup",
    "dev": "tsup --watch"
  }
}
```

## Building apps with Vite

```bash
pnpm create vite my-app --template react-ts
```

## Publishing

```bash
pnpm build
pnpm publish --access public
```

Use `changesets` for version management in monorepos:

```bash
pnpm add -D @changesets/cli
pnpm changeset init
pnpm changeset         # record a change
pnpm changeset version # bump versions
pnpm changeset publish
```

## Lockfile discipline

- Commit `pnpm-lock.yaml`.
- Never edit it manually.
- In CI use `pnpm install --frozen-lockfile`.

## Anti-patterns

- Mixing `npm install` and `pnpm install` in the same repo.
- Publishing without a `"files"` field.
- Shipping ESM-only without setting `"type": "module"`.
- Using `peerDependencies` without `peerDependenciesMeta.optional: true`
  on optional peers.
- Forgetting to add internal workspace packages to the consuming
  package's `dependencies`.

## Tool detection

```bash
for tool in node pnpm tsc tsup; do
  command -v "$tool" >/dev/null && echo "ok: $tool" || echo "MISSING: $tool"
done
```

## References

- pnpm docs: https://pnpm.io
- Workspaces: https://pnpm.io/workspaces
- tsup: https://tsup.egoist.dev
- Vite: https://vitejs.dev
- changesets: https://github.com/changesets/changesets
