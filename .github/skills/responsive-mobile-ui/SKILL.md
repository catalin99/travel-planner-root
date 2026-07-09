---
name: responsive-mobile-ui
description: "Responsive design + mobile/phone UI expert for the travel-planner-frontend. Use whenever you build or restyle ANY screen/component so it looks great and feels smooth on phones, tablets, and desktop — the app's breakpoints, the slide-in nav drawer pattern, fluid grids, touch-target/tap sizing, safe-area insets, dvh, no-horizontal-scroll, reduced-motion, and the per-feature responsive checklist. Grounded in the app's plain-CSS design tokens (migrating to Mantine)."
---

# Responsive & Mobile UI Skill

Every screen must work from a **360px phone** up to a wide desktop, and feel
smooth (no layout shift, no horizontal scroll, comfortable tap targets). This is
the source of truth for that. Pair with [ui-ux-frontend](../ui-ux-frontend/SKILL.md)
(component library + a11y) and [frontend-react](../frontend-react/SKILL.md) (where
code goes).

## The app's breakpoints (desktop-first `max-width`)
The codebase is **plain CSS, desktop-first** (`@media (max-width: …)`). Match it.

| Breakpoint | Meaning | Use for |
|-----------|---------|---------|
| `1280px` | small laptop / tablet | **Header collapses to the hamburger drawer here** (dense RO nav + identity don't fit a bar below this) |
| `1024px` | tablet | dense multi-column → fewer columns |
| `768px` | large phone / small tablet | stack columns; `body { overflow-x: hidden }` (global, in `index.css`) |
| `640px` / `560px` | phone | single column; smaller headings/padding; stack action rows |
| `480px` | small phone | hide non-essential chrome (e.g. logo text); full-width drawer |
| `420px` | very small phone | let buttons go full-width (`flex: 1 1 100%`) |

Don't invent new random breakpoints — reuse these. Prefer **fluid** layout
(`minmax`, `clamp`, `%`, `flex-wrap`) so fewer breakpoints are needed.

## Design tokens (use these, never hard-code brand colours)
In `src/index.css :root`: `--primary-color #667eea`, `--secondary-color #764ba2`,
`--text-color #2c3e50`, `--text-light #7f8c8d`, `--background #f8f9fa`,
`--white`, `--border-radius 8px`, `--shadow`. The brand gradient is
`linear-gradient(135deg, var(--primary-color), var(--secondary-color))`.

## Core patterns (copy these)

- **Fluid card grid** (no media query needed for the columns):
  ```css
  display: grid;
  grid-template-columns: repeat(auto-fit, minmax(230px, 1fr));
  gap: 1rem;
  ```
  Then at `≤640px` force `grid-template-columns: 1fr` if cards must stack.

- **Slide-in nav drawer** (the header pattern; `Header.css`): below the collapse
  breakpoint show `.mobile-menu-toggle`, turn `.nav` into a fixed right-anchored
  panel (`right: -100%` → `.mobile-open { right: 0 }`), `flex-direction: column`,
  `width: min(320px, 88vw)`, `height: 100dvh`, `overflow-y: auto`. A dense bar that
  would wrap onto a broken 2nd row is the signal to **raise the collapse
  breakpoint**, not to shrink fonts.

- **Full-height panels:** use `height: 100dvh` (with `100vh` fallback line above
  it) so mobile browser chrome doesn't clip the panel.

- **Modals on phones:** dock to the bottom as a sheet —
  `align-items: flex-end; border-radius: 16px 16px 0 0; max-width: 100%` at
  `≤480px` (see `UpgradeDialog.css`). Always keep a visible close control.

- **Action rows stack:** `flex-direction: column` for button groups at `≤560px`;
  primary action full-width and on top.

- **Truncate vs wrap:** identity/labels that must stay one line use
  `white-space: nowrap; overflow: hidden; text-overflow: ellipsis; max-width`.
  In the drawer, release the cap (`max-width: none`).

## Touch, motion, safe areas (the "smooth on phones" part)
- **Tap targets ≥ 44×44px** (Apple HIG) / 48px (Material). Give small pills/icons
  enough padding on touch; don't rely on `:hover` for critical affordances.
- **Disable hover-lift transforms on touch/small** (`transform: none` at `≤640px`)
  so cards don't "stick" in a hovered state after tap.
- **`@media (prefers-reduced-motion: reduce)`**: kill non-essential
  `animation`/`transition` (every animated component here already does).
- **Notches:** for full-bleed fixed bars/sheets add
  `padding-left: env(safe-area-inset-left)` etc. when relevant.
- **No horizontal scroll:** never let a child force width; test that the page
  doesn't scroll sideways at 360px. Global `body { overflow-x: hidden }` exists at
  `≤768px` but that hides bugs — fix the offending element.
- Consider `-webkit-tap-highlight-color: transparent` on custom buttons for a
  cleaner tap.

## Per-feature responsive checklist (run before "done")
1. **360 / 390 / 414** (phones), **768** (tablet), **1024 / 1280** (laptop),
   ≥1440 (desktop) — check each in DevTools device toolbar.
2. No horizontal scroll at any width; no element overflowing its container.
3. Headings/padding scale down on phones; nothing feels cramped or huge.
4. Multi-column → single column where it would squash (`≤640px`).
5. Button/action rows stack; primary action reachable with a thumb.
6. Tap targets ≥44px; no hover-only affordance; hover-lift disabled on small.
7. Modals become bottom sheets; drawers use `100dvh` + scroll.
8. `prefers-reduced-motion` respected.
9. All text still comes from the **locale path** (`tf('CODE','fallback')`) — see
   [localization](../localization/SKILL.md); long RO strings are wider than EN, so
   re-check wrapping in Romanian (a frequent cause of overflow here).
10. `npm run build` green; lint the changed files only.

## Gotchas seen in this codebase
- **Romanian labels are ~20–30% wider than English** → a bar that fits in EN wraps
  in RO. The header hamburger sits at `1280px` for exactly this reason.
- Putting an item inside a `flex-wrap: wrap` nav means it can wrap to a broken 2nd
  line — either raise the collapse breakpoint or move it out of the wrapping row.
- `vh` on mobile ≠ visible height (browser chrome) → prefer `dvh`.

## Authoritative references (read on demand)
- [MDN — Responsive design](https://developer.mozilla.org/en-US/docs/Learn/CSS/CSS_layout/Responsive_Design) · [Media queries](https://developer.mozilla.org/en-US/docs/Web/CSS/CSS_media_queries/Using_media_queries)
- [web.dev — Responsive design basics](https://web.dev/articles/responsive-web-design-basics) · [Learn Responsive Design](https://web.dev/learn/design)
- [CSS `min()`/`max()`/`clamp()`](https://developer.mozilla.org/en-US/docs/Web/CSS/clamp) · [Large/small/dynamic viewport units (dvh)](https://developer.mozilla.org/en-US/docs/Web/CSS/length#viewport-percentage_lengths)
- [`env()` safe-area insets](https://developer.mozilla.org/en-US/docs/Web/CSS/env) · [`prefers-reduced-motion`](https://developer.mozilla.org/en-US/docs/Web/CSS/@media/prefers-reduced-motion)
- Touch targets: [Apple HIG (44pt)](https://developer.apple.com/design/human-interface-guidelines/accessibility) · [Material (48dp)](https://m3.material.io/foundations/designing/structure) · [WCAG 2.5.5 Target Size](https://www.w3.org/WAI/WCAG21/Understanding/target-size.html)
- [Mantine responsive](https://mantine.dev/styles/responsive/) (the adopted library — prefer its responsive props/`useMediaQuery` as we migrate).

**Current best practice (2025-26):** design **fluid-first** (intrinsic layout with
`clamp()`, `min()`, grid `auto-fit/minmax`, container queries) and treat explicit
breakpoints as touch-ups, not the primary tool. Use **`dvh`/`svh`** for mobile
full-height, **container queries** for component-driven layout when a component
appears in many widths, respect `prefers-reduced-motion` and **WCAG 2.5.5** target
sizes. As this app migrates to **Mantine**, prefer its responsive style props,
`useMediaQuery`, and `hiddenFrom`/`visibleFrom` over new hand-written media queries.

## Auto-learn after each task
After a task that used this skill, reflect and improve it (full loop in
[docs-maintenance](../docs-maintenance/SKILL.md)): fold in any new breakpoint
decision, a reusable responsive pattern, or a phone gotcha you hit — edit this
`SKILL.md` surgically; refresh the references if a source changed; cascade to
[PROJECT_OVERVIEW.md](../../../PROJECT_OVERVIEW.md) only if a user-facing layout
convention changed; then say in one line what you updated.
