---
name: hermes-tweet
description: Use when installing, validating, or operating Hermes Tweet, the native Hermes Agent X/Twitter plugin for read, explore, and explicitly gated action workflows with XQUIK_API_KEY.
license: MIT
---

# Hermes Tweet

Hermes Tweet is a native Hermes Agent plugin for X/Twitter automation. Use it
when a task calls for Hermes-native social search, account reads, trend checks,
monitors, webhooks, media workflows, or explicitly enabled tweet actions.

Primary references:

- Repository: <https://github.com/Xquik-dev/hermes-tweet>
- Package: <https://pypi.org/project/hermes-tweet/>
- Hermes Agent: <https://github.com/NousResearch/hermes-agent>

## Fit Check

Use Hermes Tweet when all of these are true:

1. The user wants X/Twitter capability from a Hermes Agent session.
2. The work benefits from a maintained plugin rather than ad-hoc scraping.
3. The environment can provide `XQUIK_API_KEY` for network-backed reads.
4. Any write action is explicitly requested and allowed by the operator.

Do not use it as a generic Claude Code, Pi, or claude.ai skill runtime. This
skill only helps agents install, validate, and use the Hermes Agent plugin.

## Install

Preferred Hermes install:

```bash
hermes plugins install Xquik-dev/hermes-tweet --enable
```

If the plugin is installed into the Hermes Python environment from PyPI:

```bash
uv pip install --python ~/.hermes/hermes-agent/venv/bin/python hermes-tweet
hermes plugins enable hermes-tweet
```

Hermes prompts for `XQUIK_API_KEY` during an interactive install. For
non-interactive installs, set `XQUIK_API_KEY` in the environment or
`~/.hermes/.env` before calling network-backed read workflows.

## Safety Model

- `tweet_explore` should remain available without network access.
- Read workflows require `XQUIK_API_KEY`.
- Action workflows require both `XQUIK_API_KEY` and
  `HERMES_TWEET_ENABLE_ACTIONS=true`.
- Never enable action workflows only to satisfy discovery or smoke tests.
- Treat secrets in logs, chat, issue text, or copied terminal output as
  compromised and ask the operator to rotate them.

## Validation

After install or upgrade:

1. Run `hermes plugins list` and confirm `hermes-tweet` is enabled.
2. Confirm `tweet_explore` is visible before depending on network access.
3. Confirm read workflows only after `XQUIK_API_KEY` is configured.
4. Keep action workflows disabled unless the user explicitly needs writes.
5. When changing the plugin package, run the checks documented in the upstream
   Hermes Tweet README before publishing or recommending the change.
