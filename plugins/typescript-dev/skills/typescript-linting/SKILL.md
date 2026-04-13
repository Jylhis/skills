---
name: typescript-linting
description: >
  ESLint 9 flat config with typescript-eslint, shared config patterns,
  rule selection, ignoring generated code, lint scripts. Apply when
  setting up lint for a new project or tightening rules on an existing one.
---

# TypeScript linting with ESLint 9 (flat config)

ESLint 9 uses flat config (`eslint.config.js`) as the default. The legacy
`.eslintrc.*` format is deprecated.

## Install

```bash
pnpm add -D eslint typescript-eslint @eslint/js
```

For React projects add `eslint-plugin-react` and
`eslint-plugin-react-hooks`.

## Minimal flat config

```js
// eslint.config.js
import js from '@eslint/js';
import tseslint from 'typescript-eslint';

export default tseslint.config(
  js.configs.recommended,
  ...tseslint.configs.recommendedTypeChecked,
  {
    languageOptions: {
      parserOptions: {
        projectService: true,
        tsconfigRootDir: import.meta.dirname,
      },
    },
  },
  {
    ignores: ['dist/', 'coverage/', '**/*.generated.ts'],
  },
);
```

`projectService: true` (ESLint-TS 8.0+) auto-resolves the nearest
`tsconfig.json`.

## Rule selection

**Always enable:**
- `@typescript-eslint/no-floating-promises`
- `@typescript-eslint/no-misused-promises`
- `@typescript-eslint/await-thenable`
- `@typescript-eslint/no-unused-vars` (with `argsIgnorePattern: '^_'`)
- `@typescript-eslint/consistent-type-imports`
- `@typescript-eslint/no-explicit-any` (warn at minimum)

**Consider:**
- `@typescript-eslint/strict-boolean-expressions`
- `@typescript-eslint/prefer-nullish-coalescing`
- `@typescript-eslint/prefer-optional-chain`
- `@typescript-eslint/switch-exhaustiveness-check`

**Disable:**
- `no-unused-vars` (base rule — use the TS version).

## Per-file overrides

```js
{
  files: ['**/*.test.ts', '**/*.spec.ts'],
  rules: {
    '@typescript-eslint/no-explicit-any': 'off',
  },
},
```

## Scripts

```json
{
  "scripts": {
    "lint": "eslint .",
    "lint:fix": "eslint . --fix",
    "typecheck": "tsc --noEmit"
  }
}
```

Treat `tsc --noEmit` as a separate check from lint.

## CI integration

```bash
pnpm lint          # use --max-warnings=0 in CI
pnpm typecheck
pnpm test run
```

## Editor integration

- **VS Code:** ESLint extension auto-detects flat config.
- **Neovim:** `nvim-lspconfig` via `eslint-lsp` or
  `typescript-tools.nvim`.

## Anti-patterns

- Mixing flat config and legacy `.eslintrc.*`.
- Turning off rules instead of fixing violations.
- Extending community configs you don't understand and fighting the rules.
- Enabling Prettier stylistic rules in ESLint.

## Tool detection

```bash
for tool in node pnpm eslint tsc; do
  command -v "$tool" >/dev/null && echo "ok: $tool" || echo "MISSING: $tool"
done
```

## References

- ESLint flat config: https://eslint.org/docs/latest/use/configure/configuration-files
- typescript-eslint: https://typescript-eslint.io
- Shared configs: https://typescript-eslint.io/users/configs
