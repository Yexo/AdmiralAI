class RouteFinder
{
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

function RouteFinder::_Neighbours(path, cur_node, callback_param)
{
	if (path.GetCost() + AIMap.DistanceManhattan(cur_node, RouteFinder.goal_tile) > RouteFinder.max_cost) return [];
	if (AIBridge.IsBridgeTile(cur_node)) {
		local other_end = AIBridge.GetOtherBridgeEnd(cur_node);
		if (path.GetParent().GetTile() != other_end) return [[other_end, 1]];
	}
	if (AITunnel.IsTunnelTile(cur_node)) {
		local other_end = AITunnel.GetOtherTunnelEnd(cur_node);
		if (path.GetParent().GetTile() != other_end) return [[other_end, 1]];
	}

	local tiles = [];
	local offsets = [AIMap.GetTileIndex(0, 1), AIMap.GetTileIndex(0, -1),
	                 AIMap.GetTileIndex(1, 0), AIMap.GetTileIndex(-1, 0)];
	foreach (offset in offsets) {
		if (AIRoad.AreRoadTilesConnected(cur_node, cur_node + offset)) tiles.push([cur_node + offset, 1]);
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

function RouteFinder::FindRouteBetweenRects(tile_a, tile_b, radius)
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

	_RouteFinder_pf.InitializePath(sources, goals);
	RouteFinder.max_cost <- (AIMap.DistanceManhattan(tile_a, tile_b) * 1.5).tointeger();
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
