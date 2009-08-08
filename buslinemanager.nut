/** @file buslinemanager.nut Implemenation of BusLineManager. */

/**
 * Class that manages all bus routes.
 */
class BusLineManager
{
/* public: */

	/**
	 * Creaet a new bus line manager.
	 */
	constructor()
	{
		local cargo_list = AICargoList();
		cargo_list.Valuate(AICargo.HasCargoClass, AICargo.CC_PASSENGERS);
		if (cargo_list.Count() == 0) {
			/* There is no passenger cargo, so BusLineManager is useless. */
			this._pax_cargo = null;
			return;
		}
		if (cargo_list.Count() > 1) {
			local town_list = AITownList();
			town_list.Valuate(AITown.GetPopulation);
			town_list.Sort(AIAbstractList.SORT_BY_VALUE, false);
			local best_cargo = null;
			local best_cargo_acceptance = 0;
			foreach (cargo, dummy in cargo_list) {
				local acceptance = AITile.GetCargoAcceptance(AITown.GetLocation(town_list.Begin()), cargo, 1, 1, 5);
				if (acceptance > best_cargo_acceptance) {
					best_cargo_acceptance = acceptance;
					best_cargo = cargo;
				}
			}
			this._pax_cargo = best_cargo;
		} else {
			this._pax_cargo = cargo_list.Begin();
		}

		this._town_managers = {};
		local town_list = AITownList();
		foreach (town, dummy in town_list) {
			this._town_managers.rawset(town, TownManager(town));
		}

		this._routes = []
		this._max_distance_existing_route = 100;
		this._skip_from = 0;
		this._skip_to = 0;
		this._max_distance_new_line = 60;
		this._last_search_finished = 0;
	}

	/**
	 * Try to build a new passenger route using mostly existing road.
	 * @return True if and only if a new route was found.
	 */
	function NewLineExistingRoad();

	/**
	 * Build a new passenger route, we don't care if it's over existing road or not.
	 * @return True if and only if a route was succesfully build.
	 */
	function BuildNewLine();

	/**
	 * Check all build routes to see if they have the correct amount of busses.
	 * @return True if and only if we need more money to complete the function.
	 */
	function CheckRoutes();

/* private: */

	/**
	 * A very simple valuator that just returns the item.
	 * @param item The item to valuate.
	 * @return item.
	 */
	function _ValuatorReturnItem(item);

	/**
	 * Build a depot in a given town, close to a station.
	 * @param town_manager A TownManager that is responsible for the town.
	 * @param station_manager The StationManager responsible for the station we
	 *  want a depot nearby.
	 */
	function _BuildDepot(town_manager, station_manager);

	/**
	 * Try to find two towns that are already connected by road.
	 * @param num_routes_to_check The number of connection to try before returning.
	 * @return True if and only if a new route was created.
	 * @note The function may search less routes in case a new route was
	 *  created or the end of the list was reached. Even if the end of the
	 *  list of possible routes is reached, you can safely call the function
	 *  again, as it will start over with a greater range.
	 */
	function _NewLineExistingRoadGenerator(num_routes_to_check);

	_pax_cargo = null;                   ///< The CargoID we are transporting.
	_town_managers = null;               ///< A table with a mapping from TownID to TownManager.
	_routes = null;                      ///< An array containing all BusLines we manage.
	_max_distance_existing_route = null; ///< The maximum distance between industries where we'll still check if they are alerady connected.
	_max_distance_new_line = null;
	_skip_from = null;                   ///< Skip this amount of source towns in _NewLineExistingRoadGenerator, as we already searched them in a previous run.
	_skip_to = null;                     ///< Skip this amount of target towns in _NewLineExistingRoadGenerator, as we already searched them in a previous run.
	_last_search_finished = null;
};

function BusLineManager::CheckRoutes()
{
	foreach (route in this._routes) {
		route.CheckVehicles();
	}
	return false;
}

function BusLineManager::ImproveLines()
{
	for (local i = 0; i < this._routes.len(); i++) {
		for (local j = i + 1; j < this._routes.len(); j++) {
			if (this._routes[i].GetDistance() < 100 && this._routes[j].GetDistance() < 100) {
				local st_from1 = this._routes[i].GetStationFrom();
				local st_from2 = this._routes[j].GetStationFrom();
				local st_to1 = this._routes[i].GetStationTo();
				local st_to2 = this._routes[j].GetStationTo();
				if (AIMap.DistanceManhattan(AIStation.GetLocation(st_from1.GetStationID()), AIStation.GetLocation(st_from2.GetStationID())) > 100 &&
						AIMap.DistanceManhattan(AIStation.GetLocation(st_to1.GetStationID()), AIStation.GetLocation(st_to2.GetStationID())) > 100 &&
						AIMap.DistanceManhattan(AIStation.GetLocation(st_from1.GetStationID()), AIStation.GetLocation(st_from2.GetStationID())) < 200 &&
						AIMap.DistanceManhattan(AIStation.GetLocation(st_to1.GetStationID()), AIStation.GetLocation(st_to2.GetStationID())) < 200 &&
						RouteFinder.FindRouteBetweenRects(AIStation.GetLocation(st_from1.GetStationID()), AIStation.GetLocation(st_from2.GetStationID()), 1) != null &&
						RouteFinder.FindRouteBetweenRects(AIStation.GetLocation(st_to1.GetStationID()), AIStation.GetLocation(st_to2.GetStationID()), 1) != null) {
					this._routes[i].ChangeStationTo(st_from2);
					this._routes[j].ChangeStationFrom(st_to1);
				} else if (AIMap.DistanceManhattan(AIStation.GetLocation(st_from1.GetStationID()), AIStation.GetLocation(st_to2.GetStationID())) > 100 &&
						AIMap.DistanceManhattan(AIStation.GetLocation(st_to1.GetStationID()), AIStation.GetLocation(st_from2.GetStationID())) > 100 &&
						AIMap.DistanceManhattan(AIStation.GetLocation(st_from1.GetStationID()), AIStation.GetLocation(st_to2.GetStationID())) < 200 &&
						AIMap.DistanceManhattan(AIStation.GetLocation(st_to1.GetStationID()), AIStation.GetLocation(st_from2.GetStationID())) < 200 &&
						RouteFinder.FindRouteBetweenRects(AIStation.GetLocation(st_from1.GetStationID()), AIStation.GetLocation(st_to2.GetStationID()), 1) != null &&
						RouteFinder.FindRouteBetweenRects(AIStation.GetLocation(st_to1.GetStationID()), AIStation.GetLocation(st_from2.GetStationID()), 1) != null) {
					this._routes[i].ChangeStationTo(st_to2);
					this._routes[j].ChangeStationTo(st_to1);
				}
			}
		}
	}
}

function BusLineManager::BuildNewLine()
{
	local engine_list = AIEngineList(AIVehicle.VEHICLE_ROAD);
	engine_list.Valuate(AIEngine.GetRoadType);
	engine_list.KeepValue(AIRoad.ROADTYPE_ROAD);
	engine_list.Valuate(AIEngine.IsArticulated);
	engine_list.KeepValue(0);
	engine_list.Valuate(AIEngine.CanRefitCargo, this._pax_cargo);
	engine_list.KeepValue(1);
	if (engine_list.Count() == 0) return;
	foreach (town_from, manager in this._town_managers) {
		if (!manager.CanGetStation()) continue;
		if (AITown.GetPopulation(town_from) < 150) continue;
		local townlist = AITownList();
		townlist.Valuate(BusLineManager._ValuatorReturnItem);
		townlist.KeepAboveValue(town_from);
		townlist.Valuate(AITown.GetDistanceManhattanToTile, AITown.GetLocation(town_from));
		townlist.KeepBetweenValue(10, this._max_distance_new_line);
		townlist.Sort(AIAbstractList.SORT_BY_VALUE, false);
		foreach (town_to, dummy in townlist) {
			if (!this._town_managers.rawget(town_to).CanGetStation()) continue;
			if (AITown.GetPopulation(town_to) < 150) continue;
			local list_from = AITileList();
			AdmiralAI.AddSquare(list_from, AITown.GetLocation(town_from), 0);
			local list_to = AITileList();
			AdmiralAI.AddSquare(list_to, AITown.GetLocation(town_to), 0);
			local array_from = [];
			foreach (tile, d in list_from) array_from.push(tile);
			local array_to = [];
			foreach (tile, d in list_to) array_to.push(tile);
			AILog.Info("Trying pax route between: " + AITown.GetName(town_from) + " and " + AITown.GetName(town_to));
			local station_from = manager.GetStation(this._pax_cargo);
			if (station_from == null) {AILog.Warning("Couldn't build first station"); break;}
			local station_to = this._town_managers.rawget(town_to).GetStation(this._pax_cargo);
			if (station_to == null) {AILog.Warning("Couldn't build second station"); continue; }
			local ret = RouteBuilder.BuildRoadRoute(RPF(), array_from, array_to, 1.5);
			if (ret != 0) continue;
			local route = RouteFinder.FindRouteBetweenRects(AITown.GetLocation(town_from), AITown.GetLocation(town_to), 3);
			local route2 = RouteFinder.FindRouteBetweenRects(AITown.GetLocation(town_to), AITown.GetLocation(town_from), 3);
			if (route == null) { AILog.Warning("The route we just build could not be found"); continue; }
			if (route2 == null) {
				local ret = RouteBuilder.BuildRoadRoute(RPF(), array_to, array_from, 1.5);
				if (ret != 0) continue;
				route2 = RouteFinder.FindRouteBetweenRects(AITown.GetLocation(town_to), AITown.GetLocation(town_from), 3);
				if (route2 == null) { AILog.Warning("The route2 we just build could not be found"); continue; }
			}
			AILog.Info("Build passenger route between: " + AITown.GetName(town_from) + " and " + AITown.GetName(town_to));
			local ret1 = RouteBuilder.BuildRoadRouteFromStation(station_from.GetStationID(), AIStation.STATION_BUS_STOP, [route[0]]);
			local ret2 = RouteBuilder.BuildRoadRouteFromStation(station_to.GetStationID(), AIStation.STATION_BUS_STOP, [route[1]]);
			if (ret1 == 0 && ret2 == 0) {
				AILog.Info("Route ok");
				manager.UseStation(station_from);
				this._town_managers.rawget(town_to).UseStation(station_to);
				local depot_tile = manager.GetDepot(station_from);
				if (depot_tile == null) depot_tile = this._town_managers.rawget(town_to).GetDepot(station_to);
				if (depot_tile == null) break;
				local line = BusLine(station_from, station_to, depot_tile, this._pax_cargo);
				this._routes.push(line);
				return true;
			}
		}
	}
	this._max_distance_new_line += 30;
	return false;
}

function BusLineManager::NewLineExistingRoad()
{
	if (AIDate.GetCurrentDate() - this._last_search_finished < 10) return false;
	return this._NewLineExistingRoadGenerator(40);
}

function BusLineManager::_ValuatorReturnItem(item)
{
	return item;
}

function BusLineManager::_BuildDepot(town_manager, station_manager)
{
	return town_manager.GetDepot(station_manager);
}

function BusLineManager::_NewLineExistingRoadGenerator(num_routes_to_check)
{
	local engine_list = AIEngineList(AIVehicle.VEHICLE_ROAD);
	engine_list.Valuate(AIEngine.GetRoadType);
	engine_list.KeepValue(AIRoad.ROADTYPE_ROAD);
	engine_list.Valuate(AIEngine.IsArticulated);
	engine_list.KeepValue(0);
	engine_list.Valuate(AIEngine.CanRefitCargo, this._pax_cargo);
	engine_list.KeepValue(1);
	if (engine_list.Count() == 0) return;
	local current_routes = -1;
	local town_from_skipped = 0, town_to_skipped = 0;
	local do_skip = true;
	foreach (town, manager in this._town_managers) {
		if (town_from_skipped < this._skip_from && do_skip) {
			town_from_skipped++;
			continue;
		}
		if (!manager.CanGetStation()) continue;
		local townlist = AITownList();
		townlist.Valuate(BusLineManager._ValuatorReturnItem);
		townlist.KeepAboveValue(town);
		townlist.Valuate(AITown.GetDistanceManhattanToTile, AITown.GetLocation(town));
		townlist.KeepBetweenValue(10, this._max_distance_existing_route);
		townlist.Sort(AIAbstractList.SORT_BY_VALUE, false);
		foreach (town_to, dummy in townlist) {
			if (town_to_skipped < this._skip_to && do_skip) {
				town_to_skipped++;
				continue;
			}
			do_skip = false;
			this._skip_to++;
			if (!this._town_managers.rawget(town_to).CanGetStation()) continue;
			current_routes++;
			if (current_routes == num_routes_to_check) {
				return false;
			}
			local route = RouteFinder.FindRouteBetweenRects(AITown.GetLocation(town), AITown.GetLocation(town_to), 3);
			if (route == null) continue;
			AILog.Info("Found passenger route between: " + AITown.GetName(town) + " and " + AITown.GetName(town_to));
			local station_from = manager.GetStation(this._pax_cargo);
			if (station_from == null) {AILog.Warning("Couldn't build first station"); break;}
			local station_to = this._town_managers.rawget(town_to).GetStation(this._pax_cargo);
			if (station_to == null) {AILog.Warning("Couldn't build second station"); continue; }
			local ret1 = RouteBuilder.BuildRoadRouteFromStation(station_from.GetStationID(), AIStation.STATION_BUS_STOP, [route[0]]);
			local ret2 = RouteBuilder.BuildRoadRouteFromStation(station_to.GetStationID(), AIStation.STATION_BUS_STOP, [route[1]]);
			if (ret1 == 0 && ret2 == 0) {
				AILog.Info("Route ok");
				manager.UseStation(station_from);
				this._town_managers.rawget(town_to).UseStation(station_to);
				local line = BusLine(station_from, station_to, manager.GetDepot(station_from), this._pax_cargo);
				this._routes.push(line);
				this._skip_to = 0;
				return true;
			}
		}
		this._skip_to = 0;
		this._skip_from++;
		do_skip = false;
	}
	AILog.Info("Full town search done!");
	this._max_distance_existing_route = min(400, this._max_distance_existing_route + 50);
	this._skip_to = 0;
	this._skip_from = 0;
	this._last_search_finished = AIDate.GetCurrentDate();
	return false;
}
