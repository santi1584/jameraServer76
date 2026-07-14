//////////////////////////////////////////////////////////////////////
// OpenTibia - an opensource roleplaying game
//////////////////////////////////////////////////////////////////////
// NPC shop window catalog entry shared between the protocol, the game
// logic and the npc Lua bindings.
//////////////////////////////////////////////////////////////////////
// This program is free software; you can redistribute it and/or
// modify it under the terms of the GNU General Public License
// as published by the Free Software Foundation; either version 2
// of the License, or (at your option) any later version.
//////////////////////////////////////////////////////////////////////

#ifndef __OTSERV_SHOPINFO_H__
#define __OTSERV_SHOPINFO_H__

#include <stdint.h>
#include <string>
#include <list>

// Shop window event types. Mirrored in Lua as SHOPEVENT_* constants
// (data/npc/scripts/lib/npcsystem/modules.lua).
enum ShopEvent_t{
	SHOPEVENT_BUY = 1,
	SHOPEVENT_SELL = 2,
	SHOPEVENT_CLOSE = 3
};

struct ShopInfo{
	uint16_t itemId;
	// charges for runes, fluid type for fluid containers, 0 otherwise
	uint8_t subType;
	// gold per unit; 0 means "not buyable" / "not sellable"
	uint32_t buyPrice;
	uint32_t sellPrice;
	std::string name;

	ShopInfo() :
		itemId(0), subType(0), buyPrice(0), sellPrice(0)
	{}
};

typedef std::list<ShopInfo> ShopInfoList;

#endif
