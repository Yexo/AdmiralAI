/** @file trucklinemanager.nut Implemenation of TruckLineManager. */

/**
 * Class that manages all truck routes.
 */
class TruckLineManager
{
/* public: */

	/**
	 * Create a new instance.
	 */
	constructor()
	{
		this._unbuild_routes = {};
		this._ind_to_pickup_station = {};
		this._ind_to_drop_station = {};
		this._routes = [];
		this._max_distance_existing_route = 100;
		this._skip_cargo = 0;
		this._skip_ind_from = 0;
		this._skip_ind_to = 0;
		this._last_search_finished = 0;
		this._InitializeUnbuildRoutes();
	}

	/**
	 * Try to build a new cargo route using mostly existing road.
	 * @return True if and only if a new route was created.
	 */
	function NewLineExistingRoad();

	/**
	 * Build a new cargo route, we don't care if it's over existing road or not.
	 * @return True if and only if a new route was created.
	 */
	function BuildNewLine();

	/**
	 * Check all build routes to see if they have the correct amount of trucks.
	 * @return True if and only if we need more money to complete the function.
	 */
	function CheckRoutes();

/* private: */

	/**
	 * Get a station near an industry. First check if we already have one,
	 *  if so, return it. If there is no station near the industry, try to
	 *  build one.
	 * @param ind The industry to build a station near.
	 * @param dir_tile The direction we want to build in from the station.
	 * @param producing Boolean indicating whether or not we want to transport
	 *  the cargo to or from the industry.
	 * @param cargo The CargoID we are going to transport.
	 * @return A StationManager if a station was found / could be build or null.
	 */
	function _GetStationNearIndustry(ind, dir_tile, producing, cargo);

	/**
	 * Try to build a depot near the given station.
	 * @param station_manager The StationManager responsible for the station we
	 *  want a depot nearby.
	 * @return The tile the depot was build on.
	 */
	function _BuildDepot(station_manager);

	/**
	 * Try to find two industries that are already connected by road.
	 * @param num_to_try The number of connections to try before returning.
	 * @return True if and only if a new route was created.
	 * @note The function may search less routes in case a new route was
	 *  created or the end of the list was reached. Even if the end of the
	 *  list of possible routes is reached, you can safely call the function
	 *  again, as it will start over with a greater range.
	 */
	function _NewLineExistingRoadGenerator(num_to_try);

	/**
	 * Initialize the array with industries we don't service yet. This
	 * should only be called once before any other function is called.
	 */
	function _InitializeUnbuildRoutes();

	/**
	 * Returns an array with the four tiles adjacent to tile. The array is
	 *  sorted with respect to distance to the tile goal.
	 * @param tile The tile to get the neighbours from.
	 * @param goal The tile we want to be close to.
	 */
	function _GetSortedOffsets(tile, goal);

	_unbuild_routes = null;              ///< A table with as index CargoID and as value an array of industries we haven't connected.
	_ind_to_pickup_station = null;       ///< A table mapping IndustryIDs to StationManagers. If an IndustryID is not in this list, we haven't build a pickup station there yet.
	_ind_to_drop_station = null;          ///< A table mapping IndustryIDs to StationManagers.
	_routes = null;                      ///< An array containing all TruckLines build.
	_max_distance_existing_route = null; ///< The maximum distance between industries where we'll still check if they are alerady connected.
	_skip_cargo = null;                  ///< Skip this amount of CargoIDs in _NewLineExistingRoadGenerator, as we already searched them in a previous run.
	_skip_ind_from = null;               ///< Skip this amount of source industries in _NewLineExistingRoadGenerator, as we already searched them in a previous run.
	_skip_ind_to = null;                 ///< Skip this amount of goal industries in _NewLineExistingRoadGenerator, as we already searched them in a previous run.
	_last_search_finished = null;

};

function TruckLineManager::CheckRoutes()
{
	foreach (route in this._routes) {
		route.CheckVehicles();
	}
	return false;
}

function TruckLineManager::IndustryClose(industry_id)
{
	for (local i = 0; i < this._routes.len(); i++) {
		local route = this._routes[i];
		if (route.IsIndustryFrom(industry_id) || route.IsIndustryTo(industry_id)) {
			route.CloseRoute();
			this._routes.Remove(i);
			i--;
			AILog.Warning("Closed route");
		}
	}
	AILog.Warning("NumRoutes: " + this._routes.len());
}

function TruckLineManager::IndustryOpen(industry_id)
{
	AILog.Info("New industry: " + AIIndustry.GetName(industry_id));
	local cargo_list = AICargoList();
	foreach (cargo, dummy in cargo_list) {
		local ind_list = AIIndustryList_CargoProducing(cargo);
		if (ind_list.HasItem(industry_id)) {
			if (!this._unbuild_routes.rawin(cargo)) this._unbuild_routes.rawset(cargo, {});
			this._unbuild_routes[cargo].rawset(industry_id, 1);
		}
	}
}

function TruckLineManager::BuildNewLine()
{
	local cargo_list = AICargoList();
	/* Try better-earning cargos first. */
	cargo_list.Valuate(AICargo.GetCargoIncome, 80, 40);
	cargo_list.Sort(AIAbstractList.SORT_BY_VALUE, false);

	foreach (cargo, dummy in cargo_list) {
		if (!this._unbuild_routes.rawin(cargo)) continue;
		foreach (ind_from, dummy in this._unbuild_routes.rawget(cargo)) {
			if (AIIndustry.GetLastMonthProduction(ind_from, cargo) - (AIIndustry.GetLastMonthTransported(ind_from, cargo) >> 1) < 40) continue;
			local ind_acc_list = AIIndustryList_CargoAccepting(cargo);
			ind_acc_list.Valuate(AIIndustry.GetDistanceManhattanToTile, AIIndustry.GetLocation(ind_from));
			ind_acc_list.KeepBetweenValue(30, 250);
			ind_acc_list.Sort(AIAbstractList.SORT_BY_VALUE, true);
			foreach (ind_to, dummy in ind_acc_list) {
				local list_from = AITileList();
				AdmiralAI.AddSquare(list_from, AIIndustry.GetLocation(ind_from), 6);
				local list_to = AITileList();
				AdmiralAI.AddSquare(list_to, AIIndustry.GetLocation(ind_to), 6);
				local array_from = [];
				foreach (tile, d in list_from) array_from.push(tile);
				local array_to = [];
				foreach (tile, d in list_to) array_to.push(tile);
				AILog.Info("Trying to build truck route between: " + AIIndustry.GetName(ind_from) + " and " + AIIndustry.GetName(ind_to));
				local route = RouteFinder.FindRouteBetweenRects(AIIndustry.GetLocation(ind_from), AIIndustry.GetLocation(ind_to), 8);
				if (route == null) {
					local ret = RouteBuilder.BuildRoadRoute(RPF(), array_from, array_to);
					if (ret != 0) return false;
					route = RouteFinder.FindRouteBetweenRects(AIIndustry.GetLocation(ind_from), AIIndustry.GetLocation(ind_to), 8);
					if (route == null) {AILog.Warning("Couldn't find the route we just built"); continue; }
				}
				AILog.Info("Build cargo route between: " + AIIndustry.GetName(ind_from) + " and " + AIIndustry.GetName(ind_to));
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
					return true;
				}
			}
		}
	}
	return false;
}

function TruckLineManager::NewLineExistingRoad()
{
	if (AIDate.GetCurrentDate() - this._last_search_finished < 10) return false;
	return this._NewLineExistingRoadGenerator(40);
}

function TruckLineManager::_GetStationNearIndustry(ind, dir_tile, producing, cargo)
{
	AILog.Info(AIIndustry.GetName(ind) + " " + producing + " " + cargo);
	if (producing && this._ind_to_pickup_station.rawin(ind)) return this._ind_to_pickup_station.rawget(ind);
	if (!producing && this._ind_to_drop_station.rawin(ind)) return this._ind_to_drop_station.rawget(ind);

	local diagoffsets = [AIMap.GetTileIndex(0, 1), AIMap.GetTileIndex(0, -1),
	                 AIMap.GetTileIndex(1, 0), AIMap.GetTileIndex(-1, 0),
	                 AIMap.GetTileIndex(-1, -1), AIMap.GetTileIndex(-1, 1),
	                 AIMap.GetTileIndex(1, -1), AIMap.GetTileIndex(1, 1)];
	/* No station yet for this industry, so build a new one. */
	local tile_list;
	if (producing) tile_list = AITileList_IndustryProducing(ind, AIStation.GetCoverageRadius(AIStation.STATION_TRUCK_STOP));
	else tile_list = AITileList_IndustryAccepting(ind, AIStation.GetCoverageRadius(AIStation.STATION_TRUCK_STOP));

	/* We don't want to delete our own tiles (as it could be stations or necesary roads)
	 * and we can't delete tiles belonging to the competitors. */
	tile_list.Valuate(AITile.GetOwner);
	tile_list.RemoveBetweenValue(AICompany.FIRST_COMPANY - 1, AICompany.LAST_COMPANY + 1);
	tile_list.Valuate(AIMap.DistanceManhattan, dir_tile);
	tile_list.Sort(AIAbstractList.SORT_BY_VALUE, true);
	foreach (tile, dummy in tile_list) {
		local can_build = true;
		foreach (offset in diagoffsets) {
			if (AIRoad.IsRoadStationTile(tile + offset)) can_build = false;
		}
		if (!can_build) continue;
		foreach (offset in this._GetSortedOffsets(tile, dir_tile)) {
			{
				/* Test if we can build a station and the road to it. */
				local test = AITestMode();
				if (!AIRoad.BuildRoadStation(tile, tile + offset, true, false)) continue;
				if (!AIRoad.BuildRoad(tile, tile + offset)) continue;
			}
			/* Build both the road and the station. If building fails, try another location.*/
			if (!AIRoad.BuildRoad(tile, tile + offset)) continue;
			if (!AIRoad.BuildRoadStation(tile, tile + offset, true, false)) continue;
			local station_id = AIStation.GetStationID(tile);
			local manager = StationManager(station_id);
			if (producing) this._ind_to_pickup_station.rawset(ind, manager);
			else this._ind_to_drop_station.rawset(ind, manager);
			return manager;
		}
	}
	/* @TODO: if building a stations failed, try if we can clear some tiles for the station. */
	return null;
}

function TruckLineManager::_BuildDepot(station_manager)
{
	/* Create a list of all road tiles directly connected with the station tiles. */
	local stationtiles = AITileList_StationType(station_manager.GetStationID(), AIStation.STATION_TRUCK_STOP);
	stationtiles.Valuate(AIRoad.GetRoadStationFrontTile);
	/// @todo What if BuildDepot fails?
	return AdmiralAI.BuildDepot(stationtiles.GetValue(stationtiles.Begin()));
}

function TruckLineManager::_NewLineExistingRoadGenerator(num_routes_to_check)
{
	local cargo_list = AICargoList();
	/* Try better-earning cargos first. */
	cargo_list.Valuate(AICargo.GetCargoIncome, 80, 40);
	cargo_list.Sort(AIAbstractList.SORT_BY_VALUE, false);

	local current_routes = -1;
	local cargo_skipped = 0; // The amount of cargos we already searched in a previous search.
	local ind_from_skipped = 0, ind_to_skipped = 0;
	local do_skip = true;
	foreach (cargo, dummy in cargo_list) {
		if (cargo_skipped < this._skip_cargo && do_skip) {
			cargo_skipped++;
			continue;
		}
		if (!this._unbuild_routes.rawin(cargo)) continue;
		foreach (ind_from, dummy in this._unbuild_routes.rawget(cargo)) {
			if (ind_from_skipped < this._skip_ind_from && do_skip) {
				ind_from_skipped++;
				continue;
			}
			if (AIIndustry.GetLastMonthProduction(ind_from, cargo) - (AIIndustry.GetLastMonthTransported(ind_from, cargo) >> 1) < 40) continue;
			local ind_acc_list = AIIndustryList_CargoAccepting(cargo);
			ind_acc_list.Valuate(AIIndustry.GetDistanceManhattanToTile, AIIndustry.GetLocation(ind_from));
			ind_acc_list.KeepBetweenValue(30, this._max_distance_existing_route);
			ind_acc_list.Sort(AIAbstractList.SORT_BY_VALUE, true);
			foreach (ind_to, dummy in ind_acc_list) {
				if (ind_to_skipped < this._skip_ind_to && do_skip) {
					ind_to_skipped++;
					continue;
				}
				do_skip = false;
				current_routes++;
				if (current_routes == num_routes_to_check) {
					return false;
				}
				this._skip_ind_to++;
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
					this._skip_ind_to--;
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
	this._skip_ind_from = 0;
	this._skip_ind_to = 0;
	this._skip_cargo = 0;
	this._last_search_finished = AIDate.GetCurrentDate();
	return false;
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
