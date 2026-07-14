-- Shop window opening ('trade' keyword) and closing/invalidating sessions.

local PLAYER = 1001
local OTHER = 1002

local function focusedShopNpc(catalogBuy, catalogSell)
	local npcHandler, shop = makeShopNpc()
	-- Same order as ShopModule:parseParameters: sellable first, then buyable.
	if(catalogSell ~= nil) then
		shop:parseSellable(catalogSell)
	end
	if(catalogBuy ~= nil) then
		shop:parseBuyable(catalogBuy)
	end
	Stubs.addPlayer(PLAYER)
	npcHandler:changeFocus(PLAYER)
	return npcHandler, shop
end

Test.case('saying trade with focus opens the shop window with the full catalog', function()
	Stubs.reset()
	local npcHandler, shop = focusedShopNpc('rope,2120,50', 'rope,2120,8;spear,2389,3')

	local handled = npcHandler.keywordHandler:processMessage(PLAYER, 'trade')

	assert_true(handled, 'keyword handled')
	assert_eq(table.getn(Stubs.calls.opened), 1, 'open calls')
	local opened = Stubs.calls.opened[1]
	assert_eq(opened.cid, PLAYER, 'opened for player')
	assert_eq(table.getn(opened.items), 2, 'catalog entries on wire')
	assert_eq(opened.items[1].id, 2120, 'first entry id')
	assert_eq(opened.items[1].buyPrice, 50, 'first entry buyPrice')
	assert_eq(opened.items[1].sellPrice, 8, 'first entry sellPrice')
	assert_eq(opened.items[1].name, 'rope', 'first entry name')
	assert_eq(opened.items[1].subtype, 0, 'first entry subtype')
	assert_eq(opened.items[2].id, 2389, 'second entry id')
	assert_eq(opened.items[2].buyPrice, 0, 'sell-only entry buyPrice')

	local session = ShopModule.shopSessions[PLAYER]
	assert_true(session ~= nil and session.module == shop, 'session registered')
	assert_eq(session.npcCid, Stubs.npc.cid, 'session npc')
	assert_eq(shop.shopOpenFor, PLAYER, 'module remembers window owner')
end)

Test.case('saying trade without focus does nothing', function()
	Stubs.reset()
	local npcHandler, shop = makeShopNpc()
	shop:parseBuyable('rope,2120,50')
	Stubs.addPlayer(PLAYER)
	-- no focus at all

	npcHandler.keywordHandler:processMessage(PLAYER, 'trade')

	assert_eq(table.getn(Stubs.calls.opened), 0, 'no open call')
	assert_nil(ShopModule.shopSessions[PLAYER], 'no session')
end)

Test.case('saying trade while npc focuses someone else does nothing', function()
	Stubs.reset()
	local npcHandler, shop = focusedShopNpc('rope,2120,50')
	Stubs.addPlayer(OTHER)

	npcHandler.keywordHandler:processMessage(OTHER, 'trade')

	assert_eq(table.getn(Stubs.calls.opened), 0, 'no open call')
	assert_nil(ShopModule.shopSessions[OTHER], 'no session')
end)

Test.case('trade with an empty catalog does not open a window', function()
	Stubs.reset()
	local npcHandler, shop = focusedShopNpc(nil, nil)

	npcHandler.keywordHandler:processMessage(PLAYER, 'trade')

	assert_eq(table.getn(Stubs.calls.opened), 0, 'no open call')
end)

Test.case('farewell closes the shop window and clears the session', function()
	Stubs.reset()
	local npcHandler, shop = focusedShopNpc('rope,2120,50')
	npcHandler.keywordHandler:processMessage(PLAYER, 'trade')

	npcHandler:unGreet()

	assert_eq(table.getn(Stubs.calls.closed), 1, 'close packet sent')
	assert_eq(Stubs.calls.closed[1].cid, PLAYER, 'closed for player')
	assert_nil(ShopModule.shopSessions[PLAYER], 'session cleared')
	assert_nil(shop.shopOpenFor, 'module window owner cleared')
end)

Test.case('walking away closes the shop window', function()
	Stubs.reset()
	local npcHandler, shop = focusedShopNpc('rope,2120,50')
	npcHandler.keywordHandler:processMessage(PLAYER, 'trade')

	npcHandler:onWalkAway(PLAYER)

	assert_eq(table.getn(Stubs.calls.closed), 1, 'close packet sent')
	assert_nil(ShopModule.shopSessions[PLAYER], 'session cleared')
end)

Test.case('logout (creature disappear) clears the session even if the player is gone', function()
	Stubs.reset()
	local npcHandler, shop = focusedShopNpc('rope,2120,50')
	npcHandler.keywordHandler:processMessage(PLAYER, 'trade')

	Stubs.removePlayer(PLAYER)
	npcHandler:onCreatureDisappear(PLAYER)

	assert_eq(table.getn(Stubs.calls.closed), 0, 'no packet to a gone player')
	assert_nil(ShopModule.shopSessions[PLAYER], 'session cleared')
	assert_nil(shop.shopOpenFor, 'module window owner cleared')
end)

Test.case('disappear of a non-focused creature does not touch the session', function()
	Stubs.reset()
	local npcHandler, shop = focusedShopNpc('rope,2120,50')
	npcHandler.keywordHandler:processMessage(PLAYER, 'trade')

	npcHandler:onCreatureDisappear(OTHER)

	assert_true(ShopModule.shopSessions[PLAYER] ~= nil, 'session kept')
end)

Test.case('client-initiated close clears the session without a close packet', function()
	Stubs.reset()
	local npcHandler, shop = focusedShopNpc('rope,2120,50')
	npcHandler.keywordHandler:processMessage(PLAYER, 'trade')

	local ret = npcsystem_onShopEvent(PLAYER, SHOPEVENT_CLOSE, 0, 0, 0)

	assert_true(ret, 'close event handled')
	assert_eq(table.getn(Stubs.calls.closed), 0, 'no close packet echoed')
	assert_nil(ShopModule.shopSessions[PLAYER], 'session cleared')
end)

Test.case('shop events without a session or from the wrong npc are ignored', function()
	Stubs.reset()
	local npcHandler, shop = focusedShopNpc('rope,2120,50')

	assert_eq(npcsystem_onShopEvent(PLAYER, SHOPEVENT_CLOSE, 0, 0, 0), false, 'no session')

	npcHandler.keywordHandler:processMessage(PLAYER, 'trade')
	Stubs.npc.cid = 6000 -- event dispatched to a different npc's environment
	assert_eq(npcsystem_onShopEvent(PLAYER, SHOPEVENT_CLOSE, 0, 0, 0), false, 'wrong npc')
	assert_true(ShopModule.shopSessions[PLAYER] ~= nil, 'session kept')
end)

Test.case('opening a shop with a second npc supersedes the first session', function()
	Stubs.reset()
	-- First npc opens.
	local h1, shop1 = focusedShopNpc('rope,2120,50')
	h1.keywordHandler:processMessage(PLAYER, 'trade')
	assert_eq(ShopModule.shopSessions[PLAYER].module, shop1, 'first session')

	-- Second npc (different environment) opens for the same player.
	Stubs.npc = {cid = 6000, name = 'Second NPC', pos = {x = 200, y = 200, z = 7}}
	local h2, shop2 = makeShopNpc()
	shop2:parseBuyable('shovel,2554,50')
	h2:changeFocus(PLAYER)
	h2.keywordHandler:processMessage(PLAYER, 'trade')

	assert_eq(ShopModule.shopSessions[PLAYER].module, shop2, 'session superseded')
	assert_eq(ShopModule.shopSessions[PLAYER].npcCid, 6000, 'owned by second npc')
	-- C++ closed the first window implicitly on reopen.
	assert_eq(table.getn(Stubs.calls.closed), 1, 'implicit close of first window')
	assert_true(Stubs.calls.closed[1].implicit, 'close was implicit')

	-- A later farewell from the first npc must not close the second window.
	h1:unGreet()
	assert_eq(table.getn(Stubs.calls.closed), 1, 'no spurious close')
	assert_true(ShopModule.shopSessions[PLAYER] ~= nil, 'second session intact')
	assert_nil(shop1.shopOpenFor, 'first module cleaned up')
end)

Test.case('enableNpcShopWindow = false disables the window but not conversation', function()
	Stubs.reset()
	Stubs.config.enableNpcShopWindow = false
	local npcHandler, shop = focusedShopNpc('rope,2120,50')

	npcHandler.keywordHandler:processMessage(PLAYER, 'trade')
	assert_eq(table.getn(Stubs.calls.opened), 0, 'no open call')
	assert_nil(ShopModule.shopSessions[PLAYER], 'no session')

	-- Conversational buying keeps working with the window disabled.
	npcHandler.keywordHandler:processMessage(PLAYER, 'rope')
	npcHandler.keywordHandler:processMessage(PLAYER, 'yes')
	assert_eq(table.getn(Stubs.calls.buys), 1, 'conversational purchase intact')
end)

Test.case('enableNpcShopWindow = true (and unset) keeps the window enabled', function()
	Stubs.reset()
	Stubs.config.enableNpcShopWindow = true
	local npcHandler, shop = focusedShopNpc('rope,2120,50')

	npcHandler.keywordHandler:processMessage(PLAYER, 'trade')
	assert_eq(table.getn(Stubs.calls.opened), 1, 'window opened')
end)
