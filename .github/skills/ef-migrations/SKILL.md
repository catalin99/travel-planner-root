---
name: ef-migrations
description: "Run EF Core migrations for the TravelPlanner backend across its TWO DbContexts (TravelPlannerDBContext on DefaultConnection, DynamicConfigDBContext on DynamicConfigConnection). Use when adding/changing an entity or model configuration, applying or reverting schema changes, or troubleshooting schema drift. Covers exact add/update/revert/script commands and safety rules."
---

# EF Core Migrations Skill

The backend has **two DbContexts**, so every migration command must name the
right `--context`. Migration project = `TravelPlannerInfrastructure`; startup
project = `TravelPlannerAPI`. Provider = SQL Server. Run all commands from the
**`TravelPlanner/`** folder.

| Context | Connection string | Owns |
|---------|-------------------|------|
| `TravelPlannerDBContext` | `DefaultConnection` | Identity, TravelRequest, ItineraryCalendar, Accommodation, FlightSearch, AiGeneration |
| `DynamicConfigDBContext` | `DynamicConfigConnection` | Locales, CountryType/LocationType/StartingAirportType + other reference types |

> Detailed rules also in
> [TravelPlanner/.github/instructions/migrations.instructions.md](../../../TravelPlanner/.github/instructions/migrations.instructions.md).

## Preconditions
1. The entity is registered in the matching
   `Persistence/Configurations/<Module>ModelConfiguration.cs` **before** you add
   the migration.
2. `dotnet ef` is available (`dotnet tool install --global dotnet-ef` if not).

## Commands (PowerShell, run from `TravelPlanner/`)

Main DB:
```powershell
dotnet ef migrations add <DescriptiveName> -p TravelPlannerInfrastructure -s TravelPlannerAPI -c TravelPlannerDBContext
dotnet ef database update -p TravelPlannerInfrastructure -s TravelPlannerAPI -c TravelPlannerDBContext
```

DynamicConfig DB (note the separate output folder):
```powershell
dotnet ef migrations add <DescriptiveName> -p TravelPlannerInfrastructure -s TravelPlannerAPI -c DynamicConfigDBContext -o Migrations/DynamicConfig
dotnet ef database update -p TravelPlannerInfrastructure -s TravelPlannerAPI -c DynamicConfigDBContext
```

Revert to a previous migration (re-run `database update` with the target name):
```powershell
dotnet ef database update <PreviousMigrationName> -p TravelPlannerInfrastructure -s TravelPlannerAPI -c <Context>
```

Generate an idempotent SQL script (for review / prod):
```powershell
dotnet ef migrations script --idempotent -p TravelPlannerInfrastructure -s TravelPlannerAPI -c <Context> -o migration.sql
```

Remove the last (not-yet-applied) migration:
```powershell
dotnet ef migrations remove -p TravelPlannerInfrastructure -s TravelPlannerAPI -c <Context>
```

## Safety rules
1. **Never edit an applied migration** on a shared DB — add a new one.
2. **One concern per migration**, descriptively named
   (`AddIndex_TravelRequest_UserEmail`, not `Update1`).
3. **Don't hand-edit `*ModelSnapshot.cs`** — let `dotnet ef` regenerate it.
4. **Watch for schema drift:** if a generated migration tries to `CreateTable`
   something already live (a prior migration was skipped), trim those blocks from
   `Up`/`Down` so it only applies the intended delta. Always read the generated
   migration before `database update`.
7. **Multiple cascade paths (SQL error 1785):** a new **optional FK to a table that
   is already cascade-reachable** from the same principal (e.g. `ItineraryBlock →
   ItineraryExperience` when blocks already cascade from the itinerary via days)
   fails at `database update` with *"may cause cycles or multiple cascade paths"*.
   Fix = configure that relationship `.OnDelete(DeleteBehavior.ClientSetNull)` (DB
   NoAction; EF nulls the link client-side). Then `migrations remove`, re-`add`,
   re-`update`. The migration runs in a DDL transaction, so a mid-way failure rolls
   the whole thing back — the DB stays clean for the retry.
5. **Seed data:** universal seeds (locales, country/budget types) go in the
   migration `Up`; per-env data goes in `Persistence/Seed/` runners called from
   `app.InitializeServicesAsync()`.
6. After applying, run `dotnet build` and verify the app starts. Update
   [REPO_OVERVIEW.md](../../../TravelPlanner/docs/Architecture/REPO_OVERVIEW.md) if
   the schema/module shifted ([docs-maintenance](../docs-maintenance/SKILL.md)).

## Authoritative references (read on demand)
- [Migrations overview](https://learn.microsoft.com/ef/core/managing-schemas/migrations/) · [Managing migrations](https://learn.microsoft.com/ef/core/managing-schemas/migrations/managing)
- [Applying migrations (scripts / bundles / runtime)](https://learn.microsoft.com/ef/core/managing-schemas/migrations/applying)
- [Migrations in team environments](https://learn.microsoft.com/ef/core/managing-schemas/migrations/teams)
- [`dotnet ef` CLI reference](https://learn.microsoft.com/ef/core/cli/dotnet)

**Current best practice (2025-26):** for production prefer reviewed **idempotent
scripts** (`migrations script --idempotent`) or **migration bundles** over
`Database.Migrate()` at startup (runtime migration is dev/test only). Wire
`dotnet ef migrations has-pending-model-changes` into CI to catch forgotten
migrations. A property rename scaffolds as `DropColumn`+`AddColumn` (data loss) —
replace with `RenameColumn`. On parallel branches a model-snapshot merge conflict
means diverged trees: remove your migration, merge, then re-add.

## Auto-learn after each task
After a task that used this skill, reflect and improve it (full loop in
[docs-maintenance](../docs-maintenance/SKILL.md)): fold in any better pattern,
corrected fact, exact command/path, or gotcha you found — edit this `SKILL.md`
surgically in its existing style; refresh the references above if a source or
version changed; cascade to [PROJECT_OVERVIEW.md](../../../PROJECT_OVERVIEW.md)
and the owning repo's deep docs when a feature/contract/package/resource changed;
then say in one line what you updated.
