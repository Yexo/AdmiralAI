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

/** @file trucklinemanager.nut Implemenation of TruckLineManager. */

/**
 * Class that manages all truck routes.
 */
class TruckLineManager
{
	_unbuild_routes = null;              ///< A table with as index CargoID and as value an array of industries we haven't connected.
	_ind_to_pickup_stations = null;      ///< A table mapping IndustryIDs to StationManagers. If an IndustryID is not in this list, we haven't build a pickup station there yet.
	_ind_to_drop_station = null;         ///< A table mapping IndustryIDs to StationManagers.
	_routes = null;                      ///< An array containing all TruckLines build.
	_min_distance = null;                ///< The minimum distance between industries.
	_max_distance_existing_route = null; ///< The maximum distance between industries where we'll still check if they are alerady connected.
	_max_distance_new_route = null;      ///< The maximum distance between industries for a new route.
	_skip_cargo = null;                  ///< Skip this amount of CargoIDs in _NewLineExistingRoadGenerator, as we already searched them in a previous run.
	_skip_ind_from = null;               ///< Skip this amount of source industries in _NewLineExistingRoadGenerator, as we already searched them in a previous run.
	_skip_ind_to = null;                 ///< Skip this amount of goal industries in _NewLineExistingRoadGenerator, as we already searched them in a previous run.
	_last_search_finished = null;        ///< The date the last full industry search for existing routes finised.

/* public: */

	/**
	 * Create a new instance.
	 */
	constructor()
	{
		this._unbuild_routes = {};
		this._ind_to_pickup_stations = {};
		this._ind_to_drop_station = {};
		this._routes = [];
		this._min_distance = 35;
		this._max_distance_existing_route = 75;
		this._max_distance_new_route = 75;
		this._skip_cargo = 0;
		this._skip_ind_from = 0;
		this._skip_ind_to = 0;
		this._last_search_finished = 0;
		this._InitializeUnbuildRoutes();
	}

	/**
	 * Check all build routes to see if they have the correct amount of trucks.
	 * @return True if and only if we need more money to complete the function.
	 */
	function CheckRoutes();

	/**
	 * Call this function if an industry closed.
	 * @param industry_id The IndustryID of the industry that has closed.
	 */
	function IndustryClose(industry_id);

	/**
	 * Call this function when a new industry was created.
	 * @param industry_id The IndustryID of the new industry.
	 */
	function IndustryOpen(industry_id);

	/**
	 * Build a new cargo route, we don't care if it's over existing road or not.
	 * @return True if and only if a new route was created.
	 */
	function BuildNewLine();

	/**
	 * Try to build a new cargo route using mostly existing road.
	 * @return True if and only if a new route was created.
	 */
	function NewLineExistingRoad();

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
};

function TruckLineManager::TransportCargo(cargo, ind)
{
	this._unbuild_routes[cargo].rawdelete(ind);
}

function TruckLineManager::Save()
{
	local data = {pickup_stations = {}, drop_stations = {}, routes = []};

	foreach (ind, managers in this._ind_to_pickup_stations) {
		local station_ids = [];
		foreach (manager in managers) {
			station_ids.push([manager[0].GetStationID(), manager[1]]);
		}
		data.pickup_stations.rawset(ind, station_ids);
	}

	foreach (ind, station_manager in this._ind_to_drop_station) {
		data.drop_stations.rawset(ind, station_manager.GetStationID());
	}

	foreach (route in this._routes) {
		if (!route._valid) continue;
		data.routes.push([route._ind_from, route._station_from.GetStationID(), route._ind_to, route._station_to.GetStationID(), route._depot_tile, route._cargo, route._engine_id]);
	}

	return data;
}

function TruckLineManager::Load(data)
{
	if (data.rawin("pickup_stations")) {
		foreach (ind, manager_array in data.rawget("pickup_stations")) {
			local new_man_array = [];
			foreach (man_info in manager_array) {
				local man = StationManager(man_info[0]);
				man.SetCargoDrop(false);
				new_man_array.push([man, man_info[1]]);
			}
			this._ind_to_pickup_stations.rawset(ind, new_man_array);
		}
	}

	if (data.rawin("drop_stations")) {
		foreach (ind, station_id in data.rawget("drop_stations")) {
			local man = StationManager(station_id);
			man.SetCargoDrop(true);
			this._ind_to_drop_station.rawset(ind, man);
		}
	}

	if (data.rawin("routes")) {
		foreach (route_array in data.rawget("routes")) {
			local station_from = null;
			foreach (station in this._ind_to_pickup_stations.rawget(route_array[0])) {
				if (station[0].GetStationID() == route_array[1]) {
					station_from = station[0];
					break;
				}
			}
			local station_to = null;
			if (this._ind_to_drop_station.rawin(route_array[2])) {
				local station = this._ind_to_drop_station.rawget(route_array[2]);
				if (station.GetStationID() == route_array[3]) {
					station_to = station;
				}
			}
			if (station_from == null || station_to == null) continue;
			local route = TruckLine(route_array[0], station_from, route_array[2], station_to, route_array[4], route_array[5], true);
			route._engine_id = route_array[6];
			route.ScanPoints();
			this._routes.push(route);
			if (this._unbuild_routes.rawin(route_array[5])) {
				foreach (ind, dummy in this._unbuild_routes[route_array[5]]) {
					//AILog.Info(ind + " " + AIIndustry.GetName(ind));
					if (ind == route_array[0]) {
						AdmiralAI.TransportCargo(route_array[5], ind);
						break;
					}
				}
			} else {
				AILog.Error("CargoID " + route_array[5] + " not in unbuild_routes");
			}
		}
	}
}

function TruckLineManager::AfterLoad()
{
	foreach (route in this._routes) {
		route._group_id = AIGroup.CreateGroup(AIVehicle.VT_ROAD);
		route.RenameGroup();
		foreach (v, dummy in route._vehicle_list) {
			AIGroup.MoveVehicle(route._group_id, v);
		}
		route.InitiateAutoReplace();
	}
}

function TruckLineManager::ClosedStation(station)
{
	if (station.IsCargoDrop()) {
		foreach (ind, list in this._ind_to_pickup_stations) {
			local to_remove = [];
			foreach (id, station_pair in list) {
				if (station == station_pair[0]) {
					to_remove.push(id);
				}
			}
			foreach (id in to_remove) {
				list.remove(id);
			}
		}
	} else {
		local to_remove = [];
		foreach (ind, station2 in this._ind_to_drop_station) {
			if (station == station2) {
				to_remove.push(ind);
			}
		}
		foreach (ind in to_remove) {
			this._ind_to_drop_station.rawdelete(ind);
		}
	}
}

function TruckLineManager::CheckRoutes()
{
	local need_money = false;
	foreach (route in this._routes) {
		if (route.CheckVehicles()) need_money = true;
	}
	return need_money;
}

function TruckLineManager::IndustryClose(industry_id)
{
	for (local i = 0; i < this._routes.len(); i++) {
		local route = this._routes[i];
		if (route.GetIndustryFrom() == industry_id || route.GetIndustryTo() == industry_id) {
			if (route.GetIndustryTo() == industry_id) {
				this._unbuild_routes[route._cargo].rawset(route.GetIndustryFrom(), 1);
			}
			route.CloseRoute();
			this._routes.remove(i);
			i--;
			AILog.Warning("Closed route");
		}
	}
	foreach (cargo, table in this._unbuild_routes) {
		this._unbuild_routes[cargo].rawdelete(industry_id);
	}
}

function TruckLineManager::IndustryOpen(industry_id)
{
	AILog.Info("New industry: " + AIIndustry.GetName(industry_id));
	foreach (cargo, dummy in AICargoList_IndustryProducing(industry_id)) {
		if (!this._unbuild_routes.rawin(cargo)) this._unbuild_routes.rawset(cargo, {});
		this._unbuild_routes[cargo].rawset(industry_id, 1);
	}
}

function TruckLineManager::BuildNewLine()
{
	local last_road_type = AIRoad.GetCurrentRoadType();
	AIRoad.SetCurrentRoadType(AIRoad.ROADTYPE_ROAD);

	local cargo_list = ::main_instance.GetSortedCargoList();

	foreach (cargo, dummy in cargo_list) {
		if (!AICargo.IsFreight(cargo)) continue;
		if (!this._unbuild_routes.rawin(cargo)) continue;
		local engine_list = AIEngineList(AIVehicle.VT_ROAD);
		engine_list.Valuate(AIEngine.GetRoadType);
		engine_list.KeepValue(AIRoad.ROADTYPE_ROAD);
		engine_list.Valuate(AIEngine.IsArticulated);
		engine_list.KeepValue(0);
		engine_list.Valuate(AIEngine.CanRefitCargo, cargo);
		engine_list.KeepValue(1);
		if (engine_list.Count() == 0) continue;
		foreach (ind_from, dummy in this._unbuild_routes.rawget(cargo)) {
			if (AIIndustry.IsBuiltOnWater(ind_from)) continue;
			if (AIIndustry.GetLastMonthProduction(ind_from, cargo) - (AIIndustry.GetLastMonthTransported(ind_from, cargo) >> 1) < 40) {
				if (!AIIndustryType.IsRawIndustry(AIIndustry.GetIndustryType(ind_from))) continue;
			}
			local last_production = AIIndustry.GetLastMonthProduction(ind_from, cargo);
			local last_transportation = AIIndustry.GetLastMonthTransported(ind_from, cargo);
			if (last_production == 0) continue;
			/* Don't try to transport goods from industries that are serviced very well. */
			if (AdmiralAI.GetMaxCargoPercentTransported(AITile.GetClosestTown(AIIndustry.GetLocation(ind_from))) < 100 * last_transportation / last_production) continue;
			/* Serviced industries with very low production are not interesting. */
			if (last_production < 100 && last_transportation > 0) continue;
			local ind_acc_list = AIIndustryList_CargoAccepting(cargo);
			ind_acc_list.Valuate(AIIndustry.GetDistanceManhattanToTile, AIIndustry.GetLocation(ind_from));
			ind_acc_list.KeepBetweenValue(this._min_distance, this._max_distance_new_route);
			ind_acc_list.Sort(AIAbstractList.SORT_BY_VALUE, AIAbstractList.SORT_ASCENDING);
			foreach (ind_to, dummy in ind_acc_list) {
				local list_from = AITileList();
				Utils_Tile.AddSquare(list_from, AIIndustry.GetLocation(ind_from), 6);
				local list_to = AITileList();
				Utils_Tile.AddSquare(list_to, AIIndustry.GetLocation(ind_to), 6);
				local array_from = [];
				foreach (tile, d in list_from) array_from.push(tile);
				local array_to = [];
				foreach (tile, d in list_to) array_to.push(tile);
				AILog.Info("Trying to build truck route between: " + AIIndustry.GetName(ind_from) + " and " + AIIndustry.GetName(ind_to));
				local route = RouteFinder.FindRouteBetweenRects(AIIndustry.GetLocation(ind_from), AIIndustry.GetLocation(ind_to), 8);
				local ends_to_delete = [];
				if (route == null) {
					local ret = RouteBuilder.BuildRoadRoute(RPF(), array_from, array_to, 1.2, 20, [], ends_to_delete);
					if (ret != 0) {
						AIRoad.SetCurrentRoadType(last_road_type);
						return false;
					}
					route = RouteFinder.FindRouteBetweenRects(AIIndustry.GetLocation(ind_from), AIIndustry.GetLocation(ind_to), 8);
					if (route == null) {AILog.Warning("Couldn't find the route we just built"); continue; }
					local route2 = RouteFinder.FindRouteBetweenRects(AIIndustry.GetLocation(ind_to), AIIndustry.GetLocation(ind_from), 8);
					if (route2 == null) {
						ret = RouteBuilder.BuildRoadRoute(RPF(), array_to, array_from, 1.2, 20, [], ends_to_delete);
						if (ret != 0) {
							AIRoad.SetCurrentRoadType(last_road_type);
							return false;
						}
						route2 = RouteFinder.FindRouteBetweenRects(AIIndustry.GetLocation(ind_to), AIIndustry.GetLocation(ind_from), 8);
						if (route2 == null) {
							AILog.Warning("Couldn't find the second route we just built");
							AIRoad.SetCurrentRoadType(last_road_type);
							return false;
						}
					}
				}
				AILog.Info("Build cargo route between: " + AIIndustry.GetName(ind_from) + " and " + AIIndustry.GetName(ind_to));
				local station_from = this._GetStationNearIndustry(ind_from, route[0], true, cargo);
				if (station_from == null) break;
				local ret1 = RouteBuilder.BuildRoadRouteFromStation(station_from.GetStationID(), AIStation.STATION_TRUCK_STOP, [route[0]]);
				if (ret1 != 0) break;
				local depot = this._BuildDepot(station_from);
				if (depot == null) break;
				local station_to = this._GetStationNearIndustry(ind_to, route[1], false, cargo);
				if (station_to == null) continue;
				/** @todo We have 80 here random speed, maybe create an engine list and take the real value. */
				if (station_to.CanAddTrucks(5, AIIndustry.GetDistanceManhattanToTile(ind_from, AIIndustry.GetLocation(ind_to)), 80) < 5) continue;
				local ret2 = RouteBuilder.BuildRoadRouteFromStation(station_to.GetStationID(), AIStation.STATION_TRUCK_STOP, [route[1]]);
				if (ret2 != 0) continue;
				foreach (tile in ends_to_delete) RouteBuilder.DeleteDeadEnd(tile);
				AILog.Info("Route ok");
				local line = TruckLine(ind_from, station_from, ind_to, station_to, depot, cargo, false);
				this._routes.push(line);
				AdmiralAI.TransportCargo(cargo, ind_from);
				this._UsePickupStation(ind_from, station_from);
				AIRoad.SetCurrentRoadType(last_road_type);
				return true;
			}
		}
	}
	AIRoad.SetCurrentRoadType(last_road_type);
	this._max_distance_new_route = min(200, _max_distance_new_route + 25);
	return false;
}

function TruckLineManager::NewLineExistingRoad()
{
	if (AIDate.GetCurrentDate() - this._last_search_finished < 10) return false;
	local last_road_type = AIRoad.GetCurrentRoadType();
	AIRoad.SetCurrentRoadType(AIRoad.ROADTYPE_ROAD);
	local ret = this._NewLineExistingRoadGenerator(40);
	AIRoad.SetCurrentRoadType(last_road_type);
	return ret;
}

function TruckLineManager::_GetStationNearTown(town, dir_tile, cargo)
{
	AILog.Info("Goods station near " + AITown.GetName(town));
	local tile_list = AITileList();
	Utils_Tile.AddSquare(tile_list, AITown.GetLocation(town), 10);
	tile_list.Valuate(AITile.GetCargoAcceptance, cargo, 1, 1, AIStation.GetCoverageRadius(AIStation.STATION_TRUCK_STOP));
	tile_list.KeepAboveValue(12); /* Tiles with an acceptance lower than 8 don't accept the cargo. */

	local diagoffsets = [AIMap.GetTileIndex(0, 1), AIMap.GetTileIndex(0, -1),
	                 AIMap.GetTileIndex(1, 0), AIMap.GetTileIndex(-1, 0),
	                 AIMap.GetTileIndex(-1, -1), AIMap.GetTileIndex(-1, 1),
	                 AIMap.GetTileIndex(1, -1), AIMap.GetTileIndex(1, 1)];

	tile_list.Valuate(AITile.GetOwner);
	tile_list.RemoveBetweenValue(AICompany.COMPANY_FIRST - 1, AICompany.COMPANY_LAST + 1);
	tile_list.Valuate(AITile.GetMaxHeight);
	tile_list.KeepAboveValue(0);
	tile_list.Valuate(AIBase.RandItem);
	tile_list.Sort(AIAbstractList.SORT_BY_VALUE, AIAbstractList.SORT_ASCENDING);
	foreach (tile, dummy in tile_list) {
		local can_build = true;
		foreach (offset in diagoffsets) {
			if (AITile.IsStationTile(tile + offset)) can_build = false;
		}
		if (!can_build) continue;
		foreach (offset in this._GetSortedOffsets(tile, dir_tile)) {
			{
				/* Test if we can build a station and the road to it. */
				local test = AITestMode();
				if (!AIRoad.BuildRoadStation(tile, tile + offset, AIRoad.ROADVEHTYPE_TRUCK, AIStation.STATION_NEW)) {
					{
						local exec = AIExecMode();
						if (AITile.GetMaxHeight(tile) == 1 || !AITile.LowerTile(tile, AITile.GetSlope(tile))) continue;
					}
					if (!AIRoad.BuildRoadStation(tile, tile + offset, AIRoad.ROADVEHTYPE_TRUCK, AIStation.STATION_NEW)) continue;
				}
				if (!AIRoad.BuildRoad(tile, tile + offset)) continue;
			}
			if (AITile.GetMaxHeight(tile + offset) > AITile.GetMaxHeight(tile)) {
				if (!AITile.LowerTile(tile + offset, AITile.GetSlope(tile + offset))) continue;
			} else if (AITile.GetMaxHeight(tile + offset) < AITile.GetMaxHeight(tile) || AITile.GetSlope(tile + offset) != AITile.SLOPE_FLAT) {
				if (!AITile.RaiseTile(tile + offset, AITile.GetComplementSlope(AITile.GetSlope(tile + offset)))) continue;
			}
			/* Build both the road and the station. If building fails, try another location.*/
			if (!AIRoad.BuildRoad(tile, tile + offset)) continue;
			if (!AIRoad.BuildRoadStation(tile, tile + offset, AIRoad.ROADVEHTYPE_TRUCK, AIStation.STATION_NEW)) continue;
			local station_id = AIStation.GetStationID(tile);
			local manager = StationManager(station_id);
			manager.SetCargoDrop(true);
			return manager;
		}
	}
	/* @TODO: if building a stations failed, try if we can clear some tiles for the station. */
	return null;
}

function TruckLineManager::_UsePickupStation(ind, station_manager)
{
	foreach (station_pair in this._ind_to_pickup_stations.rawget(ind)) {
		if (station_pair[0] == station_manager) station_pair[1] = true;
	}
}

function TruckLineManager::_GetStationNearIndustry(ind, dir_tile, producing, cargo)
{
	AILog.Info(AIIndustry.GetName(ind) + " " + producing + " " + cargo);
	if (producing && this._ind_to_pickup_stations.rawin(ind)) {
		foreach (station_pair in this._ind_to_pickup_stations.rawget(ind)) {
			if (!station_pair[1]) return station_pair[0];
		}
	}
	if (!producing && this._ind_to_drop_station.rawin(ind)) return this._ind_to_drop_station.rawget(ind);

	local diagoffsets = [AIMap.GetTileIndex(0, 1), AIMap.GetTileIndex(0, -1),
	                 AIMap.GetTileIndex(1, 0), AIMap.GetTileIndex(-1, 0),
	                 AIMap.GetTileIndex(-1, -1), AIMap.GetTileIndex(-1, 1),
	                 AIMap.GetTileIndex(1, -1), AIMap.GetTileIndex(1, 1), AIMap.GetTileIndex(0, 2), AIMap.GetTileIndex(2, 0),
	                  AIMap.GetTileIndex(0, -2), AIMap.GetTileIndex(-2, 0)];
	/* No station yet for this industry, so build a new one. */
	local tile_list;
	if (producing) tile_list = AITileList_IndustryProducing(ind, AIStation.GetCoverageRadius(AIStation.STATION_TRUCK_STOP));
	else tile_list = AITileList_IndustryAccepting(ind, AIStation.GetCoverageRadius(AIStation.STATION_TRUCK_STOP));

	/* We don't want to delete our own tiles (as it could be stations or necesary roads)
	 * and we can't delete tiles belonging to the competitors. */
	tile_list.Valuate(AITile.GetOwner);
	tile_list.RemoveBetweenValue(AICompany.COMPANY_FIRST - 1, AICompany.COMPANY_LAST + 1);
	tile_list.Valuate(AITile.GetMaxHeight);
	tile_list.KeepAboveValue(0);
	if (!producing) {
		tile_list.Valuate(AITile.GetCargoAcceptance, cargo, 1, 1, AIStation.GetCoverageRadius(AIStation.STATION_TRUCK_STOP));
		tile_list.KeepAboveValue(7);
	}
	tile_list.Valuate(AIBase.RandItem);
	tile_list.Sort(AIAbstractList.SORT_BY_VALUE, producing ? AIAbstractList.SORT_ASCENDING : AIAbstractList.SORT_DESCENDING);
	foreach (tile, dummy in tile_list) {
		local can_build = true;
		foreach (offset in diagoffsets) {
			if (AITile.IsStationTile(tile + offset)) can_build = false;
		}
		if (!can_build) continue;
		foreach (offset in this._GetSortedOffsets(tile, dir_tile)) {
			/* This is mainly so we don't build a station with the entrance on rails. */
			if (!AITile.IsBuildable(tile + offset) && !AIRoad.IsRoadTile(tile + offset)) continue;
			{
				/* Test if we can build a station and the road to it. */
				local test = AITestMode();
				if (!AIRoad.BuildRoadStation(tile, tile + offset, AIRoad.ROADVEHTYPE_TRUCK, AIStation.STATION_NEW)) {
					{
						local exec = AIExecMode();
						if (AITile.GetMaxHeight(tile) == 1 || !AITile.LowerTile(tile, AITile.GetSlope(tile))) continue;
					}
					if (!AIRoad.BuildRoadStation(tile, tile + offset, AIRoad.ROADVEHTYPE_TRUCK, AIStation.STATION_NEW)) continue;
				}
				if (!AIRoad.BuildRoad(tile, tile + offset)) continue;
			}
			if (AITile.GetMaxHeight(tile + offset) > AITile.GetMaxHeight(tile)) {
				if (!AITile.LowerTile(tile + offset, AITile.GetSlope(tile + offset))) continue;
			} else if (AITile.GetMaxHeight(tile + offset) < AITile.GetMaxHeight(tile) || AITile.GetSlope(tile + offset) != AITile.SLOPE_FLAT) {
				if (!AITile.RaiseTile(tile + offset, AITile.GetComplementSlope(AITile.GetSlope(tile + offset)))) continue;
				/* TODO: this is not always enough, ie if tile+offset is lower and non-flat. */
			}
			if (AITile.GetSlope(tile) != AITile.SLOPE_FLAT) AITile.RaiseTile(tile, AITile.GetComplementSlope(AITile.GetSlope(tile)));
			/* Build both the road and the station. If building fails, try another location.*/
			if (!AIRoad.BuildRoad(tile, tile + offset)) continue;
			if (!AIRoad.BuildRoadStation(tile, tile + offset, AIRoad.ROADVEHTYPE_TRUCK, AIStation.STATION_NEW)) continue;
			local station_id = AIStation.GetStationID(tile);
			local manager = StationManager(station_id);
			manager.SetCargoDrop(!producing);
			if (producing) {
				if (!this._ind_to_pickup_stations.rawin(ind)) {
					this._ind_to_pickup_stations.rawset(ind, [[manager, false]]);
				} else {
					this._ind_to_pickup_stations.rawget(ind).push([manager, false]);
				}
			}
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
	local cargo_list = ::main_instance.GetSortedCargoList();

	local current_routes = -1;
	local cargo_skipped = 0; // The amount of cargos we already searched in a previous search.
	local ind_from_skipped = 0, ind_to_skipped = 0;
	local do_skip = true;
	foreach (cargo, dummy in cargo_list) {
		if (cargo_skipped < this._skip_cargo && do_skip) {
			cargo_skipped++;
			continue;
		}
		if (!AICargo.IsFreight(cargo)) continue;
		if (!this._unbuild_routes.rawin(cargo)) continue;
		local engine_list = AIEngineList(AIVehicle.VT_ROAD);
		engine_list.Valuate(AIEngine.GetRoadType);
		engine_list.KeepValue(AIRoad.ROADTYPE_ROAD);
		engine_list.Valuate(AIEngine.IsArticulated);
		engine_list.KeepValue(0);
		engine_list.Valuate(AIEngine.CanRefitCargo, cargo);
		engine_list.KeepValue(1);
		if (engine_list.Count() == 0) continue;

		local val_list = AIList();
		foreach (ind_from, dummy in this._unbuild_routes.rawget(cargo)) {
			if (AIIndustry.IsBuiltOnWater(ind_from)) continue;
			if (AIIndustry.GetLastMonthProduction(ind_from, cargo) - (AIIndustry.GetLastMonthTransported(ind_from, cargo) >> 1) < 40) {
				if (!AIIndustryType.IsRawIndustry(AIIndustry.GetIndustryType(ind_from))) continue;
			}
			local last_production = AIIndustry.GetLastMonthProduction(ind_from, cargo);
			local last_transportation = AIIndustry.GetLastMonthTransported(ind_from, cargo);
			if (last_production == 0) continue;
			/* Don't try to transport goods from industries that are serviced very well. */
			if (AdmiralAI.GetMaxCargoPercentTransported(AITile.GetClosestTown(AIIndustry.GetLocation(ind_from))) < 100 * last_transportation / last_production) continue;
			/* Serviced industries with very low production are not interesting. */
			if (last_production < 100 && last_transportation > 0) continue;
			local free_production = last_production - last_transportation;
			val_list.AddItem(ind_from, free_production + AIBase.RandRange(free_production));
		}
		val_list.Sort(AIAbstractList.SORT_BY_VALUE, AIAbstractList.SORT_DESCENDING);

		foreach (ind_from, dummy in val_list) {
			if (ind_from_skipped < this._skip_ind_from && do_skip) {
				ind_from_skipped++;
				continue;
			}
			local ind_acc_list = AIIndustryList_CargoAccepting(cargo);
			ind_acc_list.Valuate(AIIndustry.GetDistanceManhattanToTile, AIIndustry.GetLocation(ind_from));
			ind_acc_list.KeepBetweenValue(this._min_distance, this._max_distance_existing_route);
			ind_acc_list.Sort(AIAbstractList.SORT_BY_VALUE, AIAbstractList.SORT_ASCENDING);
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
				local ret1 = RouteBuilder.BuildRoadRouteFromStation(station_from.GetStationID(), AIStation.STATION_TRUCK_STOP, [route[0]]);
				local depot = this._BuildDepot(station_from);
				if (depot == null) break;
				local station_to = this._GetStationNearIndustry(ind_to, route[1], false, cargo);
				if (station_to == null) continue;
				/** @todo We have 80 here random speed, maybe create an engine list and take the real value. */
				if (station_to.CanAddTrucks(5, AIIndustry.GetDistanceManhattanToTile(ind_from, AIIndustry.GetLocation(ind_to)), 80) < 5) continue;
				local ret2 = RouteBuilder.BuildRoadRouteFromStation(station_to.GetStationID(), AIStation.STATION_TRUCK_STOP, [route[1]]);
				if (ret1 == 0 && ret2 == 0) {
					AILog.Info("Route ok");
					local line = TruckLine(ind_from, station_from, ind_to, station_to, depot, cargo, false);
					this._routes.push(line);
					AdmiralAI.TransportCargo(cargo, ind_from);
					this._UsePickupStation(ind_from, station_from);
					this._skip_ind_to--;
					return true;
				}
			}
			this._skip_ind_to = 0;
			do_skip = false;

			local transport_to_town = false;
			local min_town_pop;
			switch (AICargo.GetTownEffect(cargo)) {
				case AICargo.TE_GOODS:
					transport_to_town = true;
					min_town_pop = 1000;
					break;

				case AICargo.TE_FOOD:
					transport_to_town = true;
					min_town_pop = 200;
					break;
			}

			if (transport_to_town) {
				local town_list = AITownList();
				town_list.Valuate(AITown.GetPopulation);
				town_list.KeepAboveValue(min_town_pop);
				town_list.Valuate(AITown.GetDistanceManhattanToTile, AIIndustry.GetLocation(ind_from));
				town_list.KeepBetweenValue(50, 400);
				town_list.Sort(AIAbstractList.SORT_BY_VALUE, AIAbstractList.SORT_DESCENDING);
				foreach (town, distance in town_list) {
					local route = RouteFinder.FindRouteBetweenRects(AIIndustry.GetLocation(ind_from), AITown.GetLocation(town), 8);
					if (route == null) continue;
					AILog.Info("Found goods route between: " + AIIndustry.GetName(ind_from) + " and " + AITown.GetName(town));
					local station_from = this._GetStationNearIndustry(ind_from, route[0], true, cargo);
					if (station_from == null) break;
					local ret1 = RouteBuilder.BuildRoadRouteFromStation(station_from.GetStationID(), AIStation.STATION_TRUCK_STOP, [route[0]]);
					local depot = this._BuildDepot(station_from);
					if (depot == null) break;
					local station_to = this._GetStationNearTown(town, route[1], cargo);
					if (station_to == null) continue;
					/** @todo We have 80 here random speed, maybe create an engine list and take the real value. */
					if (station_to.CanAddTrucks(5, AIIndustry.GetDistanceManhattanToTile(ind_from, AITown.GetLocation(town)), 80) < 5) continue;
					local ret2 = RouteBuilder.BuildRoadRouteFromStation(station_to.GetStationID(), AIStation.STATION_TRUCK_STOP, [route[1]]);
					if (ret1 == 0 && ret2 == 0) {
						AILog.Info("Route ok");
						local line = TruckLine(ind_from, station_from, null, station_to, depot, cargo, false);
						this._routes.push(line);
						AdmiralAI.TransportCargo(cargo, ind_from);
						this._UsePickupStation(ind_from, station_from);
						return true;
					}
				}
			}
			this._skip_ind_from++;
		}
		this._skip_ind_from = 0;
		this._skip_cargo++;
		do_skip = false;
	}
	AILog.Info("Full industry search done!");
	this._max_distance_existing_route = min(200, this._max_distance_existing_route + 25);
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
			if (tile_x < goal_x) {
				return [AIMap.GetMapSizeX(), 1, -1, -AIMap.GetMapSizeX()];
			} else {
				return [AIMap.GetMapSizeX(), -1, 1, -AIMap.GetMapSizeX()];
			}
		} else {
			if (tile_x < goal_x) {
				return [-AIMap.GetMapSizeX(), 1, -1, AIMap.GetMapSizeX()];
			} else {
				return [-AIMap.GetMapSizeX(), -1, 1, AIMap.GetMapSizeX()];
			}
		}
	} else {
		if (tile_x < goal_x) {
			if (tile_y < goal_y) {
				return [1, AIMap.GetMapSizeX(), -AIMap.GetMapSizeX(), -1];
			} else {
				return [1, AIMap.GetMapSizeX(), -AIMap.GetMapSizeX(), -1];
			}
		} else {
			if (tile_y < goal_y) {
				return [-1, -AIMap.GetMapSizeX(), AIMap.GetMapSizeX(), 1];
			} else {
				return [-1, -AIMap.GetMapSizeX(), AIMap.GetMapSizeX(), 1];
			}
		}
	}
}
