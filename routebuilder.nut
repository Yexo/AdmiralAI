class RouteBuilder
{
}

function RouteBuilder::BuildRoadRouteFromStation(station, station_type, goals)
{
	local list = AITileList_StationType(station, station_type);
	list.Valuate(AIRoad.GetRoadStationFrontTile);
	local sources = [];
	foreach (tile, front_tile in list) {
		sources.push(front_tile);
	}
	return RouteBuilder.BuildRoadRoute(RPF(), sources, goals);
}

function RouteBuilder::BuildRoadRoute(pf, sources, goals)
{
	pf.InitializePath(sources, goals);
	local path = pf.FindPath(-1);
	if (path == null) {
		AILog.Warning("RouteBuilder::BuildRoadRoute(): No path could be found");
		return -1;
	}

	while (path != null) {
		local par = path.GetParent();
		if (par != null) {
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
					/* Other errors are ignored for now. */
				}
			} else {
				/* Build a bridge or tunnel. */
				if (!AIBridge.IsBridgeTile(path.GetTile()) && !AITunnel.IsTunnelTile(path.GetTile())) {
					/* If it was a road tile, demolish it first. Do this to work around expended roadbits. */
					if (AIRoad.IsRoadTile(path.GetTile())) AITile.DemolishTile(path.GetTile());
					if (AITunnel.GetOtherTunnelEnd(path.GetTile()) == par.GetTile()) {
						if (!AITunnel.BuildTunnel(AIVehicle.VEHICLE_ROAD, path.GetTile())) {
							if (AIError.GetLastError() == AIError.ERR_NOT_ENOUGH_CASH) return -2;
						}
					} else {
						local bridge_list = AIBridgeList_Length(AIMap.DistanceManhattan(path.GetTile(), par.GetTile()) + 1);
						bridge_list.Valuate(AIBridge.GetMaxSpeed);
						bridge_list.Sort(AIAbstractList.SORT_BY_VALUE, false);
						if (!AIBridge.BuildBridge(AIVehicle.VEHICLE_ROAD, bridge_list.Begin(), path.GetTile(), par.GetTile())) {
							if (AIError.GetLastError() == AIError.ERR_NOT_ENOUGH_CASH) return -2;
						}
					}
				}
			}
		}
		//if (this._first_repair ) AISign.BuildSign(path.GetTile(), path.GetTile() + "-" + path.GetCost());
		path = par;
	}
	return 0;
}