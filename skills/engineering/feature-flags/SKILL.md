---
name: feature-flags
description: Feature flags that decouple deploy from release — PostHog as canonical provider, required metadata, wiring patterns in Python/TypeScript, kill-switch path, and cleanup checklist. Use when shipping risky, partial, or user-facing changes; when creating or cleaning up a PostHog flag; or when reviewing code that needs a flag.
metadata:
  jylhis-hard-rule: "4"
  jylhis-ratified: "JYL-140"
  authored: "2026-06-03"
---

# Feature Flags

Hard Rule #4 at Jylhis. PostHog is the **only** canonical flag provider *for the Jylhis team and marketplace standard*. That is a team default, not an assumption about every consumer's stack. The discipline in this skill (required metadata, default-OFF, kill-switch path, cleanup checklist) is provider-agnostic; if your org standardizes on a different flag system, keep the discipline and treat the PostHog steps below as the worked example to translate. See [references/posthog.md](references/posthog.md) for PostHog-specific mechanics.

## When a flag is required

A flag is required when the change is any of:

- **Risky** — could regress existing behavior for all users.
- **Partial** — the feature is incomplete but safe to merge.
- **User-facing** — the user sees a new UI, new copy, or changed behavior.
- **Not safe for everyone** — only some users or environments should see it.

If none of the above apply, no flag is needed.

## Required flag metadata

Every flag **must** have all four fields set before the PR merges:

| Field | Requirement |
|---|---|
| **Default state** | OFF (never default ON) |
| **Owner** | Named engineer or team responsible for cleanup |
| **Rollout plan** | How/when it will be enabled (e.g., "internal team first, then 10% → 100%") |
| **Cleanup date** | The date by which the flag must be removed or re-justified on a ticket |

Flags past their cleanup date are tech debt. Remove them or open a ticket to re-justify.

## Creating a flag in PostHog

Use the PostHog MCP tool (`feature-flag` domain) to create the flag programmatically:

```
Domain: feature-flag
Action: create
Payload:
  key: my-feature-name        # kebab-case, descriptive
  name: "My Feature"
  description: "Owner: <name>. Cleanup: <YYYY-MM-DD>. <One-line rationale>"
  active: true                # flag infrastructure active; value still OFF by default
  filters:
    groups:
      - properties: []
        rollout_percentage: 0   # starts at 0% = OFF
```

Reference the flag key and cleanup date in the PR description.

## Wiring a flag into code

### Language-agnostic pattern

```
if feature_enabled("my-feature-name", user_context):
    # new behavior
else:
    # existing behavior (preserved, not deleted until flag removed)
```

Never delete the old code path until the flag is removed. The old path is your kill-switch.

### Python (PostHog SDK)

```python
import posthog

# Initialize once (e.g., in app startup)
posthog.project_api_key = "phc_..."
posthog.host = "https://eu.posthog.com"

def is_enabled(flag_key: str, distinct_id: str) -> bool:
    return posthog.feature_enabled(flag_key, distinct_id) or False

# Usage
if is_enabled("my-feature-name", user.id):
    return new_behavior()
return existing_behavior()
```

### TypeScript / Node (PostHog SDK)

```typescript
import { PostHog } from "posthog-node";

const client = new PostHog("phc_...", { host: "https://eu.posthog.com" });

async function isEnabled(flagKey: string, distinctId: string): Promise<boolean> {
  return (await client.isFeatureEnabled(flagKey, distinctId)) ?? false;
}

// Usage
if (await isEnabled("my-feature-name", user.id)) {
  return newBehavior();
}
return existingBehavior();
```

## Kill-switch path

If the new behavior is causing incidents:

1. Go to PostHog → Flags → `my-feature-name` → set rollout to **0%**.
2. The old code path is immediately active for all users (no deploy needed).
3. Open a ticket to diagnose, fix, and re-enable or remove the flag.

This only works if the old code path was preserved. Do not delete `else` branches until the flag is cleaned up.

## Long-lived dark code

"Long-lived dark code" is production code that is never executed in any environment because its flag is permanently OFF and has no cleanup plan. It is a liability:

- It rots (references to deleted APIs, changed types).
- It makes code review harder.
- It implies technical debt with no owner.

**Rule:** if a flag is older than its cleanup date with no re-justification ticket, remove the flag and the old code path in the same PR. Do not leave dark code indefinitely.

## Cleanup checklist

When a flag has been fully rolled out (100%) and stable:

- [ ] Remove the `if/else` branch — keep only the new code path
- [ ] Delete the flag from PostHog
- [ ] Remove the flag key from all environment configs
- [ ] Update or close the original ticket that created the flag
- [ ] PR description references the flag key and confirms it is deleted
