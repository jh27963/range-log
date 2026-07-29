# Schema

Four databases. Two are append-only fact tables (Sessions, Purchases), two are
dimension tables (Firearms, Ammunition Inventory) whose interesting columns are
all derived.

```
                    ┌──────────────────┐
                    │    Firearms      │
                    │  (dimension)     │
                    │                  │
                    │ Lifetime Rounds ◄┼──┐  rollup
                    │ Range Trips     ◄┼──┤  rollup
                    │ Last Fired      ◄┼──┤  rollup
                    └──────────────────┘  │
                                          │ Gun
                    ┌──────────────────┐  │
                    │  Range Sessions  ├──┘
                    │  (fact, append)  │
                    └────────┬─────────┘
                             │ Ammo Stock
                             ▼
                    ┌──────────────────────┐
                    │ Ammunition Inventory │
                    │    (dimension)       │
                    │                      │
                    │ Total Rounds Fired ◄─┤ rollup (from Sessions)
                    │ Total Purchased    ◄─┤ rollup (from Purchases)
                    │ Total Spent        ◄─┤ rollup (from Purchases)
                    │ On Hand (Calc)       │ = Total Purchased − Total Rounds Fired
                    └──────────▲───────────┘
                               │ Stock
                    ┌──────────┴───────┐
                    │  Ammo Purchases  │
                    │  (fact, append)  │
                    └──────────────────┘
```

---

## Range Sessions — fact table

One row per weapon fired per visit. Shooting three guns on one trip = three rows
sharing a date.

| Column | Type | Notes |
|---|---|---|
| Firearm | title | Gun name as text. Redundant with the `Gun` relation — kept for display. |
| Date | date | |
| Caliber | select | Redundant with the gun's caliber. Denormalized on purpose for easy filtering. |
| Rounds Fired | number | |
| Ammo Type | select | FMJ, JHP, Match Grade, Hollow Point, Soft Point, Other |
| Distance (yds) | number | |
| Accuracy | select | Excellent, Good, Fair, Poor |
| Target Type | rich_text | |
| **Gun** | **relation → Firearms** | **Required.** Drives all Firearms rollups. |
| **Ammo Stock** | **relation → Ammunition Inventory** | **Required.** Drives `Total Rounds Fired`. |
| Notes | rich_text | Synthetic rows are tagged `Reconstructed — ...` here. |

## Ammo Purchases — fact table

One row per buy.

| Column | Type | Notes |
|---|---|---|
| Purchase | title | e.g. `9mm — 500 rds` |
| Date | date | |
| Caliber | select | |
| Rounds | number | |
| Total Cost | number | dollars |
| Cost per Round | formula | `Total Cost / Rounds`, guards div-by-zero |
| Ammo Type | select | |
| Brand | rich_text | |
| Vendor | rich_text | Scheels / Fleet Farm |
| **Stock** | **relation → Ammunition Inventory** | **Required.** Drives `Total Purchased`. |
| Notes | rich_text | |

## Ammunition Inventory — dimension

One row per caliber. **Never write to this table.** Everything that matters is derived.

| Column | Type | Notes |
|---|---|---|
| Caliber | title | |
| Low-Stock Alert | number | threshold; the only field you'd hand-edit |
| Total Rounds Fired | rollup | sum of `Rounds Fired` over related Sessions |
| Total Purchased | rollup | sum of `Rounds` over related Purchases |
| Total Spent | rollup | sum of `Total Cost` over related Purchases |
| **On Hand (Calc)** | **formula** | **`Total Purchased − Total Rounds Fired`. This is the stock level.** |
| Rounds on Hand | number | **DEAD.** Legacy mutable field from before the migration. Delete it. |
| Sessions | relation | back-ref from Range Sessions |
| Purchases | relation | back-ref from Ammo Purchases |
| Notes | rich_text | |

> There is a stray `.45 ACP` row and an empty untitled row in this table. Neither
> corresponds to a gun you own. Delete both.

## Firearms — dimension

One row per gun.

| Column | Type | Notes |
|---|---|---|
| Firearm | title | |
| Type | select | Pistol, Revolver, Rifle, Shotgun, AR/Modern Sporting, Rimfire, Other |
| Caliber | select | |
| Make | rich_text | |
| Model | rich_text | |
| Purchase Date | date | gates the synthetic backfill — a gun can't be fired before you owned it |
| Last Cleaned | date | pairs with `Last Fired` for a maintenance signal |
| Lifetime Rounds | rollup | sum of `Rounds Fired` over related Sessions |
| Range Trips | rollup | count of related Sessions |
| Last Fired | rollup | latest Session date |
| Sessions | relation | back-ref |
| Notes | rich_text | |

---

## Deliberate denormalizations

Two, both defensible:

**`Caliber` on Sessions and Purchases** duplicates the caliber implied by the
relation. Kept because Notion filtering and grouping on a select is far easier
than traversing a relation, and caliber never changes for a given gun.

**`Firearm` title on Sessions** duplicates the `Gun` relation's name. Kept so the
row has a readable title in list views.

Both are write-once and never updated independently, so they can't drift in
practice — the app always sets them from the same source.
