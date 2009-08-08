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

/** @file railfollower.nut A custom rail track finder. */

/**
 * A Rail pathfinder for existing rails.
 */
class RailFollower
{
	_aystar_class = AyStar;
	_max_cost = null;              ///< The maximum cost for a route.
	_pathfinder = null;            ///< A reference to the used AyStar object.

	_running = null;
	_goals = null;
	_new_type = null;

	constructor()
	{
		this._max_cost = 10000000;
		this._pathfinder = this._aystar_class(this._Cost, this._Estimate, this._Neighbours, this._CheckDirection, this, this, this, this);

		this._running = false;
	}

	/**
	 * Initialize a path search between sources and goals.
	 * @param sources The source tiles.
	 * @param goals The target tiles.
	 * @param ignored_tiles An array of tiles that cannot occur in the final path.
	 * @see AyStar::InitializePath()
	 */
	function InitializePath(sources, goals, ignored_tiles = [], new_type = null) {
		local nsources = [];

		foreach (node in sources) {
			local path = this._pathfinder.Path(null, node[1], 0xFF, this._Cost, this);
			path = this._pathfinder.Path(path, node[0], 0xFF, this._Cost, this);
			nsources.push(path);
		}
		this._goals = goals;
		this._pathfinder.InitializePath(nsources, goals, ignored_tiles);
		this._new_type = new_type;
	}

	/**
	 * Try to find the path as indicated with InitializePath with the lowest cost.
	 * @param iterations After how many iterations it should abort for a moment.
	 *  This value should either be -1 for infinite, or > 0. Any other value
	 *  aborts immediatly and will never find a path.
	 * @return A route if one was found, or false if the amount of iterations was
	 *  reached, or null if no path was found.
	 *  You can call this function over and over as long as it returns false,
	 *  which is an indication it is not yet done looking for a route.
	 * @see AyStar::FindPath()
	 */
	function FindPath(iterations);
};

function RailFollower::FindPath(iterations)
{
	local test_mode = AITestMode();
	local ret = this._pathfinder.FindPath(iterations);
	this._running = (ret == false) ? true : false;
	if (!this._running && ret != null) {
		foreach (goal in this._goals) {
			if (goal[0] == ret.GetTile()) {
				return this._pathfinder.Path(ret, goal[1], 0, this._Cost, this);
			}
		}
	}
	return ret;
}

function RailFollower::_nonzero(a, b)
{
	return a != 0 ? a : b;
}

function RailFollower::_Cost(path, new_tile, new_direction, self)
{
	/* path == null means this is the first node of a path, so the cost is 0. */
	if (path == null) return 0;
	return path.GetCost() + AIMap.DistanceManhattan(path.GetTile(), new_tile);
}

function RailFollower::_Estimate(cur_tile, cur_direction, goal_tiles, self)
{
	local min_cost = self._max_cost;
	foreach (tile in goal_tiles) {
		min_cost = min(min_cost, AIMap.DistanceManhattan(tile[0], cur_tile));
	}
	return min_cost;
}

function RailFollower::_Neighbours(path, cur_node, self)
{
	/* self._max_cost is the maximum path cost, if we go over it, the path isn't valid. */
	if (path.GetCost() >= self._max_cost) return [];

	local offsets = [AIMap.GetTileIndex(0, 1), AIMap.GetTileIndex(0, -1),
	                 AIMap.GetTileIndex(1, 0), AIMap.GetTileIndex(-1, 0)];
	local tiles = [];
	if (AITile.HasTransportType(cur_node, AITile.TRANSPORT_RAIL)) {
		/* Only use track we own. */
		if (!AICompany.IsMine(AITile.GetOwner(cur_node))) return [];

		/* If the existing track type is incompatible this tile is unusable. */
		if (!AIRail.TrainHasPowerOnRail(AIRail.GetRailType(cur_node), self._new_type)) return [];

		if (AIRail.GetSignalType(path.GetParent().GetTile(), path.GetTile()) != AIRail.SIGNALTYPE_NONE) return [];
		if (AITile.IsStationTile(cur_node)) return [];

		/* Check if the current tile is part of a bridge or tunnel. */
		if (AIBridge.IsBridgeTile(cur_node) || AITunnel.IsTunnelTile(cur_node)) {
			if ((AIBridge.IsBridgeTile(cur_node) && AIBridge.GetOtherBridgeEnd(cur_node) == path.GetParent().GetTile()) ||
			  (AITunnel.IsTunnelTile(cur_node) && AITunnel.GetOtherTunnelEnd(cur_node) == path.GetParent().GetTile())) {
				local other_end = path.GetParent().GetTile();
				local next_tile = cur_node + (cur_node - other_end) / AIMap.DistanceManhattan(cur_node, other_end);
				tiles.push([next_tile, self._GetDirection(null, cur_node, next_tile, true)]);
			} else if (AIBridge.IsBridgeTile(cur_node)) {
				local other_end = AIBridge.GetOtherBridgeEnd(cur_node);;
				local prev_tile = cur_node + (cur_node - other_end) / AIMap.DistanceManhattan(cur_node, other_end);
				if (prev_tile == path.GetParent().GetTile()) tiles.push([AIBridge.GetOtherBridgeEnd(cur_node), self._GetDirection(null, path.GetParent().GetTile(), cur_node, true)]);
			} else {
				local other_end = AITunnel.GetOtherTunnelEnd(cur_node);
				local prev_tile = cur_node + (cur_node - other_end) / AIMap.DistanceManhattan(cur_node, other_end);
				if (prev_tile == path.GetParent().GetTile()) tiles.push([AITunnel.GetOtherTunnelEnd(cur_node), self._GetDirection(null, path.GetParent().GetTile(), cur_node, true)]);
			}
		} else {
			foreach (offset in offsets) {
				local next_tile = cur_node + offset;
				/* Don't turn back */
				if (next_tile == path.GetParent().GetTile()) continue;
				/* Disallow 90 degree turns */
				if (path.GetParent().GetParent() != null &&
					next_tile - cur_node == path.GetParent().GetParent().GetTile() - path.GetParent().GetTile()) continue;
				if (AIRail.AreTilesConnected(path.GetParent().GetTile(), cur_node, next_tile)) {
					tiles.push([next_tile, self._GetDirection(path.GetParent().GetTile(), cur_node, next_tile, false)]);
				}
			}
		}
	}
	return tiles;
}

function RailFollower::_CheckDirection(tile, existing_direction, new_direction, self)
{
	return false;
}

function RailFollower::_dir(from, to)
{
	if (from - to == 1) return 0;
	if (from - to == -1) return 1;
	if (from - to == AIMap.GetMapSizeX()) return 2;
	if (from - to == -AIMap.GetMapSizeX()) return 3;
	throw("Shouldn't come here in _dir");
}

function RailFollower::_GetDirection(pre_from, from, to, is_bridge)
{
	if (is_bridge) {
		if (from - to == 1) return 1;
		if (from - to == -1) return 2;
		if (from - to == AIMap.GetMapSizeX()) return 4;
		if (from - to == -AIMap.GetMapSizeX()) return 8;
	}
	return 1 << (4 + (pre_from == null ? 0 : 4 * this._dir(pre_from, from)) + this._dir(from, to));
}
