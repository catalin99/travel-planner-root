---
name: ai-pipeline
description: "The TravelPlanner AI generation pipeline: queued AI itinerary + flight-suggestion jobs processed out-of-process by TravelPlannerAiWorker via Azure Queue Storage, the Azure Foundry (OpenAI-compatible) model provider, role-driven model selection, batched generation with retries, cooperative cross-process cancellation, and the system prompts. Use when changing how AI jobs are queued/processed, the worker, the AI provider, prompts, or polling endpoints."
---

# AI Generation Pipeline Skill

The product generates **AI itineraries** and **AI flight suggestions**
asynchronously. The API only **enqueues**; a separate worker process does the
work. Deep rules:
[TravelPlanner/.github/copilot-instructions.md](../../../TravelPlanner/.github/copilot-instructions.md)
(§8–9) and
[queues-and-workers.instructions.md](../../../TravelPlanner/.github/instructions/queues-and-workers.instructions.md).

## End-to-end flow
```
[Browser] → API POST /api/aiitinerary/generate
          → IAiJobService: validate → INSERT AiQueuedJob → SendMessage(AiQueueMessage)
          → 202 Accepted { jobId, status: "Queued" }
[Azure Queue Storage]  ──ReceiveMessage──▶  [TravelPlannerAiWorker]
[Worker] AiQueueProcessorWorker → IAiJobService.ProcessJobAsync(jobId)
          → outline phase → batched day phases (IAiModelProvider → Azure Foundry)
          → parse JSON → IItineraryService persists days/blocks transactionally
[Worker] sweeps every poll cycle for orphan Queued rows and re-publishes them
[Browser] polls GET /api/ai-jobs/{jobId}  (and /api/flight-suggestions/{id})
```

## Key pieces
- **Provider:** `IAiModelProvider` → `AzureFoundryModelProvider`
  (`TravelPlannerInfrastructure/ExternalServices/AiModels/`). Azure Foundry is
  an OpenAI-compatible **Responses API** (`input` array with system/user
  messages). Selected via `IAiModelProviderFactory`. Swappable by design — keep
  the interface stable.
- **Queue:** `IAiQueueService` / `AzureQueueStorageService`
  (`ExternalServices/AzureQueue/`, singleton). Message DTO `AiQueueMessage`
  (`JobId`, `UserId`, `RequestType`, `RelevantId`, `CorrelationId`, `AiModel`) —
  keep it small; full state lives in the `AiQueuedJob` entity
  (`TravelPlannerDomain/Entities/AiQueue/`).
- **Worker loop:** `SemaphoreSlim` gates `MaxConcurrentJobs`; receive with a
  visibility timeout; on a message `Task.Run(ProcessMessageAsync)` and grab the
  next slot; on empty poll, reconcile stuck rows then `Task.Delay(pollInterval)`.
- **Job orchestration:** `AiJobService.ProcessJobAsync` does outline → batches
  (default batch size from settings), with per-batch retries and job-level
  retries/backoff; sets `RequestStatus` (`Queued`/`InProgress`/`Retrying`/
  `PartiallyCompleted`/`Completed`/`Failed`/`Cancelled`).
- **Model selection is role-driven:** `AiModelSettings.ResolveModelForRoles` via
  `RoleModelMapping`; per-model tuning under `AiModel:Models:<name>` (temperature,
  batch size, retries, timeouts).
- **Grouped experiences (authoritative, not AI-invented):** at queue time
  `AiJobService.MergePersistedExperiencesAsync` loads the travel request's
  `TravelRequestExperience` rows (+ segments) into `request.Experiences`, and
  `ExperiencePlanner.ResolvePlacements` assigns each a stable `Ref`/colour/start day.
  The prompt (`ExperiencePlanner.BuildPromptContext`) tells the model to **reserve**
  the day/time window and not invent inside it. After the header is created the worker
  persists `ItineraryExperience` rows (`IItineraryService.AddExperiencesToItineraryAsync`
  → `ref→id` map), then per batch injects the segment blocks verbatim
  (`ExperiencePlanner.BuildSegmentBlocksByDay` + `MergeInjectedIntoBatch`) linked via
  `ItineraryBlock.ExperienceId`. Supports multi-day (full-day) and single-day multi-stop
  experiences. `ExperiencePlanner` is pure/static — unit-testable, no I/O.
- **Experience sourcing seam (future supplier AI pipeline):** attaching an experience
  goes through `IExperienceSourcingService.SourceAndAttachAsync`. `provider="manual"`
  persists caller content; a supplier key runs **AI query-build → provider search → AI
  map → persist** via `IExperienceProvider` (Infra, config-driven like Flights under
  `Experiences:Providers`, `Disabled` flag), `IExperienceQueryBuilder` and
  `IExperienceResultMapper` (Application; deterministic defaults now, swap for AI-backed
  later — one-line DI change). `GetYourGuideExperienceProvider` is the disabled stub
  marking where the real partner API + AI parse drop in. Endpoint:
  `POST /api/travelrequestexperiences/by-request/{id}/source` (501 when a supplier is
  disabled).
- **Prompts:** system prompts are assets in
  [TravelPlanner/docs/AiPrompts/](../../../TravelPlanner/docs/AiPrompts)
  (`itinerary-agent-instructions.md`, `flight-suggestions-agent-instructions.md`).
  Both API and Worker csproj copy them via a `<Content Include="..\docs\AiPrompts\**\*">`
  glob — preserve that glob when editing csproj.
- **Cancellation (cross-process):** API sets
  `AiQueuedJob.CancellationRequested = true`; the worker polls the column.
  `AiJobCancellationTracker` (singleton) is an in-process fast path only.

## Grounded config (from appsettings — `AiModel` + `AzureQueueStorage`)
- **Provider endpoint:** Azure AI Foundry project `travelplanner-dev` on
  `travelplanner-foundry.services.ai.azure.com`, path `/openai/v1/responses`.
- **Model deployments:** `gpt-4.1-mini` (default; the **Free/`User`** tier) and
  `gpt-5.4-mini` (the paid roles `Agent`…`SuperAdmin`). `RoleModelMapping` drives
  selection — this is the lever the subscription/credit model rides on
  ([pricing-strategy](../pricing-strategy/SKILL.md)). Per-model knobs under
  `AiModel:Models:<name>`: `Temperature` 0.3, `MaxOutputTokens` 100k/150k,
  `BatchSize` 9, `MaxRetry` 10, `MaxRetryPerBatch` 3, `HttpTimeoutSeconds` 400/460.
- **Queue:** Storage account `travelplannerai`, queue **`ai-itinerary-jobs`**,
  `MaxConcurrentJobs` 3, `PollingIntervalSeconds` 5, `MessageVisibilityTimeoutSeconds`
  600. To raise AI throughput, scale workers/concurrency **and** Foundry quota
  together ([scalability-concurrency](../scalability-concurrency/SKILL.md)); manage
  the cloud side via [azure-resources](../azure-resources/SKILL.md).

## Adding / changing a queue-backed job
1. Define a message DTO (sibling of `AiQueueMessage`) or extend `RequestType`.
2. Add a DB entity mirroring `AiQueuedJob` (status, retries, timestamps,
   cancellation flag) + repository + module UoW slot, then a migration
   ([ef-migrations](../ef-migrations/SKILL.md)).
3. Add the enqueue path (mirror `AiJobService.QueueItineraryGenerationAsync`).
4. Add/extend a worker that polls with a `SemaphoreSlim`, reconciles stuck rows
   on empty polls, and honors cooperative cancellation.
5. **Register new dependencies in BOTH** `TravelPlannerAiWorker/Program.cs` **and**
   the matching API `<Module>ModuleExtensions.cs` (and mirror the Mapster scan).

## Frontend side
Poll the job endpoint (`/api/ai-jobs/{jobId}`, `/api/flight-suggestions/...`) and
keep `src/types/aiJob.ts` statuses in sync ([frontend-react](../frontend-react/SKILL.md)).

## Validate
`dotnet build` for both API and Worker. Run the worker locally to confirm it
drains the queue. Don't run heavy services in both hosts when only the worker
needs them.

## Authoritative references (read on demand)
- [Azure AI Foundry docs](https://learn.microsoft.com/azure/ai-foundry/)
- [Azure OpenAI Responses API](https://learn.microsoft.com/azure/ai-services/openai/how-to/responses) · [Structured outputs (JSON schema)](https://learn.microsoft.com/azure/ai-services/openai/how-to/structured-outputs)
- [Prompt engineering (Azure)](https://learn.microsoft.com/azure/ai-services/openai/concepts/prompt-engineering) · [OpenAI prompt guide](https://platform.openai.com/docs/guides/prompt-engineering)
- [Queue Storage performance checklist](https://learn.microsoft.com/azure/storage/queues/storage-performance-checklist)

**Current best practice (2025-26):** prefer the **Responses API** with
`background=true` + poll the response id for long jobs (and `previous_response_id`
for stateful chaining). Enforce shape with **Structured Outputs (`json_schema`)**
rather than prompt-only "return JSON", and validate before persisting. LLM + queue
ops are at-least-once — **dedupe on job id** and make processing idempotent. Put
the key instruction first *and* restate it at the end (recency bias); keep queue
messages compact and watch token budgets via batching.

## Auto-learn after each task
After a task that used this skill, reflect and improve it (full loop in
[docs-maintenance](../docs-maintenance/SKILL.md)): fold in any better pattern,
corrected fact, exact command/path, or gotcha you found — edit this `SKILL.md`
surgically in its existing style; refresh the references above if a source or
version changed; cascade to [PROJECT_OVERVIEW.md](../../../PROJECT_OVERVIEW.md)
and the owning repo's deep docs when a feature/contract/package/resource changed;
then say in one line what you updated.
