# PostHog Feature Flags — Reference

PostHog is the canonical flag provider for Jylhis (Hard Rule #4).

## MCP tool quick-reference

The PostHog MCP (`feature-flag` domain) is available in Claude Code via the PostHog integration. Use `exec` with the domain set to `feature-flag`.

### Create a flag

```json
{
  "domain": "feature-flag",
  "action": "create",
  "payload": {
    "key": "my-feature-name",
    "name": "My Feature",
    "description": "Owner: eng-name. Cleanup: 2026-09-01. One-line rationale.",
    "active": true,
    "filters": {
      "groups": [{ "properties": [], "rollout_percentage": 0 }]
    }
  }
}
```

### Read flag state

```json
{
  "domain": "feature-flag",
  "action": "get",
  "payload": { "key": "my-feature-name" }
}
```

### Update rollout percentage

```json
{
  "domain": "feature-flag",
  "action": "update",
  "payload": {
    "key": "my-feature-name",
    "filters": {
      "groups": [{ "properties": [], "rollout_percentage": 10 }]
    }
  }
}
```

### Delete a flag (cleanup)

```json
{
  "domain": "feature-flag",
  "action": "delete",
  "payload": { "key": "my-feature-name" }
}
```

## Rollout sequence

Typical rollout after the feature is verified:

| Step | Rollout % | When |
|---|---|---|
| Internal (Jylhis team) | 100% internal users | Day 1 after merge |
| Canary | 10% all users | After 1–2 days with no incidents |
| Full | 100% all users | After canary is stable |
| Cleanup | Delete flag | Within cleanup date |

Use PostHog person properties or cohorts to target internal users. Add a `is_internal` property on your Jylhis employees in PostHog to enable selective rollout.

## Naming conventions

| Convention | Example |
|---|---|
| kebab-case | `new-checkout-flow` |
| Verb-noun for features | `enable-dark-mode` |
| Short and descriptive | `rag-citations-v2` (not `new-rag-feature-experiment-final`) |

## PostHog SDK setup

### Python

Install via Nix (Hard Rule #2). In `devenv.nix` or `flake.nix`:

```nix
packages = [ pkgs.python3Packages.posthog ];
```

```python
import posthog
posthog.project_api_key = os.environ["POSTHOG_API_KEY"]
posthog.host = "https://eu.posthog.com"
```

### TypeScript / Node

Install via Nix:

```nix
packages = [ pkgs.nodePackages.posthog-node ];
```

```typescript
import { PostHog } from "posthog-node";
const client = new PostHog(process.env.POSTHOG_API_KEY!, {
  host: "https://eu.posthog.com",
});
// Call client.shutdown() on process exit to flush pending events
```

## Evaluating flags server-side vs. client-side

| Context | Method | Notes |
|---|---|---|
| Backend (per-request) | `posthog.feature_enabled(key, distinct_id)` | Hits PostHog API; cache locally if latency matters |
| Backend (local eval) | `posthog.get_all_flags(distinct_id)` after local evaluation setup | Requires `personal_api_key` for local eval |
| Frontend (browser) | PostHog JS SDK `posthog.isFeatureEnabled(key)` | Loaded from bootstrap or network |

Prefer **server-side evaluation** for Jylhis to avoid exposing flag logic to clients.
