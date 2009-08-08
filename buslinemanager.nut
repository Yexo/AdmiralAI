class BusLineManager
{
	_pax_cargo = null;
	_town_managers = null;
	_routes = null;
	_max_distance_existing_route = null;
	_skip_from = null;
	_skip_to = null;

	constructor()
	{
		local cargo_list = AICargoList();
		cargo_list.Valuate(AICargo.HasCargoClass, AICargo.CC_PASSENGERS);
		if (cargo_list.Count() == 0) {
			/* There is no passenger cargo, so BusLineManager is useless. */
			this._pax_cargo = null;
			return;
		}
		this._pax_cargo = cargo_list.Begin();

		this._town_managers = {};
		local town_list = AITownList();
		foreach (town, dummy in town_list) {
			this._town_managers.rawset(town, TownManager(town));
		}

		this._routes = []
		this._max_distance_existing_route = 100;
		this._skip_from = 0;
		this._skip_to = 0;
	}

	/**
	 * Try to build a new passenger route using mostly existing road.
	 */
	function NewLineExistingRoad();

	/**
	 * Build a new passenger route, we don't care if it's over existing road or not.
	 */
	function BuildNewLine();

	/**
	 * Check all build routes to see if they have the correct amount of busses.
	 */
	function CheckRoutes();
}

function BusLineManager::CheckRoutes()
{
	foreach (route in this._routes) {
		route.CheckVehicles();
	}
	return false;
}

function BusLineManager::_BuildDepot(town_manager, station_manager)
{
	return town_manager.GetDepot(station_manager);
}

function BusLineManager::BuildNewLine()
{
	return false; //TODO
}

function BusLineManager::NewLineExistingRoad()
{
	local result = this._NewLineExistingRoadGenerator(40);
	if (result == null) {
		result = false;
	}
	return result;
}

function BusLineManager::_NewLineExistingRoadGenerator(num_routes_to_check)
{
	local current_routes = -1;
	local town_from_skipped = 0, town_to_skipped = 0;
	local do_skip = true;
	foreach (town, manager in this._town_managers) {
		if (town_from_skipped < this._skip_from && do_skip) {
			town_from_skipped++;
			continue;
		}
		local townlist = AITownList();
		townlist.Valuate(AITown.GetDistanceManhattanToTile, AITown.GetLocation(town));
		townlist.KeepBetweenValue(10, this._max_distance_existing_route);
		townlist.Sort(AIAbstractList.SORT_BY_VALUE, false);
		foreach (town_to, dummy in townlist) {
			if (town_to <= town) continue;
			if (town_to_skipped < this._skip_to && do_skip) {
				town_to_skipped++;
				continue;
			}
			do_skip = false;
			this._skip_to++;
			if (!manager.CanGetStation()) continue;
			if (!this._town_managers.rawget(town_to).CanGetStation()) continue;
			current_routes++;
			if (current_routes == num_routes_to_check) {
				return false;
			}
			local route = RouteFinder.FindRouteBetweenRects(AITown.GetLocation(town), AITown.GetLocation(town_to), 3);
			if (route == null) continue;
			AILog.Info("Found passenger route between: " + AITown.GetName(town) + " and " + AITown.GetName(town_to));
			local station_from = manager.GetStation(AITown.GetLocation(town));
			if (station_from == null) {AILog.Warning("Couldn't build first station"); break;}
			local station_to = this._town_managers.rawget(town_to).GetStation(AITown.GetLocation(town_to));
			if (station_to == null) {AILog.Warning("Couldn't build second station"); continue; }
			local ret1 = RouteBuilder.BuildRoadRouteFromStation(station_from.GetStationID(), AIStation.STATION_BUS_STOP, [route[0]]);
			local ret2 = RouteBuilder.BuildRoadRouteFromStation(station_to.GetStationID(), AIStation.STATION_BUS_STOP, [route[1]]);
			if (ret1 == 0 && ret2 == 0) {
				AILog.Info("Route ok");
				local line = BusLine(station_from, station_to, manager.GetDepot(station_from), this._pax_cargo);
				this._routes.push(line);
				return true;
			}
		}
		this._skip_to = 0;
		this._skip_from++;
		do_skip = false;
	}
	AILog.Info("Full town search done!");
	this._max_distance_existing_route = min(400, this._max_distance_existing_route + 50);
	this._skip_from = 0;
	return null;
}
