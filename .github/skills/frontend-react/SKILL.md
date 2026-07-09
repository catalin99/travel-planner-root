---
name: frontend-react
description: "Expert workflow for the travel-planner-frontend React 19 + Vite 7 + TypeScript 5.9 app: adding components/pages/routes/hooks, calling the backend through the shared axios apiClient, keeping src/types/ aligned with backend DTOs, using Auth/Currency/Language contexts, and mapbox-gl maps. Use when editing or debugging frontend code, build/lint/type errors, or wiring a new API call."
---

# Frontend (React 19 + Vite + TS) Skill

Deep idioms live in the frontend repo's own skills — load them on demand:
[react-vite-frontend](../../../travel-planner-frontend/.github/skills/react-vite-frontend/SKILL.md),
[mapbox-gl](../../../travel-planner-frontend/.github/skills/mapbox-gl/SKILL.md),
[travel-planner-backend](../../../travel-planner-frontend/.github/skills/travel-planner-backend/SKILL.md),
plus [travel-planner-frontend/.github/copilot-instructions.md](../../../travel-planner-frontend/.github/copilot-instructions.md).
This skill is the quick operating procedure.

## When to use
- Adding/editing components under `src/views/**` or pages, or routes in `src/routes.tsx`.
- Creating/updating an API service in `src/services/api/<resource>Service.ts`.
- Touching `Auth`/`Currency`/`Language` contexts or hooks in `src/hooks/`.
- Diagnosing Vite, TypeScript (strict), or ESLint flat-config issues.

## Stack ground rules
- **React 19** function components + hooks only; no class components.
- **TypeScript strict:** explicit return types on exported functions; no `any` —
  use `unknown` and narrow. Reuse types from `src/types/` instead of inline ones.
- **HTTP through the shared client only:** add a typed function in
  `src/services/api/<resource>Service.ts` that calls
  [apiClient](../../../travel-planner-frontend/src/services/api/apiClient.ts)
  (`get`/`getPublic`/`post`/`postPublic`/`put`/`delete`). Never call axios inline
  or construct a new instance — that bypasses auth-token injection and base URL.
- **State:** local UI → `useState`/`useReducer`; cross-cutting → existing contexts;
  server state → a hook in `src/hooks/` (pattern: `useTravelRequests`, `useFlightSearch`).
- **Routing:** register routes in `src/routes.tsx`; wrap auth-only routes in
  `ProtectedRoute`. Exactly one `BrowserRouter` (in `App.tsx`).
- **i18n / currency:** use `LanguageContext` (`t(code)`) and `CurrencyContext`
  (`convertAmount`, `formatPrice`) — never hardcode strings or currency symbols.
  **Every new/changed UI string goes through the locale path:** pick an UPPER_SNAKE
  `code`, render it via a `tf(code, 'English fallback')` helper, and add+insert its
  **RO+EN** entries into the DB per the [localization](../localization/SKILL.md) skill
  (correct Romanian diacritics). Don't ship visible literals.
- **Styling:** plain CSS colocated with the component; reuse primitives from
  `src/views/common/` before creating new ones.
- **Maps:** follow the `mapbox-gl` skill — init/teardown guard, cleanup in
  `useEffect`, import the CSS once, token from config (never hardcoded).

## Procedure: add or change an API-backed feature
1. **Confirm the backend contract first.** Read the controller and DTO in
   `TravelPlanner/...` (see [feature-workflow](../feature-workflow/SKILL.md) and the
   frontend `travel-planner-backend` skill). Don't guess shapes.
2. **Type:** add/update `src/types/<resource>.ts` to match the DTO exactly
   (`Guid`→`string`, `DateTime`→ISO `string`, enums→string-literal unions).
3. **Service:** add/update `src/services/api/<resource>Service.ts` so path, verb,
   query params, and body match the controller; choose `*Public` vs authenticated
   per the endpoint's `[Authorize]`.
4. **Hook (if it owns server state):** encapsulate fetch + state + error in
   `src/hooks/use<Resource>.ts`.
5. **View:** build under the right `src/views/<area>/`, composing `common/` primitives.
6. **Route:** wire it in `src/routes.tsx` if needed.

## Validate
From `travel-planner-frontend/`: `npm run lint`, then `npm run build`
(`tsc -b` + Vite). Optional `npm run dev` smoke test on port 5173. When backend
DTOs change, update `src/types/` first, then fix the compile errors that surface.

## Common pitfalls
- Calling axios directly instead of `apiClient`. Duplicating `BrowserRouter`.
- Stale types after a backend change. Effect leaks (missing cleanup) with mapbox
  or listeners. Introducing `.eslintrc.*` (this repo uses the flat
  `eslint.config.js`). Adding a dependency without asking.

## Authoritative references (read on demand)
- [React docs](https://react.dev) · [React 19 release notes](https://react.dev/blog/2024/12/05/react-19)
- [TypeScript handbook](https://www.typescriptlang.org/docs/handbook/intro.html) · [Vite guide](https://vite.dev/guide/)
- [React Router v7](https://reactrouter.com/) · [Axios](https://axios-http.com/docs/intro)
- [TanStack Query v5](https://tanstack.com/query/latest) · [ESLint flat config](https://eslint.org/docs/latest/use/configure/configuration-files)

**Current best practice (2025-26):** React 19 mutations use **Actions** —
`useActionState` + `useOptimistic` + `useFormStatus` with `<form action>` instead
of manual `isPending`/error state. `ref` is now a plain prop — drop `forwardRef`
in new components; render `<Context value>` directly. Read promises/context in
render via the `use` API behind `<Suspense>` + an Error Boundary (cache the
promise; don't create it in render). Treat **server state** separately (a query
lib for caching/dedupe/invalidation); keep `useState`/`useReducer` for local UI.
Vite 7 needs Node 20.19+/22.12+.

## Auto-learn after each task
After a task that used this skill, reflect and improve it (full loop in
[docs-maintenance](../docs-maintenance/SKILL.md)): fold in any better pattern,
corrected fact, exact command/path, or gotcha you found — edit this `SKILL.md`
surgically in its existing style; refresh the references above if a source or
version changed; cascade to [PROJECT_OVERVIEW.md](../../../PROJECT_OVERVIEW.md)
and the owning repo's deep docs when a feature/contract/package/resource changed;
then say in one line what you updated.
