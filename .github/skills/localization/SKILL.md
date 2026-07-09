---
name: localization
description: "Add and insert UI translations (locales) for TravelPlanner across ALL system languages (currently Romanian + English). Use whenever new user-facing frontend text is created, existing text is changed, or a locale needs inserting/updating. Covers the Locale schema + the two-DB layout, the mandatory frontend locale path (never hard-code UI strings), generating RO+EN pairs, the idempotent MERGE upsert, and \u2014 critically \u2014 inserting Romanian diacritics (\u0103 \u00e2 \u00ee \u0219 \u021b) correctly into SQL Server."
---

# Localization (Locales) Skill

Every user-facing frontend string must come from the **locale system**, not a hard-coded
literal. When you add or change UI text, you also add/insert its RO+EN locale entries and
push them to the DB. This skill is the source of truth for that loop.

## Where locales live
- **DB:** `travelplanner_dynamicconfig` (the DynamicConfig context, `DynamicConfigConnection`).
  Table **`Locales(Code, LocaleRo, LocaleEn)`** \u2014 `Code` is the PK (UPPER_SNAKE_CASE),
  `LocaleRo`/`LocaleEn` are `nvarchar(500)`.
- **Entity:** `TravelPlannerDomain/Entities/DynamicConfig/Locale.cs`.
- **Served by:** `GET /api/locales` (public) \u2192 `LocalePublicService.GetAllLocalesAsync()`
  which reads **directly from the DB** (via `IUnitOfWork.Locales`). So a freshly-inserted
  locale is returned **immediately \u2014 no API restart needed**. (The in-memory
  `LocaleService`/`LocaleRefreshService` cache is a *separate* backend-side cache used for
  server-rendered emails etc.; it refreshes on a schedule.)
- **Admin CRUD:** `POST/PUT/DELETE /api/locales` (`Policies.RequireAdminRole`) for one-off
  edits; bulk seeding is done with SQL (below).

## Frontend locale path (mandatory for all new text)
- Consume via `useLanguage()` \u2192 `t(code)`. `localeService.getTranslation` returns a
  `Locale_<lang>_<CODE>` **placeholder on a miss** (not the code), so wrap `t` in a small
  fallback helper so English shows until the locale is seeded:
  ```ts
  const { t } = useLanguage();
  const tf = (code: string, fallback: string) => {
    const v = t(code);
    return !v || v === code || v.startsWith('Locale_') ? fallback : v;
  };
  // <button>{tf('ITINERARY_GROUP', 'Group')}</button>
  ```
- **Interpolation:** locales are plain strings; use a placeholder token and `.replace`:
  RO/EN store `"Se \u00eentinde pe {count} zi(le)"` / `"Spans {count} day(s)"`, then
  `tf('ITINERARY_ACTIVITY_SPANS','Spans {count} day(s)').replace('{count}', String(n))`.
- **Never** hard-code a visible string. Pick a clear `MODULE_THING` code
  (e.g. `ITINERARY_GROUP`, `ITINERARY_UNGROUP_TITLE`).
- Frontend caches locales in `localStorage` for **1h** (`localeService`), so after inserting
  new codes a **hard refresh** (or clearing the cache) is needed to see them in an open session.

## Generate translations for ALL languages
Every new code needs a value for **every** system language \u2014 currently **`ro` + `en`**.
Never insert only one. Write natural, concise Romanian (not literal machine translation).

## Romanian diacritics \u2014 get this right
Use **comma-below** letters (modern Romanian), not the legacy cedilla forms:
`\u0103` (a-breve U+0103), `\u00e2` (\u00e2 U+00E2), `\u00ee` (\u00ee U+00EE), **`\u0219`** (s-comma U+0219, *not* \u015f U+015F),
**`\u021b`** (t-comma U+021B, *not* \u0163 U+0163). Uppercase: `\u0102 \u00c2 \u00ce \u0218 \u021a`.

Two things must both be true for diacritics to store correctly in SQL Server:
1. **`N'...'` Unicode literal prefix on EVERY value** (RO *and* EN \u2014 EN often has `\u2026 \u2014 \u2019`).
   Without `N`, non-ASCII is silently converted to `?`.
2. **The SQL text must reach the server as Unicode.** Do **not** run a UTF-8 `.sql` through
   plain `sqlcmd -i` (it mis-reads the bytes). Use one of:
   - `Invoke-Sqlcmd` reading the file as UTF-8 (**preferred, bulletproof** \u2014 the string is
     UTF-16 in memory and SqlClient sends Unicode):
     ```powershell
     $srv='DESKTOP-DG9VN9O\SQLEXPRESS'; $db='travelplanner_dynamicconfig'
     $sql = Get-Content -Raw -Encoding UTF8 'path\to\locales.sql'
     Invoke-Sqlcmd -ServerInstance $srv -Database $db -Query $sql -ErrorAction Stop
     ```
   - or `sqlcmd -f 65001 -i file.sql` (tells sqlcmd the input codepage is UTF-8).

## Idempotent MERGE (upsert) pattern
Never `DELETE FROM Locales` for an incremental add. Use a re-runnable `MERGE` keyed on `Code`:
```sql
MERGE INTO Locales AS t
USING (VALUES
    (N'ITINERARY_GROUP', N'Grupeaz\u0103', N'Group')
    -- , (N'CODE', N'RO', N'EN') ...
) AS s (Code, LocaleRo, LocaleEn)
ON t.Code = s.Code
WHEN MATCHED THEN UPDATE SET t.LocaleRo = s.LocaleRo, t.LocaleEn = s.LocaleEn
WHEN NOT MATCHED THEN INSERT (Code, LocaleRo, LocaleEn) VALUES (s.Code, s.LocaleRo, s.LocaleEn);
```
Keep seed files under `TravelPlanner/TravelPlannerInfrastructure/Migrations/INSERT_LOCALES_*.sql`
(the established convention; example: `INSERT_LOCALES_ITINERARY_ACTIVITIES.sql`).
Escape a literal `'` inside a value by doubling it (`''`); prefer curly `\u2019` in copy to avoid it.

## The workflow (do this whenever there is locale work)
1. Add the `tf('CODE','English fallback')` calls in the frontend (locale path, no literals).
2. Create/extend an `INSERT_LOCALES_<feature>.sql` MERGE with **RO+EN** for every new code
   (`N'...'`, comma-below diacritics).
3. **Insert it** via `Invoke-Sqlcmd` (UTF-8 read) against `travelplanner_dynamicconfig`.
4. **Verify diacritics by code point** (independent of console font):
   ```powershell
   $g=(Invoke-Sqlcmd -ServerInstance $srv -Database $db -Query "SELECT LocaleRo FROM Locales WHERE Code='ITINERARY_GROUP'").LocaleRo
   $g.Contains([char]0x0103)   # a-breve present?  ; 0x0219 s-comma ; 0x021B t-comma
   ```
5. `npm run lint` the changed FE files. Note that open sessions need a hard refresh (1h cache).

## Authoritative references (read on demand)
- [SQL Server Unicode / `N` prefix & nvarchar](https://learn.microsoft.com/sql/t-sql/data-types/nchar-and-nvarchar-transact-sql) \u00b7 [`MERGE`](https://learn.microsoft.com/sql/t-sql/statements/merge-transact-sql)
- [`Invoke-Sqlcmd`](https://learn.microsoft.com/powershell/module/sqlserver/invoke-sqlcmd) \u00b7 [`sqlcmd` `-f` codepage](https://learn.microsoft.com/sql/tools/sqlcmd/sqlcmd-utility)
- [Romanian orthography \u2014 comma-below \u0219/\u021b vs cedilla](https://en.wikipedia.org/wiki/Romanian_alphabet#Comma-below_versus_cedilla)

**Current best practice (2025-26):** externalize every UI string behind a stable key; keep
one key \u2192 N language values; seed idempotently (upsert), never destructively; store text as
Unicode end-to-end (`N'...'` + UTF-8 transport) and verify by code point, since a console/CI
that renders `\u0103` as `?` can hide correct storage (or mask corruption). Prefer
`Invoke-Sqlcmd` over `sqlcmd -i` for UTF-8 seed files.

## Auto-learn after each task
After a task that used this skill, reflect and improve it (full loop in
[docs-maintenance](../docs-maintenance/SKILL.md)): fold in any new locale convention, a code
that should be reused, a diacritic/encoding gotcha, or an added system language \u2014 edit this
`SKILL.md` surgically; cascade to [PROJECT_OVERVIEW.md](../../../PROJECT_OVERVIEW.md) if the
localization approach changed; then say in one line what you updated.
