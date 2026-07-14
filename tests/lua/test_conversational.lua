-- Regression: the conversational buy/sell flow ("buy rope" -> "yes") must
-- keep working exactly as before, including alongside an open shop window.

local PLAYER = 1001

local function focusedShopNpc()
	local npcHandler, shop = makeShopNpc()
	-- Same order as ShopModule:parseParameters: sellable first, then buyable.
	shop:parseSellable('rope,2120,8')
	shop:parseBuyable('rope,2120,50')
	Stubs.addPlayer(PLAYER)
	npcHandler:changeFocus(PLAYER)
	return npcHandler, shop
end

Test.case('conversational buy still works: "rope" then "yes"', function()
	Stubs.reset()
	local npcHandler, shop = focusedShopNpc()

	npcHandler.keywordHandler:processMessage(PLAYER, 'rope')
	assert_true(string.find(lastCall(Stubs.calls.said), 'buy') ~= nil, 'MESSAGE_BUY asked')

	npcHandler.keywordHandler:processMessage(PLAYER, 'yes')

	assert_eq(table.getn(Stubs.calls.buys), 1, 'one purchase')
	local buy = Stubs.calls.buys[1]
	assert_eq(buy.itemid, 2120, 'itemid')
	assert_eq(buy.count, 1, 'default count')
	assert_eq(buy.cost, 50, 'price')
	assert_nil(buy.charges, 'no charges')
	assert_true(string.find(lastCall(Stubs.calls.said), 'pleasure') ~= nil, 'MESSAGE_ONBUY said')
end)

Test.case('conversational buy with amount still works: "rope 5" then "yes"', function()
	Stubs.reset()
	local npcHandler, shop = focusedShopNpc()

	npcHandler.keywordHandler:processMessage(PLAYER, 'rope 5')
	npcHandler.keywordHandler:processMessage(PLAYER, 'yes')

	local buy = Stubs.calls.buys[1]
	assert_eq(buy.count, 5, 'count parsed from message')
	assert_eq(buy.cost, 250, 'total cost')
end)

Test.case('conversational sell still works: "sell rope" then "yes"', function()
	Stubs.reset()
	local npcHandler, shop = focusedShopNpc()

	npcHandler.keywordHandler:processMessage(PLAYER, 'sell rope')
	npcHandler.keywordHandler:processMessage(PLAYER, 'yes')

	assert_eq(table.getn(Stubs.calls.sells), 1, 'one sale')
	local sell = Stubs.calls.sells[1]
	assert_eq(sell.itemid, 2120, 'itemid')
	assert_eq(sell.count, 1, 'count')
	assert_eq(sell.cost, 8, 'payout')
end)

Test.case('conversational decline still works: "rope" then "no"', function()
	Stubs.reset()
	local npcHandler, shop = focusedShopNpc()

	npcHandler.keywordHandler:processMessage(PLAYER, 'rope')
	npcHandler.keywordHandler:processMessage(PLAYER, 'no')

	assert_eq(table.getn(Stubs.calls.buys), 0, 'no purchase')
end)

Test.case('conversational buy works while the shop window is open', function()
	Stubs.reset()
	local npcHandler, shop = focusedShopNpc()
	npcHandler.keywordHandler:processMessage(PLAYER, 'trade')
	assert_eq(table.getn(Stubs.calls.opened), 1, 'window open')

	npcHandler.keywordHandler:processMessage(PLAYER, 'rope')
	npcHandler.keywordHandler:processMessage(PLAYER, 'yes')

	assert_eq(table.getn(Stubs.calls.buys), 1, 'conversational purchase went through')
	assert_true(ShopModule.shopSessions[PLAYER] ~= nil, 'window session still open')
end)
