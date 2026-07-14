-- Test runner. Execute from the repository root:
--   lua5.1 tests/lua/run.lua
-- Loads the REAL npcsystem files (the copy the engine loads, see npc.cpp:114)
-- on top of a stub binding environment.

dofile('tests/lua/harness.lua')
dofile('tests/lua/stubs.lua')

-- Same load order as data/npc/scripts/lib/npcsystem/npcsystem.lua
dofile('data/npc/scripts/lib/npcsystem/keywordhandler.lua')
dofile('data/npc/scripts/lib/npcsystem/queue.lua')
dofile('data/npc/scripts/lib/npcsystem/npchandler.lua')
dofile('data/npc/scripts/lib/npcsystem/modules.lua')

-- Make npcs reply synchronously so tests can assert on said messages.
NPCHANDLER_TALKDELAY = TALKDELAY_NONE

dofile('tests/lua/test_catalog.lua')
dofile('tests/lua/test_open_close.lua')
dofile('tests/lua/test_buy.lua')
dofile('tests/lua/test_sell.lua')
dofile('tests/lua/test_conversational.lua')

Test.summary()
