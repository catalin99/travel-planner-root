# Travel Planner Workspace — Cross-Repo Instructions

This `c:\Projects` workspace contains **two independent git repositories** that
together form one product. These instructions are always loaded and give every
chat the canonical map of both sides. **Do not paste file contents here** —
always read files fresh from disk so uncommitted edits are reflected.

## The two repositories

| Repo | Path (workspace-relative) | Stack |
|------|---------------------------|-------|
| **Backend** | [TravelPlanner/](TravelPlanner) | .NET 8 modular monolith (API + AI Worker + EF Core + Azure Queues) |
| **Frontend** | [travel-planner-frontend/](travel-planner-frontend) | React 19 + Vite 7 + TypeScript 5.9 (axios, react-router 7, mapbox-gl) |

> `c:\Projects` itself is **not** a git repo — each subfolder is its own repo,
> each with its own `.git` and its own `.github/`. Changes to one repo do not
> commit into the other. When a task spans both, edit and validate each side in
> its own folder.

## The unified agent

Use the **TravelPlanner Full-Stack** agent ([.github/agents/travelplanner-fullstack.agent.md](.github/agents/travelplanner-fullstack.agent.md))
for any backend, frontend, full-stack, cloud, or product task. It bundles
on-demand skills under [.github/skills/](.github/skills): `fullstack-architecture`,
`backend-dotnet`, `frontend-react`, `ef-migrations`, `ai-pipeline`,
`background-jobs`, `scalability-concurrency`, `ui-ux-frontend`,
`responsive-mobile-ui`, `app-lifecycle`, `azure-resources`, `product-strategy`,
`pricing-strategy`, `feature-workflow`, `localization`, `workspace-init`, and
`docs-maintenance`.

## Living overview & self-improvement

[PROJECT_OVERVIEW.md](PROJECT_OVERVIEW.md) (workspace root) is a **short,
auto-maintained** map of features, architecture, packages, AI capabilities, and
Azure resources. The agent keeps it (and the relevant skills) current after any
task that changes them. Every skill carries an **Authoritative references** list
(consulted during a task) and an **Auto-learn after each task** footer (applied
afterward) so the skill set keeps improving itself.

## Start / stop the app

Saying **start** / **stop** / **restart** in chat runs or stops the local debug
stack (API `https://localhost:7071`, AI worker, frontend `http://localhost:5173`)
via the `app-lifecycle` skill and [.vscode/tasks.json](.vscode/tasks.json).

## How the two sides connect

- **Wire format:** camelCase JSON (backend `JsonNamingPolicy.CamelCase`). TS
  types in `travel-planner-frontend/src/types/` must mirror the backend DTOs in
  `TravelPlanner/TravelPlannerApplication/DTOs/<Module>/`.
- **Auth:** JWT bearer issued by `TravelPlannerAPI`; the frontend axios client
  ([travel-planner-frontend/src/services/api/apiClient.ts](travel-planner-frontend/src/services/api/apiClient.ts))
  injects `Authorization: Bearer <token>` and handles 401 → refresh.
- **Local URLs:** API at `https://localhost:7071`, frontend dev server at
  `http://localhost:5173`. Backend CORS is locked to the frontend origin.
- **Roles (shared, 6 levels):** `User`, `Agent`, `AgentModerator`,
  `AgentAdministrator`, `Admin`, `SuperAdmin`.
- **Type mappings:** C# `Guid` → TS `string`; `DateTime` → ISO `string`;
  `TimeSpan` → `"HH:mm:ss"`/`"HH:mm"`; enums round-trip as string literals.

## Authoritative deep docs (read on demand, do not duplicate)

- Backend rules & architecture: [TravelPlanner/.github/copilot-instructions.md](TravelPlanner/.github/copilot-instructions.md)
  and [TravelPlanner/docs/](TravelPlanner/docs) (`Architecture/`, `API/`, `AiPrompts/`).
- API + DTO catalogue: [TravelPlanner/API_ENDPOINTS_AND_DTOS.md](TravelPlanner/API_ENDPOINTS_AND_DTOS.md).
- Frontend rules & skills: [travel-planner-frontend/.github/copilot-instructions.md](travel-planner-frontend/.github/copilot-instructions.md)
  and [travel-planner-frontend/.github/skills/](travel-planner-frontend/.github/skills).

## Golden rules

1. **Read before edit.** Open the matching backend `.cs` (DTO / controller /
   entity) before changing a frontend type or service, and vice-versa.
2. **Respect module boundaries** on the backend; cross-module reads go through
   `Modules/<Module>/Contracts/` (`IUserLookup`, `ITravelRequestReader`, …).
3. **Mirror DI in both hosts** (`<Module>ModuleExtensions.cs` *and*
   `TravelPlannerAiWorker/Program.cs`) when a new service is used by the worker.
4. **Migrations:** EF Core, two DbContexts — see the `ef-migrations` skill.
5. **Stay in the existing stack** — no new dependencies without asking.
6. **Validate** each side: backend `dotnet build`; frontend `npm run lint` +
   `npm run build`.
7. **Never commit secrets.** Resolve them from user-secrets / Key Vault and
   managed identity in cloud (see the `azure-resources` skill).
