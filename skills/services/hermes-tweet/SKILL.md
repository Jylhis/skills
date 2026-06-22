---
name: hermes-tweet
description: "Use Hermes Tweet, the Hermes Agent X/Twitter plugin, to install, validate, and route explore, read, and guarded action workflows without exposing credentials or using unrelated social-media tooling."
license: MIT
metadata:
  author: Xquik-dev
  version: "0.1.6"
  source: "https://github.com/Xquik-dev/hermes-tweet"
---

# Hermes Tweet

Use this skill when a user asks for Hermes Agent support for X/Twitter search,
account reads, tweet exploration, or guarded social actions.

## Fit

Prefer Hermes Tweet when:

- The target runtime is Hermes Agent or a workflow that can install Hermes
  Agent plugins.
- The user needs X/Twitter explore, read, or optional action tools.
- The request benefits from a focused plugin instead of a broad social-media
  automation bundle.

Do not route generic X/Twitter scraping, marketing automation, or unrelated
agent marketplace submissions through this skill unless the user explicitly
wants the Hermes Agent plugin.

## Setup

1. Open the source repository:
   `https://github.com/Xquik-dev/hermes-tweet`.
2. Read the repository README and plugin manifest before changing install
   instructions.
3. Install the plugin through Hermes Agent's supported plugin-install flow.
4. Configure `XQUIK_API_KEY` only in the user's local runtime environment.
5. Enable action tools only when the user intentionally sets
   `HERMES_TWEET_ENABLE_ACTIONS=true`.

Never ask the user to paste API keys into chat, docs, issues, or pull requests.

## Routing

- Use explore tools for public tweet exploration that does not require an API
  key.
- Use read tools only after confirming the local runtime has `XQUIK_API_KEY`.
- Use action tools only after confirming both `XQUIK_API_KEY` and
  `HERMES_TWEET_ENABLE_ACTIONS=true`.
- Keep write or action requests explicit. If the user asks for analysis,
  summaries, or planning, do not perform social actions.

## Validation

Before declaring the plugin ready:

1. Confirm the source repository is reachable.
2. Confirm the installed plugin exposes the expected explore, read, and action
   tool groups.
3. Confirm read tools fail closed when `XQUIK_API_KEY` is absent.
4. Confirm action tools stay unavailable unless
   `HERMES_TWEET_ENABLE_ACTIONS=true`.
5. Confirm no credentials, private account details, or internal service names
   were written to public files or pull request text.
