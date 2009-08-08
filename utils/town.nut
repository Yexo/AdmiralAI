/*
 * This file is part of AdmiralAI.
 *
 * AdmiralAI is free software: you can redistribute it and/or modify
 * it under the terms of the GNU General Public License as published by
 * the Free Software Foundation, either version 2 of the License, or
 * (at your option) any later version.
 *
 * AdmiralAI is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 * GNU General Public License for more details.
 *
 * You should have received a copy of the GNU General Public License
 * along with AdmiralAI.  If not, see <http://www.gnu.org/licenses/>.
 *
 * Copyright 2008-2009 Thijs Marinussen
 */

 /** @file utils/town.nut Some town-related functions. */

/**
 * A utility class containing some functions related to towns.
 */
class Utils_Town
{
/* public: */

	/**
	 * Does this tile fit in with the town road layout?
	 * @param tile The tile to check.
	 * @param town_id The town to get the road layout from.
	 * @param default_value The value to return if we can't determine whether the tile is on the grid.
	 * @return True iff the tile on placed on the town grid.
	 */
	static function TileOnTownLayout(tile, town_id, default_value);
};

function Utils_Town::TileOnTownLayout(tile, town_id, default_value)
{
	local town_loc = AITown.GetLocation(town_id);
	switch (AITown.GetRoadLayout(town_id)) {
		case AITown.ROAD_LAYOUT_ORIGINAL:
		case AITown.ROAD_LAYOUT_BETTER_ROADS:
			return default_value;
		case AITown.ROAD_LAYOUT_2x2:
			return abs(AIMap.GetTileX(tile) - AIMap.GetTileX(town_loc)) % 3 == 0 ||
			       abs(AIMap.GetTileY(tile) - AIMap.GetTileY(town_loc)) % 3 == 0;
		case AITown.ROAD_LAYOUT_3x3:
			return abs(AIMap.GetTileX(tile) - AIMap.GetTileX(town_loc)) % 4 == 0 ||
			       abs(AIMap.GetTileY(tile) - AIMap.GetTileY(town_loc)) % 46 == 0;
	}
	assert(false);
}
