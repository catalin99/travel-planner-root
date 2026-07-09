---
name: docs-maintenance
description: "Read and keep the TravelPlanner documentation current across both repos and the workspace root: the living PROJECT_OVERVIEW.md, backend living docs (REPO_OVERVIEW, PHASE1_MODULARIZATION, DB_PERFORMANCE_PLAN), per-controller API docs, API_ENDPOINTS_AND_DTOS.md, AI prompt assets, the .github instructions/skills/agent, and the frontend README/rework. Use to look up authoritative docs and to update them (the self-improvement loop) after any contract, module, schema, pipeline, package, or resource change."
---

# Documentation Maintenance & Self-Improvement Skill

Treat docs as part of the change, not an afterthought. When code shifts, update
the matching doc in the **same** repo so the next session reads accurate context.

## Where the docs live

### Backend (`TravelPlanner/`)
| Doc | Update it when… |
|-----|-----------------|
| [docs/Architecture/REPO_OVERVIEW.md](../../../TravelPlanner/docs/Architecture/REPO_OVERVIEW.md) | projects, modules, hosts, DbContexts, or the cross-process flow change |
| [docs/Architecture/PHASE1_MODULARIZATION.md](../../../TravelPlanner/docs/Architecture/PHASE1_MODULARIZATION.md) | a module boundary / contract / stage of the refactor advances |
| [docs/Architecture/DB_PERFORMANCE_PLAN.md](../../../TravelPlanner/docs/Architecture/DB_PERFORMANCE_PLAN.md) | indexes/query hot paths or perf decisions change |
| [docs/API/](../../../TravelPlanner/docs/API) (one `.md` per controller) | a controller's routes, auth, or response shapes change |
| [API_ENDPOINTS_AND_DTOS.md](../../../TravelPlanner/API_ENDPOINTS_AND_DTOS.md) | any endpoint or DTO is added/changed (high-level catalogue) |
| [docs/AiPrompts/](../../../TravelPlanner/docs/AiPrompts) | the AI system prompt / output schema changes (also kept as a build-copied asset) |
| [.github/copilot-instructions.md](../../../TravelPlanner/.github/copilot-instructions.md) + [.github/instructions/](../../../TravelPlanner/.github/instructions) | a convention, pattern, or rule changes (this file mirrors the scoped instructions for VS 2026) |

### Frontend (`travel-planner-frontend/`)
| Doc | Update it when… |
|-----|-----------------|
| [README.md](../../../travel-planner-frontend/README.md) | setup, scripts, or tech stack change |
| [rework.md](../../../travel-planner-frontend/rework.md) | the trip-form UX (Quick vs Full planner, progressive disclosure) evolves |
| [.github/copilot-instructions.md](../../../travel-planner-frontend/.github/copilot-instructions.md) + [.github/skills/](../../../travel-planner-frontend/.github/skills) | frontend conventions or stack idioms change |

### Workspace root (`c:\Projects`)
- [PROJECT_OVERVIEW.md](../../../PROJECT_OVERVIEW.md) — the **short, living**
  product map (features, architecture, packages-per-area, AI features, Azure
  resources, monetization). Update it after **any** task that changes a feature,
  an architecture decision, a library/package, an AI capability, or a cloud
  resource. Keep it terse — it is auto-maintained, not a manual.
- [.github/copilot-instructions.md](../../copilot-instructions.md) — the always-on
  cross-repo map. Update if the repos move, the connection contract changes, or
  the agent/skill set changes.
- [.github/agents/](../../agents) and [.github/skills/](../../skills) — **improve
  the agent and skills themselves** when you learn a better pattern, a corrected
  fact, an exact command/path, or a recurring gotcha.

## Self-improvement loop (run at the end of each task)

1. Did a **feature / architecture / package / AI capability / Azure resource**
   change? → update [PROJECT_OVERVIEW.md](../../../PROJECT_OVERVIEW.md).
2. Did a **convention, command, path, or pattern** change, or did you hit a
   gotcha worth remembering? → refine the **owning skill** (or the agent file),
   matching its style, without bloating it.
3. Did a **contract / endpoint / module / schema / prompt** change? → update the
   matching deep doc in the owning repo (tables above).
4. Record durable lessons in memory when available.
5. Tell the user, in one line, which docs/skills you updated.

Keep every edit surgical and only when something genuinely changed — churn-free
docs stay trustworthy.

## Procedure
1. **Reading:** prefer the doc for orientation, but **cross-check the actual
   code** — markdown can lag (especially `API_ENDPOINTS_AND_DTOS.md` and
   `docs/API/*`). Trust the `.cs`/`.ts` source when they disagree, and fix the doc.
2. **Updating:** keep edits surgical and factual; match the existing structure and
   tone (these are concise living docs, not essays). Don't duplicate content
   across docs — link instead.
3. **Scope correctly:** backend docs into `TravelPlanner/`, frontend docs into
   `travel-planner-frontend/`, cross-repo map into the root `.github/`. They are
   separate git repos — each doc commits with its own repo.
4. **Don't create new doc files** unless the user asks or a genuinely new topic
   has no home.

## Authoritative references (read on demand)
- [Diátaxis](https://diataxis.fr/) · [arc42](https://arc42.org/)
- [ADRs (adr.github.io / MADR)](https://adr.github.io/) · [Nygard — Documenting Architecture Decisions](https://cognitect.com/blog/2011/11/15/documenting-architecture-decisions.html) · [ADR templates](https://github.com/architecture-decision-record/architecture-decision-record)
- [Docs as Code (Write the Docs)](https://www.writethedocs.org/guide/docs-as-code/) · [Make a README](https://www.makeareadme.com/)

**Current best practice (2025-26):** split docs by **Diátaxis** modes — tutorial,
how-to, reference, explanation — and never mix two modes on one page. Keep ADRs
immutable, numbered, in-repo (supersede rather than edit, so history stays
auditable). Adopt **docs-as-code**: docs live in Git, change via PR review, and CI
can block a feature merge that ships without the matching doc update — this is what
keeps the "living docs" actually current.

## Auto-learn after each task
This skill *owns* the self-improvement loop above — apply it to this file too:
when you discover a better doc home, framework, or convention (or a reference
changes), fold it in here and refresh the references, so every future task keeps
itself documented. Keep edits surgical.
