---
name: azure
description: "Azure cloud umbrella — routes to the right Azure sub-skill for the task. Use when the user mentions Azure generally or asks for help with Azure without naming a specific service, or when you need to figure out which Azure skill applies. Covers: AI services (Search, Speech, OpenAI, Document Intelligence), cost management (historical costs, forecasting, optimization), compliance and security audits (azqr, Key Vault expiration), deployment (azd up, bicep, terraform apply for already-prepared apps), AKS (cluster creation, Automatic readiness), and Storage (blob, files, queues, tables, Data Lake). Read the routing table below, then load the specific sub-skill."
---

# Azure skill index

This is a router. Pick the sub-skill that matches the task and read its
`SKILL.md` before acting. Each sub-skill is the focused, opinionated
guidance for that Azure service area.

| Sub-skill | When to use | Path |
|---|---|---|
| Azure AI | AI Search (full-text, vector, hybrid), Speech (STT/TTS), OpenAI, Document Intelligence (OCR) | `azure-ai/SKILL.md` |
| Azure compliance | Compliance scans, security audits, azqr, Key Vault expiration checks, orphaned resources | `azure-compliance/SKILL.md` |
| Azure cost | Historical cost queries, spending forecasts, cost optimization, rightsizing, budget alerts | `azure-cost/SKILL.md` |
| Azure deploy | Execute deployments for already-prepared apps (azd up, azd deploy, terraform apply, bicep deploy) | `azure-deploy/SKILL.md` |
| Azure Kubernetes (AKS) | Plan, create, configure AKS clusters; SKU selection, networking, security, autoscaling | `azure-kubernetes/SKILL.md` |
| AKS Automatic readiness | Assess workloads for AKS Automatic compatibility; migrate from Standard to Automatic | `azure-kubernetes-automatic-readiness/SKILL.md` |
| Azure Storage | Blob, File Shares, Queue, Table Storage, Data Lake; access tiers; lifecycle management | `azure-storage/SKILL.md` |

## Common rules across all Azure sub-skills

- Use the `az` CLI or Azure MCP tools as the primary interface. Confirm
  the subscription context (`az account show`) before any mutation.
- Prefer `azqr` and the Azure Well-Architected Framework for assessing
  existing resources before recommending changes.
- For security topics, also consult the `security` skill's framework-specific
  references.

After reading the sub-skill, follow its guidance for the task.
