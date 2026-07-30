# IDs & endpoints

## Relay

```
https://range-log.jd9hall.workers.dev
```

Health check: `GET /` → `{"ok":true,"service":"range-log relay"}`

Allowlisted endpoints (anything else 403s):

| Method | Path | Backs onto |
|---|---|---|
| GET | `/firearms` | `firearms_calc` view |
| GET | `/inventory` | `ammunition_inventory_calc` view |
| GET | `/sessions` | `range_sessions` table (raw `date`,`rounds_fired` — client buckets by month for the Dashboard chart) |
| POST | `/sessions` | `range_sessions` table |
| POST | `/purchases` | `ammo_purchases` table |

## Supabase

Project ref: `ywblwmbaiplnphiqzalm` ("jh27963's Project" — shared with other
projects, not dedicated to Range Log). See `supabase/schema.sql` for the
full DDL.

## Firearms — row IDs

Needed when writing a session's `firearm_id`.

| Firearm | Caliber | id |
|---|---|---|
| Canik SFx Rival S | 9mm | `7e534bc9-99ac-4f61-9b4f-ac227e641047` |
| Springfield Hellcat Pro Comp | 9mm | `b63ddf5b-dbd4-4dc6-8a0f-848081cf15be` |
| S&W Bodyguard 2.0 | .380 ACP | `ff270dff-580f-426a-b702-56ce91fbadd4` |
| Ruger 10/22 | .22 LR | `4736af7f-1c32-4c1f-b1aa-f189a195dbb8` |
| 16' AR 15 BCA | 5.56 NATO | `4d246035-f82c-475f-8408-96636b91c488` |

## Ammunition Inventory — row IDs

Needed for `ammo_stock_id` / `stock_id`.

| Caliber | id |
|---|---|
| 9mm | `1a10eee7-e231-4f79-83c7-fb108fea5b4c` |
| .380 ACP | `2ed1a0ed-bd81-409c-abc3-fdf9bd5aa448` |
| 5.56 NATO | `500857df-1039-4abf-86f5-236f6a826ea6` |
| .22 LR | `3266ed4c-a8e0-4e1e-ba1d-7d22ecec4583` |

## Deployment

| Thing | Where |
|---|---|
| Worker | Cloudflare → Workers & Pages → `range-log` |
| App | Cloudflare Pages → `range-log-app` → `range-log-app.pages.dev` |
| Secrets | Worker → Settings → Variables → `SUPABASE_SERVICE_KEY` (encrypted) |
| Plain vars | Worker → Variables → `SUPABASE_URL`, `ALLOWED_ORIGIN` |
| CORS lock | `ALLOWED_ORIGIN` must exactly match the app's origin — no trailing slash |

## Legacy — Notion (read-only backup, not part of the live path)

The app ran on Notion until the Supabase migration (2026-07-29). Notion is
left in place, untouched, as a historical backup — nothing writes to it
anymore. Kept here in case anyone needs to go back and read it directly.

| Table | Data source ID |
|---|---|
| Range Sessions | `4fae7323-f890-47c9-8004-c43c8fb27cac` |
| Ammunition Inventory | `40bb29d1-af4d-4bb0-9b53-c5826f896600` |
| Firearms | `e850e5dc-bf3f-43d4-9a77-6577c60b5ecb` |
| Ammo Purchases | `c7fa221c-d512-43c4-a95f-60853ff68e37` |

Each Supabase row's `notion_id` column is the original Notion page ID
(hyphenated), for anyone tracing a row back to its source.

| Page | URL |
|---|---|
| Range Log (parent) | https://app.notion.com/p/39ac22d42b50819c8be0f945805ffa57 |
| Ammunition Dashboard | https://app.notion.com/p/39ac22d42b508155b0b3cead48f5abf1 |
| Ideas & Backlog | https://app.notion.com/p/39bc22d42b5081e385f8f2c6a29c8227 |
