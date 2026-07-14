-- Catalog normalization: ShopModule must retain a normalized catalog of
-- everything the npc buys and sells, keyed by (itemid, subtype).

Test.case('plain buyable items produce catalog entries with subtype 0', function()
	Stubs.reset()
	local npcHandler, shop = makeShopNpc()
	shop:parseBuyable('rope,2120,50;shovel,2554,50')

	local rope = shop:getCatalogEntry(2120, 0)
	assert_true(rope ~= nil, 'rope entry')
	assert_eq(rope.buyPrice, 50, 'rope buyPrice')
	assert_eq(rope.sellPrice, 0, 'rope sellPrice')
	assert_eq(rope.name, 'rope', 'rope name')
	assert_eq(rope.subtype, 0, 'rope subtype')
	assert_nil(rope.charges, 'rope charges')

	assert_eq(table.getn(shop.shopItems), 2, 'catalog size')
	assert_eq(shop.shopItems[1].itemid, 2120, 'wire order preserved')
	assert_eq(shop.shopItems[2].itemid, 2554, 'wire order preserved')
end)

Test.case('fluid container keeps charges as subtype', function()
	Stubs.reset()
	Stubs.setItemType(2006, {fluid = true})
	local npcHandler, shop = makeShopNpc()
	shop:parseBuyable('vial of oil,2006,100,11')

	local entry = shop:getCatalogEntry(2006, 11)
	assert_true(entry ~= nil, 'fluid entry')
	assert_eq(entry.buyPrice, 100, 'fluid buyPrice')
	assert_eq(entry.subtype, 11, 'fluid subtype')
	assert_eq(entry.charges, 11, 'fluid charges')
end)

Test.case('rune keeps charges as subtype', function()
	Stubs.reset()
	Stubs.setItemType(2260, {rune = true})
	local npcHandler, shop = makeShopNpc()
	shop:parseBuyable('blank rune,2260,120,5')

	local entry = shop:getCatalogEntry(2260, 5)
	assert_true(entry ~= nil, 'rune entry')
	assert_eq(entry.charges, 5, 'rune charges')
end)

Test.case('rune without charges is skipped (existing behavior preserved)', function()
	Stubs.reset()
	Stubs.setItemType(2261, {rune = true})
	local npcHandler, shop = makeShopNpc()
	shop:parseBuyable('bad rune,2261,100')

	assert_nil(shop:getCatalogEntry(2261, 0), 'no entry for skipped rune')
	assert_true(shop.shopItems == nil or table.getn(shop.shopItems) == 0, 'catalog empty')
end)

Test.case('buyable and sellable of same (itemid, subtype) merge into one entry', function()
	Stubs.reset()
	local npcHandler, shop = makeShopNpc()
	shop:parseBuyable('rope,2120,50')
	shop:parseSellable('rope,2120,8')

	assert_eq(table.getn(shop.shopItems), 1, 'merged catalog size')
	local rope = shop:getCatalogEntry(2120, 0)
	assert_eq(rope.buyPrice, 50, 'merged buyPrice')
	assert_eq(rope.sellPrice, 8, 'merged sellPrice')
end)

Test.case('sell-only entry has buyPrice 0', function()
	Stubs.reset()
	local npcHandler, shop = makeShopNpc()
	shop:parseSellable('spear,2389,3')

	local spear = shop:getCatalogEntry(2389, 0)
	assert_true(spear ~= nil, 'spear entry')
	assert_eq(spear.buyPrice, 0, 'spear buyPrice')
	assert_eq(spear.sellPrice, 3, 'spear sellPrice')
end)

Test.case('duplicate buyable entries do not duplicate catalog rows', function()
	Stubs.reset()
	local npcHandler, shop = makeShopNpc()
	shop:parseBuyable('machete,2420,40;machete,2420,40')

	assert_eq(table.getn(shop.shopItems), 1, 'no duplicate rows')
end)

Test.case('catalog instances are not shared between modules', function()
	Stubs.reset()
	local h1, shop1 = makeShopNpc()
	local h2, shop2 = makeShopNpc()
	shop1:parseBuyable('rope,2120,50')

	assert_true(shop2.shopItems == nil or table.getn(shop2.shopItems) == 0, 'second module catalog empty')
	assert_nil(shop2:getCatalogEntry(2120, 0), 'second module has no rope')
end)
