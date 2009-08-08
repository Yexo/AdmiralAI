class TruckLineManager
{
	_unbuild_routes = null;             ///< A table with as index CargoID and as value an array of industries we haven't connected.
	_ind_to_station = null;             ///< A table mapping IndustryIDs to StationManagers. If an IndustryID is not in this list, we haven't build a station there yet.
	_routes = null;                     ///< An array containing all TruckLines build.
	_max_distance_existing_route = null; ///< The maximum distance between industries where we'll still check if they are alerady connected.
	_skip_cargo = null;                 ///< Skip this amount of CargoIDs in _NewLineExistingRoadGenerator, as we already searched them in a previous run.
	_skip_ind_from = null;              ///< Skip this amount of source industries in _NewLineExistingRoadGenerator, as we already searched them in a previous run.
	_skip_ind_to = null;                ///< Skip this amount of goal industries in _NewLineExistingRoadGenerator, as we already searched them in a previous run.

	constructor()
	{
		this._unbuild_routes = {};
		this._ind_to_station = {};
		this._routes = [];
		this._max_distance_existing_route = 100;
		this._skip_cargo = 0;
		this._skip_ind_from = 0;
		this._skip_ind_to = 0;
		this._InitializeUnbuildRoutes();
	}

	/**
	 * Try to build a new cargo route using mostly existing road.
	 */
	function NewLineExistingRoad();

	/**
	 * Build a new cargo route, we don't care if it's over existing road or not.
	 */
	function BuildNewLine();

	/**
	 * Check all build routes to see if they have the correct amount of trucks.
	 */
	function CheckRoutes();
}

function TruckLineManager::_InitializeUnbuildRoutes()
{
	local cargo_list = AICargoList();
	foreach (cargo, dummy1 in cargo_list) {
		local ind_acc_list = AIIndustryList_CargoAccepting(cargo);
		if (ind_acc_list.Count() == 0) continue;
		this._unbuild_routes.rawset(cargo, {});
		local ind_prod_list = AIIndustryList_CargoProducing(cargo);
		foreach (ind, dummy in ind_prod_list) {
			this._unbuild_routes[cargo].rawset(ind, 1);
		}
	}
}

function TruckLineManager::_GetSortedOffsets(tile, goal)
{
	local tile_x = AIMap.GetTileX(tile);
	local tile_y = AIMap.GetTileY(tile);
	local goal_x = AIMap.GetTileX(goal);
	local goal_y = AIMap.GetTileY(goal);
	if (abs(tile_x - goal_x) < abs(tile_y - goal_y)) {
		if (tile_y < goal_y) {
			return [AIMap.GetMapSizeX(), -1, 1, -AIMap.GetMapSizeX()];
		} else {
			return [-AIMap.GetMapSizeX(), -1, 1, AIMap.GetMapSizeX()];
		}
	} else {
		if (tile_x < goal_x) {
			return [1, -AIMap.GetMapSizeX(), AIMap.GetMapSizeX(), -1];
		} else {
			return [-1, -AIMap.GetMapSizeX(), AIMap.GetMapSizeX(), 1];
		}
	}
}

function TruckLineManager::_GetStationNearIndustry(ind, dir_tile, producing, cargo)
{
	if (this._ind_to_station.rawin(ind)) return this._ind_to_station.rawget(ind);

	/* No station yet for this industry, so build a new one. */
	local tile_list;
	if (producing) tile_list = AITileList_IndustryProducing(ind, AIStation.GetCoverageRadius(AIStation.STATION_TRUCK_STOP));
	else tile_list = AITileList_IndustryAccepting(ind, AIStation.GetCoverageRadius(AIStation.STATION_TRUCK_STOP));

	tile_list.Valuate(AITile.GetOwner);
	tile_list.RemoveBetweenValue(AICompany.FIRST_COMPANY - 1, AICompany.LAST_COMPANY + 1);
	tile_list.Valuate(AIMap.DistanceManhattan, dir_tile);
	tile_list.Sort(AIAbstractList.SORT_BY_VALUE, true);
	local offsets = [AIMap.GetTileIndex(0, 1), AIMap.GetTileIndex(0, -1),
                     AIMap.GetTileIndex(1, 0), AIMap.GetTileIndex(-1, 0)];
	foreach (tile, dummy in tile_list) {
		foreach (offset in this._GetSortedOffsets(tile, dir_tile)) {
			{
				local test = AITestMode();
				if (!AIRoad.BuildRoadStation(tile, tile + offset, true, false)) continue;
				if (!AIRoad.BuildRoad(tile, tile + offset)) continue;
			}
			AIRoad.BuildRoad(tile, tile + offset);
			AIRoad.BuildRoadStation(tile, tile + offset, true, false);
			local station_id = AIStation.GetStationID(tile);
			if (!AIStation.IsValidStation(station_id)) continue;
			local manager = StationManager(station_id);
			this._ind_to_station.rawset(ind, manager);
			return manager;
		}
	}
	return null;
}

function TruckLineManager::CheckRoutes()
{
	foreach (route in this._routes) {
		route.CheckVehicles();
	}
	return false;
}

function TruckLineManager::_BuildDepot(station_manager)
{
	local stationtiles = AITileList_StationType(station_manager.GetStationID(), AIStation.STATION_TRUCK_STOP);
	stationtiles.Valuate(AIRoad.GetRoadStationFrontTile);
	return AdmiralAI.BuildDepot(stationtiles.GetValue(stationtiles.Begin()));
}

function TruckLineManager::BuildNewLine()
{
	return false; //TODO
}

function TruckLineManager::NewLineExistingRoad()
{
	local result = this._NewLineExistingRoadGenerator(40);
	if (result == null) {
		this._skip_cargo = 0;
		this._skip_ind_from = 0;
		this._skip_ind_to = 0;
		result = false;
	}
	return result;
}

function TruckLineManager::_NewLineExistingRoadGenerator(num_routes_to_check)
{
	local cargo_list = AICargoList();
	cargo_list.Valuate(AICargo.GetCargoIncome, 80, 40);
	cargo_list.Sort(AIAbstractList.SORT_BY_VALUE, false);

	local current_routes = -1;
	local cargo_skipped = 0, ind_from_skipped = 0, ind_to_skipped = 0;
	local do_skip = true;
	foreach (cargo, dummy in cargo_list) {
		if (cargo_skipped < this._skip_cargo && do_skip) {
			cargo_skipped++;
			continue;
		}
		if (!this._unbuild_routes.rawin(cargo)) continue;
		foreach (ind_from, dummy in this._unbuild_routes.rawget(cargo)) {
			if (!this._unbuild_routes[cargo].rawin(ind_from)) continue;
			if (AIIndustry.GetLastMonthProduction(ind_from, cargo) - (AIIndustry.GetLastMonthTransported(ind_from, cargo) >> 1) < 40) continue;
			if (ind_from_skipped < this._skip_ind_from && do_skip) {
				ind_from_skipped++;
				continue;
			}
			do_skip = false;
			local ind_acc_list = AIIndustryList_CargoAccepting(cargo);
			ind_acc_list.Valuate(AIIndustry.GetDistanceManhattanToTile, AIIndustry.GetLocation(ind_from));
			ind_acc_list.KeepBetweenValue(30, this._max_distance_existing_route);
			ind_acc_list.Sort(AIAbstractList.SORT_BY_VALUE, true);
			foreach (ind_to, dummy in ind_acc_list) {
				if (ind_to_skipped < this._skip_ind_to && do_skip) {
					ind_to_skipped++;
					ind_from_skipped++;
					continue;
				}
				do_skip = false;
				this._skip_ind_to++;
				current_routes++;
				if (current_routes == num_routes_to_check) {
					return false;
				}
				local route = RouteFinder.FindRouteBetweenRects(AIIndustry.GetLocation(ind_from), AIIndustry.GetLocation(ind_to), 8);
				if (route == null) continue;
				AILog.Info("Found cargo route between: " + AIIndustry.GetName(ind_from) + " and " + AIIndustry.GetName(ind_to));
				local station_from = this._GetStationNearIndustry(ind_from, route[0], true, cargo);
				if (station_from == null) break;
				local station_to = this._GetStationNearIndustry(ind_to, route[1], false, cargo);
				if (station_to == null) continue;
				local ret1 = RouteBuilder.BuildRoadRouteFromStation(station_from.GetStationID(), AIStation.STATION_TRUCK_STOP, [route[0]]);
				local ret2 = RouteBuilder.BuildRoadRouteFromStation(station_to.GetStationID(), AIStation.STATION_TRUCK_STOP, [route[1]]);
				if (ret1 == 0 && ret2 == 0) {
					AILog.Info("Route ok");
					local line = TruckLine(ind_from, station_from, ind_to, station_to, this._BuildDepot(station_from), cargo);
					this._routes.push(line);
					this._unbuild_routes[cargo].rawdelete(ind_from);
					this._skip_ind_from = 0;
					this._skip_ind_to = 0;
					return true;
				}
			}
			this._skip_ind_to = 0;
			this._skip_ind_from++;
			do_skip = false;
		}
		this._skip_ind_from = 0;
		this._skip_cargo++;
		do_skip = false;
	}
	AILog.Info("Full industry search done!");
	this._max_distance_existing_route = min(400, this._max_distance_existing_route + 50);
	this._skip_cargo = 0;
	return null;
}
