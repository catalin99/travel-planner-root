---
name: fullstack-architecture
description: "The combined TravelPlanner system map across both repos: .NET 8 backend layers/modules/packages and the React 19 frontend structure/packages, plus how they connect (camelCase JSON wire format, JWT auth, base URLs, CORS, roles, type mappings). Use to orient at the start of any non-trivial or full-stack task, to understand layers/connectivity/packages/API definitions, or to locate where a concern lives on either side."
---

# Full-Stack Architecture (TravelPlanner)

Use this skill to **orient** before planning or editing. It is a map and a set of
pointers — read the linked source-of-truth docs for depth instead of trusting
this summary blindly.

## Two repos, one product

| Repo | Path | Stack |
|------|------|-------|
| Backend | [TravelPlanner/](../../../TravelPlanner) | .NET 8 modular monolith |
| Frontend | [travel-planner-frontend/](../../../travel-planner-frontend) | React 19 + Vite 7 + TS 5.9 |

## Backend layers (reference direction: Domain ← Infrastructure ← Application ← API | AiWorker)

| Project | Responsibility |
|---------|----------------|
| `TravelPlannerDomain` | Entities + enums only (Identity, TravelRequest, Flights, ItineraryCalendar, Accommodation, AiQueue, DynamicConfig). No outward deps. Role hierarchy + policies in `Authorization/`. |
| `TravelPlannerInfrastructure` | EF Core (two DbContexts), repositories, `IUnitOfWork` + module UoWs, `Persistence/Configurations/*ModelConfiguration.cs`, `ExternalServices/` (AiModels, AzureQueue, Currency, Flights), Serilog logging proxies. |
| `TravelPlannerApplication` | Business services (`Services/Interfaces` + `Services/Implementations`), DTOs (`DTOs/<Module>/`), Mapster config (`Mapping/`), module contracts (`Modules/<Module>/Contracts/`), `BackgroundServices/`. |
| `TravelPlannerAPI` | ASP.NET Core 8 host. Controllers, `Authorization/HasRoleHandler`, `Configuration/Modules/<Module>ModuleExtensions.cs`, middleware, Swagger. Composition root `Program.cs`. |
| `TravelPlannerAiWorker` | .NET Worker host running `AiQueueProcessorWorker`. Curated DI graph — only the AI pipeline services. |

**Modules** (logical): `Identity`, `TravelRequests`, `ItineraryCalendar`,
`Accommodation`, `AiGeneration`, `DynamicConfig`, `SharedKernel`. Cross-module
reads go through Stage E contracts (`IUserLookup`, `ITravelRequestReader`).

**Key backend packages:** EF Core 8 (SqlServer), Mapster + Mapster.DependencyInjection
(the *only* mapper — no AutoMapper), Serilog, `Microsoft.AspNetCore.Authentication.JwtBearer`,
`Azure.Storage.Queues`, MailKit, Swashbuckle. **No** MediatR / Hangfire / Quartz /
FluentValidation — orchestration is manual in services.

## Frontend structure

```
src/
  config/api.config.ts     ← base URL (https://localhost:7071), axios defaults
  contexts/                ← AuthContext, CurrencyContext, LanguageContext
  hooks/                   ← useFlightSearch, useTravelRequests (server-state hooks)
  services/
    api/                   ← apiClient.ts + one <resource>Service.ts per backend resource
    utility/               ← jwtHelper, localeService, botDetection, blockTypeHelper
  types/                   ← TS types mirroring backend DTOs (camelCase)
  views/{admin,agent,common,home,layout,messages,plan-trip,quick-search,trips,user,utility}
  pages/                   ← legacy/partial; views/ is primary
  routes.tsx               ← central route table (ProtectedRoute guards)
```

**Key frontend packages:** react 19, react-dom 19, react-router-dom 7, axios,
mapbox-gl 3, react-datepicker; dev: vite 7, typescript 5.9, eslint 9 +
typescript-eslint. **No** Redux / MUI / Tailwind / React Query / i18n library —
state is the Context API + custom hooks; styling is plain colocated CSS.

## How the two sides connect

- **Wire format:** camelCase JSON. Keep `src/types/<resource>.ts` matching
  `TravelPlannerApplication/DTOs/<Module>/`.
- **Type mappings:** `Guid`→`string`, `DateTime`→ISO `string`,
  `TimeSpan`→`"HH:mm:ss"`/`"HH:mm"` (backend has `TimeSpanJsonConverter`), enums →
  string-literal unions. Roles: `"User" | "Agent" | "AgentModerator" | "AgentAdministrator" | "Admin" | "SuperAdmin"`.
- **Auth:** JWT bearer; `apiClient` request interceptor adds the token, response
  interceptor handles 401 → refresh. `AuthContext` owns token state.
- **URLs:** API `https://localhost:7071`; frontend `http://localhost:5173`;
  backend CORS is locked to the frontend origin.
- **Async AI work:** API returns `202 Accepted` + a jobId; the frontend polls
  `/api/ai-jobs/{jobId}` (and `/api/flight-suggestions/...`) — see `ai-pipeline`.

## Grounded specifics (memorize these)
- **Local debug:** API `https://localhost:7071` (+ `http://localhost:5245`),
  Swagger `/swagger`, `ASPNETCORE_ENVIRONMENT=Development`; frontend
  `http://localhost:5173`. Start/stop from chat via [app-lifecycle](../app-lifecycle/SKILL.md).
- **Flights:** provider-agnostic search already integrates **Duffel** (default,
  can ticket) and **Aviasales/Travelpayouts** (affiliate); `Flights:Providers` in
  appsettings. AI flight suggestions score a candidate pool with weights
  (`Price` 35, `Duration` 20, `Stops` 15, `Layover` 10, …).
- **Azure:** AI Foundry project `travelplanner-dev`
  (`travelplanner-foundry.services.ai.azure.com`), Storage account
  `travelplannerai` → queue `ai-itinerary-jobs`. DB is **local SQL Express** today
  (Azure SQL is the target). See [azure-resources](../azure-resources/SKILL.md).

## Source-of-truth docs (read on demand)

- Living map: [PROJECT_OVERVIEW.md](../../../PROJECT_OVERVIEW.md) (workspace root).

- Backend: [TravelPlanner/.github/copilot-instructions.md](../../../TravelPlanner/.github/copilot-instructions.md),
  [TravelPlanner/docs/Architecture/REPO_OVERVIEW.md](../../../TravelPlanner/docs/Architecture/REPO_OVERVIEW.md),
  [TravelPlanner/docs/API/](../../../TravelPlanner/docs/API),
  [TravelPlanner/API_ENDPOINTS_AND_DTOS.md](../../../TravelPlanner/API_ENDPOINTS_AND_DTOS.md).
- Frontend: [travel-planner-frontend/.github/copilot-instructions.md](../../../travel-planner-frontend/.github/copilot-instructions.md)
  and skills [react-vite-frontend](../../../travel-planner-frontend/.github/skills/react-vite-frontend/SKILL.md),
  [mapbox-gl](../../../travel-planner-frontend/.github/skills/mapbox-gl/SKILL.md),
  [travel-planner-backend](../../../travel-planner-frontend/.github/skills/travel-planner-backend/SKILL.md).

## Then

Pick the workflow: [feature-workflow](../feature-workflow/SKILL.md) to build or
refactor; [backend-dotnet](../backend-dotnet/SKILL.md) /
[frontend-react](../frontend-react/SKILL.md) for stack-specific depth;
[ef-migrations](../ef-migrations/SKILL.md), [ai-pipeline](../ai-pipeline/SKILL.md),
[background-jobs](../background-jobs/SKILL.md),
[scalability-concurrency](../scalability-concurrency/SKILL.md),
[ui-ux-frontend](../ui-ux-frontend/SKILL.md),
[app-lifecycle](../app-lifecycle/SKILL.md),
[azure-resources](../azure-resources/SKILL.md),
[product-strategy](../product-strategy/SKILL.md),
[pricing-strategy](../pricing-strategy/SKILL.md), or
[docs-maintenance](../docs-maintenance/SKILL.md) as needed.

## Authoritative references (read on demand)
- [.NET Architecture Guides](https://dotnet.microsoft.com/learn/dotnet/architecture-guides) · [Architect modern web apps (eShopOnWeb)](https://learn.microsoft.com/dotnet/architecture/modern-web-apps-azure/) · [Ardalis Clean Architecture](https://github.com/ardalis/CleanArchitecture)
- [Milan Jovanović — modular monolith](https://www.milanjovanovic.tech/blog/what-is-a-modular-monolith) · [Kamil Grzybek — primer](https://www.kamilgrzybek.com/blog/posts/modular-monolith-primer)
- [C4 model](https://c4model.com/)
- [OpenAPI in ASP.NET Core](https://learn.microsoft.com/aspnet/core/fundamentals/openapi/overview) · [openapi-typescript](https://github.com/openapi-ts/openapi-typescript)

**Current best practice (2025-26):** stay a **modular monolith** — in-process
modules with explicit public contracts; extract microservices only for a concrete
driver. Make boundaries **executable**: enforce layer/module rules with
architecture tests (NetArchTest / ArchUnitNET) so violations fail the build, not
review. Treat **OpenAPI as the single source of truth** — emit the spec at build
time and codegen the TS types (openapi-typescript) so the camelCase wire contract
can't drift. Apply C4 only to the depth you need (Context + Container always,
Component on demand).

## Auto-learn after each task
After a task that used this skill, reflect and improve it (full loop in
[docs-maintenance](../docs-maintenance/SKILL.md)): fold in any better pattern,
corrected fact, exact path, or gotcha you found — edit this `SKILL.md` surgically
in its existing style; refresh the references above if a source or version
changed; cascade to [PROJECT_OVERVIEW.md](../../../PROJECT_OVERVIEW.md) and the
owning repo's deep docs when the architecture/contract changed; then say in one
line what you updated.
