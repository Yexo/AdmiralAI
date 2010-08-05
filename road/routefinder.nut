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
 * Copyright 2008-2010 Thijs Marinussen
 */

/** @file routefinder.nut Implementation of RouteFinder. */

/**
 * Some functions to check if there already exists a route between two points.
 */
class RouteFinder
{
/* public: */

	/**
	 * Check if a route between the neighbourhoods of two points already exists.
	 * @param tile_a The first tile.
	 * @param tile_b The second tile.
	 * @param radius The radius we can start around both tile_a and tile_b.
	 * @return null if no route was found, otherwise an array with three elements:
	 *  0: The tile the route starts.
	 *  1: The tile the route ends.
	 *  2: The length of the route.
	 */
	static function FindRouteBetweenRects(tile_a, tile_b, radius);

/* private: */

	/**
	 * The cost function for the route finder.
	 * @param old_path The path untill now.
	 * @param new_tile The tile that has been added to the path.
	 * @param new_direction Ignored.
	 * @param callback_param Ignored.
	 * @return The cost for the new path including new_tile.
	 */
	static function _Cost(old_path, new_tile, new_direction, callback_param);

	/**
	 * Give an estimate for the cost from a tile to the closest goal tile.
	 * @param tile The tile to give the estimate for.
	 * @param direction Ignored.
	 * @param goal_nodes An array containing all goal nodes.
	 * @param estimate_callback_param Ignored.
	 * @return An estimate of the cost from tile to the closest tile from goal_nodes.
	 */
	static function _Estimate(tile, direction, goal_nodes, estimate_callback_param);

	/**
	 * Get a list of neighbouring tiles.
	 * @param path The path untill now.
	 * @param cur_tile The tile to give the neighbours for.
	 * @param callback_param Ignored.
	 * @return An array containing all neighbouring tiles.
	 */
	static function _Neighbours(path, cur_tile, callback_param);

	/**
	 * Check if the tile can be entered from a second direction.
	 * @param tile Ignored.
	 * @param existing_direction Ignored.
	 * @param new_direction Ignored.
	 * @param callback_param Ignored.
	 * @return False.
	 */
	static function _CheckDirection(tile, existing_direction, new_direction, callback_param);
};

function RouteFinder::FindRouteBetweenRects(tile_a, tile_b, radius, ignored_tiles = [])
{
	local sources = [];
	local max_x = AIMap.GetTileX(tile_a) + radius;
	for (local x = AIMap.GetTileX(tile_a) - radius; x <= max_x; x++) {
		local max_y = AIMap.GetTileY(tile_a) + radius;
		for (local y = AIMap.GetTileY(tile_a) - radius; y <= max_y; y++) {
			local tile = AIMap.GetTileIndex(x, y);
			if (AIRoad.IsRoadTile(tile)) sources.push([tile, 1]);
		}
	}
	if (sources.len() == 0) return null;

	local goals = [];
	local max_x = AIMap.GetTileX(tile_b) + radius;
	for (local x = AIMap.GetTileX(tile_b) - radius; x <= max_x; x++) {
		local max_y = AIMap.GetTileY(tile_b) + radius;
		for (local y = AIMap.GetTileY(tile_b) - radius; y <= max_y; y++) {
			local tile = AIMap.GetTileIndex(x, y);
			if (AIRoad.IsRoadTile(tile)) goals.push(tile);
		}
	}
	if (goals.len() == 0) return null;

	_RouteFinder_pf.InitializePath(sources, goals, ignored_tiles);
	RouteFinder.max_cost <- 20 + (AIMap.DistanceManhattan(tile_a, tile_b) * 1.2).tointeger();
	RouteFinder.goal_tile <- tile_b;
	local path = _RouteFinder_pf.FindPath(-1);
	if (path == null) return null;

	local end_tile = path.GetTile();
	local start_tile = path.GetTile();
	local length = 0;
	path = path.GetParent();
	while (path != null) {
		length += AIMap.DistanceManhattan(start_tile, path.GetTile());
		start_tile = path.GetTile();
		path = path.GetParent();
	}
	return [start_tile, end_tile, length];
}

function RouteFinder::_Cost(old_path, new_tile, new_direction, callback_param)
{
	if (old_path == null) return 0;
	return old_path.GetCost() + AIMap.DistanceManhattan(old_path.GetTile(), new_tile);
}

function RouteFinder::_Estimate(tile, direction, goal_nodes, estimate_callback_param)
{
	local min_cost = 99999;
	foreach (goal in goal_nodes) {
		min_cost = min(min_cost, AIMap.DistanceManhattan(tile, goal));
	}
	return min_cost;
}

function RouteFinder::_Neighbours(path, cur_tile, callback_param)
{
	if (path.GetCost() + AIMap.DistanceManhattan(cur_tile, RouteFinder.goal_tile) > RouteFinder.max_cost) return [];
	if (AIBridge.IsBridgeTile(cur_tile)) {
		local other_end = AIBridge.GetOtherBridgeEnd(cur_tile);
		if (path.GetParent().GetTile() != other_end) return [[other_end, 1]];
	}
	if (AITunnel.IsTunnelTile(cur_tile)) {
		local other_end = AITunnel.GetOtherTunnelEnd(cur_tile);
		if (path.GetParent().GetTile() != other_end) return [[other_end, 1]];
	}

	local tiles = [];
	local offsets = [AIMap.GetTileIndex(0, 1), AIMap.GetTileIndex(0, -1),
	                 AIMap.GetTileIndex(1, 0), AIMap.GetTileIndex(-1, 0)];
	foreach (offset in offsets) {
		if (AIRoad.AreRoadTilesConnected(cur_tile, cur_tile + offset)) tiles.push([cur_tile + offset, 1]);
	}
	return tiles;
}

function RouteFinder::_CheckDirection(tile, existing_direction, new_direction, callback_param)
{
	return false;
}

_RouteFinder_pf <- AyStar(RouteFinder._Cost, RouteFinder._Estimate, RouteFinder._Neighbours, RouteFinder._CheckDirection);
RouteFinder.max_cost <- 0;
RouteFinder.goal_tile <- 0;
