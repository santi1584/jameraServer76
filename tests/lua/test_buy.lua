-- Shop window buy requests: validation and delegation to doPlayerBuyItem.

local PLAYER = 1001

local function openShop(catalogBuy, catalogSell)
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
	npcHandler.keywordHandler:processMessage(PLAYER, 'trade')
	return npcHandler, shop
end

Test.case('valid buy uses catalog price and existing doPlayerBuyItem', function()
	Stubs.reset()
	openShop('rope,2120,50')

	local ret = npcsystem_onShopEvent(PLAYER, SHOPEVENT_BUY, 2120, 0, 3)

	assert_true(ret, 'buy handled')
	assert_eq(table.getn(Stubs.calls.buys), 1, 'one transaction')
	local buy = Stubs.calls.buys[1]
	assert_eq(buy.itemid, 2120, 'itemid')
	assert_eq(buy.count, 3, 'count')
	assert_eq(buy.cost, 150, 'total cost from catalog (50 x 3)')
	assert_nil(buy.charges, 'no charges for plain item')
	assert_eq(table.getn(Stubs.calls.goods), 2, 'goods re-sent after purchase (open + buy)')
	assert_true(string.find(lastCall(Stubs.calls.said), 'pleasure') ~= nil, 'MESSAGE_ONBUY said')
end)

Test.case('buy of a fluid preserves charges/subtype', function()
	Stubs.reset()
	Stubs.setItemType(2006, {fluid = true})
	openShop('life fluid,2006,60,10')

	local ret = npcsystem_onShopEvent(PLAYER, SHOPEVENT_BUY, 2006, 10, 5)

	assert_true(ret, 'buy handled')
	local buy = Stubs.calls.buys[1]
	assert_eq(buy.itemid, 2006, 'itemid')
	assert_eq(buy.count, 5, 'count')
	assert_eq(buy.cost, 300, 'total cost from catalog')
	assert_eq(buy.charges, 10, 'fluid subtype forwarded as charges')
end)

Test.case('buy with wrong subtype is rejected', function()
	Stubs.reset()
	Stubs.setItemType(2006, {fluid = true})
	openShop('life fluid,2006,60,10')

	local ret = npcsystem_onShopEvent(PLAYER, SHOPEVENT_BUY, 2006, 7, 1)

	assert_eq(ret, false, 'rejected')
	assert_eq(table.getn(Stubs.calls.buys), 0, 'no transaction')
end)

Test.case('buy of an item outside the catalog is rejected', function()
	Stubs.reset()
	openShop('rope,2120,50')

	local ret = npcsystem_onShopEvent(PLAYER, SHOPEVENT_BUY, 2554, 0, 1)

	assert_eq(ret, false, 'rejected')
	assert_eq(table.getn(Stubs.calls.buys), 0, 'no transaction')
end)

Test.case('buy of a sell-only item is rejected', function()
	Stubs.reset()
	openShop('rope,2120,50', 'spear,2389,3')

	local ret = npcsystem_onShopEvent(PLAYER, SHOPEVENT_BUY, 2389, 0, 1)

	assert_eq(ret, false, 'rejected')
	assert_eq(table.getn(Stubs.calls.buys), 0, 'no transaction')
end)

Test.case('excessive or zero quantities are rejected', function()
	Stubs.reset()
	openShop('rope,2120,50')

	assert_eq(npcsystem_onShopEvent(PLAYER, SHOPEVENT_BUY, 2120, 0, 0), false, 'zero rejected')
	assert_eq(npcsystem_onShopEvent(PLAYER, SHOPEVENT_BUY, 2120, 0, 101), false, '101 rejected')
	assert_eq(npcsystem_onShopEvent(PLAYER, SHOPEVENT_BUY, 2120, 0, 500), false, '500 rejected')
	assert_eq(npcsystem_onShopEvent(PLAYER, SHOPEVENT_BUY, 2120, 0, nil), false, 'nil rejected')
	assert_eq(table.getn(Stubs.calls.buys), 0, 'no transactions')

	assert_true(npcsystem_onShopEvent(PLAYER, SHOPEVENT_BUY, 2120, 0, 100), '100 accepted')
	assert_eq(Stubs.calls.buys[1].cost, 5000, 'boundary cost')
end)

Test.case('buy after losing focus is rejected and the window closes', function()
	Stubs.reset()
	local npcHandler, shop = openShop('rope,2120,50')
	npcHandler.focus = 0 -- focus silently lost (no callback fired)

	local ret = npcsystem_onShopEvent(PLAYER, SHOPEVENT_BUY, 2120, 0, 1)

	assert_eq(ret, false, 'rejected')
	assert_eq(table.getn(Stubs.calls.buys), 0, 'no transaction')
	assert_eq(table.getn(Stubs.calls.closed), 1, 'window closed')
	assert_nil(ShopModule.shopSessions[PLAYER], 'session cleared')
end)

Test.case('buy from out of range is rejected and the window closes', function()
	Stubs.reset()
	local npcHandler, shop = openShop('rope,2120,50')
	Stubs.addPlayer(PLAYER, {pos = {x = 150, y = 100, z = 7}}) -- teleported away

	local ret = npcsystem_onShopEvent(PLAYER, SHOPEVENT_BUY, 2120, 0, 1)

	assert_eq(ret, false, 'rejected')
	assert_eq(table.getn(Stubs.calls.buys), 0, 'no transaction')
	assert_eq(table.getn(Stubs.calls.closed), 1, 'window closed')
end)

Test.case('buy from a different floor is rejected', function()
	Stubs.reset()
	local npcHandler, shop = openShop('rope,2120,50')
	Stubs.addPlayer(PLAYER, {pos = {x = 101, y = 100, z = 6}})

	local ret = npcsystem_onShopEvent(PLAYER, SHOPEVENT_BUY, 2120, 0, 1)

	assert_eq(ret, false, 'rejected')
	assert_eq(table.getn(Stubs.calls.buys), 0, 'no transaction')
end)

Test.case('failed transaction says NEEDMOREMONEY and does not update goods', function()
	Stubs.reset()
	openShop('rope,2120,50')
	Stubs.buyResult = LUA_ERROR

	local ret = npcsystem_onShopEvent(PLAYER, SHOPEVENT_BUY, 2120, 0, 1)

	assert_eq(ret, false, 'reported as failed')
	assert_eq(table.getn(Stubs.calls.goods), 1, 'goods only from open, not re-sent')
	assert_true(string.find(lastCall(Stubs.calls.said), 'money') ~= nil, 'MESSAGE_NEEDMOREMONEY said')
end)
