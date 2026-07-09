---
name: workspace-init
description: "Reconstruct the full TravelPlanner working folder structure from the travel-planner-root meta repo by cloning the two product repos (travel-planner-BE -> TravelPlanner/, travel-planner-FE -> travel-planner-frontend/) into place. Use when setting up the workspace on a new machine/clone, when a product folder is missing, or to explain how the root repo relates to the two product repos. The product repos are gitignored in root and are the only ones deployed."
---

# Workspace Init Skill

`c:\Projects` (the **travel-planner-root** repo) tracks only shared/meta files
(`.github` AI tooling, `.vscode`, `PROJECT_OVERVIEW.md`, IATA data). The two product
repos are **gitignored** and must be cloned in to get a working tree.

## The three repositories

| Folder | GitHub repo | Role |
|--------|-------------|------|
| `.` (root) | `catalin99/travel-planner-root` | Meta only — AI tooling + shared data. **Not deployed.** |
| `TravelPlanner/` | `catalin99/travel-planner-BE` | .NET 8 backend (API + AI worker). Deployed. |
| `travel-planner-frontend/` | `catalin99/travel-planner-FE` | React 19 + Vite frontend. Deployed. |

Default branch for both product repos: **`master`**.

## Reconstruct the workspace (preferred)

Run the bootstrap script from the root — it is idempotent (skips a folder that is
already a git repo, warns on a non-empty non-repo folder):

```powershell
cd c:\Projects
./init.ps1
```

Optional overrides: `./init.ps1 -Branch master -Root c:\Projects`.

## Equivalent manual clone

```powershell
cd c:\Projects
git clone --branch master https://github.com/catalin99/travel-planner-BE.git TravelPlanner
git clone --branch master https://github.com/catalin99/travel-planner-FE.git travel-planner-frontend
```

The target **folder names must match exactly** (`TravelPlanner`, `travel-planner-frontend`)
— the root `.gitignore`, `.vscode/tasks.json`, and every skill reference those paths.

## Rules & gotchas

- **Never commit the product folders into root.** They are gitignored on purpose; each
  has its own `.git`, history, and deploy. If `git status` in root shows `TravelPlanner/`
  or `travel-planner-frontend/` as trackable, the `.gitignore` entry is missing.
- **Deploy from the product repos only** — root is never deployed.
- `init.ps1` clones from the remotes, so it reproduces **pushed** state. Commit & push
  in-progress work in the product repos before relying on it to reconstruct elsewhere.
- Prereqs for a working stack after init: .NET 8 SDK, Node, SQL Server Express + migrated
  DBs, and backend secrets — see the `app-lifecycle` and `ef-migrations` skills.

## Authoritative references (read on demand)
- [`git clone`](https://git-scm.com/docs/git-clone) · [gitignore](https://git-scm.com/docs/gitignore)
- [Managing multiple repos / meta-repo patterns](https://git-scm.com/book/en/v2/Git-Tools-Submodules) (context only — this workspace uses **independent** repos, not submodules)

**Current best practice (2025-26):** keep independent product repos independently
deployable; a thin **meta/root repo** that versions shared tooling + a bootstrap script
(and gitignores the product checkouts) is simpler and less error-prone than git submodules
for a small set of repos, and keeps CI/CD scoped to each product repo.

## Auto-learn after each task
After a task that used this skill, reflect and improve it: if a product repo URL, folder
name, default branch, or the bootstrap flow changed, update this `SKILL.md`, `init.ps1`,
the root `README.md`, and (if the structure changed) [PROJECT_OVERVIEW.md](../../../PROJECT_OVERVIEW.md);
then say in one line what you updated.
