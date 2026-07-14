-- Shop window sell requests: validation and delegation to doPlayerSellItem.

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

Test.case('valid sell uses catalog price and existing doPlayerSellItem', function()
	Stubs.reset()
	openShop('rope,2120,50', 'rope,2120,8')

	local ret = npcsystem_onShopEvent(PLAYER, SHOPEVENT_SELL, 2120, 0, 4)

	assert_true(ret, 'sell handled')
	assert_eq(table.getn(Stubs.calls.sells), 1, 'one transaction')
	local sell = Stubs.calls.sells[1]
	assert_eq(sell.itemid, 2120, 'itemid')
	assert_eq(sell.count, 4, 'count')
	assert_eq(sell.cost, 32, 'total payout from catalog (8 x 4)')
	assert_eq(table.getn(Stubs.calls.goods), 2, 'goods re-sent after sale')
	assert_true(string.find(lastCall(Stubs.calls.said), 'Thank you') ~= nil, 'MESSAGE_ONSELL said')
end)

Test.case('selling a buy-only item is rejected', function()
	Stubs.reset()
	openShop('rope,2120,50', 'spear,2389,3')

	local ret = npcsystem_onShopEvent(PLAYER, SHOPEVENT_SELL, 2120, 0, 1)

	assert_eq(ret, false, 'rejected')
	assert_eq(table.getn(Stubs.calls.sells), 0, 'no transaction')
end)

Test.case('selling an item outside the catalog is rejected', function()
	Stubs.reset()
	openShop(nil, 'spear,2389,3')

	local ret = npcsystem_onShopEvent(PLAYER, SHOPEVENT_SELL, 9999, 0, 1)

	assert_eq(ret, false, 'rejected')
	assert_eq(table.getn(Stubs.calls.sells), 0, 'no transaction')
end)

Test.case('sell quantities are bounded', function()
	Stubs.reset()
	openShop(nil, 'spear,2389,3')

	assert_eq(npcsystem_onShopEvent(PLAYER, SHOPEVENT_SELL, 2389, 0, 0), false, 'zero rejected')
	assert_eq(npcsystem_onShopEvent(PLAYER, SHOPEVENT_SELL, 2389, 0, 101), false, '101 rejected')
	assert_eq(table.getn(Stubs.calls.sells), 0, 'no transactions')
end)

Test.case('failed sell says NOTHAVEITEM and does not update goods', function()
	Stubs.reset()
	openShop(nil, 'spear,2389,3')
	Stubs.sellResult = LUA_ERROR

	local ret = npcsystem_onShopEvent(PLAYER, SHOPEVENT_SELL, 2389, 0, 5)

	assert_eq(ret, false, 'reported as failed')
	assert_eq(table.getn(Stubs.calls.goods), 1, 'goods only from open')
	assert_true(string.find(lastCall(Stubs.calls.said), 'have that item') ~= nil, 'MESSAGE_NOTHAVEITEM said')
end)

Test.case('sell after losing focus is rejected and the window closes', function()
	Stubs.reset()
	local npcHandler, shop = openShop(nil, 'spear,2389,3')
	npcHandler.focus = 0

	local ret = npcsystem_onShopEvent(PLAYER, SHOPEVENT_SELL, 2389, 0, 1)

	assert_eq(ret, false, 'rejected')
	assert_eq(table.getn(Stubs.calls.sells), 0, 'no transaction')
	assert_eq(table.getn(Stubs.calls.closed), 1, 'window closed')
end)
