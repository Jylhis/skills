---
name: grafana
description: "Grafana observability umbrella — routes to the right Grafana sub-skill for the task. Use when the user mentions Grafana generally or asks about observability, dashboards, alerting, or monitoring without naming a specific sub-area, or when you need to figure out which Grafana skill applies. Covers: alerting and IRM (alert rules, contact points, notification policies, on-call, SLOs), dashboard authoring (panel types, JSON, variables, transformations, API push), OpenTelemetry instrumentation (SDK, OTLP, Alloy, sampling), Grafana OSS (provisioning, data sources, grafana.ini, roles), and PromQL (rate, aggregation, histogram_quantile, recording rules, cardinality). Read the routing table below, then load the specific sub-skill."
---

# Grafana skill index

This is a router. Pick the sub-skill that matches the task and read its
`SKILL.md` before acting. Each sub-skill is the focused, opinionated
guidance for that Grafana area.

| Sub-skill | When to use | Path |
|---|---|---|
| Grafana alerting | Alert rules, contact points (Slack/PagerDuty/email), notification policies, silences, on-call schedules, SLOs, incident management | `grafana-alerting/SKILL.md` |
| Grafana dashboarding | Build/modify dashboards as JSON via HTTP API; panel types, gridPos layout, variables, transformations, annotations | `grafana-dashboarding/SKILL.md` |
| Grafana OpenTelemetry | Instrument apps with OTel; ship metrics/logs/traces to Grafana Cloud or self-hosted Mimir/Loki/Tempo; Beyla eBPF; sampling | `grafana-opentelemetry/SKILL.md` |
| Grafana OSS | Provisioning from YAML, data sources, grafana.ini config, roles, service-account tokens, plugins, local Grafana | `grafana-oss/SKILL.md` |
| Grafana PromQL | Write, validate, optimize PromQL queries; rate vs irate, aggregation, histogram_quantile, recording rules, cardinality hunting | `grafana-promql/SKILL.md` |

## Common rules across all Grafana sub-skills

- Confirm the Grafana stack is reachable before any API call. Use the
  health-check endpoint (`GET /api/health`) to verify connectivity.
- After every dashboard API push, verify with the returned `version`
  plus a GET on the dashboard UID.
- For PromQL queries, the golden rule: `rate()` / `increase()` require
  a range vector >= 4x the scrape interval.

After reading the sub-skill, follow its guidance for the task.
