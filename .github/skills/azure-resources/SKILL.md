---
name: azure-resources
description: "Manage the Azure resources TravelPlanner actually uses: the Azure AI Foundry project + model deployments (gpt-4.1-mini, gpt-5.4-mini) behind the AI pipeline, and the Azure Storage account + Queue (ai-itinerary-jobs) behind the AI worker. Covers az CLI inspection/management, secrets handling (Key Vault, user-secrets, managed identity, key rotation), the Azure SQL migration path for the currently-local database, scaling/cost, and observability. Use when inspecting, configuring, securing, scaling, or troubleshooting cloud resources, or wiring new ones."
---

# Azure Resources Skill

Manage the cloud resources this product depends on. **Never print secret values**
(keys, connection strings, tokens) in chat, code, commits, or docs — reference
them by name and resolve them from a secret store at runtime.

## Resources actually in use (grounded in appsettings)

| Resource | Identity (name) | Used by | Config section |
|----------|-----------------|---------|----------------|
| **Azure AI Foundry** | resource `travelplanner-foundry` (`*.services.ai.azure.com`), project `travelplanner-dev` | AI pipeline ([ai-pipeline](../ai-pipeline/SKILL.md)) | `AiModel:Endpoint`, `AiModel:ApiKey` |
| **Model deployments** | `gpt-4.1-mini` (Free/`User` role), `gpt-5.4-mini` (Agent…SuperAdmin) | role-based model selection | `AiModel:RoleModelMapping`, `AiModel:Models` |
| **Azure Storage account** | `travelplannerai` (`core.windows.net`) | AI worker queue | `AzureQueueStorage:ConnectionString` |
| **Azure Storage Queue** | `ai-itinerary-jobs` (visibility 600s) | enqueue/dequeue AI jobs | `AzureQueueStorage:QueueName` |
| **Database (SQL Server)** | **currently LOCAL** SQL Express (`...\SQLEXPRESS`), DBs `travelplanner`, `travelplanner_dynamicconfig` | EF Core, two DbContexts | `ConnectionStrings:*` |

> The endpoint is Azure Foundry's **OpenAI-compatible Responses API**
> (`/openai/v1/responses`). Email uses **Gmail SMTP** (not an Azure resource).
> Flights use **Duffel** + **Aviasales/Travelpayouts** (external, not Azure).

## Prerequisites
- Azure CLI: `az --version`; sign in `az login`; pick the subscription
  `az account set --subscription "<name-or-id>"`.
- If the Azure MCP server or the Azure Resources VS Code extension is available,
  prefer it for resource browsing; otherwise use `az` below. Don't add new Azure
  dependencies/resources without asking.

## Inspect / manage with az CLI

**Storage account + queue (AI job queue):**
```powershell
# Find the account and its resource group
az storage account show -n travelplannerai --query "{rg:resourceGroup,loc:location,sku:sku.name}" -o table
# Queue depth / peek (use a connection string or --auth-mode login)
az storage message peek  --queue-name ai-itinerary-jobs --account-name travelplannerai --num-messages 10 --auth-mode login
az storage queue stats   --account-name travelplannerai --auth-mode login
# Rotate the account key (then update the secret store, NOT appsettings)
az storage account keys renew -g <rg> -n travelplannerai --key key1
```
Queue tuning lives in `AzureQueueStorage` (`MaxConcurrentJobs`,
`PollingIntervalSeconds`, `MessageVisibilityTimeoutSeconds`) — scale by the
worker's competing-consumer model ([scalability-concurrency](../scalability-concurrency/SKILL.md)),
not by changing visibility blindly. Consider a **dead-letter queue** for poison
messages and alerting on queue depth.

**Azure AI Foundry (models):**
```powershell
az cognitiveservices account show -n travelplanner-foundry -g <rg> -o table
az cognitiveservices account deployment list -n travelplanner-foundry -g <rg> -o table   # see gpt-4.1-mini / gpt-5.4-mini
az cognitiveservices account keys regenerate -n travelplanner-foundry -g <rg> --key-name Key1
```
Check **TPM/RPM quota** per deployment when tuning AI throughput; raise quota or
add a deployment before increasing worker concurrency. Keep the cheap model for
the Free tier and the premium model for paid roles (already wired).

## Secrets & identity (cloud best practice)
- **Local dev:** keep secrets out of committed files — use `dotnet user-secrets`
  per host project (`dotnet user-secrets init`, then
  `... set "AiModel:ApiKey" "<value>"`), mirrored into `TravelPlannerAiWorker`.
- **Cloud:** store secrets in **Azure Key Vault** read via the Key Vault config
  provider, and prefer **Managed Identity** over keys (`DefaultAzureCredential`)
  for Storage, Foundry, and SQL so there are no keys to manage. Grant
  least-privilege Azure RBAC (e.g. *Storage Queue Data Contributor*,
  *Cognitive Services User*).

## Database: local → Azure SQL (migration path)
The DB is local today. To move to **Azure SQL Database**:
1. Provision: `az sql server create` + `az sql db create` (pick a tier; start
   General Purpose serverless for cost).
2. Networking: firewall rule / private endpoint; enable **Microsoft Entra auth**.
3. Update `ConnectionStrings:DefaultConnection` + `DynamicConfigConnection` in the
   **secret store** (use `Authentication=Active Directory Default` for managed
   identity — no password).
4. Apply migrations against the new server ([ef-migrations](../ef-migrations/SKILL.md));
   keep the two-context split.
5. Re-point both the API and the worker; verify the worker can reach the DB.

## Scaling & cost (for the 1M-user target)
- **Compute:** host API + worker on Azure Container Apps / App Service; scale the
  **worker** on **queue depth** (KEDA) as competing consumers; keep the API
  stateless behind a load balancer. See [scalability-concurrency](../scalability-concurrency/SKILL.md).
- **Data:** scale Azure SQL up/out (read replicas, elastic pool); watch DTU/vCore
  and connection-pool limits.
- **AI:** cost is dominated by tokens — keep role-based model selection, batch
  generation, and quota headroom; alert on Foundry spend.
- **Cache:** add **Azure Cache for Redis** for shared caches / distributed rate-limit
  counters when running multiple API instances.

## Observability
- Add **Application Insights** (or Azure Monitor) for the API and worker; correlate
  with the existing `TransactionContext.TransactionId`. Track queue depth,
  enqueue→completion latency, AI call latency/failures, and DB query time.

## Guardrails
- No secret values in chat/code/commits/docs — names and placeholders only.
- Prefer Managed Identity + Key Vault over keys.
- Don't provision/destroy/scale shared cloud resources without explicit user
  confirmation; `az ... delete` and key regeneration are consequential.

## Authoritative references (read on demand)
- [Azure Well-Architected Framework](https://learn.microsoft.com/azure/well-architected/) · [Azure AI Foundry](https://learn.microsoft.com/azure/ai-foundry/)
- [Queue Storage](https://learn.microsoft.com/azure/storage/queues/storage-queues-introduction) · [Container Apps scaling (KEDA)](https://learn.microsoft.com/azure/container-apps/scale-app)
- [DefaultAzureCredential chains](https://learn.microsoft.com/dotnet/azure/sdk/authentication/credential-chains) · [Key Vault](https://learn.microsoft.com/azure/key-vault/general/overview)
- [Azure SQL Database](https://learn.microsoft.com/azure/azure-sql/database/sql-database-paas-overview) · [az CLI reference](https://learn.microsoft.com/cli/azure/reference-index)

**Current best practice (2025-26):** authenticate Storage/Foundry/SQL with
**managed identity + Azure RBAC** (passwordless) instead of connection strings;
in prod pin `ManagedIdentityCredential` (or narrow `DefaultAzureCredential` via
`AZURE_TOKEN_CREDENTIALS`). Scale the worker with the **`azure-queue` KEDA scaler**
(`queueLength`, authenticated by managed identity) and scale-to-zero when idle.
For Azure SQL use the **serverless** compute tier for bursty load + Entra auth.
Instrument with the **Azure Monitor OpenTelemetry Distro** (migrate off classic
App Insights SDKs); tag resources + set Budgets/alerts for cost.

## Auto-learn after each task
After a task that used this skill, reflect and improve it (full loop in
[docs-maintenance](../docs-maintenance/SKILL.md)): fold in any better pattern,
corrected fact, exact command/path, or gotcha you found — edit this `SKILL.md`
surgically in its existing style; refresh the references above if a source or
version changed; cascade to [PROJECT_OVERVIEW.md](../../../PROJECT_OVERVIEW.md)
and the owning repo's deep docs when a feature/contract/package/resource changed;
then say in one line what you updated.
