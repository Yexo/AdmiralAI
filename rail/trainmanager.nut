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
 * Copyright 2008 Thijs Marinussen
 */

/** @file trainmanager.nut Implemenation of TrainManager. */

/**
 * Class that manages all train routes.
 */
class TrainManager
{
	_unbuild_routes = null;              ///< A table with as index CargoID and as value an array of industries we haven't connected.
	_ind_to_pickup_stations = null;      ///< A table mapping IndustryIDs to StationManagers. If an IndustryID is not in this list, we haven't build a pickup station there yet.
	_ind_to_drop_stations = null;        ///< A table mapping IndustryIDs to StationManagers.
	_routes = null;                      ///< An array containing all TruckLines build.
	_platform_length = null;
	_max_distance_new_route = null;      ///< The maximum length of a new train route.

/* public: */

	/**
	 * Create a new instance.
	 */
	constructor()
	{
		this._unbuild_routes = {};
		this._ind_to_pickup_stations = {};
		this._ind_to_drop_stations = {};
		this._routes = [];
		this._platform_length = 4;
		this._max_distance_new_route = 100;
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
	 * Build a new cargo route,.
	 * @return True if and only if a new route was created.
	 */
	function BuildNewRoute();

/* private: */

	/**
	 * Get a station near an industry. First check if we already have one,
	 *  if so, return it. If there is no station near the industry, try to
	 *  build one.
	 * @param ind The industry to build a station near.
	 * @param producing Boolean indicating whether or not we want to transport
	 *  the cargo to or from the industry.
	 * @param cargo The CargoID we are going to transport.
	 * @return A StationManager if a station was found / could be build or null.
	 */
	function _GetStationNearIndustry(ind, producing, cargo);

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

function TrainManager::Save()
{
	local data = {pickup_stations = {}, drop_stations = {}, routes = []};

	foreach (ind, managers in this._ind_to_pickup_stations) {
		local station_ids = [];
		foreach (manager in managers) {
			station_ids.push([manager[0].GetStationID(), manager[1]]);
		}
		data.pickup_stations.rawset(ind, station_ids);
	}

	foreach (ind, managers in this._ind_to_drop_stations) {
		local station_ids = [];
		foreach (manager in managers) {
			station_ids.push([manager[0].GetStationID(), manager[1]]);
		}
		data.drop_stations.rawset(ind, station_ids);
	}

	foreach (route in this._routes) {
		if (!route._valid) continue;
		data.routes.push([route._ind_from, route._station_from.GetStationID(), route._ind_to, route._station_to.GetStationID(), route._depot_tiles, route._cargo, route._platform_length, route._rail_type]);
	}

	data.rawset("max_distance_new_route", this._max_distance_new_route);

	return data;
}

function TrainManager::Load(data)
{
	if (data.rawin("pickup_stations")) {
		foreach (ind, manager_array in data.rawget("pickup_stations")) {
			local new_man_array = [];
			foreach (man_info in manager_array) {
				local man = StationManager(man_info[0]);
				man.SetCargoDrop(false);
				man.AfterLoadSetRailType(null);
				new_man_array.push([man, man_info[1]]);
			}
			this._ind_to_pickup_stations.rawset(ind, new_man_array);
		}
	}

	if (data.rawin("drop_stations")) {
		foreach (ind, manager_array in data.rawget("drop_stations")) {
			local new_man_array = [];
			foreach (man_info in manager_array) {
				local man = StationManager(man_info[0]);
				man.SetCargoDrop(true);
				man.AfterLoadSetRailType(null);
				new_man_array.push([man, man_info[1]]);
			}
			this._ind_to_drop_stations.rawset(ind, new_man_array);
		}
	}

	if (data.rawin("routes")) {
		foreach (route_array in data.rawget("routes")) {
			local station_from = null;
			foreach (man_array in this._ind_to_pickup_stations.rawget(route_array[0])) {
				if (man_array[0].GetStationID() == route_array[1]) {
					station_from = man_array[0];
					man_array[1] = true;
					break;
				}
			}
			/* TODO: rewrite save/load code (or all station_manager code, so bind StationID's to
			 * managers, for example with a map in ::main_instance. */
			local station_to = null;
			foreach (man_array in this._ind_to_drop_stations.rawget(route_array[2])) {
				if (man_array[0].GetStationID() == route_array[3]) {
					station_to = man_array[0];
					man_array[1] = true;
					break;
				}
			}
			if (station_from == null || station_to == null) continue;
			local route = TrainLine(route_array[0], station_from, route_array[2], station_to, route_array[4], route_array[5], true, route_array[6], route_array[7]);
			station_from.AfterLoadSetRailType(route_array[7]);
			station_to.AfterLoadSetRailType(route_array[7]);
			AILog.Info("Loaded route between " + AIStation.GetName(station_from.GetStationID()) + " and " + AIStation.GetName(station_to.GetStationID()));
			this._routes.push(route);
			if (this._unbuild_routes.rawin(route_array[5])) {
				foreach (ind, dummy in this._unbuild_routes[route_array[5]]) {
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

	if (data.rawin("max_distance_new_route")) {
		this._max_distance_new_route = data.rawget("max_distance_new_route");
	}
}

function TrainManager::AfterLoad()
{
	foreach (route in this._routes) {
		route._group_id = AIGroup.CreateGroup(AIVehicle.VEHICLE_RAIL);
		route._RenameGroup();
	}
}

function TrainManager::ClosedStation(station)
{
	local ind_station_mapping = this._ind_to_pickup_stations
	if (station.IsCargoDrop()) local ind_station_mapping = this._ind_to_drop_stations;

	foreach (ind, list in ind_station_mapping) {
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
}

function TrainManager::CheckRoutes()
{
	foreach (route in this._routes) {
		if (route.CheckVehicles()) return true;
	}
	return false;
}

function TrainManager::IndustryClose(industry_id)
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
			AILog.Warning("Closed train route");
		}
	}
	foreach (cargo, table in this._unbuild_routes) {
		this._unbuild_routes[cargo].rawdelete(industry_id);
	}
}

function TrainManager::IndustryOpen(industry_id)
{
	AILog.Info("New industry: " + AIIndustry.GetName(industry_id));
	foreach (cargo, dummy in AICargoList_IndustryProducing(industry_id)) {
		if (!this._unbuild_routes.rawin(cargo)) this._unbuild_routes.rawset(cargo, {});
		this._unbuild_routes[cargo].rawset(industry_id, 1);
	}
}

function TrainManager::RailTypeValuator(rail_type, cargo_id)
{
	local list = AIEngineList(AIVehicle.VEHICLE_RAIL);
	list.Valuate(AIEngine.HasPowerOnRail, rail_type);
	list.KeepValue(1);
	list.Valuate(AIEngine.IsWagon);
	list.KeepValue(0);
	list.Valuate(AIEngine.CanPullCargo, cargo_id);
	list.KeepValue(1);
	list.Valuate(AIEngine.GetMaxSpeed);
	list.Sort(AIAbstractList.SORT_BY_VALUE, false);
	if (list.Count() == 0) return -1;

	local list2 = AIEngineList(AIVehicle.VEHICLE_RAIL);
	list2.Valuate(AIEngine.CanRunOnRail, rail_type);
	list2.KeepValue(1);
	list2.Valuate(AIEngine.IsWagon);
	list2.KeepValue(1);
	list2.Valuate(AIEngine.CanRefitCargo, cargo_id);
	list2.KeepValue(1);
	list2.Valuate(AIEngine.GetCapacity);
	list2.Sort(AIAbstractList.SORT_BY_VALUE, false);
	if (list2.Count() == 0) return -1;

	return AIEngine.GetMaxSpeed(list.Begin()) * AIEngine.GetCapacity(list2.Begin());
}

function TrainManager::BuildNewRoute()
{
	local rail_type_list = AIRailTypeList();
	if (rail_type_list.Count() == 0) return false;

	local cargo_list = ::main_instance.GetSortedCargoList();

	foreach (cargo, dummy in cargo_list) {
		if (!AICargo.IsFreight(cargo)) continue;
		if (!this._unbuild_routes.rawin(cargo)) continue;

		rail_type_list.Valuate(TrainManager.RailTypeValuator, cargo);
		rail_type_list.RemoveValue(-1);
		rail_type_list.Sort(AIAbstractList.SORT_BY_VALUE, false);
		/* If there is no railtype with a possible train, try another cargo type. */
		if (rail_type_list.Count() == 0) continue;
		AIRail.SetCurrentRailType(rail_type_list.Begin());

		local val_list = AIList();
		foreach (ind_from, dummy in this._unbuild_routes.rawget(cargo)) {
			if (AIIndustry.IsBuiltOnWater(ind_from)) continue;
			if (AIIndustry.GetLastMonthProduction(ind_from, cargo) - (AIIndustry.GetLastMonthTransported(ind_from, cargo) >> 1) < 40) {
				if (!AIIndustryType.IsRawIndustry(AIIndustry.GetIndustryType(ind_from))) continue;
			}
			local last_production = AIIndustry.GetLastMonthProduction(ind_from, cargo);
			if (last_production > 80 && AIIndustry.GetLastMonthTransported(ind_from, cargo) * 100 / last_production > 65) continue;
			local prod = AIIndustry.GetLastMonthProduction(ind_from, cargo) - AIIndustry.GetLastMonthTransported(ind_from, cargo);
			val_list.AddItem(ind_from, prod + AIBase.RandRange(prod));
		}
		val_list.Sort(AIAbstractList.SORT_BY_VALUE, false);

		foreach (ind_from, dummy in val_list) {
			Utils_General.GetMoney(200000);
			if (AICompany.GetBankBalance(AICompany.MY_COMPANY) < 180000) return false;
			local ind_acc_list = AIIndustryList_CargoAccepting(cargo);
			ind_acc_list.Valuate(AIIndustry.GetDistanceManhattanToTile, AIIndustry.GetLocation(ind_from));
			ind_acc_list.KeepBetweenValue(50, min(this._max_distance_new_route, (AICompany.GetBankBalance(AICompany.MY_COMPANY) - 60000) / 700));
			ind_acc_list.Sort(AIAbstractList.SORT_BY_VALUE, true);
			foreach (ind_to, dummy in ind_acc_list) {
				local station_from = this._GetStationNearIndustry(ind_from, true, cargo, ind_to);
				if (station_from == null) break;
				local station_to = this._GetStationNearIndustry(ind_to, false, cargo, ind_from);
				if (station_to == null) continue;
				local ret = RailRouteBuilder.ConnectRailStations(station_from.GetStationID(), station_to.GetStationID());
				if (typeof(ret) == "array") {
					AILog.Info("Rail route build succesfully");
					local line = TrainLine(ind_from, station_from, ind_to, station_to, ret, cargo, false, this._platform_length, AIRail.GetCurrentRailType());
					this._routes.push(line);
					AdmiralAI.TransportCargo(cargo, ind_from);
					this._UsePickupStation(ind_from, station_from);
					this._UseDropStation(ind_to, station_to);
					return true;
				} else if (ret == -1) {
					/* remove source station. */
					this._DeletePickupStation(ind_from, station_from);
				} else if (ret == -2) {
					/* Remove destination station. */
					this._DeleteDropStation(ind_to, station_to);
				} else {
					AILog.Warning("Error while building rail route: " + ret);
				}
			}
		}
	}
	this._max_distance_new_route = min(200, this._max_distance_new_route + 20);
	return false;
}

function TrainManager::TransportCargo(cargo, ind)
{
	this._unbuild_routes[cargo].rawdelete(ind);
}

function TrainManager::_UsePickupStation(ind, station_manager)
{
	foreach (station_pair in this._ind_to_pickup_stations.rawget(ind)) {
		if (station_pair[0] == station_manager) station_pair[1] = true;
	}
}

function TrainManager::_UseDropStation(ind, station_manager)
{
	foreach (station_pair in this._ind_to_drop_stations.rawget(ind)) {
		if (station_pair[0] == station_manager) station_pair[1] = true;
	}
}

function TrainManager::_DeletePickupStation(ind, station_manager)
{
	local idx = null;
	foreach (i, station_pair in this._ind_to_pickup_stations.rawget(ind)) {
		if (station_pair[0] == station_manager) idx = i;
	}
	assert(idx != null);
	this._ind_to_pickup_stations.rawget(ind).remove(idx);
	::main_instance.sell_stations.append([station_manager.GetStationID(), AIStation.STATION_TRAIN]);
}

function TrainManager::_DeleteDropStation(ind, station_manager)
{
	local idx = null;
	foreach (i, station_pair in this._ind_to_drop_stations.rawget(ind)) {
		if (station_pair[0] == station_manager) idx = i;
	}
	assert(idx != null);
	this._ind_to_drop_stations.rawget(ind).remove(idx);
	::main_instance.sell_stations.append([station_manager.GetStationID(), AIStation.STATION_TRAIN]);
}

function TrainManager::MoveStationTileList(tile, new_list, offset, width, height)
{
	new_list.AddRectangle(tile + offset, tile + offset + AIMap.GetTileIndex(width - 1, height - 1));
	return 0;
}

function TrainManager::HasBuildingRoom1(tile, platform_length)
{
	return AITile.IsBuildableRectangle(tile + AIMap.GetTileIndex(-1, -2), 4, 2) ||
		AITile.IsBuildableRectangle(tile + AIMap.GetTileIndex(-1, platform_length + 2), 4, 2);
}

function TrainManager::HasBuildingRoom2(tile, platform_length)
{
	return AITile.IsBuildableRectangle(tile + AIMap.GetTileIndex(-2, -1), 2, 4) ||
		AITile.IsBuildableRectangle(tile + AIMap.GetTileIndex(platform_length + 2, -1), 2, 4);
}

function TrainManager::CheckCargoAcceptance1(tile, cargo)
{
	return AITile.GetCargoAcceptance(tile + AIMap.GetTileIndex(0, 2), cargo, 2, 5, AIStation.GetCoverageRadius(AIStation.STATION_TRAIN));
}

function TrainManager::CheckCargoAcceptance2(tile, cargo)
{
	return AITile.GetCargoAcceptance(tile + AIMap.GetTileIndex(2, 0), cargo, 5, 2, AIStation.GetCoverageRadius(AIStation.STATION_TRAIN));
}

function TrainManager::TileValuator1(item, tile, max_rand, platform_length)
{
	local val = AIMap.DistanceManhattan(item, tile) + AIBase.RandRange(max_rand);
	if (tile < item && AITile.IsBuildableRectangle(item + AIMap.GetTileIndex(-1, -2), 4, 2)) val -= 20;
	if (tile > item && AITile.IsBuildableRectangle(item + AIMap.GetTileIndex(-1, platform_length + 2), 4, 2)) val -= 20;
	return val;
}

function TrainManager::TileValuator2(item, tile, max_rand, platform_length)
{
	local val = AIMap.DistanceManhattan(item, tile) + AIBase.RandRange(max_rand);
	if (AIMap.GetTileX(tile) < AIMap.GetTileX(item) && AITile.IsBuildableRectangle(item + AIMap.GetTileIndex(-2, -1), 2, 4)) val -= 20;
	if (AIMap.GetTileX(tile) > AIMap.GetTileX(item) && AITile.IsBuildableRectangle(item + AIMap.GetTileIndex(platform_length + 2, -1), 2, 4)) val -= 20;
	return val;
}

function TrainManager::_GetStationNearIndustry(ind, producing, cargo, other_ind)
{
	AILog.Info(AIIndustry.GetName(ind) + " " + producing + " " + cargo);
	if (producing && this._ind_to_pickup_stations.rawin(ind)) {
		foreach (station_pair in this._ind_to_pickup_stations.rawget(ind)) {
			if (!station_pair[1]) {
				local man = station_pair[0];
				if (man._rail_type != AIRail.GetCurrentRailType() && !man.ConvertRailType(AIRail.GetCurrentRailType())) continue;
				return man;
			}
		}
	}
	if (!producing && this._ind_to_drop_stations.rawin(ind)) {
		foreach (station_pair in this._ind_to_drop_stations.rawget(ind)) {
			local man = station_pair[0];
			if (man._rail_type != AIRail.GetCurrentRailType() &&
				(!AIRail.TrainHasPowerOnRail(man._rail_type, AIRail.GetCurrentRailType()) || !man.ConvertRailType(AIRail.GetCurrentRailType()))) continue;
			return man;
		}
	}
	local ind_types = [];
	local distance = AIMap.DistanceManhattan(AIIndustry.GetLocation(ind), AIIndustry.GetLocation(other_ind));
	if (producing) {
		ind_types.append(AIIndustry.GetIndustryType(ind));
		ind_types.append(AIIndustry.GetIndustryType(other_ind));
	} else {
		ind_types.append(AIIndustry.GetIndustryType(other_ind));
		ind_types.append(AIIndustry.GetIndustryType(ind));
	}

	local platform_length = this._platform_length;

	/* No useable station yet for this industry, so build a new one. */
	local tile_list;
	if (producing) tile_list = AITileList_IndustryProducing(ind, AIStation.GetCoverageRadius(AIStation.STATION_TRAIN));
	else tile_list = AITileList_IndustryAccepting(ind, AIStation.GetCoverageRadius(AIStation.STATION_TRAIN));
	tile_list.Valuate(Utils_Tile.GetRealHeight);
	tile_list.KeepAboveValue(0);

	local tile_list2 = AITileList();
	tile_list2.AddList(tile_list);

	local new_tile_list = AITileList();
	tile_list.Valuate(this.MoveStationTileList, new_tile_list, AIMap.GetTileIndex(-1, -platform_length + 1), 2, platform_length - 2);
	tile_list = new_tile_list;
	tile_list.Valuate(this.HasBuildingRoom1, platform_length);
	tile_list.KeepValue(1);
	if (!producing) {
		tile_list.Valuate(this.CheckCargoAcceptance1, cargo);
		tile_list.KeepAboveValue(7);
	}

	new_tile_list = AITileList();
	tile_list2.Valuate(this.MoveStationTileList, new_tile_list, AIMap.GetTileIndex(-platform_length + 1, -1), platform_length - 2, 2);
	tile_list2 = new_tile_list;
	tile_list2.Valuate(this.HasBuildingRoom2, platform_length);
	tile_list2.KeepValue(1);
	if (!producing) {
		tile_list2.Valuate(this.CheckCargoAcceptance2, cargo);
		tile_list2.KeepAboveValue(7);
	}

	{
		local test = AITestMode();
		tile_list.Valuate(Utils_Tile.CanBuildStation, 2, platform_length + 2);
		tile_list.KeepAboveValue(0);
		tile_list.Valuate(Utils_Tile.CanBuildStation, platform_length + 2, 2);
		tile_list2.KeepAboveValue(0);
	}

	tile_list.Valuate(this.TileValuator1, AIIndustry.GetLocation(other_ind), 4, platform_length);
	tile_list.Sort(AIAbstractList.SORT_BY_VALUE, true);
	tile_list2.Valuate(this.TileValuator2, AIIndustry.GetLocation(other_ind), 4, platform_length);
	tile_list2.Sort(AIAbstractList.SORT_BY_VALUE, true);

	if (tile_list.Count() == 0 && tile_list2.Count() == 0) AILog.Warning("No tiles");
	local lists = [];
	local loc1 = AIIndustry.GetLocation(ind);
	local loc2 = AIIndustry.GetLocation(other_ind);
	if (abs(AIMap.GetTileX(loc1) - AIMap.GetTileX(loc2)) > abs(AIMap.GetTileY(loc1) - AIMap.GetTileY(loc2))) {
		lists.append([tile_list2, AIRail.RAILTRACK_NE_SW, this.HasBuildingRoom2]);
		lists.append([tile_list, AIRail.RAILTRACK_NW_SE, this.HasBuildingRoom1]);
	} else {
		lists.append([tile_list, AIRail.RAILTRACK_NW_SE, this.HasBuildingRoom1]);
		lists.append([tile_list2, AIRail.RAILTRACK_NE_SW, this.HasBuildingRoom2]);
	}
	foreach (list_dir in lists) {
		local tile_list = list_dir[0];
		local trackdir = list_dir[1];
		local func = list_dir[2];
		foreach (tile, dummy in tile_list) {
			if (!func(tile, platform_length)) {
				AILog.Error("Error");
				if (::main_instance.GetSetting("debug_signs")) AISign.BuildSign(tile, "E");
			}
			if (trackdir == AIRail.RAILTRACK_NW_SE) {
				local h = Utils_Tile.CanBuildStation(tile, 2, platform_length + 2);
				if (h == -1) continue;
				if (!Utils_Tile.FlattenLandForStation(tile, 2, platform_length + 2, h, false, true)) continue;
			} else {
				local h = Utils_Tile.CanBuildStation(tile, platform_length + 2, 2);
				if (h == -1) continue;
				if (!Utils_Tile.FlattenLandForStation(tile, platform_length + 2, 2, h, true, false)) continue;
			}
			/* If the town rating is too low and we can't fix it, return. */
			if (!::main_instance._town_managers[AITile.GetClosestTown(tile)].ImproveTownRating(AITown.TOWN_RATING_POOR)) return null;
			if (AIRail.BuildNewGRFRailStation(tile, trackdir, 2, platform_length + 2, false, cargo, ind_types[0], ind_types[1], distance, producing)) {
				local manager = StationManager(AIStation.GetStationID(tile));
				manager.SetCargoDrop(!producing);
				manager._rail_type = AIRail.GetCurrentRailType();
				manager._platform_length = platform_length;
				if (producing) {
					if (!this._ind_to_pickup_stations.rawin(ind)) {
						this._ind_to_pickup_stations.rawset(ind, [[manager, false]]);
					} else {
						this._ind_to_pickup_stations.rawget(ind).push([manager, false]);
					}
				}
				else {
					if (!this._ind_to_drop_stations.rawin(ind)) {
						this._ind_to_drop_stations.rawset(ind, [[manager, false]]);
					} else {
						this._ind_to_drop_stations.rawget(ind).push([manager, false]);
					}
				}
				return manager;
			} else {
				AILog.Error("Rail station building failed near " + AIIndustry.GetName(ind));
				if (::main_instance.GetSetting("debug_signs")) AISign.BuildSign(tile, "RS Fail");
			}
		}
	}

	/* @TODO: if building a stations failed, try if we can clear / terraform some tiles for the station. */
	return null;
}

function TrainManager::_InitializeUnbuildRoutes()
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
