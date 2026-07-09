---
name: pricing-strategy
description: "Monetization and pricing-mechanism design for TravelPlanner: the bundled package commission (merchant-of-record), AI features under subscription with credit metering, and flight/hotel quick-search via affiliate/referral. Use when designing or changing pricing, subscription tiers, AI credit economics, package take-rate/markup, affiliate fallback, or evaluating margin/regulatory/transparency constraints. Grounded in travel-industry economics research and the app's role-based AI model selection."
---

# Pricing & Monetization Strategy Skill

Design how the product makes money without eroding trust or margin. Pair with
[product-strategy](../product-strategy/SKILL.md) (what to build) and
[scalability-concurrency](../scalability-concurrency/SKILL.md) (AI cost at scale).

## The three revenue streams (the intended model)
1. **Bundled package — merchant model + commission.** AI assembles a complete trip;
   the user pays the **full package once**; we remit net to suppliers and keep the
   **blended margin**. This is the high-margin differentiator and carries the
   regulatory load (organiser/MoR).
2. **AI features — subscription.** Itinerary generation, AI flight suggestions, etc.
   gated behind tiers, **metered in credits** (each generation has real token cost).
3. **Quick-search — affiliate/referral.** Flights/hotels/cars the user searches but
   we can't (yet) book in-house earn **referral commission** via partner links.

## Travel economics you must know (sets the take-rate ceiling)
- **Hotels:** ~15% standard commission, up to ~18-25% with visibility tiers — the
  richest, most reliable margin pool.
- **Tours/activities** (Viator/GetYourGuide): suppliers pay ~20-30%; **affiliate**
  referral to us ≈ up to ~8%.
- **Flights:** near-zero airline commission — margin = **markup + service fee +
  ancillaries**. Duffel charges the seller (≈ $3/order + 1% managed content + $2/paid
  ancillary + 2% FX), so **add your own markup/fee on top**.
- **Cars** ~10%; **rail/bus** thin (~2-10%, often a flat booking fee).
- **Affiliate payouts:** Booking ≈ 4-6% of booking value (share of their commission),
  Trip.com up to 7%, GetYourGuide up to ~8%, Skyscanner CPC/revenue-share — all
  **last-click, cookie-window (7-30 days)**.
- **Dynamic packaging is the margin lever:** one opaque package price lets you blend
  a low-margin flight with a high-margin hotel/tour and raise **blended take rate**,
  while showing a single "you save $X vs. booking separately."

## Pricing-mechanism best practices
- **Value-based, not cost-plus:** price the outcome (a complete bookable trip). Token
  cost only sets your **floor**.
- **Good-better-best (3 tiers):** maximizes conversion; anchor with the top tier,
  use a decoy to steer to the target tier.
- **Freemium with a natural wall:** free tier delivers real value but hits a credit
  cap / cheaper model / save limit mapped to willingness-to-pay. Benchmark free→paid
  **2-5%**.
- **Meter AI in credits:** 1 credit = 1 standard generation (cheap model);
  premium/long/multi-city = 2-4 credits (premium model). Sell top-up packs for
  overage instead of throttling payers. Make in-session edits/regenerations
  fractional/free to protect UX.
- **Bundling psychology:** always show savings vs. summed à-la-carte components.
- **Protect margin:** markup floors, free-tier model spend caps, credit expiry,
  abuse rate-limits.

## Recommended architecture (starting point — validate before shipping)

> **Implemented (payment-free), 2026-07:** the app now ships a working subscription +
> entitlements system built to this shape (annual billing; see
> [PRICING_IMPLEMENTATION_PLAN.md](../../../PRICING_IMPLEMENTATION_PLAN.md)).
> Tiers **Free / Plus / Pro / Ultra** + a per-trip **Trip Pass** (unlocked by booking
> a flight/stay with us — the margin-aligned flywheel). Catalog =
> `SubscriptionPlanType` (DynamicConfig, admin-tunable). Per-user state =
> `UserSubscription` + `TripEntitlement` + `FeatureUsageLog` (main DB). AI generation
> is gated by a **hierarchical** check (Trip Pass → subscription: generations-per-trip
> + distinct-trips-per-year) → **HTTP 402** with `{reason, requiredPlan}`; flight
> suggestions are a soft-gated feature. `AiModelSettings.ResolveModelForUser(planTier,
> roles)` = max(plan model, role model). Metering counts `FeatureUsageLog` rows by a
> period key (`SUB:{periodStart}` / `PASS:{id}`), so rolling the period resets
> allowances (daily `SubscriptionMaintenanceJob`). **Upgrade + booking are simulated**
> (`POST /api/subscription/change`, `.../trips/{id}/unlock`) — these are the exact
> single-transition seams a **Stripe (MoR) webhook + real checkout** will later drive
> with zero rework to the engine/gating/UI. Illustrative annual prices: Plus $15 /
> Pro $79 / Ultra $179 (display-only). Not yet built: payments, credit top-up packs,
> denial/wall-hit analytics (usage logs successes only).

| Tier | Price/mo | AI credits | Model | Gated |
|------|----------|-----------|-------|-------|
| **Free** | $0 | 3-5 generations | cheap (`gpt-4.1-mini`) | basic itinerary; search via **affiliate links only**; ads |
| **Plus** | $9-12 | ~40-50 | premium (`gpt-5.4-mini`) | AI flight suggestions, save/compare, no ads, package booking |
| **Pro** | $25-29 | high / fair-use | premium + priority | multi-city, priority generation, reduced/zero booking fee, concierge |

This maps directly onto the existing **role-based model selection**
(`AiModel:RoleModelMapping`: `User`→cheap, paid roles→premium) — extend it into a
credit economy rather than rebuilding it.

**Package flow (merchant):** AI assembles → show **one transparent all-in total**
with itemized breakdown and savings → collect full payment → remit net to suppliers.
Embed margin = per-component commission (highest on hotels/tours) + small package
markup. **Affiliate fallback:** if a component has no merchant API, deep-link and
earn referral — never block the trip.

**AI COGS guardrail:** price credits so AI cost stays **< ~20-30% of subscription
revenue**; free tier = cheapest model + hard monthly cap to bound spend on
non-payers.

## Guardrails (don't get this wrong)
- **Don't double-charge:** a subscriber booking a package shouldn't also pay a full
  per-booking service fee — pick one revenue source per transaction.
- **All-in price up front:** **US FTC junk-fee rule (16 CFR 464, 2025)** bans drip
  pricing for lodging/tickets; **EU** requires total-price disclosure. Itemize
  taxes/fees; no checkout surprises.
- **EU package exposure:** combining ≥2 service types for one price makes you the
  **organiser** (insolvency protection + liability; a tour counts toward a "package"
  at ≥25% of trip value; >8% price increase lets the customer cancel free).
  Consider "linked travel arrangements" (separate contracts + info form) or a bonded
  partner to limit liability — coordinate with [product-strategy](../product-strategy/SKILL.md).
- **Price freshness:** re-validate component prices before charging (offers expire) —
  never honor a stale bundle total.
- **Refunds/cancellations** must mirror the strictest underlying supplier; reserve
  for chargebacks (MoR risk).

## KPIs to instrument
- **Take rate** = net revenue ÷ GMV (target blended **8-15%** via bundling).
- **Attach rate** (components/booking, % with add-ons like insurance/tours).
- **AOV** & **gross margin per package** (after supplier net + AI + payment fees).
- **ARPU/ARPPU**, **free→paid conversion** (2-5%), **subscription churn**.
- **LTV/CAC** (≥3:1), CAC payback < 12 mo.
- **AI cost per booking** and **AI COGS % of revenue** (<20-30%), **credit utilization**.
- **Search-to-book**, **booking conversion**, **refund/cancellation rate**,
  **affiliate vs merchant revenue mix**.

## How to use this skill
1. For a monetization change, pick the stream (package / subscription / affiliate)
   and check it against the guardrails (double-charge, all-in price, EU/MoR).
2. For AI features, size the credit cost against the COGS guardrail and the role→model map.
3. Surface regulatory implications early; reflect any user-facing pricing change in
   [PROJECT_OVERVIEW.md](../../../PROJECT_OVERVIEW.md).

*Research basis: Duffel pricing; Booking/Trip.com/Skyscanner/Kiwi/GetYourGuide partner
programs; EU Package Travel Directive 2015/2302; US FTC 16 CFR 464; widely-reported
commission norms. Validate current rates before committing pricing.*

## Authoritative references (read on demand)
- [OpenView — Usage-Based Pricing](https://openviewpartners.com/usage-based-pricing/) · [Paddle — SaaS metrics guide](https://www.paddle.com/resources/the-ultimate-saas-metrics-guide) · [Paddle — Merchant of Record](https://www.paddle.com/blog/what-is-merchant-of-record)
- [Lenny's Newsletter — AI monetization](https://www.lennysnewsletter.com/p/why-saas-freemium-playbooks-dont) · [a16z — 16 Startup Metrics](https://a16z.com/16-startup-metrics/)
- [Viator affiliate](https://partnerresources.viator.com/) (≈8%, 30-day cookie) · travel commission/affiliate economics
- Regulation: [EU Omnibus Directive 2019/2161](https://eur-lex.europa.eu/legal-content/EN/TXT/?uri=CELEX:32019L2161) · [FTC junk-fees rule](https://www.ftc.gov/news-events/news/press-releases/2024/12/federal-trade-commission-announces-final-junk-fees-rule)

**Current best practice (2025-26):** **hybrid** pricing wins — a subscription base
+ usage/credit overage beats pure seats; pick one value metric. AI breaks the
seat/freemium model (token COGS scale with use), so **meter AI as credits** and
route by role/complexity (cheap model for simple jobs) to protect gross margin per
AI action. Track NRR (benchmark >109%), CAC payback, LTV:CAC, ARPU + marketplace
take-rate/GMV. **Show all-in pricing upfront** (total incl. taxes/mandatory fees)
to satisfy the EU Omnibus/Price-Indication rules and the FTC junk-fees rule.

## Auto-learn after each task
After a task that used this skill, reflect and improve it (full loop in
[docs-maintenance](../docs-maintenance/SKILL.md)): fold in any updated commission
rate, pricing experiment result, regulation change, or corrected benchmark — edit
this `SKILL.md` surgically; refresh the references above if a source changed;
cascade to [PROJECT_OVERVIEW.md](../../../PROJECT_OVERVIEW.md) on any user-facing
pricing change; then say in one line what you updated.
