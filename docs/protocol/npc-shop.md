# NPC Shop Window Protocol (opcodes 0x7A–0x7C)

Server-side support for a structured NPC shop window, added on top of Jiddo's
npcsystem (`module_shop`). A focused player saying **`trade`** to a shop NPC
receives the full catalog; the client can then send buy/sell requests that are
validated entirely server-side. The conversational flow ("buy rope" → "yes")
keeps working unchanged as a fallback.

The window can be disabled server-wide with `enableNpcShopWindow = false` in
`config.lua` (unset or `true` = enabled) — useful when stock 7.6 clients
connect, since they debug-assert on unknown opcodes. Conversational
buying/selling works regardless of the flag.

These opcodes are unused by the 7.6 protocol in both directions (verified
against every `case` in `Protocol76::parsePacket` and every outgoing
`AddByte(type)` in `protocol76.cpp`). They deliberately do **not** touch the
player-to-player trade opcodes **0x7D–0x80**, which remain exactly as before.

## Wire conventions

- All integers are **little-endian** (`NetworkMessage` convention).
- `string` = `u16 length` followed by `length` raw bytes, **no** NUL terminator.
- Catalog entries carry **both** item ids:
  - `serverItemId` — the server-side item id. Clients **echo this id back** in
    buy/sell requests; there is no ambiguous clientId→serverId reverse mapping.
  - `clientSpriteId` — `Item::items[id].clientId`, for rendering only.
- `subType` is the charge count for runes, the fluid type for fluid
  containers, and `0` for everything else. Requests must echo the entry's
  `subType` exactly.

## Server → Client

### 0x7A — OpenShopWindow

Sent when the focused player says `trade` (always followed by an `0x7B`).

| Field | Type | Notes |
|---|---|---|
| opcode | `u8` | `0x7A` |
| npcName | `string` | window title |
| itemCount | `u16` | number of catalog entries |
| — per entry — | | |
| serverItemId | `u16` | echo this in requests |
| clientSpriteId | `u16` | for rendering |
| subType | `u8` | charges / fluid type / 0 |
| name | `string` | shop keyword name from the NPC XML (`realname` if configured) |
| buyPrice | `u32` | gold per unit; `0` = not buyable |
| sellPrice | `u32` | gold per unit; `0` = not sellable |

### 0x7B — ShopGoods

Sent right after `0x7A` and again after every **successful** transaction.

| Field | Type | Notes |
|---|---|---|
| opcode | `u8` | `0x7B` |
| playerMoney | `u32` | total gold the player carries |
| goodsCount | `u8` | entries follow (only sellable items the player owns; capped at 255) |
| — per entry — | | |
| serverItemId | `u16` | |
| count | `u16` | player-owned count, capped at 65535; counted **by item id**, subtype-agnostic (matches `doPlayerTakeItem` sell semantics) |

### 0x7C — CloseShopWindow

| Field | Type | Notes |
|---|---|---|
| opcode | `u8` | `0x7C`, no payload |

Sent when: the NPC conversation ends (farewell words, ~30s idle timeout,
walking out of talk radius), a transaction request arrives after focus/range
was silently lost, the owning NPC despawned, or another NPC opens a shop for
the same player (the old window is closed before the new `0x7A`).

**Clients must tolerate unsolicited `0x7B` and `0x7C` at any time.**

## Client → Server

### 0x7A — Buy / 0x7B — Sell

| Field | Type | Notes |
|---|---|---|
| opcode | `u8` | `0x7A` buy, `0x7B` sell |
| serverItemId | `u16` | from the catalog entry |
| subType | `u8` | must equal the catalog entry's subType |
| amount | `u8` | valid range **1..100** |

No prices are ever sent by the client; totals are computed server-side as
`catalogPrice × amount`.

### 0x7C — CloseShop

| Field | Type | Notes |
|---|---|---|
| opcode | `u8` | `0x7C`, no payload |

The server clears the session silently (no `0x7C` echo).

## Validation ladder (server)

1. **C++, dispatcher thread** (`Game::playerShopBuy/Sell`, `game.cpp`):
   player exists and is not removed; `amount` in 1..100; player has an open
   shop session; the owning NPC still exists (otherwise `0x7C` is sent and the
   session cleared); same floor and Chebyshev distance ≤ 7; the
   (serverItemId, subType) pair exists in the catalog the server itself sent,
   on the correct side (buyPrice/sellPrice > 0).
2. **Lua** (`ShopModule:onShopBuy/onShopSell`, `modules.lua`): session
   ownership (`npcsystem_onShopEvent` checks the owning npc cid); the NPC
   still **focuses** this player; player within `talkRadius` and on the same
   floor; amount 1..`SHOPMODULE_MAX_WINDOW_AMOUNT` (100); catalog entry lookup
   by (itemid, subtype); the transaction reuses the existing
   `doPlayerBuyItem(cid, itemid, amount, totalCost, charges)` /
   `doPlayerSellItem(cid, itemid, amount, totalPayout)` from
   `data/functions.lua`, so money, inventory and subtype handling are
   identical to the conversational flow. On failure the NPC answers with
   MESSAGE_NEEDMOREMONEY / MESSAGE_NOTHAVEITEM and no goods update is sent.

Intentional gameplay semantics kept from the conversational flow:

- If the buyer lacks free capacity/slots, the purchase is dropped at their
  feet (`doPlayerGiveItem` fallback) — same as "buy rope" today.
- Selling counts items by id regardless of subtype (`doPlayerTakeItem`).

## Client-side assumptions (for the web client implementation)

- Say `hi` then `trade` to a shop NPC to trigger `0x7A`; there is no
  client-initiated "request catalog" opcode.
- Render items by `clientSpriteId` (+ `subType` for fluids/stackables), echo
  `serverItemId` + `subType` in requests.
- Amount UI should be bounded to 1..100.
- Track window lifetime purely from `0x7A`/`0x7C`; money and sellable counts
  purely from `0x7B`.
- Transaction feedback (success/insufficient funds/missing item) arrives as
  normal NPC speech (`0xAA` creature say), not as a dedicated shop opcode.
