---
name: typescript-nodejs-patterns
description: >
  Node.js 22 LTS patterns in TypeScript: streams, `fs/promises`,
  `child_process`, `pino` logging, graceful shutdown, worker threads.
  Apply when writing server-side Node code or long-running services.
---

# Node.js patterns (Node 22 LTS)

Prefer native APIs and ESM-first idioms.

## Filesystem — `fs/promises`

Always use the promise API:

```ts
import { readFile, writeFile, mkdir, stat } from 'node:fs/promises';

const contents = await readFile('config.json', 'utf8');
await mkdir('./out', { recursive: true });
```

Use `node:` prefixes for all built-ins.

For streaming large files:

```ts
import { createReadStream } from 'node:fs';
for await (const chunk of createReadStream(path)) {
  // process chunk
}
```

## Streams

Node has three stream APIs — Web Streams, classic Node streams, and
async iterables. Prefer:

1. **Async iteration** (`for await ... of`) — simplest.
2. **Web Streams** — when interop with `fetch`, workers, or browser
   code matters.
3. **`node:stream/promises` `pipeline`** — for classic streams:
   ```ts
   import { pipeline } from 'node:stream/promises';
   import { createReadStream, createWriteStream } from 'node:fs';
   import { createGzip } from 'node:zlib';

   await pipeline(
     createReadStream('input.txt'),
     createGzip(),
     createWriteStream('input.txt.gz'),
   );
   ```

Never use `.pipe()` without error handling — `pipeline` handles cleanup
correctly.

## child_process

Prefer `spawn` (streaming) or `execFile` (captured stdout). Avoid
`exec` — it uses a shell string and is injection-prone.

```ts
import { spawn } from 'node:child_process';

const proc = spawn('git', ['status', '--porcelain'], { stdio: 'pipe' });
let stdout = '';
for await (const chunk of proc.stdout) stdout += chunk;
const code = await new Promise<number>((resolve) => proc.on('close', resolve));
```

For more ergonomic subprocess APIs use `execa`.

## Logging with pino

```ts
import pino from 'pino';

const log = pino({
  level: process.env.LOG_LEVEL ?? 'info',
  redact: ['req.headers.authorization', 'req.headers.cookie'],
});

log.info({ userId }, 'user logged in');
log.error({ err }, 'failed to load user');
```

- Pass structured context as the first argument.
- Use `pino-pretty` in dev only.
- Redact sensitive fields at the logger level.
- Use `log.child({ requestId })` for scoped loggers per request.

## Graceful shutdown

```ts
const server = app.listen(port);

async function shutdown(signal: string) {
  log.info({ signal }, 'shutting down');
  server.close();
  await db.end();
  await cache.quit();
  process.exit(0);
}

process.on('SIGTERM', () => shutdown('SIGTERM'));
process.on('SIGINT',  () => shutdown('SIGINT'));
```

Set a hard timeout (e.g. 30s) and `process.exit(1)` if shutdown stalls.

## Worker threads

For CPU-bound work (parsing, hashing, crypto):

```ts
import { Worker } from 'node:worker_threads';

const worker = new Worker('./cpuTask.js', { workerData: input });
worker.on('message', (result) => { /* ... */ });
```

Transfer large data with `SharedArrayBuffer` or `MessageChannel` to
avoid copy overhead. Worker threads are for CPU work, not request
fan-out.

## Environment variables

- Use `process.env.FOO` directly for simple cases.
- For larger apps, validate with Zod at startup:
  ```ts
  const env = EnvSchema.parse(process.env);
  ```
- Use `node --env-file=.env` (Node 20.6+) instead of `dotenv`.

## Top-level await

Node 14+ supports top-level `await` in ESM:

```ts
// main.ts
import { loadConfig } from './config.js';
const config = await loadConfig();
startServer(config);
```

## Anti-patterns

- Callback-style `fs` in new code — use `fs/promises`.
- `util.promisify` when the promise API already exists.
- Custom HTTP servers with `http.createServer` for non-trivial apps —
  use Fastify or Hono.
- Forgetting to `unref()` timers in CLI tools.
- `require()` inside ESM files (use dynamic `import()`).

## Tool detection

```bash
for tool in node pnpm; do
  command -v "$tool" >/dev/null && echo "ok: $tool" || echo "MISSING: $tool"
done
```

## References

- Node.js API docs: https://nodejs.org/docs/latest-v22.x/api/
- `node:stream/promises`: https://nodejs.org/api/stream.html#streams-promises-api
- pino: https://getpino.io
- execa: https://github.com/sindresorhus/execa
