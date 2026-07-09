---
name: app-lifecycle
description: "Start and stop the whole TravelPlanner stack in local debug/Development mode from chat. Use when the user says 'start', 'run', 'stop', 'restart', 'launch the app', or wants the backend API, the AI worker, and the frontend dev server up or down. Knows the exact projects, launch profiles, ports, health URLs, prerequisites, and stop/cleanup commands."
---

# App Lifecycle (Start / Stop in Debug) Skill

The user can control the local stack with a bare message:

| Message (or similar) | Action |
|----------------------|--------|
| **start** / run / launch | Start all three debug services, then report URLs |
| **stop** / kill / shutdown | Stop all three services and free the ports |
| **restart** | Stop, then start |
| **status** | Report which services are listening (ports 7071 / 5173) |

Treat a message that is essentially just "start" or "stop" as this command — do
**not** ask for clarification; act, then confirm what happened.

> **User preference (this workspace):** "start the backend" always means **API +
> AI Worker together** — the user considers the worker part of the backend
> ("the background jobs"). Never start the API alone; always bring the worker up
> too unless the user explicitly says API-only.

## The three services

| Service | Folder | Command (launch profile = Development) | Listens on |
|---------|--------|----------------------------------------|------------|
| Backend API | `TravelPlanner/` | `dotnet run --project TravelPlannerAPI --launch-profile https` | `https://localhost:7071` (+ `http://localhost:5245`), Swagger at `/swagger` |
| AI Worker | `TravelPlanner/` | `dotnet run --project TravelPlannerAiWorker` (`DOTNET_ENVIRONMENT=Development`) | no HTTP — drains the `ai-itinerary-jobs` Azure queue |
| Frontend | `travel-planner-frontend/` | `npm run dev` | `http://localhost:5173` |

These are codified as VS Code tasks in [.vscode/tasks.json](../../.vscode/tasks.json):
`Backend: API (debug)`, `Backend: AI Worker (debug)`, `Frontend: Dev (Vite)`, and
the compound **`Start All (debug)`**.

## START procedure
1. Prefer the **`Start All (debug)`** task (or run the three commands as
   **background** terminals — one per service, never block the turn).
2. Start order doesn't strictly matter, but API + Worker before the frontend is
   tidiest. The Worker and API are independent processes (the worker only needs
   the DB + Azure queue reachable).
3. Wait for readiness signals, then confirm:
   - API: `Now listening on: https://localhost:7071` → open `https://localhost:7071/swagger`.
   - Frontend: Vite prints `Local: http://localhost:5173/`.
   - Worker: `Application started` / polling logs.
4. Report the URLs and that all three are up. If a service is already listening
   on its port, say so instead of starting a duplicate.

## STOP procedure
1. If you started them as tracked background terminals/tasks, **terminate those**
   first (kill the terminals / "Terminate Task").
2. Fallback — free the ports on Windows PowerShell (run from any cwd):
   ```powershell
   foreach ($p in 7071,5245,5173) {
     Get-NetTCPConnection -LocalPort $p -State Listen -ErrorAction SilentlyContinue |
       Select-Object -Expand OwningProcess -Unique |
       ForEach-Object { Stop-Process -Id $_ -Force -ErrorAction SilentlyContinue }
   }
   ```
   The AI worker has no port — stop it via its task/terminal, or (last resort,
   **only if no other .NET app is running**) the `dotnet`/`TravelPlannerAiWorker`
   process. Never blanket-kill all `dotnet`/`node` without warning the user.
3. Confirm the ports are free.

## Prerequisites (check if a service fails to start)
- **.NET 8 SDK** (`dotnet --version`) and **Node** (`npm --version`).
- **SQL Server Express** running and the two databases migrated — see
  [ef-migrations](../ef-migrations/SKILL.md). A DB connection failure is the most
  common API/worker startup error.
- Backend secrets present (Azure Foundry, Azure Storage, JWT, SMTP). The AI worker
  needs the Azure Queue connection; the API additionally needs JWT + SMTP.
- **Worker DI mirroring** — the worker builds its own curated DI graph in
  [TravelPlannerAiWorker/Program.cs](../../../TravelPlanner/TravelPlannerAiWorker/Program.cs).
  If a service the AI pipeline touches gains a new dependency (e.g. a Contract
  like `TravelRequestReader` or a module UoW like `IDynamicConfigUnitOfWork`),
  it must be registered there too or the worker dies at startup with
  `Unable to resolve service for type '…UnitOfWork' while attempting to activate
  '…Reader'`. Fix = add the matching `AddScoped` mirroring the API's
  `<Module>ModuleExtensions.cs`, not disabling DI validation.
- Frontend talks to `https://localhost:7071`; the dev TLS cert must be trusted
  (`dotnet dev-certs https --trust`) or the browser will block API calls.

## Notes
- For hot reload you may substitute `dotnet watch --project <proj>` and Vite's
  built-in HMR; plain `dotnet run` is the deterministic default used above.
- This is **local debug only**. For cloud resources/deploys see
  [azure-resources](../azure-resources/SKILL.md).

## Authoritative references (read on demand)
- [`dotnet run`](https://learn.microsoft.com/dotnet/core/tools/dotnet-run) · [`dotnet watch`](https://learn.microsoft.com/dotnet/core/tools/dotnet-watch)
- [Environments & launch profiles](https://learn.microsoft.com/aspnet/core/fundamentals/environments) · [Enforce HTTPS / dev certs](https://learn.microsoft.com/aspnet/core/security/enforcing-ssl)
- [Vite dev server](https://vite.dev/guide/) · [VS Code tasks](https://code.visualstudio.com/docs/editor/tasks)

**Current best practice (2025-26):** select a profile with `dotnet run -lp <name>`
(driven by `launchSettings.json`); `dotnet watch` gives hot reload and restarts on
rude edits. Trust the dev cert once with `dotnet dev-certs https --trust`. The
compound `Start All` task lists services in `dependsOn` (parallel by default) —
long-running servers/watchers need `"isBackground": true` plus a background
`problemMatcher` so VS Code knows when each is "ready."

## Auto-learn after each task
After a task that used this skill, reflect and improve it (full loop in
[docs-maintenance](../docs-maintenance/SKILL.md)): fold in any better pattern,
corrected fact, exact command/path, or gotcha you found — edit this `SKILL.md`
surgically in its existing style; refresh the references above if a source or
version changed; cascade to [PROJECT_OVERVIEW.md](../../../PROJECT_OVERVIEW.md)
and the owning repo's deep docs when a feature/contract/package/resource changed;
then say in one line what you updated.
