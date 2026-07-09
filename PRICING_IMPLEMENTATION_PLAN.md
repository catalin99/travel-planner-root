# TravelPlanner — Pricing & Entitlements Implementation Plan

> Status: **living plan**. Payment-free now (simulated upgrades + simulated bookings),
> but every seam is pre-cut so Stripe (merchant-of-record) and the real booking flow
> drop in later with zero rework. Grounded in `pricing-strategy` + `product-strategy`
> skills and the current codebase.

## 1. Objective

Ship a professional, 2026-grade **annual** subscription + **credit-metered** AI model
where a user can **simulate an upgrade** (and simulate a booking) and **instantly
unlock benefits** — no payment system yet. Benefits are clearly differentiated and
surfaced across the app with tasteful contextual upsells ("Upgrade to X to unlock Y").

## 2. Confirmed decisions

- **Billing period:** annual (travel is episodic; annual smooths churn between trips).
- **Trip Pass model:** cheap (`gpt-4.1-mini`); premium model is an **Ultra** perk.
- **Illustrative annual prices (display-only, nothing charges):**
  Free $0 · **Plus $15/yr** · **Pro $79/yr** · **Ultra $179/yr**.
- **Two simulated events** = the exact future real triggers:
  - `subscription.changed` → later a **Stripe webhook**.
  - `booking.completed` (flight **or** hotel booked with us) → grants a **Trip Pass**
    for that `TravelRequestId` (later fired by real checkout).

## 3. Tiers & entitlements (source of truth)

| Entitlement | Guest (demo) | Free | **Plus** ($15/yr) | **Pro** ($79/yr) | **Ultra** ($179/yr) | **Trip Pass** (booking-unlock) |
|---|---|---|---|---|---|---|
| Saved trips | none (24h code) | up to 3 | **unlimited** | unlimited | unlimited | n/a (the one trip) |
| Trips w/ AI generation / yr | 1 sample | 0 | **5** | ~25 / generous | fair-use | **+1 (this trip, additive)** |
| Generations per trip | 1 (sample) | — | **2** | more | high | **2** |
| Refinements per generation | 0 | — | **2–3** | unlimited | unlimited | 2–3 |
| AI model | cheap | cheap | cheap | **premium** | premium + **priority** | cheap |
| AI flight suggestions | ✗ | ✗ | ✗ | ✓ | ✓ | ✗ |
| Grouped experiences (calendar) | ✗ | view | edit | edit | edit | edit (this trip) |
| Multi-city / long trips | ✗ | ✗ | ✗ | limited | ✓ | ✗ |
| Ads | ✓ | ✓ | ✓ | ✗ | ✗ | — |
| Concierge / export / reduced booking fee | ✗ | ✗ | ✗ | ✗ | ✓ | ✗ |

**Credit costs:** standard itinerary generation = 1; multi-city/long = 2–4;
flight-suggestion run = 1; **in-session refinement = bounded 2–3 per generation**
(cheap model, existing itinerary as context + a small preference delta — NOT a cold
generation). Free tier = cheapest model + hard cap → keeps **AI COGS < 20–30%**.

**COGS check:** Plus = 5 trips × 2 gens = ~10 cheap-model generations/yr (+ bounded
refinements) ≈ $1–2/yr AI cost → huge margin even at $15/yr. Booking-unlocked trips
are funded by their own commission.

## 4. Architecture (three orthogonal axes + trip-scoped grant)

- **Role** = staff permissions (unchanged; 6-level enum).
- **UserStatusCode** = account standing (Standard/Suspended/Trial) — existing, dormant.
- **Plan** = commercial entitlement (**NEW**) — annual `UserSubscription`.
- **Trip Pass** = per-trip grant (**NEW** `TripEntitlement`) — additive, does NOT
  consume plan quota; earned by booking or simulated.

### Model selection
Extend `AiModelSettings.ResolveModelForRoles` → **`ResolveModelForUser(plan, roles)`**
= max(planModel, roleModel). A Plus subscriber OR an internal Agent gets premium; a
Trip Pass uses cheap. Staff override preserved.

### Hierarchical entitlement check (the core engine)

```
Generate itinerary for trip X:
  1. Active Trip Pass for X?  → gens_used(X) < 2 ? allow(cheap) : 402
  2. else Subscription:
       distinct trips-with-gen this sub-year < plan.TripsWithGenerationPerYear ?
       AND gens_used(X) < plan.GenerationsPerTrip ?
         → allow(ResolveModelForUser) ; else 402 {reason, requiredPlan, usage}
  3. Refinement of an existing generation for X:
       refinements_used(gen) < plan.RefinementsPerGeneration ? allow(cheap) : 402
Log usage: FeatureUsageLog { UserId, TravelRequestId, UsageKind, PeriodKey, CreatedAt }
```

Counting reuses the existing `RateLimitRepository` period-count pattern.
Denials return **402** with a structured upgrade payload (not a bare 403).

## 5. Data model

**DynamicConfig DB** — `SubscriptionPlanType : EntityEnumTypeBase` (admin-tunable):
`Code (FREE/PLUS/PRO/ULTRA/TRIP_PASS)`, `SavedTripLimit` (null=unlimited),
`TripsWithGenerationPerYear`, `GenerationsPerTrip`, `RefinementsPerGeneration`,
`ModelTier` (cheap/premium), `AllowsFlightSuggestions`, `AllowsExperiencesEdit`,
`AllowsMultiCity`, `PriorityQueue`, `ShowsAds`, `AnnualPriceDisplay`, `SortOrder`,
+ Ultra flags (`AllowsConcierge`, `AllowsExport`, `ReducedBookingFee`).

**Main DB (TravelPlannerDBContext):**
- `UserSubscription` { `UserId`, `PlanCode`, `Status`, `PeriodStart`, `PeriodEnd`,
  `Source` (Simulated/Stripe), `CreatedAt`, `UpdatedAt` }.
- `TripEntitlement` { `UserId`, `TravelRequestId`, `GrantedPlanCode`, `Source`
  (BookingUnlock/Simulated), `Status`, `GrantedAt`, `BookingRef?` }.
- `FeatureUsageLog` { `UserId`, `TravelRequestId?`, `Feature`, `UsageKind`
  (Generation/Refinement/FlightSuggestion), `CreditCost`, `PeriodKey`, `CreatedAt` }.

Backfill: every existing user → `FREE` active subscription.

## 6. Phases

- **Phase 0 — Spec & locales:** plan codes + RO/EN copy for names, benefit lines, upsell
  strings (localization skill; SQL gitignored, DB is source of truth).
- **Phase 1 — DB & domain:** entities above; EF configs; both migrations; Free backfill;
  seed catalog. *(implementation start)*
- **Phase 2 — Backend engine:** `IEntitlementService` (hierarchical check),
  `ResolveModelForUser`, enforce in `AiJobService` + `FlightSuggestionService`;
  endpoints `GET /subscription/plans`, `GET /subscription/me`,
  `POST /subscription/change` (simulated), `POST /api/trip/{id}/simulate-booking`
  (grants Trip Pass). Mirror DI in the worker. 402 upgrade payload.
- **Phase 3 — FE plumbing:** `types/subscription.ts`, `subscriptionService.ts`,
  `SubscriptionContext`, hooks `useSubscription`/`useEntitlements`/
  `useCanUse(feature, tripId?)`; centralize 402→upgrade in `apiClient`.
- **Phase 4 — FE gating & UX:** `<FeatureGate>`, `<UpgradeDialog>`, per-trip usage
  meter, **`/plans` comparison page**, contextual upsells (see §7). All localized.
- **Phase 5 — Guest demo:** `GUEST` profile = Free-minus-persistence; 1 pre-baked
  sample itinerary; quick search IP-limited; dual CTA (sign up / book to unlock / go
  annual).
- **Phase 6 — Admin, guardrails, analytics, docs:** admin tunes catalog live; annual
  reset job (RateLimitCleanup pattern); KPIs (free→paid, booking-unlock→subscribe,
  wall-hit rate); compliance copy (FTC junk-fee / EU Omnibus all-in price); update
  `PROJECT_OVERVIEW.md` + skills; document Stripe-MoR + booking-unlock seams.

## 7. Where plans surface in the app (tasteful, not annoying)

One dedicated page + a few high-intent contextual nudges (each dismissible, shown at
the moment of value, never stacked):
1. **`/plans`** — full comparison table with clear benefit explanations + tooltips.
2. **Header** — small plan badge + usage meter ("Trip 3/5 · gen 1/2"); "Upgrade" link.
3. **At the AI wall** — when a cap is hit: `<UpgradeDialog>` explaining exactly what
   unlocks (the single most important nudge).
4. **Save-limit wall** (Free → Plus) — "Unlock unlimited saved trips."
5. **Trip page (booked-with-us path)** — "Unlock this trip's AI itinerary by booking
   your flight/stay with us" (ties AI to the commission stream).
6. **Profile** — current plan + renewal + "Manage/Change plan."

Rule: **max one contextual upsell per screen**, only at a natural wall, always with a
concrete benefit + dual CTA.

## 8. The payment/booking seam (future, no rework)

`POST /subscription/change` and `POST /api/trip/{id}/simulate-booking` are the single
state transitions. Today: buttons call them. Later: Stripe Checkout (MoR) webhook →
same `subscription.changed`; real checkout → same `booking.completed` → Trip Pass.
Engine, gating, and UI unchanged.

## 9. KPIs to instrument (Phase 6)

free→paid conversion (2–5%), **booking-unlock→subscribe** conversion (the flywheel),
credit/generation utilization, wall-hit rate, AI COGS % of revenue (<20–30%),
LTV:CAC, annual renewal/churn.

## 10. Guardrails

All-in price display (FTC 16 CFR 464 / EU Omnibus); no double-charge (a booked package
shouldn't also burn AI credits for the same action); re-validate component prices before
any future charge; refunds mirror strictest supplier. EU package-organiser exposure when
bundling ≥2 service types — coordinate with product-strategy before real booking.
