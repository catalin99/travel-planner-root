---
name: scalability-concurrency
description: "How to write TravelPlanner backend code that handles very high concurrency (1M+ simultaneous users) including the AI generation path. Covers code-level patterns (non-blocking async, cancellation, EF Core efficiency, no-tracking, pagination, DbContext pooling, HttpClientFactory, scoped resolution, allocation control) AND infrastructure/architecture (caching/Redis, rate limiting, queue-based load leveling, competing-consumer worker scaling, throttling/back-pressure, circuit breakers, outbound AI rate limits, horizontal scale). Use when writing hot-path endpoints/services, tuning the AI queue/worker throughput, diagnosing thread-pool starvation or DB contention, or planning to scale."
---

# Scalability & Concurrency Skill

Goal: serve a very large number of concurrent users — including AI itinerary /
flight-suggestion generation — without thread-pool starvation, DB contention, or
overloading the AI provider. Patterns below are grounded in this stack (.NET 8 +
EF Core/SQL Server + Azure Queue Storage + Azure Foundry AI) and Microsoft's
performance guidance.

## Mental model
- **Synchronous user requests** must be fast and fully async; they should never
  do slow/AI/long-running work inline.
- **Slow & AI work is offloaded** to the queue + `TravelPlannerAiWorker` (already
  the design — see [ai-pipeline](../ai-pipeline/SKILL.md)). The queue is the
  shock absorber between bursty intake and bounded AI throughput.

## Code-level rules (the hot path)

**Async all the way — never block:**
- No `.Result`, `.Wait()`, `.GetAwaiter().GetResult()`, or sync-over-async — they
  consume a pool thread per in-flight request and cause **thread-pool starvation**
  under load. Make controllers/services/`SaveChangesAsync` fully async.
- Don't `Task.Run(...)` then immediately `await` it on the server — it just adds
  scheduling overhead. ASP.NET already runs on pool threads.
- Every public service/repo method takes `CancellationToken cancellationToken =
  default` and threads it through to EF/HTTP — so abandoned requests and cancelled
  AI jobs free resources promptly (cancellation is already a first-class concept
  here via `AiQueuedJob.CancellationRequested` + `AiJobCancellationTracker`).

**EF Core efficiency (the usual bottleneck at scale):**
- Use **`AsNoTracking()`** for all read-only queries (most GETs) — less memory, no
  change-tracking/identity-resolution overhead.
- **Project only needed columns** with `.Select(...)` into DTOs; don't materialize
  full entities for read endpoints.
- **Filter/aggregate in the database** (`Where/Select/Sum`), never in memory.
- **Avoid N+1 / lazy loading** — use eager `Include` or projections; use **split
  queries** to avoid cartesian explosion on multi-`Include` reads.
- **Paginate** every potentially large list (the rate-limit + user-management
  endpoints already do). Prefer **keyset pagination** over big `Skip/Take`
  offsets on hot paths. Return `ToListAsync()`/`IAsyncEnumerable<T>`, never a
  lazily-enumerated `IEnumerable<T>` from an action.
- Consider **DbContext pooling** (`AddDbContextPool`) and, only if profiling
  justifies it, **compiled queries** for the hottest queries. Measure first.
- Add the right **indexes** for hot predicates (see
  [DB_PERFORMANCE_PLAN.md](../../../TravelPlanner/docs/Architecture/DB_PERFORMANCE_PLAN.md));
  watch for predicates that defeat indexes (e.g. `ToLower()` on a column,
  `EndsWith`).

**Concurrency hygiene:**
- A `BackgroundService`/worker is a singleton — resolve Scoped services
  (UoW/DbContext) via `IServiceScopeFactory.CreateScope()` per unit of work, never
  via constructor injection ([background-jobs](../background-jobs/SKILL.md)).
- Don't capture `HttpContext`, request-scoped services, or a `DbContext` in
  fire-and-forget/background closures (they're disposed when the request ends).
  `HttpContext` is not thread-safe — copy needed values into locals before any
  parallel/`Task.WhenAll` work.
- Bound in-process parallelism with `SemaphoreSlim` (the worker already gates
  concurrency with `MaxConcurrentJobs`).

**HTTP / outbound:**
- Always use **typed `HttpClient` via `IHttpClientFactory`**
  (`AddHttpClient<TInterface,TImpl>`) — the AI and flight/currency providers
  already do. Never `new HttpClient()` per call (socket exhaustion).

**Allocations:** avoid large (≥ 85 KB) short-lived allocations on hot paths (they
hit the LOH and force gen-2 GC). Don't buffer large request/response bodies into a
single `string`/`byte[]`; stream and use `System.Text.Json` async.

## Infrastructure & architecture (the 1M-user picture)

**Stateless + scale out:** keep the API stateless (JWT bearer, no server session)
so it scales horizontally behind a load balancer. Anything in-memory that must be
shared (caches, rate-limit counters at true global scale) moves to a distributed
store.

**Caching (reduce origin load):**
- Cache hot, slowly-changing reads — `DynamicConfig`/locales/currency are already
  cached in-memory (`ILocaleService` singleton, currency cache). For multi-instance
  correctness use a **distributed cache (Redis)** so all instances share it.
- Apply the **cache-aside** pattern; set TTLs; protect against stampedes on
  popular keys. Caching reduces *average* load — it does **not** bound peak load,
  so pair it with throttling (below).
- Turn on **response compression** for large JSON payloads.

**Rate limiting / throttling (bound peak, protect the system):**
- Per-principal/IP rate limits already exist (`RateLimit*`). For global correctness
  across many instances, back counters with a shared store. Use ASP.NET Core's
  **rate limiting middleware** (token/leaky/fixed/sliding window — pick per the
  endpoint's burst tolerance) and return **HTTP 429 with a `Retry-After`** header.
- Shed load **early and cheaply** (reject before expensive auth/parsing); shed
  lower-value work first. Make limits configurable without redeploying.
- Limit at the dimension that **saturates first** — often concurrency at a
  fan-out point or a downstream limit, not raw requests/sec.

**AI generation at scale (the special case):**
- **Queue-based load leveling:** the API enqueues `AiQueuedJob` + a queue message
  and returns `202` immediately; it never calls the AI inline. The queue buffers
  bursts so the AI tier processes at a controlled rate.
- **Competing consumers:** scale throughput by running **more
  `TravelPlannerAiWorker` instances** (and/or higher `MaxConcurrentJobs`) reading
  the same queue — but only up to what the **AI provider quota and the DB** can
  take. Scale the *whole* pipeline, not just compute.
- **Respect the AI provider's limits (outbound throttling):** cap concurrent
  outbound calls; on provider `429`/timeouts back off with retry + jitter (the job
  already has batch/job retries). Add a **circuit breaker** so a failing AI
  endpoint doesn't cause a retry storm; surface back-pressure instead of hiding it.
- **Idempotency + at-least-once:** queue delivery is at-least-once and the worker
  can restart — job processing must be idempotent and resumable (batch progress is
  already tracked on `AiQueuedJob`). Route permanently-failing messages aside
  (poison/dead-letter) instead of looping forever.
- **Cost/UX:** model selection is role-driven; keep cheaper models for the
  free/`User` tier. The frontend polls job status — keep poll intervals sane
  (a few seconds) to avoid a self-inflicted request flood.

**Data tier:** the DB is the hardest thing to scale — push read load to
caches/replicas, keep transactions short, use set-based operations for bulk work
(the cleanup jobs already use `ExecuteDeleteAsync`), and watch connection-pool
saturation. Bound worker concurrency so the worker fleet can't exhaust SQL
connections.

**Observability (you can't scale what you can't see):** track p99 latency (not
just averages), queue depth and enqueue-to-completion time, thread-pool/GC stats,
DB query time, and AI call latency/failure rate — all correlated by
`TransactionContext.TransactionId`.

## Procedure: make a feature scale
1. Is it slow or AI/long-running? → **offload to the queue + worker**, return
   `202` + a job id; poll for status. Don't block the request.
2. Keep the synchronous endpoint async, no-tracking, projected, paginated,
   cancellation-aware.
3. Add caching for hot reads (distributed if it must be shared); add/right-size
   rate limits for write/expensive endpoints.
4. For AI/worker changes, bound concurrency, honor provider limits with backoff +
   circuit breaker, keep processing idempotent.
5. Load-test the hot path and the rejection path; measure p99 and queue depth
   before and after.

## Guardrails
- Never block on async; never `new HttpClient()`; never capture request scope in
  background work.
- Never call the AI provider inline from a user request.
- Don't add a new messaging/cache/resilience dependency without asking — extend
  the existing Azure Queue + caching + retry patterns first.

## Authoritative references (read on demand)
- [ASP.NET Core best practices](https://learn.microsoft.com/aspnet/core/fundamentals/best-practices) · [David Fowler — Async Guidance](https://github.com/davidfowl/AspNetCoreDiagnosticScenarios/blob/master/AsyncGuidance.md)
- [EF Core performance](https://learn.microsoft.com/ef/core/performance/)
- [Rate limiting middleware](https://learn.microsoft.com/aspnet/core/performance/rate-limit) · [Build resilient apps (Polly / Microsoft.Extensions.Resilience)](https://learn.microsoft.com/dotnet/core/resilience/)
- [Queue-Based Load Leveling](https://learn.microsoft.com/azure/architecture/patterns/queue-based-load-leveling) · [Competing Consumers](https://learn.microsoft.com/azure/architecture/patterns/competing-consumers)

**Current best practice (2025-26):** inbound, use `AddRateLimiter` with
**partitioned** limiters (per user/IP/API-key). Outbound, wrap calls in a
**`Microsoft.Extensions.Resilience`/Polly** pipeline (retry + timeout + circuit
breaker + concurrency/bulkhead limiter). Keep the whole stack async —
sync-over-async (`.Result`/`.Wait()`) starves the thread pool; don't `Task.Run`
to "async-ify" sync work on hot paths. For high scale add DbContext pooling +
compiled queries (measure first).

## Auto-learn after each task
After a task that used this skill, reflect and improve it (full loop in
[docs-maintenance](../docs-maintenance/SKILL.md)): fold in any better pattern,
corrected fact, exact command/path, or gotcha you found — edit this `SKILL.md`
surgically in its existing style; refresh the references above if a source or
version changed; cascade to [PROJECT_OVERVIEW.md](../../../PROJECT_OVERVIEW.md)
and the owning repo's deep docs when a feature/contract/package/resource changed;
then say in one line what you updated.
