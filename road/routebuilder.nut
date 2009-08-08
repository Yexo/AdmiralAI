/** @file routebuilder.nut Some road route building functions. */

/**
 * Class that handles road building.
 */
class RouteBuilder
{
/* public: */

	/**
	 * Connect a station with some tiles.
	 * @param station The StationID from where we want to build a route.
	 * @param station_type The AIStation::StationType of the parts you want to connect.
	 * @param goals An array containing the tiles to which you want to connect.
	 * @return
	 * @todo fill in return value docs.
	 */
	static function BuildRoadRouteFromStation(station, station_type, goals);

	/**
	 * Build a road route between a tile from sources and a tile from goals.
	 * @param pf The pathfinder to use for finding a path.
	 * @param sources An array containing all possible source tiles.
	 * @param goals An array containing all possible goal tiles.
	 * @return One of the following:
	 *  -  0 If the route was build without any problems.
	 *  - -1 If no path was found by the pathfinder.
	 *  - -2 If the AI didn't have enough money to build the route.
	 */
	static function BuildRoadRoute(pf, sources, goals);
};

function RouteBuilder::BuildRoadRouteFromStation(station, station_type, goals)
{
	local list = AITileList_StationType(station, station_type);
	if (list.Count() == 0) {
		AILog.Error("RouteBuilder::BuildRoadRouteFromStation(): No tiles!");
		AILog.Error("station = " + station + ", valid = " + AIStation.IsValidStation(station));
		AILog.Error("Station name = " + AIStation.GetName(station));
		AILog.Error("type = " + station_type);
		throw("Invalid station passed to BuildRoadRouteFromStation!");
	}
	list.Valuate(AIRoad.GetRoadStationFrontTile);
	local sources = [];
	foreach (tile, front_tile in list) {
		sources.push(front_tile);
	}
	return RouteBuilder.BuildRoadRoute(RPF(), sources, goals, 4);
}

function RouteBuilder::BuildRoadRoute(pf, sources, goals, max_length_multiplier)
{
	local num_retries = 3;
	if (sources.len() == 0 || goals.len() == 0) return -1;

	while (num_retries > 0) {
		num_retries--;
		pf.InitializePath(sources, goals, max_length_multiplier);
		local path = pf.FindPath(-1);
		if (path == null) {
			AILog.Warning("RouteBuilder::BuildRoadRoute(): No path could be found");
			return -1;
		}

		local route_build = false;
		while (path != null) {
			local par = path.GetParent();
			if (par == null) {
				route_build = true;
				break;
			}
			local last_node = path.GetTile();
			local force_normal_road = false;
			while (par.GetParent() != null && par.GetTile() - last_node == par.GetParent().GetTile() - par.GetTile()) {
				last_node = par.GetTile();
				par = par.GetParent();
				force_normal_road = true;
			}
			if (force_normal_road || AIMap.DistanceManhattan(path.GetTile(), par.GetTile()) == 1 ) {
				if (!AIRoad.BuildRoad(path.GetTile(), par.GetTile())) {
					/* An error occured while building a piece of road, check what error it is. */
					if (AIError.GetLastError() == AIError.ERR_NOT_ENOUGH_CASH) return -2;
					if (!RouteBuilder._HandleRoadBuildError(path.GetTile(), par.GetTile())) break;
				}
			} else {
				/* Build a bridge or tunnel. */
				if (!AIBridge.IsBridgeTile(path.GetTile()) && !AITunnel.IsTunnelTile(path.GetTile())) {
					/* If it was a road tile, demolish it first. Do this to work around expended roadbits. */
					if (AIRoad.IsRoadTile(path.GetTile())) AITile.DemolishTile(path.GetTile());
					if (AITunnel.GetOtherTunnelEnd(path.GetTile()) == par.GetTile()) {
						if (!AITunnel.BuildTunnel(AIVehicle.VEHICLE_ROAD, path.GetTile())) {
							if (AIError.GetLastError() == AIError.ERR_NOT_ENOUGH_CASH) return -2;
							if (!RouteBuilder._HandleTunnelBuildError(path.GetTile())) break;
						}
					} else {
						local bridge_list = AIBridgeList_Length(AIMap.DistanceManhattan(path.GetTile(), par.GetTile()) + 1);
						bridge_list.Valuate(AIBridge.GetMaxSpeed);
						bridge_list.Sort(AIAbstractList.SORT_BY_VALUE, false);
						if (!AIBridge.BuildBridge(AIVehicle.VEHICLE_ROAD, bridge_list.Begin(), path.GetTile(), par.GetTile())) {
							if (AIError.GetLastError() == AIError.ERR_NOT_ENOUGH_CASH) return -2;
							if (!RouteBuilder._HandleBridgeBuildError(path.GetTile(), par.GetTile())) break;
						}
					}
				}
			}
			path = par;
		}
		if (route_build) return 0;
		AILog.Info("Building a route failed, but pathfinding was ok. Retrying " + num_retries);
	}
	return -1;
}

function RouteBuilder::_HandleRoadBuildError(from, to)
{
	switch (AIError.GetLastError()) {
		case AIError.ERR_NONE:
			throw("RouteBuilder::_HandleRoadBuildError(): Detected error but AIError returns ERR_NONE");

		case AIError.ERR_ALREADY_BUILT:
			return true;

		case AIError.ERR_VEHICLE_IN_THE_WAY:
			local num_retries = 10;
			while (num_retries-- > 0) {
				AIController.Sleep(20);
				if (AIRoad.BuildRoad(from, to)) return true;
				if (AIError.GetLastError() == AIError.ERR_ALREADY_BUILT) return true;
				if (AIError.GetLastError() != AIError.ERR_VEHICLE_IN_THE_WAY) return false;
			}
			break;
	}
	return false;
}

function RouteBuilder::_HandleTunnelBuildError(from)
{
	switch (AIError.GetLastError()) {
		case AIError.ERR_NONE:
			throw("RouteBuilder::_HandleTunnelBuildError(): Detected error but AIError returns ERR_NONE");

		case AIError.ERR_ALREADY_BUILT:
			return true;
	}
	return false;
}

function RouteBuilder::_HandleBridgeBuildError(from, to)
{
	switch (AIError.GetLastError()) {
		case AIError.ERR_NONE:
			throw("RouteBuilder::_HandleBridgeBuildError(): Detected error but AIError returns ERR_NONE");

		case AIError.ERR_ALREADY_BUILT:
			return true;
	}
	return false;
}
