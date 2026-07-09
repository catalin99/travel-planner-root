---
name: ui-ux-frontend
description: "UI/UX standard for the travel-planner-frontend: the chosen component library (Mantine — free/MIT, Vite-native, accessible) plus the UX and accessibility best practices every new and existing feature must follow (Nielsen heuristics, WCAG/WAI-ARIA, design tokens, responsive, loading/empty/error states, forms). Use when building or restyling any UI, choosing a component, planning the incremental migration off plain CSS, or reviewing a screen for usability/accessibility."
---

# UI/UX Frontend Standard Skill

This skill defines **how all UI is built** in `travel-planner-frontend`, going
forward and during the incremental migration of existing screens. It pairs the
chosen component library with non-negotiable UX + accessibility practices.

> Stack idioms (React 19 + Vite + TS, `apiClient`, contexts, hooks) live in the
> [frontend-react](../frontend-react/SKILL.md) skill and the repo's own
> [react-vite-frontend](../../../travel-planner-frontend/.github/skills/react-vite-frontend/SKILL.md)
> skill. This skill is about **components, look & feel, and usability**.

## Chosen library: Mantine

**Decision:** standardize on **[Mantine](https://mantine.dev)** (`@mantine/*`).
Rationale for *this* app:

- **Free & safe commercially** — all `@mantine/*` packages are MIT licensed.
- **Vite-native** — Mantine's recommended setup is Vite/SPA; no SSR plumbing.
- **Batteries-included for our domain** — `@mantine/core` (inputs, buttons,
  modals, tables, overlays), `@mantine/hooks`, `@mantine/form` (the trip planner
  and quick-search are form-heavy), `@mantine/dates` (**replaces
  `react-datepicker`** with a consistent control), `@mantine/notifications`
  (**replaces `alert()`** and ad-hoc toasts), `@mantine/modals`, `@mantine/charts`
  (admin dashboards).
- **Accessible by default** — components ship with focus management, keyboard
  interaction, and ARIA wiring.
- **Coexists with our plain CSS** — Mantine styles via CSS modules + PostCSS, not
  a runtime CSS-in-JS engine, so it drops in next to existing colocated `.css`
  during an incremental migration (no need to convert everything to utilities
  first). It also keeps bundle/runtime cost low.
- **Design tokens / theming** — a central `theme` gives us the consistent design
  system the product wants, plus light/dark support.

> Alternative considered: **shadcn/ui + Tailwind + Radix** (also free, accessible,
> you own the components). Rejected as the default here because it requires
> adopting Tailwind's utility paradigm across the app to stay consistent — a
> larger, riskier change for a codebase currently on plain CSS doing a *gradual*
> migration. Revisit only if the team decides to move to Tailwind wholesale.

### One-time setup (do this before first use; confirm latest versions)
1. From `travel-planner-frontend/`: `npm i @mantine/core @mantine/hooks`
   (add `@mantine/form @mantine/dates @mantine/notifications @mantine/modals` as
   needed). Verify the installed major version supports **React 19** (Mantine 8+).
2. Dev deps + PostCSS:
   `npm i -D postcss postcss-preset-mantine postcss-simple-vars` and add
   `postcss.config.cjs` per Mantine's Vite guide.
3. Import core styles once at the app root (`src/main.tsx`):
   `import '@mantine/core/styles.css';` (and each used package's styles).
4. Wrap the app **inside** the existing providers with `MantineProvider` holding a
   shared `theme` (define brand colors, radius, spacing as tokens). Keep the
   existing `AuthProvider` / `LanguageProvider` / `CurrencyProvider` nesting.
5. Add a small theme file (e.g. `src/theme.ts`) as the single source of design
   tokens. Do not hardcode colors/spacing in components — use the theme.

## UX best practices (Nielsen's 10 heuristics, applied here)

Every screen must satisfy these — treat them as a review checklist:

1. **Visibility of system status** — always show loading, saving, and async-job
   progress. AI itinerary/flight generation is polled; show a clear in-progress
   state and let the user know it may take time (reuse the polling hooks).
2. **Match the real world** — use the user's language via `LanguageContext`
   (`t(...)`); never hardcode user-visible strings. Currency via `CurrencyContext`.
3. **User control & freedom** — provide Cancel/Back/Undo. Long AI jobs must be
   cancellable (the cancel endpoints already exist). Confirm destructive actions.
4. **Consistency & standards** — one component per purpose from Mantine + the
   theme; don't invent bespoke buttons/inputs. Follow platform conventions.
5. **Error prevention** — validate inputs with `@mantine/form` before submit;
   disable submit while invalid/in-flight; use sensible defaults and constraints
   (date ranges, people counts).
6. **Recognition over recall** — visible labels, helper text, and inline
   validation; don't make users remember values across steps.
7. **Flexibility & efficiency** — keep the Quick Search vs Full Planner dual path
   (see [rework.md](../../../travel-planner-frontend/rework.md)); progressive
   disclosure, keyboard support, sensible tab order.
8. **Aesthetic & minimalist design** — show only what's needed per step; lean on
   whitespace and hierarchy from the theme.
9. **Help users recover from errors** — surface backend `ProblemDetails` / 400
   field errors as inline, plain-language messages (no codes); for 429
   rate-limits show the friendly rate-limit screen; offer a next action.
10. **Help & documentation** — contextual hints near complex fields, not walls of
    text.

## Accessibility (WCAG 2.1 AA — required)

- **Keyboard**: every interactive element reachable and operable by keyboard;
  visible focus rings (don't remove outlines). Mantine handles most of this —
  don't break it.
- **Labels**: every input has a real label (Mantine `label` prop); icons-only
  buttons get `aria-label`.
- **Contrast**: text ≥ 4.5:1 (3:1 for large text) — bake compliant colors into
  the theme tokens.
- **Semantics**: use proper landmarks/headings; modals trap focus and restore it
  (Mantine `Modal` does this — use it instead of hand-rolled overlays).
- **Status**: announce async results to screen readers (notifications / live
  regions), not color alone.
- **Maps**: `mapbox-gl` canvases aren't accessible on their own — provide a
  text/list alternative for itinerary points (see the repo `mapbox-gl` skill).

## Responsive & states
- Mobile-first; verify at common breakpoints. Use Mantine's responsive props /
  the theme breakpoints rather than magic numbers.
- Every data view must handle **loading**, **empty**, **error**, and **success**
  states explicitly — no blank screens.

## Incremental migration plan (existing screens)
The product chose **incremental migration on a schedule**. Apply this order:
1. **Adopt the theme + providers first** (setup above) so new and old coexist.
2. **New features: Mantine only** — no new plain-CSS components.
3. **Migrate opportunistically + on schedule:** when you touch a screen, convert
   its primitives to Mantine; prioritize shared primitives in
   `src/views/common/`, then high-traffic flows (auth, plan-trip, quick-search,
   trip details), then admin/agent dashboards.
4. **Replace `react-datepicker` with `@mantine/dates`** and `alert()`/ad-hoc
   toasts with `@mantine/notifications` as you migrate each screen; remove the old
   dependency once no longer referenced.
5. Keep each PR scoped to a screen/flow; run `npm run lint` + `npm run build` and
   eyeball the page in `npm run dev`.

## Guardrails
- Don't add a *second* UI library; Mantine is the standard.
- Don't bypass the theme with inline hardcoded colors/spacing.
- Don't ship a component that fails keyboard or contrast checks.
- Keep API/state logic in hooks/services ([frontend-react](../frontend-react/SKILL.md)),
  not in presentational components.

## Authoritative references (read on demand)
- [Mantine docs](https://mantine.dev) (current major **v8**; supports React 19; all `@mantine/*` MIT-licensed)
- [NN/g — 10 Usability Heuristics](https://www.nngroup.com/articles/ten-usability-heuristics/)
- [W3C WAI-ARIA Authoring Practices (APG)](https://www.w3.org/WAI/ARIA/apg/) · [WCAG 2.2 quickref](https://www.w3.org/WAI/WCAG22/quickref/) · [WAI forms tutorial](https://www.w3.org/WAI/tutorials/forms/)
- [Design Tokens (DTCG)](https://www.designtokens.org/) · [Style Dictionary](https://styledictionary.com/) · [Refactoring UI](https://www.refactoringui.com/)

**Current best practice (2025-26):** target **WCAG 2.2 AA**, which adds 24×24px
target size (2.5.8), focus-not-obscured (2.4.11), and accessible-authentication
rules — on top of 4.5:1 text / 3:1 non-text contrast and always-visible focus.
Build interactive widgets from **APG patterns** (correct roles/states/keyboard),
native HTML first and ARIA only to fill gaps. Required Mantine packages are
`@mantine/core` + `@mantine/hooks` (needs `postcss-preset-mantine`); add
`@mantine/form`/`dates`/`notifications`/`modals` as needed. Centralize visual
decisions as DTCG-format tokens exported via Style Dictionary.

## Auto-learn after each task
After a task that used this skill, reflect and improve it (full loop in
[docs-maintenance](../docs-maintenance/SKILL.md)): fold in any better pattern,
corrected fact, exact command/path, or gotcha you found — edit this `SKILL.md`
surgically in its existing style; refresh the references above if a source or
version changed; cascade to [PROJECT_OVERVIEW.md](../../../PROJECT_OVERVIEW.md)
and the owning repo's deep docs when a feature/contract/package/resource changed;
then say in one line what you updated.
