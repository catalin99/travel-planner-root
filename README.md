# travel-planner-root

The **root / meta repository** for the TravelPlanner product workspace. It holds only
the shared, cross-repo assets — it is **not** deployed and contains **no product code**.

## What lives here

| Path | Purpose |
|------|---------|
| [.github/](.github) | AI development tooling: the **agents**, **skills**, and **copilot-instructions** used to build the product. |
| [.vscode/](.vscode) | Workspace tasks (start/stop the local stack, parallel validation). |
| [PROJECT_OVERVIEW.md](PROJECT_OVERVIEW.md) | Living, auto-maintained map of the whole product. |
| `iata_airports_all.csv` / `.xlsx`, `GEt-Iata.ps1` | Shared IATA airport reference data + its generator. |
| [init.ps1](init.ps1) | Bootstrap script that clones the two product repos into place. |

## The two product repos (not stored here)

The actual application lives in **two separate GitHub repositories**, each with its own
history and its own deployment. They are **gitignored** in this root repo:

| Folder | Repository | Stack |
|--------|-----------|-------|
| `TravelPlanner/` | [catalin99/travel-planner-BE](https://github.com/catalin99/travel-planner-BE) | .NET 8 backend (API + AI worker) |
| `travel-planner-frontend/` | [catalin99/travel-planner-FE](https://github.com/catalin99/travel-planner-FE) | React 19 + Vite + TypeScript |

> **Production/deploy uses those two repos only.** This root repo exists purely to keep
> the AI dev tooling and shared data versioned and reproducible.

## Set up the full workspace

```powershell
git clone https://github.com/catalin99/travel-planner-root.git Projects
cd Projects
./init.ps1        # clones travel-planner-BE -> TravelPlanner/ and travel-planner-FE -> travel-planner-frontend/
```

`init.ps1` is idempotent (skips a folder that is already a git repo). See the
**workspace-init** skill ([.github/skills/workspace-init/SKILL.md](.github/skills/workspace-init/SKILL.md))
for details and options.

> The init script clones the product repos from their remotes, so commit & push any
> in-progress work in `TravelPlanner/` and `travel-planner-frontend/` before relying on it
> to reconstruct the workspace elsewhere.
