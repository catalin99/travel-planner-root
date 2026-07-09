---
name: feature-workflow
description: "The analyze → plan → implement → validate loop for building a new feature, refactor, or rework in TravelPlanner that may touch the .NET backend, the React frontend, or both. Use to plan any non-trivial change end to end, keep the DTO↔TS-type contract aligned across repos, and validate each side. Covers backend-only, frontend-only, and full-stack flows."
---

# Feature / Refactor Workflow Skill

A disciplined loop for shipping a change across one or both repos. Use the todo
list to track multi-step work.

## 1. Analyze
- Restate the goal and decide which **repo(s)** and **module(s)** it touches.
  Load [fullstack-architecture](../fullstack-architecture/SKILL.md) if unsure.
- **Read before planning.** Open the real files on each affected side:
  - Backend: controller, service interface/impl, DTOs (`DTOs/<Module>/`), entity,
    `<Module>ModuleExtensions.cs`.
  - Frontend: `src/services/api/<resource>Service.ts`, `src/types/<resource>.ts`,
    the consuming view/hook, `src/routes.tsx`.
- For a refactor/rework, map current call sites (use search/usages) so the change
  is complete, and check `docs/Architecture/PHASE1_MODULARIZATION.md` for the
  module direction the codebase is moving toward.

## 2. Plan
- Write a short, file-level plan: the exact files to add/edit per side, the new
  DTO/type shape, DI registrations, and whether a **migration** or **worker**
  change is needed.
- Note cross-cutting impacts: auth/roles, the AI pipeline, migrations, and which
  **docs** to update afterward ([docs-maintenance](../docs-maintenance/SKILL.md)).
- Confirm no new dependency is required (stay in stack).

## 3. Implement (respect dependencies; parallelize the rest)

The numbered order below is the **dependency order**, not a mandate to work
serially. After planning, split the change into **independent slices** and run them
on parallel agentic threads (dispatch several `runSubagent` calls in **one** tool
batch — they execute concurrently and you collect all results). See
**Parallel execution** below.

1. **Backend domain/data first:** entity + `<Module>ModelConfiguration` →
   migration ([ef-migrations](../ef-migrations/SKILL.md)).
2. **Backend behavior:** repository → service (interface + impl) → DTO + Mapster
   map → controller endpoint. Register DI in `<Module>ModuleExtensions.cs` (and
   `TravelPlannerAiWorker/Program.cs` if the worker uses it). Follow
   [backend-dotnet](../backend-dotnet/SKILL.md).
3. **Contract sync:** update `src/types/<resource>.ts` to mirror the final DTO
   (camelCase; `Guid`→`string`, `DateTime`→ISO string, enums→string unions).
4. **Frontend behavior:** service function → hook (if server state) → view →
   route. Follow [frontend-react](../frontend-react/SKILL.md).
5. Keep each module boundary intact; cross-module reads via `Contracts/`.

### Parallel execution (fan out after planning)

The dev machine is a 32-logical-core / 64 GB box — finish faster by running
independent slices concurrently instead of one-at-a-time. The plan is the
**synchronization point**; everything after it fans out.

1. **Freeze the contract in the plan (do this first, serially).** Pin the exact
   DTO shape, endpoint signatures, service interface(s), and the TS type. This is
   what lets threads code against a stable seam without waiting on each other.
2. **Partition by disjoint file ownership.** Give each thread a set of files no
   other thread writes — otherwise parallel edits race. Typical full-stack split:
   - **Thread A — backend data/domain:** entity + `*ModelConfiguration` (+ migration
     scaffold), repository interface/impl.
   - **Thread B — backend service + API:** service interface/impl + Mapster map +
     controller + DI, coded against the frozen DTO.
   - **Thread C — frontend:** `types/<resource>.ts` + `services/api/<resource>Service.ts`
     + view/hook/route, coded against the frozen contract.
   - Add more threads per module/resource when a slice is itself splittable.
3. **Dispatch in one batch.** Put the independent `runSubagent` calls in a single
   tool block. Each prompt must be **self-contained** (subagents are stateless and
   can't talk to each other or you mid-run): include the frozen contract, the exact
   files that thread owns, the conventions, and what to return.
4. **Keep true dependencies sequential.** Don't parallelize across a hard edge:
   entity **before** its migration; service **before** the DI line that registers it
   when they share a file; DTO **decided** before FE types; anything that edits the
   **same file** goes on one thread.
5. **Integrate + validate the seams.** After threads return, reconcile the touchpoints
   (DI registrations, `IUnitOfWork`/module wiring, the DTO↔TS match), then run the
   parallel validation below. Fix any contract drift.
6. **Verify scope after a parallel run.** A subagent can occasionally edit *outside*
   its assigned files or corrupt one (e.g. an identifier replaced by a long whitespace
   run). Per-file language-server checks miss cross-file/other-file damage, so ALWAYS:
   (a) run a **full `dotnet build`** (not just `get_errors` on changed files) — it
   surfaced a corrupted `UnitOfWork.cs` class declaration a per-file check reported as
   clean; and (b) skim **`git status --porcelain`** for files no thread was scoped to
   touch, and `git diff` any surprise. Fix or `git checkout --` stray/corrupted files.
   Distinguish genuine pre-existing uncommitted work (leave it) from glitch damage.

> When a task is small or mostly one file, skip the fan-out — orchestration
> overhead isn't worth it. Parallelize when there are ≥2 genuinely independent,
> multi-file slices (classic full-stack, or several resources at once).

## 4. Validate
- **Backend:** `dotnet build` from `TravelPlanner/`; apply the migration; start
  the API (and Worker if touched).
- **Frontend:** `npm run lint` and `npm run build` from `travel-planner-frontend/`.
- Fix type/compile errors surfaced by the contract change before finishing.
- **Update docs** for any changed contract, endpoint, module boundary, migration,
  or AI-pipeline behavior.

> **Run validation in parallel (this workspace).** The dev machine is a 32-logical-core
> / 64 GB box — fan out independent work instead of serializing it:
> - Backend build (`dotnet build -m`), frontend `lint` and frontend `tsc -b` are
>   independent → run them **concurrently**. Use the **`Validate All (parallel)`**
>   VS Code task ([.vscode/tasks.json](../../../.vscode/tasks.json)) or one PowerShell
>   fan-out (`Start-Job` per gate, then `Wait-Job`/`Receive-Job`). Stop the debug
>   stack first so the backend build isn't blocked by locked binaries.
> - Batch **independent tool calls** (reads, searches, `get_errors`, independent
>   edits via `multi_replace_string_in_file`) in one step rather than one-at-a-time.
> - Honest expectation: a small incremental edit→build simply doesn't contain 32
>   cores of work; parallelism pays off most on full rebuilds, cross-repo validation,
>   test runs, and installs. MSBuild/esbuild/tsc are already multi-core — the lever is
>   not serializing the independent pieces.

## Flow shapes
- **Backend-only:** steps 1–2 + backend validate + docs. Note any frontend type
  that will need a follow-up.
- **Frontend-only:** step 4 + frontend validate; still **read** the backend
  contract to avoid guessing shapes.
- **Full-stack:** all steps; in the summary, separate backend changes from
  frontend changes and list the files read on each side.

## Guardrails
- Don't expose entities over the API — always DTOs.
- Don't bypass `apiClient` on the frontend or `IUnitOfWork` on the backend.
- Don't edit applied migrations. Don't add dependencies without asking.
- Surface security concerns (authz on new endpoints, secrets, input validation).

## Authoritative references (read on demand)
- [Vertical Slice Architecture (Jimmy Bogard)](https://www.jimmybogard.com/vertical-slice-architecture/)
- [Google Engineering Practices — Code Review](https://google.github.io/eng-practices/review/)
- [Trunk-Based Development](https://trunkbaseddevelopment.com/)
- [Definition of Done (Atlassian)](https://www.atlassian.com/agile/project-management/definition-of-done)
- [OpenAPI in ASP.NET Core](https://learn.microsoft.com/aspnet/core/fundamentals/openapi/overview)

**Current best practice (2025-26):** build features as **vertical slices**
(UI → model → validation → data) — maximize coupling within a slice, minimize
between slices, so new work mostly *adds* code. Keep the FE/BE contract honest by
emitting the OpenAPI doc at build time and code-generating TS types from it, so
the camelCase wire shape can't silently drift. Treat Definition of Done as a
living checklist (tests, docs, review, staging) distinct from per-story
acceptance criteria.

## Auto-learn after each task
After a task that used this skill, reflect and improve it (full loop in
[docs-maintenance](../docs-maintenance/SKILL.md)): fold in any better pattern,
corrected fact, exact command/path, or gotcha you found — edit this `SKILL.md`
surgically in its existing style; refresh the references above if a source or
version changed; cascade to [PROJECT_OVERVIEW.md](../../../PROJECT_OVERVIEW.md)
and the owning repo's deep docs when a feature/contract/package/resource changed;
then say in one line what you updated.
