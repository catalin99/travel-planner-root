---
name: background-jobs
description: "Backend background processing in TravelPlanner: the in-process scheduled BackgroundService cleanup jobs (rate-limit, quick-search, locale refresh, flight-offer) hosted by TravelPlannerAPI, plus the patterns and best practices for writing reliable hosted services — periodic scheduling, scoped-service resolution, idempotency, graceful shutdown, correlation logging, and resilience. Use when adding/changing a scheduled or periodic background job, debugging a hosted service, or deciding in-process vs out-of-process. For the queued AI itinerary/flight worker, see the ai-pipeline skill."
---

# Background Jobs & Hosted Services Skill

TravelPlanner runs two kinds of background work:

1. **In-process scheduled jobs** — `BackgroundService` cleanup/refresh jobs hosted
   inside `TravelPlannerAPI` (this skill).
2. **Out-of-process queued AI jobs** — `AiQueueProcessorWorker` hosted in
   `TravelPlannerAiWorker`, draining Azure Queue Storage
   ([ai-pipeline](../ai-pipeline/SKILL.md)).

## The existing in-process jobs (read them as the templates)

All live in `TravelPlannerAPI/BackgroundJobs/` (namespace
`TravelPlannerAPI.BackgroundServices`) and are registered together via
`AddBackgroundJobs` in `TravelPlannerAPI/Configuration/BackgroundJobServiceExtensions.cs`:

| Job | Schedule | What it does |
|-----|----------|--------------|
| `RateLimitCleanupService` | every 24h, 5-min startup delay | purges old rate-limit rows |
| `QuickSearchCleanupJob` | 05:00 & 17:00 UTC + on startup | deletes expired quick-search travel requests (cascade) |
| `LocaleRefreshJob` | every 1h + initial load | refreshes the in-memory `ILocaleService` cache |
| `FlightOfferCleanupJob` | every 1 min, 15-sec startup delay | set-based `ExecuteDelete` of expired flight offers |

## The house pattern (match it exactly)

Every job is a `BackgroundService` with this shape:

```csharp
public class FooJob : BackgroundService
{
    private static readonly TimeSpan Interval = TimeSpan.FromMinutes(1);
    private readonly IServiceProvider _serviceProvider;   // singleton-safe
    private readonly ILogger<FooJob> _logger;

    protected override async Task ExecuteAsync(CancellationToken stoppingToken)
    {
        try { await Task.Delay(StartupDelay, stoppingToken); }   // let host finish wiring
        catch (OperationCanceledException) { return; }

        while (!stoppingToken.IsCancellationRequested)
        {
            try { await DoWorkAsync(stoppingToken); }
            catch (OperationCanceledException) { break; }        // graceful shutdown
            catch (Exception ex) { _logger.LogError(ex, "Foo iteration failed."); } // never crash the loop

            try { await Task.Delay(Interval, stoppingToken); }
            catch (OperationCanceledException) { break; }
        }
    }

    private async Task DoWorkAsync(CancellationToken ct)
    {
        TransactionContext.TransactionId = Guid.NewGuid().ToString("N")[..12];  // correlation per run
        using var scope = _serviceProvider.CreateScope();                       // resolve Scoped here
        var uow = scope.ServiceProvider.GetRequiredService<IFlightSearchUnitOfWork>();
        // ... do the work; prefer set-based ExecuteDeleteAsync/ExecuteUpdateAsync for bulk cleanup
    }
}
```

Non-negotiables (these are already done in the existing jobs — keep them):

- **A `BackgroundService` is effectively a singleton.** Never inject a Scoped
  service (UoW, repository, DbContext, request-scoped service) into its
  constructor. Resolve them inside the loop via
  `_serviceProvider.CreateScope()` (`IServiceScopeFactory.CreateScope`). The same
  rule applies to the worker host.
- **Startup delay** before the first run so the host finishes initializing.
- **Per-iteration try/catch** so one transient failure doesn't tear down the
  service; let the loop continue to the next cycle.
- **Honor `stoppingToken`** everywhere (`Task.Delay(..., stoppingToken)`); treat
  `OperationCanceledException` as a clean stop, not an error.
- **Correlation id** per run: set `TransactionContext.TransactionId` so Serilog's
  `TransactionIdEnricher` ties every log line of that run together.
- **Log start, completion, and counts** — not just start. A job that hangs or
  silently no-ops looks "fine" without completion + count logging.

## Best practices to apply (industry + Microsoft guidance)

- **Design every job to be idempotent.** Schedulers can overlap (a run takes
  longer than the interval), and the process can restart mid-run. Running the
  same cleanup twice must be safe. Set-based deletes filtered by an expiry
  predicate (as in `FlightOfferCleanupJob`) are naturally idempotent — prefer
  that style over load-then-loop-delete where practical.
- **Mind horizontal scale.** These jobs run *inside the API process*, so if the
  API scales to N instances, the job runs N times concurrently. Idempotent
  set-based cleanups tolerate this. For any **non-idempotent** or
  must-run-once job, add a guard before introducing it: a DB-based distributed
  lock / leader election, a "last run" timestamp row checked atomically, or move
  the job to a single-instance host (the worker or a dedicated scheduler).
- **Scheduling:** for fixed cadence use an interval `Task.Delay`; for time-of-day
  use a `GetDelayUntilNextRun()` helper (see `QuickSearchCleanupJob`). For richer
  cron needs, keep it in the same `BackgroundService` style rather than adding a
  new scheduling dependency without asking.
- **Resilience:** distinguish transient (retry next cycle) from permanent
  failures (log + skip the bad item, don't let it block the whole batch).
- **Observability:** log duration and affected-row counts; consider warning logs
  when a cleanup finds an unexpectedly large backlog (a signal something upstream
  is wrong).
- **Security:** background jobs often touch data broadly — keep their queries
  scoped to exactly what they need; never log secrets or full PII rows.

## Procedure: add a new in-process scheduled job
1. Create `TravelPlannerAPI/BackgroundJobs/<Name>Job.cs` as a `BackgroundService`
   using the house pattern above.
2. Resolve Scoped services via `CreateScope()` inside the loop; thread the
   `stoppingToken`.
3. Make the work idempotent; prefer `ExecuteDeleteAsync` / `ExecuteUpdateAsync`
   for bulk operations through the appropriate module UoW.
4. Register it in `AddBackgroundJobs`
   (`TravelPlannerAPI/Configuration/BackgroundJobServiceExtensions.cs`) with
   `services.AddHostedService<NameJob>()`.
5. Validate: `dotnet build`, run the API, confirm the start/works/completion logs
   with a correlation id.

## When NOT to use an in-process job
If the work is bursty, long-running, CPU/AI-heavy, or must scale independently of
the API, use the **queue + out-of-process worker** model instead
([ai-pipeline](../ai-pipeline/SKILL.md)) — enqueue from the API, process in
`TravelPlannerAiWorker` with queue-based load leveling and competing consumers.
See [scalability-concurrency](../scalability-concurrency/SKILL.md) for the
throughput/back-pressure rationale.

## Authoritative references (read on demand)
- [Background tasks with hosted services](https://learn.microsoft.com/aspnet/core/fundamentals/host/hosted-services)
- [Worker services in .NET](https://learn.microsoft.com/dotnet/core/extensions/workers) · [Scoped services in a BackgroundService](https://learn.microsoft.com/dotnet/core/extensions/scoped-service)
- [David Fowler — Async Guidance](https://github.com/davidfowl/AspNetCoreDiagnosticScenarios/blob/master/AsyncGuidance.md)
- [Well-Architected — background jobs](https://learn.microsoft.com/azure/well-architected/design-guides/background-jobs)

**Current best practice (2025-26):** prefer
`PeriodicTimer.WaitForNextTickAsync(stoppingToken)` inside `ExecuteAsync` over
`Task.Delay`/`System.Threading.Timer` — async-friendly, no overlapping runs,
honors cancellation. Open a scope per iteration with
`IServiceScopeFactory.CreateAsyncScope()`. Return promptly on `stoppingToken` or
the host force-stops at the ~30s shutdown timeout. Never block (`.Result`/`.Wait()`)
or use `async void` in callbacks; keep handlers idempotent (queues are
at-least-once).

## Auto-learn after each task
After a task that used this skill, reflect and improve it (full loop in
[docs-maintenance](../docs-maintenance/SKILL.md)): fold in any better pattern,
corrected fact, exact command/path, or gotcha you found — edit this `SKILL.md`
surgically in its existing style; refresh the references above if a source or
version changed; cascade to [PROJECT_OVERVIEW.md](../../../PROJECT_OVERVIEW.md)
and the owning repo's deep docs when a feature/contract/package/resource changed;
then say in one line what you updated.
