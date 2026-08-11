---
name: terraform
description: Use for Terraform and HCL infrastructure-as-code work. Covers writing and reviewing HCL to HashiCorp's style guide (file layout, naming, variables and outputs, for_each vs count, version pinning), writing and running tests with .tftest.hcl (run and assert blocks, mock providers, CI wiring), refactoring monolithic configs into reusable modules (interface design, moved-block state migration), and authoring Terraform Stacks (.tfcomponent.hcl and .tfdeploy.hcl components, deployments, linked Stacks). Read the matching reference before writing or reviewing Terraform.
metadata:
  upstream-id: hashicorp-agent-skills
  upstream-rev: 43ca9b0cde131e20a129c106bc9f6b6f9f1e5c9a
  upstream-path: terraform
  upstream-imported: 2026-05-12
---

# Terraform

Opinionated Terraform guidance, split by task. This file routes; the detail
lives in `references/`. Load only the reference for the task at hand.

| Task | Read |
|------|------|
| Writing or reviewing HCL (style, layout, naming, variables, outputs, `for_each`, version pinning) | `references/style-guide.md` (plus `references/security.md`) |
| Writing or running module tests (`.tftest.hcl`, run/assert blocks, mock providers, CI) | `references/test.md` (plus `references/test/`) |
| Refactoring monolithic config into reusable modules (interfaces, `moved` state migration) | `references/refactor-module.md` |
| Authoring Terraform Stacks (`.tfcomponent.hcl`, `.tfdeploy.hcl`, deployments, linked Stacks) | `references/stacks.md` (plus `references/stacks/`) |

## Conventions

- Format and validate before every commit: `terraform fmt -recursive` then `terraform validate`.
- Prefer `for_each` over `count` for multiple resources; reserve `count` for conditional creation.
- Every variable and output carries a `type` (variables) and a `description`; mark secrets `sensitive = true`.
- Pin `required_version` and provider versions; commit `.terraform.lock.hcl`, never state files or `.terraform/`.

Attribution: the reference bodies are adapted from HashiCorp agent-skills
(`hashicorp/agent-skills`, MPL-2.0; portions Copyright IBM Corp. 2026).
