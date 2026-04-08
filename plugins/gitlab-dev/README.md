# gitlab-dev

GitLab development intelligence for jstack: 2 skills covering glab CLI
workflows and CI/CD pipeline configuration.

## Contents

- `.claude-plugin/plugin.json` -- plugin manifest
- `skills/` -- 2 skill directories with `references/`, `scripts/`, and `assets/` subdirs

This plugin is part of [jstack](../../).

## Skills

`glab`, `gitlab-cicd`

### glab

CLI workflow automation -- merge requests, issues, epics, work items,
Quick Actions, inline MR comments, and GraphQL patterns. Includes
hard-won operational pitfalls from real GitLab usage.

### gitlab-cicd

CI/CD YAML configuration -- `.gitlab-ci.yml` gotchas, CI/CD components,
downstream pipelines, pipeline templates, caching strategies, security
scanning, and deployment best practices.

## Sources

Adapted from:
- [whid/glab](https://github.com/) -- operational workflow skill
- [gitlab-skill/new-gitlab](https://github.com/) -- comprehensive GitLab CLI + CI/CD reference
