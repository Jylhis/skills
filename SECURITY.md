# Security Policy

## Reporting a Vulnerability

Please report suspected vulnerabilities privately through GitHub security
advisories for this repository.

Do not open a public issue for vulnerabilities involving credential handling,
command execution, repository installation, plugin manifests, or skill content
that could cause unsafe agent behavior.

When reporting, include:

- affected skill, script, workflow, or plugin path
- steps to reproduce
- expected impact
- any suggested fix or mitigation

## Scope

Security-sensitive areas include:

- install scripts and plugin registration
- skill instructions that execute commands or delegate to tools
- GitHub Actions workflows
- bundled helper scripts
- marketplace manifests
- upstream import and review workflows
