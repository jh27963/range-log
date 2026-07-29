# IDs & endpoints

## Relay

```
https://range-log.jd9hall.workers.dev
```

Health check: `GET /` → `{"ok":true,"service":"range-log relay"}`

Allowlisted endpoints (anything else 403s):

| Method | Path |
|---|---|
| POST | `/v1/data_sources/{id}/query` |
| POST | `/v1/pages` |
| PATCH | `/v1/pages/{id}` |

## Notion API

Version: **`2025-09-03`** (set in `worker/worker.js`)

## Data source IDs

Used for `/v1/data_sources/{id}/query` and as `data_source_id` when creating pages.
Hyphenated form works in MCP tools; strip hyphens for REST paths.

| Table | Data source ID |
|---|---|
| Range Sessions | `4fae7323-f890-47c9-8004-c43c8fb27cac` |
| Ammunition Inventory | `40bb29d1-af4d-4bb0-9b53-c5826f896600` |
| Firearms | `e850e5dc-bf3f-43d4-9a77-6577c60b5ecb` |
| Ammo Purchases | `c7fa221c-d512-43c4-a95f-60853ff68e37` |

For SQL via MCP, prefix with `collection://`:

```sql
FROM "collection://4fae7323-f890-47c9-8004-c43c8fb27cac"
```

## Firearms — page IDs

Needed when writing a session's `Gun` relation.

| Firearm | Caliber | Page ID |
|---|---|---|
| Canik SFx Rival S | 9mm | `39ac22d4-2b50-81aa-8065-e45d85cc2872` |
| Springfield Hellcat Pro Comp | 9mm | `39ac22d4-2b50-81cc-b585-f565eed84d5e` |
| S&W Bodyguard 2.0 | .380 ACP | `39ac22d4-2b50-8166-9f85-c5517f940830` |
| Ruger 10/22 | .22 LR | `39ac22d4-2b50-80b0-96be-f5a8ad95017f` |
| 16' AR 15 BCA | 5.56 NATO | `39ac22d4-2b50-8020-a0f7-fc4868733407` |

## Ammunition Inventory — page IDs

Needed for the `Ammo Stock` and `Stock` relations.

| Caliber | Page ID |
|---|---|
| 9mm | `39ac22d4-2b50-8139-84ec-d43a3db04798` |
| .380 ACP | `39ac22d4-2b50-812f-bc49-de76c900de3d` |
| 5.56 NATO | `39ac22d4-2b50-8118-88b3-c9a5161afcd0` |
| .22 LR | `39ac22d4-2b50-81bb-b9df-ee9eedf8eee4` |

## Notion pages

| Page | URL |
|---|---|
| Range Log (parent) | https://app.notion.com/p/39ac22d42b50819c8be0f945805ffa57 |
| Ammunition Dashboard | https://app.notion.com/p/39ac22d42b508155b0b3cead48f5abf1 |
| Ideas & Backlog | https://app.notion.com/p/39bc22d42b5081e385f8f2c6a29c8227 |

## Deployment

| Thing | Where |
|---|---|
| Worker | Cloudflare → Workers & Pages → `range-log` |
| App | Netlify (currently `range-log-app-v5.netlify.app`) |
| Secret | Worker → Settings → Variables → `NOTION_TOKEN` (encrypted) |
| CORS lock | Worker → Variables → `ALLOWED_ORIGIN` (plain text, must exactly match the app's origin — no trailing slash) |
