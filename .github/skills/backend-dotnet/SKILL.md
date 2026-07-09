---
name: backend-dotnet
description: "Expert workflow for the TravelPlanner .NET 8 backend: where new services/repositories/DTOs/entities go, module boundaries and Stage E contracts, Unit-of-Work + Repository usage, Mapster mapping, Serilog + correlation ids, DI lifetimes, async/cancellation, and error handling. Use when adding or refactoring backend C# code in TravelPlanner/."
---

# Backend (.NET 8) Skill

Deep rules live in [TravelPlanner/.github/copilot-instructions.md](../../../TravelPlanner/.github/copilot-instructions.md)
(it mirrors the scoped files under
[TravelPlanner/.github/instructions/](../../../TravelPlanner/.github/instructions)).
Read it first; this skill is the quick operating procedure.

## When to use
- Adding/refactoring a service, repository, DTO, entity, controller, or module.
- Wiring DI in a `<Module>ModuleExtensions.cs`.
- Questions about layering, UoW, Mapster, Serilog, DI lifetimes, cancellation.

## Where new code goes (match the module)

| Artifact | Location |
|----------|----------|
| Service interface / impl | `TravelPlannerApplication/Services/Interfaces/<Module>/` and `.../Implementations/<Module>/` |
| DTO | `TravelPlannerApplication/DTOs/<Module>/` (`Get*`/`Create*`/`Update*`) — never expose entities |
| Cross-module contract | `TravelPlannerApplication/Modules/<Module>/Contracts/` (e.g. `IUserLookup`, `ITravelRequestReader`) |
| Repository interface / impl | `TravelPlannerInfrastructure/Repositories/Interfaces/<Module>/` and `.../Implementations/<Module>/` |
| Entity | `TravelPlannerDomain/Entities/<Module>/` + a config block in the matching `Persistence/Configurations/<Module>ModelConfiguration.cs`, then **add a migration** |
| Mapster `IRegister` | `TravelPlannerApplication/Mapping/` |
| DI registration | `TravelPlannerAPI/Configuration/Modules/<Module>ModuleExtensions.cs` (composed by `ApplicationServiceExtensions`) |

## Core patterns

- **Unit of Work + Repository:** inject `IUnitOfWork` (or the narrower module UoW
  in `Infrastructure/UnitOfWork/Modules/`). A single DbContext is shared; call
  `CompleteAsync` / transaction methods to save. Don't `new` a DbContext.
- **Cross-module access only via contracts.** Never reach into another module's
  repositories or entities directly.
- **Mapster only** (`MapsterMapper.ServiceMapper`). Use `.Adapt<TDest>()` or an
  injected `IMapper`; put custom maps in an `IRegister` under `Mapping/`. Never
  hand-write DTO↔entity mappers. Global config is scanned from the
  `TravelPlannerApplication` assembly — keep `IRegister` classes there.
- **DI lifetimes:** repositories, UoWs, and DbContext-touching services = Scoped;
  stateless cross-cutting providers (currency, queue), `AiJobCancellationTracker`,
  `ILocaleService` = Singleton; `HttpClient`-bound providers via
  `AddHttpClient<TInterface,TImpl>`. Copy the shape from a sibling module.
- **Async + cancellation:** all EF/HTTP calls async; public methods accept
  `CancellationToken cancellationToken = default` and thread it through.
- **Logging:** inject `ILogger<T>`; structured templates
  (`_logger.LogInformation("Done. Id={Id}.", id)`); correlation via
  `TransactionContext.TransactionId` (`TransactionIdEnricher`). Some interfaces use
  `services.DecorateWithLogging<T>()` — follow that pattern for new public services.
- **Errors:** throw domain-meaningful exceptions (`KeyNotFoundException`,
  `InvalidOperationException`, `UnauthorizedAccessException`); the global filter
  translates them. Don't swallow `Exception`.

## API conventions
- Controllers inherit `AuthenticatedControllerBase` (exposes user id/email from
  JWT) unless public/admin-only. Route `api/[controller]`, kebab-case sub-routes.
- Authorize with policies: `[Authorize(Policy = "RequireXxx")]` (roles `User`,
  `Agent`, `AgentModerator`, `AgentAdministrator`, `Admin`, `SuperAdmin`).
- DTOs in and out — never entities.

## If the worker needs it
Register the service in **both** the API `<Module>ModuleExtensions.cs` **and**
`TravelPlannerAiWorker/Program.cs` (and mirror the Mapster scan block). See
[ai-pipeline](../ai-pipeline/SKILL.md).

## Validate
From `TravelPlanner/`: `dotnet build`. After entity/model changes also run the
EF migration ([ef-migrations](../ef-migrations/SKILL.md)). Mirror any contract
change on the frontend ([feature-workflow](../feature-workflow/SKILL.md)).

## Authoritative references (read on demand)
- [What's new in C# 12](https://learn.microsoft.com/dotnet/csharp/whats-new/csharp-12)
- [Dependency injection guidelines](https://learn.microsoft.com/dotnet/core/extensions/dependency-injection-guidelines)
- [Architect modern web apps (eShopOnWeb)](https://learn.microsoft.com/dotnet/architecture/modern-web-apps-azure/) · [Ardalis Clean Architecture](https://github.com/ardalis/CleanArchitecture)
- [Kamil Grzybek — Modular Monolith Primer](https://www.kamilgrzybek.com/blog/posts/modular-monolith-primer)
- [Mapster](https://github.com/MapsterMapper/Mapster) · [Serilog.AspNetCore](https://github.com/serilog/serilog-aspnetcore)

**Current best practice (2025-26):** enable DI **scope validation** to catch
captive dependencies (a singleton holding a scoped service); never register
`IDisposable` as transient. Mapster: use `ProjectToType<T>()` on `IQueryable` so
mapping folds into the SQL `SELECT` (no over-fetch). Serilog: add
`UseSerilogRequestLogging()` + enrich via `IDiagnosticContext.Set(...)` to collapse
noisy per-request events into one structured event. Remember EF Core's `DbContext`
*is* a UoW and `DbSet<T>` *is* a repository — add custom repos only for aggregate
boundaries/testability.

## Auto-learn after each task
After a task that used this skill, reflect and improve it (full loop in
[docs-maintenance](../docs-maintenance/SKILL.md)): fold in any better pattern,
corrected fact, exact command/path, or gotcha you found — edit this `SKILL.md`
surgically in its existing style; refresh the references above if a source or
version changed; cascade to [PROJECT_OVERVIEW.md](../../../PROJECT_OVERVIEW.md)
and the owning repo's deep docs when a feature/contract/package/resource changed;
then say in one line what you updated.
