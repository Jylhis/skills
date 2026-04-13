---
name: typescript-formatting
description: >
  Prettier configuration for TypeScript / JavaScript projects:
  `.prettierrc`, `.prettierignore`, integration with ESLint, pre-commit
  hooks. Apply when adding or updating formatter config.
---

# TypeScript formatting with Prettier

**Do not mix Prettier with ESLint stylistic rules.** Prettier handles
whitespace, line breaks, and wrapping; ESLint handles logic and code
quality.

## Install

```bash
pnpm add -D prettier
```

## Minimal config

Create `.prettierrc.json`:

```json
{
  "printWidth": 100,
  "singleQuote": true,
  "trailingComma": "all",
  "arrowParens": "always",
  "semi": true
}
```

## `.prettierignore`

```
dist/
coverage/
node_modules/
pnpm-lock.yaml
*.generated.ts
```

## Scripts

```json
{
  "scripts": {
    "format": "prettier --write .",
    "format:check": "prettier --check ."
  }
}
```

Run `format:check` in CI.

## Integration with ESLint

Prettier runs as a separate step. If you must disable stylistic ESLint
rules that conflict, add `eslint-config-prettier` as the **last** entry
in your flat config:

```js
import prettier from 'eslint-config-prettier';

export default tseslint.config(
  // ... other configs
  prettier,
);
```

## Editor integration

- **VS Code:** Prettier extension, set as default formatter, enable
  format on save.
- **Neovim:** `conform.nvim` with `prettier` formatter.
- **Pre-commit:** `lefthook` or `husky` + `lint-staged`.

## lint-staged config

```json
{
  "lint-staged": {
    "*.{ts,tsx,js,jsx,json,md}": "prettier --write"
  }
}
```

## Anti-patterns

- Checking in `.editorconfig` values that conflict with `.prettierrc`.
- Enabling Prettier rules inside ESLint (`plugin:prettier/recommended`).
- Running Prettier on generated files or lockfiles.
- Multiple Prettier invocation points (hook + format-on-save + CI) with
  different config — pick one source of truth.

## Tool detection

```bash
for tool in node pnpm prettier; do
  command -v "$tool" >/dev/null && echo "ok: $tool" || echo "MISSING: $tool"
done
```

## References

- Prettier docs: https://prettier.io/docs/en/
- Options: https://prettier.io/docs/en/options
- Ignoring code: https://prettier.io/docs/en/ignore
- Biome (alternative): https://biomejs.dev
