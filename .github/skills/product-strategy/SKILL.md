---
name: product-strategy
description: "Business/product strategy and market intelligence for TravelPlanner — the vision of AI-generating a complete, bookable multimodal trip (flights + stay + train + bus + ferry + car + tours) with one confirmation and one payment, plus quick-search and a manual itinerary calendar. Use when prioritizing the roadmap, evaluating a feature against the vision/competitors, planning supplier integrations, weighing build-vs-affiliate, or assessing regulatory/market risk. Grounded in the current codebase and 2025-2026 competitor/market research."
---

# Product Strategy & Market Intelligence Skill

Use this to make **product decisions** that move toward the vision, grounded in
what the code already does and how the market is moving. Pair tactical execution
with [feature-workflow](../feature-workflow/SKILL.md) and money decisions with
[pricing-strategy](../pricing-strategy/SKILL.md).

## The vision (north star)
> **Best trip, minimum effort.** The user enters preferences; the app
> AI-assembles a complete, **bookable multimodal package** — flights, accommodation,
> train, bus, ferry, car rental, and GetYourGuide-style tours — maps and prices
> everything, and the user simply **confirms and pays once** (a bundle with our
> commission). Secondary: quick search (flights / cars / stays) folded into an
> itinerary **calendar** the user can also fill manually.

### North-star principles (apply to every feature decision)
1. **One trip, one confirmation, one payment** — never dead-end at a deep link.
2. **Never show a price you can't sell** — re-validate live before checkout; zero
   hallucinated inventory.
3. **Multimodal by default** — air+rail+bus+ferry+car+stay+tours, optimized
   end-to-end, not vertical-by-vertical.
4. **Minimum user effort** — preferences in, bookable trip out; confirm-and-pay.
5. **Trust is the product** — transparent totals, real reviews/photos, clear
   change/cancel, package protection.
6. **Margin where we transact, referral where we can't** — upgrade affiliate →
   merchant over time.
7. **Agentic, not just conversational** — the AI books and re-books on disruption,
   human-in-the-loop.
8. **Own the post-booking** — support/disruption handling is where loyalty lives.
9. **Personalization flywheel** — every trip improves the next.
10. **Compliance as a moat** — organiser/ATOL/MoR done right is a barrier, not a tax.

## Where the code is today (read before strategizing)
- AI itinerary generation works end-to-end (queue → worker → batched generation →
  persisted day/block calendar) — [ai-pipeline](../ai-pipeline/SKILL.md).
- **Flights already integrate Duffel (default) + Aviasales/Travelpayouts**, with a
  scored **AI flight-suggestion** pipeline (price/duration/stops/layover weights).
- Itinerary **calendar** with days/blocks exists; manual editing is supported.
- **Not yet built:** real booking/checkout, accommodation/tours/rail/bus/ferry/car
  inventory, single-payment packaging, supplier order management, payments.
- So today the app **plans and suggests**; the strategic job is to **close the
  booking loop** and **go multimodal**.

## Competitive map (2025-2026) — and the gap
- **AI generators** (Mindtrip, Layla/Roam Around, Trip Planner AI, Wonderplan,
  GuideGeek, Vacay, iplan.ai, Curiosio): plan well, **book shallow** — they
  deep-link to partners; no bundle, no single checkout, little/no rail-bus-ferry.
- **OTAs/metasearch with planning** (Booking AI Trip Planner, Expedia Romie, Kayak,
  Hopper, Google/Gemini, Trip.com AITrip, Kiwi): **book deep but walled** —
  discovery bolted onto a single-brand, mostly single-vertical funnel.
- **Organizers** (TripIt, Wanderlog, Roadtrippers): organize, don't generate or sell.
- **White space = the "agentic dynamic-package OTA":** AI-assembled, cross-supplier,
  **multimodal**, **single-payment**, package-protected trips with minimum effort.
  **No incumbent does this.** That is the wedge — protect it.

## Supplier integration reality (build-vs-partner)
Use this to sequence integrations (most self-serve first):
- **Flights:** Duffel (self-serve, can actually **ticket**; already in code) → Amadeus/Kiwi later (partnership).
- **Stays:** Duffel Stays / Hotelbeds (self-serve/contract) bookable; Booking/Expedia EPS = partnership + affiliate; **Airbnb has no public booking API** → deep-link only.
- **Tours:** Viator (Partner API + affiliate, accessible) and GetYourGuide (partner approval).
- **Rail/bus/ferry** (most fragmented, partnership-gated): Omio, Distribusion (bus), Trainline; ferries via Direct Ferries.
- **Car:** CarTrawler (B2B aggregator), Amadeus Cars.
- Rule: **transact where an API lets you, affiliate where it doesn't** — never
  block the trip on a missing integration.

## Risks to design around
- **Hallucination / stale price** → re-validate every component live before pay.
- **Regulatory:** bundling ≥2 service types for one price makes you a **package
  organiser** (EU Package Travel Directive 2015/2302 → insolvency protection +
  liability; UK flight-inclusive → **ATOL/CAA**). Ticketing flights needs **IATA**
  or an aggregator's authority (Duffel provides one). **Merchant-of-record** adds
  PCI/refund/chargeback exposure. Treat compliance as a moat, but budget for it.
- **Supplier dependency / unit economics** — affiliate ≈ low single-digit % and you
  don't own the customer; merchant = higher margin but you carry payments/support.
- **AI-native discovery shift** (ChatGPT/Gemini/Perplexity) — plan for AI visibility
  as a distribution channel.

## Roadmap (prioritized)
- **MVP — prove the loop:** 1-2 corridors; Duffel (flights) + Duffel Stays/Hotelbeds
  + Viator/GYG (tours) + one rail/bus (Omio/Distribusion); AI assembles → user
  confirms → **single checkout (Stripe as MoR)**. Obsess over live re-validation
  and the calendar with manual fill (secondary feature). Affiliate-link anything
  not yet bookable.
- **Growth:** add car (CarTrawler) + ferries (Direct Ferries); more corridors; a
  **dynamic-packaging margin engine**; collaborative planning; mobile; **post-booking
  management** (changes/cancellations via Duffel Order Management).
- **Moat:** become **package organiser of record** (insolvency/ATOL cover); direct
  supplier contracts for better rates; proprietary **multimodal routing +
  bundle-margin optimization**; **agentic disruption re-booking**; personalization
  data flywheel.

## How to use this skill
1. For any feature, ask: does it advance "one trip, one confirmation, one payment"
   and "multimodal by default"? If not, justify it as enabling (calendar, trust,
   personalization) or defer it.
2. For an integration, place it on the build-vs-partner map and pick transact vs
   affiliate accordingly.
3. Flag regulatory/MoR implications early; loop in [pricing-strategy](../pricing-strategy/SKILL.md)
   for take-rate and packaging economics.
4. When the product surface changes, update [PROJECT_OVERVIEW.md](../../../PROJECT_OVERVIEW.md)
   ([docs-maintenance](../docs-maintenance/SKILL.md)).

*Research basis: Mindtrip, Layla, Trip Planner AI, Duffel, Amadeus, Kiwi/Tequila,
Viator/GetYourGuide, Omio/Distribusion, PhocusWire (2026), EU Package Travel
Directive 2015/2302, UK CAA/ATOL. Re-validate before betting the roadmap on any
single source.*

## Authoritative references (read on demand)
- [Skift Research](https://skift.com/research/) · [Phocuswright](https://www.phocuswright.com/) · [PhocusWire](https://www.phocuswire.com/) · [Arival (tours & activities)](https://arival.travel/)
- Supplier programs: [Duffel](https://duffel.com/) · [Amadeus Self-Service](https://developers.amadeus.com/self-service) · [Kiwi Tequila](https://tequila.kiwi.com/) · [Viator partner](https://partnerresources.viator.com/) · [GetYourGuide partner](https://partner.getyourguide.com/) · [Distribusion](https://www.distribusion.com/) · [CarTrawler](https://corporate.cartrawler.com/) · [Omio](https://www.omio.com/)
- Regulation: [EU Package Travel Directive 2015/2302](https://eur-lex.europa.eu/legal-content/EN/TXT/?uri=CELEX:32015L2302) · [UK ATOL / CAA](https://www.caa.co.uk/atol-protection/)
- Frameworks: [Jobs to Be Done (HBR)](https://hbr.org/2016/09/know-your-customers-jobs-to-be-done) · [North Star Metric](https://amplitude.com/blog/product-north-star-metric)

**Current best practice (2025-26):** AI is becoming the discovery/distribution
layer — optimize listings for AI Mode / "Things to Do," not just OTA rank. Anchor
the roadmap to the traveler's **job** (plan → book a whole trip, one payment) and a
single value-aligned **North Star** (completed multimodal bookings), not vanity
DAU. Remember: bundling ≥2 service types at an inclusive price (or a second booking
within 24h) triggers **organiser liability + insolvency-protection** duties under
Dir. 2015/2302 (UK flight-inclusive → ATOL).

## Auto-learn after each task
After a task that used this skill, reflect and improve it (full loop in
[docs-maintenance](../docs-maintenance/SKILL.md)): fold in any fresh market
intel, competitor move, supplier-program change, or corrected fact — edit this
`SKILL.md` surgically; refresh the references above if a source changed; cascade
to [PROJECT_OVERVIEW.md](../../../PROJECT_OVERVIEW.md) when the product surface or
strategy shifts; then say in one line what you updated.
