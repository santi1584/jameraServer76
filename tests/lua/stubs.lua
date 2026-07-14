-- Stub environment emulating the C++ Lua bindings the npcsystem uses, so the
-- real data/npc/scripts/lib/npcsystem files can run under plain lua5.1.
-- The shop-window bindings mirror the semantics of the C++ implementations in
-- "source 7.6/npc.cpp" (ownership checks, close-previous-shop-on-reopen).

Stubs = {}

-- Constants from data/global.lua
TRUE = 1
FALSE = 0
LUA_ERROR = -1
LUA_NO_ERROR = 0

local itemTypes = {}
local players = {}

-- The npc whose script environment is currently executing (getNpcCid()).
Stubs.npc = {cid = 5000, name = 'Test NPC', pos = {x = 100, y = 100, z = 7}}

-- Equivalent of Player::shopOwnerId on the C++ side: [playerCid] = npcCid
Stubs.shopOwner = {}

function Stubs.reset()
	itemTypes = {}
	players = {}
	Stubs.npc = {cid = 5000, name = 'Test NPC', pos = {x = 100, y = 100, z = 7}}
	Stubs.shopOwner = {}
	Stubs.buyResult = LUA_NO_ERROR
	Stubs.sellResult = LUA_NO_ERROR
	Stubs.config = {}
	Stubs.calls = {
		opened = {},
		closed = {},
		goods = {},
		buys = {},
		sells = {},
		said = {}
	}
	if(ShopModule ~= nil) then
		ShopModule.shopSessions = {}
	end
end

function Stubs.setItemType(id, info)
	itemTypes[id] = info
end

function Stubs.addPlayer(cid, opts)
	opts = opts or {}
	players[cid] = {
		name = opts.name or ('Player' .. cid),
		pos = opts.pos or {x = 101, y = 100, z = 7}
	}
	return players[cid]
end

function Stubs.removePlayer(cid)
	players[cid] = nil
end

-- ---------------------------------------------------------------------------
-- Item information bindings (luascript.cpp)
-- ---------------------------------------------------------------------------
function isItemRune(itemid)
	local it = itemTypes[itemid]
	if(it ~= nil and it.rune) then
		return TRUE
	end
	return FALSE
end

function isItemFluidContainer(itemid)
	local it = itemTypes[itemid]
	if(it ~= nil and it.fluid) then
		return TRUE
	end
	return FALSE
end

function isItemStackable(itemid)
	local it = itemTypes[itemid]
	if(it ~= nil and it.stackable) then
		return TRUE
	end
	return FALSE
end

-- ---------------------------------------------------------------------------
-- Player/npc bindings (luascript.cpp, npc.cpp)
-- ---------------------------------------------------------------------------
function getPlayerName(cid)
	local p = players[cid]
	if(p == nil) then
		return LUA_ERROR
	end
	return p.name
end

function getPlayerPosition(cid)
	local p = players[cid]
	if(p == nil) then
		return LUA_ERROR
	end
	return {x = p.pos.x, y = p.pos.y, z = p.pos.z, stackpos = 1}
end

function selfGetPosition()
	return Stubs.npc.pos.x, Stubs.npc.pos.y, Stubs.npc.pos.z
end

function selfSay(message)
	table.insert(Stubs.calls.said, message)
end

function doNpcSetCreatureFocus(cid)
	Stubs.calls.focus = cid
end

function getNpcCid()
	return Stubs.npc.cid
end

-- config.lua access (luascript.cpp luaGetConfigValue); nil for unset keys,
-- booleans arrive as booleans (ConfigManager::moveValue).
function getConfigValue(key)
	return Stubs.config[key]
end

-- ---------------------------------------------------------------------------
-- Shop window bindings (npc.cpp: NpcScriptInterface::luaOpenShopWindow & co.)
-- ---------------------------------------------------------------------------
function doPlayerOpenShopWindow(cid, items)
	if(players[cid] == nil) then
		return LUA_ERROR
	end
	if(Stubs.shopOwner[cid] ~= nil and Stubs.shopOwner[cid] ~= getNpcCid()) then
		-- C++ closes the previous npc's window before opening the new one.
		table.insert(Stubs.calls.closed, {cid = cid, implicit = true})
	end
	Stubs.shopOwner[cid] = getNpcCid()
	table.insert(Stubs.calls.opened, {cid = cid, npcCid = getNpcCid(), items = items})
	table.insert(Stubs.calls.goods, {cid = cid})
	return LUA_NO_ERROR
end

function doPlayerCloseShopWindow(cid)
	if(players[cid] == nil) then
		return LUA_ERROR
	end
	if(Stubs.shopOwner[cid] ~= getNpcCid()) then
		return LUA_ERROR
	end
	Stubs.shopOwner[cid] = nil
	table.insert(Stubs.calls.closed, {cid = cid})
	return LUA_NO_ERROR
end

function doPlayerSendShopGoods(cid)
	if(players[cid] == nil or Stubs.shopOwner[cid] ~= getNpcCid()) then
		return LUA_ERROR
	end
	table.insert(Stubs.calls.goods, {cid = cid})
	return LUA_NO_ERROR
end

-- ---------------------------------------------------------------------------
-- Transaction functions (data/functions.lua), stubbed with configurable results
-- ---------------------------------------------------------------------------
Stubs.buyResult = LUA_NO_ERROR
function doPlayerBuyItem(cid, itemid, count, cost, charges)
	table.insert(Stubs.calls.buys, {cid = cid, itemid = itemid, count = count, cost = cost, charges = charges})
	return Stubs.buyResult
end

Stubs.sellResult = LUA_NO_ERROR
function doPlayerSellItem(cid, itemid, count, cost)
	table.insert(Stubs.calls.sells, {cid = cid, itemid = itemid, count = count, cost = cost})
	return Stubs.sellResult
end

-- ---------------------------------------------------------------------------
-- Test helpers
-- ---------------------------------------------------------------------------

-- Builds a real NpcHandler + ShopModule pair, wired exactly like
-- NpcSystem.parseParameters does (addModule -> init, then parsing).
function makeShopNpc()
	local keywordHandler = KeywordHandler:new()
	local npcHandler = NpcHandler:new(keywordHandler)
	local shop = ShopModule:new()
	npcHandler:addModule(shop)
	return npcHandler, shop
end

function lastCall(list)
	return list[table.getn(list)]
end
