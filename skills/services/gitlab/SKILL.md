---
name: gitlab
description: Use for GitLab work focused on push + merge-request creation — authoring `.gitlab-ci.yml` pipelines (templates, downstream pipelines, Docker builds, caching, runner config, artifacts vs cache, pipeline inputs, duplicate pipeline traps) and the `glab` CLI for creating MRs, syncing forks, and debugging your own CI failures. Read the matching reference before editing pipelines or running glab.
---

# GitLab skill index

Scope: pushing branches, creating merge requests, syncing forks, and
authoring CI/CD pipeline configuration. This skill does **not** cover
issue management, epics, work items, or inline review comments on
other contributors' MRs.

Pick the topic and read its reference first.

| Topic | When to read | Reference |
|---|---|---|
| CI/CD (.gitlab-ci.yml) | pipeline templates, components, downstream pipelines, Docker builds, caching, runner config, artifacts vs cache, pipeline inputs | `references/cicd.md` (+ `cicd/pipeline-templates.md`) |
| glab CLI | creating MRs, listing your own MRs, checking pipeline status, `glab ci` commands | `references/glab.md` |

Helper scripts under `scripts/` (Go, run with `go run`):

- `sync-fork/` — fetch upstream, fast-forward merge, push to origin.
  Run: `go run scripts/sync-fork/main.go [branch] [upstream-remote]`
  (defaults: `main`, `upstream`).
- `ci-debug/` — list failed jobs in a pipeline and tail their logs.
  Run: `go run scripts/ci-debug/main.go <pipeline-id>`.

After reading the reference, follow its guidance for the task.
