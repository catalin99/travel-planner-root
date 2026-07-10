<!-- AUTO-MAINTAINED: the TravelPlanner Full-Stack agent updates this file after any task
     that changes a feature, the architecture, a package, an AI capability, or a cloud
     resource. Keep it SHORT and factual. Deep docs live in each repo (see Reference). -->

# TravelPlanner — Project Overview

**Vision:** best trip, minimum effort. The user enters preferences; the app
AI-assembles a complete, bookable multimodal trip (flights + stay + train + bus +
ferry + car + tours), prices and maps it, and the user confirms and pays once
(bundle + our commission). Secondary: quick search folded into an itinerary
calendar the user can also fill manually.

## Repositories
| Repo | Path | Stack |
|------|------|-------|
| Backend | `TravelPlanner/` | .NET 8 modular monolith — API + AI Worker + EF Core + Azure Queue |
| Frontend | `travel-planner-frontend/` | React 19 + Vite 7 + TypeScript 5.9 |

Local debug: API `https://localhost:7071` (`/swagger`), frontend
`http://localhost:5173`. Say **start** / **stop** in chat to run/stop the stack.

## Features (short)
| Feature | What it does | Status |
|---------|--------------|--------|
| Auth & users | Register/login, JWT (15-min access + rotating refresh, remember-me), email **and phone (SMS OTP)** verification, forgot/reset password, cross-channel change email/phone, GDPR consent + data export + account deletion, login lockout + password policy, 6-role hierarchy | done |
| Travel requests | Create trip brief (destination, dates, people, preferences); quick-search; public code lookup | done |
| AI itinerary generation | Async AI builds a day-by-day calendar (days/blocks) from the request | done |
| Itinerary calendar | View/edit days & blocks; manual fill | done |
| Grouped experiences | Bookable multi-activity "inner trips" (safari, beaches tour) linked across days/hours; created by grouping consecutive blocks or from scratch (auto-absorbing overlapping blocks), editable/ungroupable from the calendar ribbon, blocks drag-and-drop across hours/days and in/out of an activity, links survive save; AI-sourced experiences reserve their window during generation; highlighted on the calendar | done |
| Flight search | Provider-agnostic search (Duffel + Aviasales/Travelpayouts) | done |
| AI flight suggestions | Scores a candidate pool, AI ranks top-N | done |
| Currency | Multi-currency conversion (Frankfurter rates, cached) | done |
| Localization | RO/EN locale text, in-memory cache + refresh | done |
| Pricing & entitlements | Annual tiers (Free/Plus/Pro/Ultra) + per-trip **Trip Pass** (booking-unlock); credit-metered AI generation with hierarchical limits; **simulated** upgrade + booking (no payments yet); `/plans` page, header usage meter, contextual upgrade dialog, admin metrics | done (payment-free) |
| Guest demo | Anonymous visitors see a zero-cost pre-baked sample AI itinerary (`/demo`) with sign-up / see-plans CTAs | done |
| Admin/Agent | User management, agent trip views, rate-limit admin, subscription metrics, dynamic config | done |
| Booking & single-payment package | Confirm + pay a bundled multimodal trip | **planned** |
| Multimodal inventory | Accommodation, tours, rail, bus, ferry, car | **planned** |

## Architecture (design)
- **Backend:** Clean Architecture / modular monolith. Reference direction
  `Domain ← Infrastructure ← Application ← (API | AiWorker)`. Modules: Identity,
  TravelRequests, ItineraryCalendar, Accommodation, AiGeneration, Subscription,
  DynamicConfig, SharedKernel; cross-module reads via `Modules/<Module>/Contracts/`.
  Unit-of-Work + Repository over EF Core (two DbContexts). Mapster for mapping. Serilog
  with per-request correlation id. JWT bearer + policy-based roles.
- **Async AI:** API enqueues an `AiQueuedJob` to Azure Queue Storage and returns
  `202`; the separate **AI Worker** drains the queue and generates in batches with
  retries and cross-process cancellation. Frontend polls job status.
- **Frontend:** Context API (Auth/Currency/Language) + custom hooks; all HTTP via a
  shared axios `apiClient` (Bearer + 401→refresh); TS types in `src/types/` mirror
  backend DTOs (camelCase). Plain CSS today; **migrating to Mantine** (UI standard).
- **Contract:** camelCase JSON; `Guid`→`string`, `DateTime`→ISO string, enums→string
  literals.

## Libraries / packages (by area)
- **Backend:** EF Core 8 (SQL Server), Mapster, Serilog, `Microsoft.AspNetCore.
  Authentication.JwtBearer`, `Azure.Storage.Queues`, MailKit (email), Swashbuckle.
  No MediatR/Hangfire/FluentValidation (manual orchestration).
- **Flights:** Duffel (default; can ticket), Aviasales/Travelpayouts (affiliate).
- **Frontend:** react 19, react-router-dom 7, axios, mapbox-gl 3, react-datepicker;
  **Mantine** (`@mantine/core/hooks/form/dates/notifications`) is the adopted UI
  library (incremental migration). Build: Vite 7, TypeScript 5.9, ESLint 9.

## AI features
- **Itinerary generation** — Azure AI Foundry (OpenAI-compatible Responses API),
  outline phase → batched day generation → parse → transactional save. System prompt
  in `TravelPlanner/docs/AiPrompts/itinerary-agent-instructions.md`.
- **Flight suggestions** — pre-scored candidate pool ranked by an AI agent; prompt in
  `docs/AiPrompts/flight-suggestions-agent-instructions.md`.
- **Role/plan-based model selection** — `gpt-4.1-mini` for Free/`User`, `gpt-5.4-mini`
  for premium plans/paid roles. The Subscription module's entitlement engine
  (`ISubscriptionService.ResolveModelForUser` via `AiModelSettings`) picks the more
  capable of the plan tier and the user's role — see pricing-strategy skill.
- **Grouped experiences** — pre-booked/sourced experiences persisted on the travel
  request (`TravelRequestExperience` + segments) are reserved in the prompt and
  materialised verbatim into linked `ItineraryExperience` blocks by the worker
  (`ExperiencePlanner`); the AI never invents their internal activities. Attached via
  the frontend `ExperienceManager` or `POST /api/travelrequestexperiences`. A
  provider seam (`IExperienceProvider` + AI `IExperienceQueryBuilder`/
  `IExperienceResultMapper`, config-driven like Flights) lets a real GetYourGuide/
  Viator connector drop in later via `.../source` — ships disabled today.
- Cooperative cross-process cancellation via `AiQueuedJob.CancellationRequested`.

## Cloud resources (Azure)
- **Azure AI Foundry** — resource `travelplanner-foundry`, project `travelplanner-dev`,
  deployments `gpt-4.1-mini` / `gpt-5.4-mini`.
- **Azure Storage account** `travelplannerai` → Queue `ai-itinerary-jobs`.
- **Database** — currently local SQL Express (`travelplanner`,
  `travelplanner_dynamicconfig`); Azure SQL is the cloud target.
- Email via Gmail SMTP (not Azure). See the `azure-resources` skill.

## Monetization (intended)
Bundled package (merchant + commission) · AI features by subscription with credit
metering · quick-search via affiliate/referral. Details in the `pricing-strategy`
skill.

**Implemented (payment-free):** a full subscription + entitlements system — annual
tiers Free/Plus/Pro/Ultra + per-trip **Trip Pass** (unlocked by booking with us),
stored in DynamicConfig (`SubscriptionPlanType`) + main DB (`UserSubscription`,
`TripEntitlement`, `FeatureUsageLog`). AI itinerary generation is gated by a
hierarchical check (Trip Pass → subscription: per-trip generations + distinct-trips-
per-year) returning **HTTP 402** with an upgrade payload; flight suggestions are a
soft-gated plan feature. Upgrade + booking are **simulated** today
(`POST /api/subscription/change`, `.../trips/{id}/unlock`) — the exact seams a future
Stripe (merchant-of-record) webhook + real checkout will drive with zero rework.
A daily `SubscriptionMaintenanceJob` rolls annual periods forward (resetting
allowances) and prunes old usage. Plan catalog is seeded via a tracked MERGE; the
living plan is `PRICING_IMPLEMENTATION_PLAN.md`.

## Reference (deep docs)
- Cross-repo map: `.github/copilot-instructions.md`; agent: `.github/agents/`;
  skills: `.github/skills/`.
- Backend: `TravelPlanner/.github/copilot-instructions.md`, `TravelPlanner/docs/`,
  `TravelPlanner/API_ENDPOINTS_AND_DTOS.md`.
- Frontend: `travel-planner-frontend/.github/copilot-instructions.md` + skills.
