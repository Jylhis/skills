---
name: azure-deploy
description: "Execute Azure deployments for ALREADY-PREPARED applications that have existing infrastructure files (azure.yaml, infra/) and, ideally, an .azure/deployment-plan.md. This skill runs azd up, azd deploy, terraform apply, and az deployment commands with built-in error recovery. Confirm infrastructure is generated and validated before running. WHEN: \"run azd up\", \"run azd deploy\", \"execute deployment\", \"push to production\", \"push to cloud\", \"go live\", \"ship it\", \"bicep deploy\", \"terraform apply\", \"publish to Azure\", \"launch on Azure\". DO NOT USE WHEN: the app or its infrastructure has not been created yet — scaffold and generate infrastructure first, then return here to deploy."
license: MIT
metadata:
  author: Microsoft
  version: 1.1.2
  upstream-id: microsoft-azure-skills
  upstream-rev: b71de35cb5a1acc458e1f518cbb9acc830f6d7c6
  upstream-path: azure-deploy
  upstream-imported: 2026-05-12
---

# Azure Deploy

> **AUTHORITATIVE GUIDANCE — MANDATORY COMPLIANCE**
>
> **PREREQUISITE**: Deployable, validated infrastructure must exist BEFORE executing this skill. This skill deploys; it does not scaffold an app or generate infrastructure.

> **⛔ PREREQUISITE CHECK REQUIRED**
> Before proceeding, ensure the prerequisites are met. Verify them inline — this skill is self-contained and does not depend on a separate preparation skill:
>
> 1. **Infrastructure is generated** → `azure.yaml` and `infra/` (Bicep or Terraform) exist for the project. If they do not, scaffold and generate them first, then return here.
> 2. **Configuration is validated** → infrastructure has been checked (e.g. `azd provision --preview`, `bicep build`, `terraform validate`/`terraform plan`), required environment values are set, and RBAC role assignments are present in the IaC. If an `.azure/deployment-plan.md` exists, confirm its status reads `Validated` and its **Validation Proof** section (Section 7) contains real command output with timestamps.
>
> If validation has NOT been performed, run the validation checks above first — do not deploy unvalidated infrastructure.
>
> **⛔ DO NOT FABRICATE VALIDATION RESULTS**
>
> Do not mark a plan `Validated` or fill in a Validation Proof section without actually running the validation commands. If you record a status without running the checks, deployments will fail.
>
> **DO NOT ASSUME** the app is ready. **DO NOT SKIP** validation to save time. Skipping steps causes deployment failures. The complete workflow is:
>
> generate infrastructure → validate → deploy (this skill)

## Triggers

Activate this skill when user wants to:
- Execute deployment of an already-prepared application (azure.yaml and infra/ exist)
- Push updates to an existing Azure deployment
- Run `azd up`, `azd deploy`, or `az deployment` on a prepared project
- Ship already-built code to production
- Deploy an application that already includes API Management (APIM) gateway infrastructure

> **Scope**: This skill executes deployments. It does not create applications, generate infrastructure code, or scaffold projects — generate those first, then return here to deploy.

> **APIM / AI Gateway**: Use this skill to deploy applications whose APIM/AI gateway infrastructure was already generated. For creating or changing APIM resources, see [APIM deployment guide](https://learn.microsoft.com/azure/api-management/get-started-create-service-instance). For AI governance policies on API Management, see the [APIM policies for AI workloads guide](https://learn.microsoft.com/azure/api-management/genai-gateway-capabilities).

## Rules

1. Run only after infrastructure has been generated and validated
2. If an `.azure/deployment-plan.md` is in use, it must exist with status `Validated`
3. **Pre-deploy checklist required** — [Pre-Deploy Checklist](references/pre-deploy-checklist.md)
4. ⛔ **Destructive actions require `ask_user`** — [global-rules](references/global-rules.md)
5. **Scope: deployment execution only** — This skill owns execution of `azd up`, `azd deploy`, `terraform apply`, and `az deployment` commands. These commands are run through this skill's error recovery and verification pipeline.

---

## Steps

| # | Action | Reference |
|---|--------|-----------|
| 1 | **Check Plan** — Read `.azure/deployment-plan.md`, verify status = `Validated` AND **Validation Proof** section is populated | `.azure/deployment-plan.md` |
| 2 | **Pre-Deploy Checklist** — MUST complete ALL steps | [Pre-Deploy Checklist](references/pre-deploy-checklist.md) |
| 3 | **Load Recipe** — Based on `recipe.type` in `.azure/deployment-plan.md` | [recipes/README.md](references/recipes/README.md) |
| 4 | **RBAC Health Check** — For Container Apps + ACR with managed identity: run `azd provision --no-prompt`, then verify `AcrPull` role has propagated before proceeding (see checklist) | [Pre-Deploy Checklist — Container Apps RBAC](references/pre-deploy-checklist.md#container-apps--acr--pre-deploy-rbac-health-check) |
| 5 | **Execute Deploy** — Follow recipe steps | Recipe README |
| 6 | **Post-Deploy** — Configure SQL managed identity and apply EF migrations if applicable | [Post-Deployment](references/recipes/azd/post-deployment.md) |
| 7 | **Handle Errors** — See recipe's `errors.md` | — |
| 8 | **Verify Success** — Confirm deployment completed and endpoints are accessible | [Verification](references/recipes/azd/verify.md) |
| 9 | **Live Role Verification** — Query Azure to confirm provisioned RBAC roles are correct and sufficient | [live-role-verification.md](references/live-role-verification.md) |
| 10 | **Report Results** — Present deployed endpoint URLs to the user as fully-qualified `https://` links | [Verification](references/recipes/azd/verify.md) |

> **⛔ URL FORMAT RULE**
>
> When presenting endpoint URLs to the user, you **MUST** always use fully-qualified URLs with the `https://` scheme (e.g. `https://myapp.azurewebsites.net`, not `myapp.azurewebsites.net`). Many Azure CLI commands return bare hostnames without a scheme — always prepend `https://` before presenting them.

> **⛔ VALIDATION PROOF CHECK**
>
> When checking the plan, verify the **Validation Proof** section (Section 7) contains actual validation results with commands run and timestamps. If this section is empty, validation was bypassed — run the validation checks (see the Prerequisite Check above) before deploying.

## SDK Quick References

- **Azure Developer CLI**: [azd](references/sdk/azd-deployment.md)
- **Azure Identity**: [Python](references/sdk/azure-identity-py.md) | [.NET](references/sdk/azure-identity-dotnet.md) | [TypeScript](references/sdk/azure-identity-ts.md) | [Java](references/sdk/azure-identity-java.md)

## MCP Tools

| Tool | Purpose |
|------|---------|
| `mcp_azure_mcp_subscription_list` | List available subscriptions |
| `mcp_azure_mcp_group_list` | List resource groups in subscription |
| `mcp_azure_mcp_azd` | Execute AZD commands |
| `azure__role` | List role assignments for live RBAC verification (step 9) |

## References

- [Troubleshooting](references/troubleshooting.md) - Common issues and solutions
- [Post-Deployment Steps](references/recipes/azd/post-deployment.md) - SQL + EF Core setup
