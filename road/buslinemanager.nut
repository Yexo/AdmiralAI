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

/** @file buslinemanager.nut Implemenation of BusLineManager. */

/**
 * Class that manages all bus routes.
 */
class BusLineManager
{
	_routes = null;                      ///< An array containing all BusLines we manage.
	_max_distance_existing_route = null; ///< The maximum distance between industries where we'll still check if they are alerady connected.
	_max_distance_new_line = null;
	_skip_from = null;                   ///< Skip this amount of source towns in _NewLineExistingRoadGenerator, as we already searched them in a previous run.
	_skip_to = null;                     ///< Skip this amount of target towns in _NewLineExistingRoadGenerator, as we already searched them in a previous run.
	_last_search_finished = null;

/* public: */

	/**
	 * Creaet a new bus line manager.
	 */
	constructor()
	{
		this._routes = [];
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
};

function BusLineManager::Save()
{
	local data = {};
	return data;
}

function BusLineManager::Load(data)
{
}

function BusLineManager::AfterLoad()
{
	local vehicle_list = AIVehicleList();
	vehicle_list.Valuate(AIVehicle.GetVehicleType);
	vehicle_list.KeepValue(AIVehicle.VT_ROAD);
	vehicle_list.Valuate(AIVehicle.GetCapacity, ::main_instance._passenger_cargo_id);
	vehicle_list.KeepAboveValue(0);
	local st_from = {};
	local st_to = {};
	foreach (v, dummy in vehicle_list) {
		if (AIOrder.GetOrderCount(v) != 3) {
			::main_instance.sell_vehicles.AddItem(v, 0);
			continue;
		}
		if (AIRoad.IsRoadDepotTile(AIOrder.GetOrderDestination(v, 0))) AIOrder.MoveOrder(v, 0, 2);
		if (!AIRoad.IsRoadStationTile(AIOrder.GetOrderDestination(v, 0)) ||
				!AIRoad.IsRoadStationTile(AIOrder.GetOrderDestination(v, 1)) ||
				!AIRoad.IsRoadDepotTile(AIOrder.GetOrderDestination(v, 2))) {
			::main_instance.sell_vehicles.AddItem(v, 0);
			continue;
		}
		local station_a = AIStation.GetStationID(AIOrder.GetOrderDestination(v, 0));
		local station_b = AIStation.GetStationID(AIOrder.GetOrderDestination(v, 1));
		if (st_from.rawin(station_a)) {
			if (station_b == st_from.rawget(station_a).GetStationTo().GetStationID()) {
				/* Add the vehicle to both bus station a and b. */
				local station_from = st_from.rawget(station_a).GetStationFrom();
				local station_to = st_from.rawget(station_a).GetStationTo();
				station_from.AddBusses(1, AIMap.DistanceManhattan(AIStation.GetLocation(station_from.GetStationID()), AIStation.GetLocation(station_to.GetStationID())), AIEngine.GetMaxSpeed(AIVehicle.GetEngineType(v)));
				station_to.AddBusses(1, AIMap.DistanceManhattan(AIStation.GetLocation(station_from.GetStationID()), AIStation.GetLocation(station_to.GetStationID())), AIEngine.GetMaxSpeed(AIVehicle.GetEngineType(v)));
			} else {
				::main_instance.sell_vehicles.AddItem(v, 0);
				continue;
			}
		} else {
			if (st_to.rawin(station_b) || st_to.rawin(station_b) || st_from.rawin(station_b)) {
				::main_instance.sell_vehicles.AddItem(v, 0);
				continue;
			}
			/* New BusLine from station_a to station_b. */
			local station_manager_a = StationManager(station_a);
			local station_manager_b = StationManager(station_b);
			local depot_list = AIDepotList(AITile.TRANSPORT_ROAD);
			depot_list.Valuate(AIMap.DistanceManhattan, AIStation.GetLocation(station_a));
			depot_list.Sort(AIAbstractList.SORT_BY_VALUE, AIAbstractList.SORT_ASCENDING);
			local depot_tile = depot_list.Begin();
			local articulated = station_manager_a.HasArticulatedBusStop() && station_manager_b.HasArticulatedBusStop();
			local line = BusLine(station_manager_a, station_manager_b, depot_tile, ::main_instance._passenger_cargo_id, articulated);
			this._routes.push(line);
			st_from.rawset(station_a, line);
			st_to.rawset(station_b, null);
		}
	}

	foreach (town_id, manager in ::main_instance._town_managers) {
		manager.ScanMap();
	}

	foreach (route in this._routes) {
		route.InitiateAutoReplace();
	}
}


function BusLineManager::CheckRoutes()
{
	local need_money = false;
	foreach (route in this._routes) {
		if (route.CheckVehicles()) need_money = true;
	}
	return need_money;
}

function BusLineManager::ImproveLines()
{
	return;
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
					this._routes[i].RenameGroup();
					this._routes[j].RenameGroup();
				} else if (AIMap.DistanceManhattan(AIStation.GetLocation(st_from1.GetStationID()), AIStation.GetLocation(st_to2.GetStationID())) > 100 &&
						AIMap.DistanceManhattan(AIStation.GetLocation(st_to1.GetStationID()), AIStation.GetLocation(st_from2.GetStationID())) > 100 &&
						AIMap.DistanceManhattan(AIStation.GetLocation(st_from1.GetStationID()), AIStation.GetLocation(st_to2.GetStationID())) < 200 &&
						AIMap.DistanceManhattan(AIStation.GetLocation(st_to1.GetStationID()), AIStation.GetLocation(st_from2.GetStationID())) < 200 &&
						RouteFinder.FindRouteBetweenRects(AIStation.GetLocation(st_from1.GetStationID()), AIStation.GetLocation(st_to2.GetStationID()), 1) != null &&
						RouteFinder.FindRouteBetweenRects(AIStation.GetLocation(st_to1.GetStationID()), AIStation.GetLocation(st_from2.GetStationID()), 1) != null) {
					this._routes[i].ChangeStationTo(st_to2);
					this._routes[j].ChangeStationTo(st_to1);
					this._routes[i].RenameGroup();
					this._routes[j].RenameGroup();
				}
			}
		}
	}
}

function BusLineManager::BuildNewLine()
{
	local engine_list = AIEngineList(AIVehicle.VT_ROAD);
	engine_list.Valuate(AIEngine.GetRoadType);
	engine_list.KeepValue(AIRoad.GetCurrentRoadType());
	engine_list.Valuate(AIEngine.CanRefitCargo, ::main_instance._passenger_cargo_id);
	engine_list.KeepValue(1);
	if (engine_list.Count() == 0) return;
	/* If there are only articulated vehicles available we must build a dtrs. */
	engine_list.Valuate(AIEngine.IsArticulated);
	engine_list.KeepValue(0);
	local force_dtrs = engine_list.Count() == 0;

	local subsidies = AISubsidyList();
	/* Only non-awarded subsidies are taken into consideration. */
	subsidies.Valuate(AISubsidy.IsAwarded);
	subsidies.KeepValue(0);
	/* We only want passengers subsidies from town to town. */
	subsidies.Valuate(AISubsidy.GetCargoType);
	subsidies.KeepValue(::main_instance._passenger_cargo_id);
	subsidies.Valuate(AISubsidy.GetSourceType);
	subsidies.KeepValue(AISubsidy.SPT_TOWN);
	subsidies.Valuate(AISubsidy.GetDestinationType);
	subsidies.KeepValue(AISubsidy.SPT_TOWN);
	/* We need at least 6 months or the subsidy might already be expired
	 * before we are done building the route. */
	subsidies.Valuate(AISubsidy.GetExpireDate);
	subsidies.KeepAboveValue(AIDate.GetCurrentDate() + 180);
	/* Finally we have a list of usaable subsidies. */
	foreach (subsidy, dummy in subsidies) {
		local town_from = AISubsidy.GetSourceIndex(subsidy);
		local town_to = AISubsidy.GetDestinationIndex(subsidy);
		local manager = ::main_instance._town_managers[town_from];
		local manager2 = ::main_instance._town_managers[town_to];
		if (!manager.CanGetStation() || !manager2.CanGetStation()) continue;
		local array_from = [AITown.GetLocation(town_from)];
		local array_to = [AITown.GetLocation(town_to)];
		AILog.Info("Trying subsidy pax route between: " + AITown.GetName(town_from) + " and " + AITown.GetName(town_to));
		local station_from = manager.GetStation(force_dtrs);
		if (station_from == null) {AILog.Warning("Couldn't build first station"); break;}
		local station_to = manager2.GetStation(force_dtrs);
		if (station_to == null) {AILog.Warning("Couldn't build second station"); continue; }
		local ret = RouteBuilder.BuildRoadRoute(RPF([town_from, town_to]), array_from, array_to, 1.2, 20);
		if (ret != 0) continue;
		local route = RouteFinder.FindRouteBetweenRects(AITown.GetLocation(town_from), AITown.GetLocation(town_to), 3);
		local route2 = RouteFinder.FindRouteBetweenRects(AITown.GetLocation(town_to), AITown.GetLocation(town_from), 3);
		if (route == null) { AILog.Warning("The route we just build could not be found"); continue; }
		if (route2 == null) {
			local ret = RouteBuilder.BuildRoadRoute(RPF([town_from, town_to]), array_to, array_from, 1.2, 20);
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
			::main_instance._town_managers.rawget(town_to).UseStation(station_to);
			local depot_tile = manager.GetDepot(station_from);
			if (depot_tile == null) depot_tile = ::main_instance._town_managers.rawget(town_to).GetDepot(station_to);
			if (depot_tile == null) break;
			local articulated = station_from.HasArticulatedBusStop() && station_to.HasArticulatedBusStop();
			local line = BusLine(station_from, station_to, depot_tile, ::main_instance._passenger_cargo_id, false, articulated);
			this._routes.push(line);
			return true;
		}
	}

	foreach (town_from, manager in ::main_instance._town_managers) {
		if (!manager.CanGetStation()) continue;
		if (AITown.GetPopulation(town_from) < 150) continue;
		local townlist = AITownList();
		townlist.Valuate(Utils_Valuator.ItemValuator);
		townlist.KeepAboveValue(town_from);
		townlist.Valuate(AITown.GetDistanceManhattanToTile, AITown.GetLocation(town_from));
		townlist.KeepBetweenValue(50, this._max_distance_new_line);
		townlist.Sort(AIAbstractList.SORT_BY_VALUE, AIAbstractList.SORT_DESCENDING);
		foreach (town_to, dummy in townlist) {
			local manager2 = ::main_instance._town_managers[town_to];
			if (!manager2.CanGetStation()) continue;
			if (AITown.GetPopulation(town_to) < 150) continue;
			local list_from = AITileList();
			Utils_Tile.AddSquare(list_from, AITown.GetLocation(town_from), 0);
			local list_to = AITileList();
			Utils_Tile.AddSquare(list_to, AITown.GetLocation(town_to), 0);
			local array_from = [];
			foreach (tile, d in list_from) array_from.push(tile);
			local array_to = [];
			foreach (tile, d in list_to) array_to.push(tile);
			AILog.Info("Trying pax route between: " + AITown.GetName(town_from) + " and " + AITown.GetName(town_to));
			local station_from = manager.GetStation(force_dtrs);
			if (station_from == null) {AILog.Warning("Couldn't build first station"); break;}
			local station_to = manager2.GetStation(force_dtrs);
			if (station_to == null) {AILog.Warning("Couldn't build second station"); continue; }
			local ret = RouteBuilder.BuildRoadRoute(RPF([town_from, town_to]), array_from, array_to, 1.2, 20);
			if (ret != 0) continue;
			local route = RouteFinder.FindRouteBetweenRects(AITown.GetLocation(town_from), AITown.GetLocation(town_to), 3);
			local route2 = RouteFinder.FindRouteBetweenRects(AITown.GetLocation(town_to), AITown.GetLocation(town_from), 3);
			if (route == null) { AILog.Warning("The route we just build could not be found"); continue; }
			if (route2 == null) {
				local ret = RouteBuilder.BuildRoadRoute(RPF([town_from, town_to]), array_to, array_from, 1.2, 20);
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
				::main_instance._town_managers.rawget(town_to).UseStation(station_to);
				local depot_tile = manager.GetDepot(station_from);
				if (depot_tile == null) depot_tile = ::main_instance._town_managers.rawget(town_to).GetDepot(station_to);
				if (depot_tile == null) break;
				local articulated = station_from.HasArticulatedBusStop() && station_to.HasArticulatedBusStop();
				local line = BusLine(station_from, station_to, depot_tile, ::main_instance._passenger_cargo_id, false, articulated);
				this._routes.push(line);
				::main_instance.BuildHQ(station_to.GetStationID(), 1, 1);
				::main_instance.BuildHQ(station_from.GetStationID(), 1, 1);
				return true;
			}
		}
	}
	this._max_distance_new_line = min(300, this._max_distance_new_line + 30);
	return false;
}

function BusLineManager::NewLineExistingRoad()
{
	if (AIDate.GetCurrentDate() - this._last_search_finished < 10) return false;
	return this._NewLineExistingRoadGenerator(200);
}

function BusLineManager::_BuildDepot(town_manager, station_manager)
{
	return town_manager.GetDepot(station_manager);
}

function BusLineManager::_NewLineExistingRoadGenerator(num_routes_to_check)
{
	local engine_list = AIEngineList(AIVehicle.VT_ROAD);
	engine_list.Valuate(AIEngine.GetRoadType);
	engine_list.KeepValue(AIRoad.GetCurrentRoadType());
	engine_list.Valuate(AIEngine.CanRefitCargo, ::main_instance._passenger_cargo_id);
	engine_list.KeepValue(1);
	if (engine_list.Count() == 0) return;
	/* If there are only articulated vehicles available we must build a dtrs. */
	engine_list.Valuate(AIEngine.IsArticulated);
	engine_list.KeepValue(0);
	local force_dtrs = engine_list.Count() == 0;

	local current_routes = -1;
	local town_from_skipped = 0, town_to_skipped = 0;
	local do_skip = true;
	foreach (town, manager in ::main_instance._town_managers) {
		if (town_from_skipped < this._skip_from && do_skip) {
			town_from_skipped++;
			continue;
		}
		if (!manager.CanGetStation()) continue;
		local townlist = AITownList();
		townlist.Valuate(Utils_Valuator.ItemValuator);
		townlist.KeepAboveValue(town);
		townlist.Valuate(AITown.GetDistanceManhattanToTile, AITown.GetLocation(town));
		townlist.KeepBetweenValue(50, this._max_distance_existing_route);
		townlist.Sort(AIAbstractList.SORT_BY_VALUE, AIAbstractList.SORT_DESCENDING);
		foreach (town_to, dummy in townlist) {
			if (town_to_skipped < this._skip_to && do_skip) {
				town_to_skipped++;
				continue;
			}
			do_skip = false;
			this._skip_to++;
			local manager2 = ::main_instance._town_managers[town_to];
			if (!manager2.CanGetStation()) continue;
			current_routes++;
			if (current_routes == num_routes_to_check) {
				return false;
			}
			local route = RouteFinder.FindRouteBetweenRects(AITown.GetLocation(town), AITown.GetLocation(town_to), 3);
			if (route == null) continue;
			AILog.Info("Found passenger route between: " + AITown.GetName(town) + " and " + AITown.GetName(town_to));
			local station_from = manager.GetStation(force_dtrs);
			if (station_from == null) {AILog.Warning("Couldn't build first station"); break;}
			local station_to = manager2.GetStation(force_dtrs);
			if (station_to == null) {AILog.Warning("Couldn't build second station"); continue; }
			local ret1 = RouteBuilder.BuildRoadRouteFromStation(station_from.GetStationID(), AIStation.STATION_BUS_STOP, [route[0]]);
			local ret2 = RouteBuilder.BuildRoadRouteFromStation(station_to.GetStationID(), AIStation.STATION_BUS_STOP, [route[1]]);
			if (ret1 == 0 && ret2 == 0) {
				AILog.Info("Route ok");
				manager.UseStation(station_from);
				::main_instance._town_managers.rawget(town_to).UseStation(station_to);
				local depot_tile = manager.GetDepot(station_from);
				if (depot_tile == null) depot_tile = ::main_instance._town_managers.rawget(town_to).GetDepot(station_to);
				if (depot_tile == null) break;
				local articulated = station_from.HasArticulatedBusStop() && station_to.HasArticulatedBusStop();
				local line = BusLine(station_from, station_to, depot_tile, ::main_instance._passenger_cargo_id, false, articulated);
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
	this._max_distance_existing_route = min(300, this._max_distance_existing_route + 50);
	this._skip_to = 0;
	this._skip_from = 0;
	this._last_search_finished = AIDate.GetCurrentDate();
	return false;
}
