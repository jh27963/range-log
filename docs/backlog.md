# Backlog

Mirrors the [Ideas & Backlog](https://app.notion.com/p/39bc22d42b5081e385f8f2c6a29c8227)
page in Notion. Keep them roughly in sync, or pick one as canonical and delete this.

## Cleanup (do first — these are small and they're actively wrong)

- [x] Fix the `ALLOWED_ORIGIN` typo on the Worker so the CORS lock actually works.
- [x] Retire old Netlify deploys (v2, v4, `ranng-log-app`). Settle on one URL —
      done via the Supabase migration: the app now lives on Cloudflare Pages
      at `range-log-app.pages.dev`, the one canonical URL.
- [x] Log tab footnote still says it "deducts rounds from inventory." Fixed
      in the same migration, since that code was already being touched.
- [ ] Delete the dead `Rounds on Hand` column on Ammunition Inventory.
      Rename `On Hand (Calc)` → `Rounds on Hand` to take its place. **Moot** —
      this was Notion-only, and Notion is now a read-only backup, not part
      of the live path. Only matters if you're cleaning up the backup itself.
- [ ] Delete the `.45 ACP` inventory row (no such gun) and the empty untitled row.
      **Moot for the live app** — these were already excluded when the data
      moved to Supabase (see `docs/supabase-migration.md`). Only matters for
      the Notion backup itself.
- [ ] Link the 2026-07-09 Canik session to its Ammo Stock row — it predates the
      relation, which is why 9mm reads 600 instead of 650. **Unverified as of
      the Supabase migration** — that session's row was found with both `Gun`
      and `Ammo Stock` already populated during extraction, so either this was
      already fixed in Notion before the migration or the note is stale.
      The migrated Supabase data reflects whatever Notion had at migration
      time (9mm on-hand reconciled to 600, matching `sql/inventory-reconcile.sql`).
      If 650 is actually correct, it needs a manual correction in Supabase now,
      not in Notion.

## Drill-down by weapon (the next real feature)

Tap a gun on the Guns tab → its own page.

- [ ] Full session history for that weapon
- [ ] Rounds-over-time chart
- [ ] Accuracy distribution / trend
- [ ] Average distance
- [ ] Cost per session (join the purchase ledger for $/rd by caliber)
- [ ] **Rounds since last cleaned** — pairs `Last Cleaned` against sessions after
      that date. See `sql/maintenance.sql`. Genuinely useful; nothing
      off-the-shelf does it.

**Needs no Worker change.** A filtered
`POST /v1/data_sources/{sessions}/query` with a relation filter on the gun ID uses
the endpoint that's already allowlisted.

**Build it in Notion first.** A linked view of Sessions grouped by Gun costs five
clicks and zero code. Live with it a week, see what you actually reach for, then
port only that into the app. Cheaper than guessing.

## Not yet fleshed out

- [ ]
