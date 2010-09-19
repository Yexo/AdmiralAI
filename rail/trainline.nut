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

/** @file trainline.nut Implementation of TrainLine. */

/**
 * Class that controls a train line between two industries. It can buy and
 *  sell vehicles to keep up with the demand.
 */
class TrainLine
{
	_ind_from = null;        ///< The IndustryID where we are transporting cargo from.
	_ind_to = null;          ///< The IndustryID where we are transporting cargo to.
	_valid = null;           ///< True as long as the route is ok. Set to false when the route is closed down.
	_station_from = null;    ///< The StationManager managing the first station.
	_station_to = null;      ///< The StationManager managing the second station.
	_vehicle_list = null;    ///< An AIList() containing all vehicles on this route.
	_depot_tiles = null;     ///< An array with TileIndexes indicating the depots that are used by this route (both to build new vehicles and to service existing ones).
	_cargo = null;           ///< The CargoID of the cargo we'll transport.
	_engine_id = null;       ///< The EngineID of the engine of the trains on this route.
	_wagon_engine_id = null; ///< The EngineID of the wagons of the trains on this route.
	_group_id = null;        ///< The GroupID of the group all vehicles from this route are in.
	_platform_length = null; ///< The length of the shortest platform of both stations.
	_rail_type = null;       ///< The railtype of the rails from this route.

/* public: */

	/**
	 * Create a new train line.
	 * @param ind_from The IndustryID we are transporting cargo from.
	 * @param station_from A StationManager that controls the station we are transporting cargo from.
	 * @param ind_to The IndustryID we are transporting cargo to.
	 * @param station_to A StationManager that controls the station we are transporting cargo to.
	 * @param depot_tiles An array with TileIndexes of the depot tiles.
	 * @param cargo The CargoID we are transporting.
	 * @param loaded True if the constructor is called from the Load() function.
	 * @param platform_length The length of the shortest train platform.
	 */
	constructor(ind_from, station_from, ind_to, station_to, depot_tiles, cargo, loaded, platform_length, rail_type) {
		this._ind_from = ind_from;
		this._station_from = station_from;
		this._ind_to = ind_to;
		this._station_to = station_to;
		this._depot_tiles = depot_tiles;
		this._cargo = cargo;
		this._platform_length = platform_length;
		this._valid = true;
		this._rail_type = rail_type;
		if (!loaded) {
			this._group_id = AIGroup.CreateGroup(AIVehicle.VT_RAIL);
			this._RenameGroup();
			this.BuildVehicles(1);
		}
	}

	/**
	 * Get the IndustryID of the industry this line is transporting cargo from.
	 * @return The IndustryID.
	 */
	function GetIndustryFrom();

	/**
	 * Get the StationManager of the station this line is transporting cargo from.
	 * @return The Stationmanager.
	 */
	function GetStationFrom();

	/**
	 * Get the IndustryID of the industry this line is transporting cargo to.
	 * @return The IndustryID.
	 */
	function GetIndustryTo();

	/**
	 * Get the StationManager of the station this line is transporting cargo to.
	 * @return The Stationmanager.
	 */
	function GetStationTo();

	/**
	 * Close down this route. This function tries to sell all vehicles and closes
	 *  down both stations if necesary (determined by StationManager).
	 */
	function CloseRoute();

	/**
	 * Build some new vehicles for this route. First call _FindEngineID()
	 *  so we'll build the best engine available.
	 * @param num The number of vehicles to build.
	 * @return False if and only if the building failed because we didn't
	 *  have enough money.
	 * @note BuildVehicles may return true even if the building failed.
	 */
	function BuildVehicles(num);

	/**
	 * Check if all vehicles on this route are still making a profit. If
	 *  they all do and there is surplus cargo at the source station, build
	 *  some new vehicles.
	 * @return True if and only if we need more money to complete the function.
	 */
	function CheckVehicles();

/* private: */

	/**
	 * Initiate autoreplace from one engine type to another.
	 * @param old_vehicle_id The EngineID that is being replaced.
	 * @param new_engine_id The EngineID we will replace with.
	 */
	function _AutoReplace(old_vehicle_id, new_engine_id)

	/**
	 * Update this._vehicle_list to contain all vehicles belonging to this route.
	 * Call this before using this._vehicle_list, because that list could
	 * otherwise have invalid vehicles or vehicles that are being sold.
	 */
	function _UpdateVehicleList()

	/**
	 * Assign a value to an engine.
	 * @param engine_id The EngineID to valuate.
	 * @return A value for that engine.
	 */
	function _SortEngineList(engine_id)

	/**
	 * Assign a value to a wagon.
	 * @param engine_id The EngineID of a wagon to valuate.
	 * @return A value for that wagon.
	 */
	function _SortEngineWagonList(engine_id)

	/**
	 * Update this._engine_id and this._wagon_engine_id and initiate autoreplace
	 * if necessary.
	 */
	function _FindEngineID()

	/**
	 * Give the group of this route a proper name.
	 */
	function _RenameGroup();

	/*
	 * Check wheher a better compatible railtype is available and update if so.
	 */
	function _UpdateRailType();
};

function TrainLine::GetIndustryFrom()
{
	if (!this._valid) return -1;
	return this._ind_from;
}

function TrainLine::GetIndustryTo()
{
	if (!this._valid) return -1;
	return this._ind_to;
}

function TrainLine::SellVehicle(veh_id)
{
	::main_instance.sell_vehicles.AddItem(veh_id, 0);
	local last_order = AIOrder.GetOrderCount(veh_id) - 1;
	if (AIOrder.IsGotoDepotOrder(veh_id, last_order)) {
		AIOrder.SetOrderFlags(veh_id, last_order, AIOrder.AIOF_STOP_IN_DEPOT);
	}
	if (AIOrder.IsGotoDepotOrder(veh_id, 1)) {
		AIOrder.SetOrderFlags(veh_id, 1, AIOrder.AIOF_STOP_IN_DEPOT);
	}
	AIOrder.SetOrderFlags(veh_id, 0, AIOrder.AIOF_NO_UNLOAD);
}

function TrainLine::CloseRoute()
{
	if (!this._valid) return;
	AILog.Warning("Closing down train route");
	this._UpdateVehicleList();
	foreach (v, _ in this._vehicle_list) this.SellVehicle(v);
	::main_instance.SendVehicleToSellToDepot();
	this._valid = false;
}

function TrainLine::BuildVehicles(num)
{
	AILog.Info("TrainLine.BuildVehicles(" + num + ")");
	if (!this._valid) return true;
	this._UpdateVehicleList();
	this._FindEngineID();
	if (this._engine_id == null || this._wagon_engine_id == null) {
		AILog.Warning("No vehicles id found");
		return true;
	}
	local max_veh_speed = AIEngine.GetMaxSpeed(this._engine_id);

	for (local i = 0; i < num; i++) {
		local depot = this._depot_tiles[0] == null ? this._depot_tiles[1] : this._depot_tiles[0];
		Utils_General.GetMoney(AIEngine.GetPrice(this._engine_id));
		local v = AIVehicle.BuildVehicle(depot, this._engine_id);
		if (!AIVehicle.IsValidVehicle(v)) {
			if (AIError.GetLastError() == AIError.ERR_NOT_ENOUGH_CASH) return false;
			AILog.Warning("Error building train engine: " + AIError.GetLastErrorString());
			return true;
		}
		/* We don't know how may wagons we need, so reserve a bit too much.
		 * Nothing happens yet if we don't have enough money. */
		Utils_General.GetMoney(AIEngine.GetPrice(this._wagon_engine_id) * 20);
		local last_length = AIVehicle.GetLength(v);
		while (last_length <= 16 * this._platform_length) {
			if (AICompany.GetBankBalance(AICompany.COMPANY_SELF) < AIEngine.GetPrice(this._wagon_engine_id)) {
				/* We don't have enough money, try to loan some and hope we can. */
				Utils_General.GetMoney(AIEngine.GetPrice(this._wagon_engine_id) * 5);
			}
			local wagon_id = AIVehicle.BuildVehicle(depot, this._wagon_engine_id);
			/* Check if the wagon was already added to the engine. */
			if (AIVehicle.GetLength(v) == last_length) {
				/* The wagon_id is invalid. This is not because it was
				 * automatically added to the first engine (checked
				 * above), so it must be because some eror occured. */
				if (!AIVehicle.IsValidVehicle(wagon_id)) {
					local cash_shortage = AIError.GetLastError() == AIError.ERR_NOT_ENOUGH_CASH;
					AILog.Warning("Error building train wagon: " + AIError.GetLastErrorString());
					AIVehicle.SellVehicle(v);
					return !cash_shortage;
				}
				AIVehicle.MoveWagon(wagon_id, 0, v, 0);
			}
			last_length = AIVehicle.GetLength(v);
		}
		AIVehicle.SellWagon(v, 1);
		if (!AIVehicle.RefitVehicle(v, this._cargo)) {
			local cash_shortage = AIError.GetLastError() == AIError.ERR_NOT_ENOUGH_CASH;
			AIVehicle.SellVehicle(v);
			return !cash_shortage;
		}
		if (this._vehicle_list.Count() > 0) {
			AIOrder.ShareOrders(v, this._vehicle_list.Begin());
		} else {
			AIOrder.AppendOrder(v, AIStation.GetLocation(this._station_from.GetStationID()), AIOrder.AIOF_FULL_LOAD_ANY | AIOrder.AIOF_NON_STOP_INTERMEDIATE);
			if (this._depot_tiles[1] != null) AIOrder.AppendOrder(v, this._depot_tiles[1], AIOrder.AIOF_SERVICE_IF_NEEDED);
			AIOrder.AppendOrder(v, AIStation.GetLocation(this._station_to.GetStationID()), AIOrder.AIOF_UNLOAD | AIOrder.AIOF_NO_LOAD | AIOrder.AIOF_NON_STOP_INTERMEDIATE);
			if (this._depot_tiles[0] != null) AIOrder.AppendOrder(v, this._depot_tiles[0], AIOrder.AIOF_SERVICE_IF_NEEDED);
		}
		AIGroup.MoveVehicle(this._group_id, v);
		AIVehicle.StartStopVehicle(v);
		this._vehicle_list.AddItem(v, 0);
	}
	return true;
}

function TrainLine::_RailTypeCompatible(new_type, orig_type)
{
	return AIRail.TrainCanRunOnRail(orig_type, new_type);
}

function TrainLine::ConvertRoute(station_a, station_b, return_path, new_type)
{
	local pf = RailFollower();
	local sources = [];
	local goals = [];
	local platform_length = this._platform_length;

	local tile = AIStation.GetLocation(station_a);
	if (AIRail.GetRailTracks(tile) == AIRail.RAILTRACK_NW_SE) {
		local tile2 = tile + AIMap.GetTileIndex(0, -1);
		local tile3 = tile + AIMap.GetTileIndex(0, platform_length);
		if (AIRail.IsRailTile(tile2) && AICompany.IsMine(AITile.GetOwner(tile2)) && !AIRail.IsRailStationTile(tile2) && (AIRail.GetRailTracks(tile2) & AIRail.RAILTRACK_NW_SW) != 0) {
			sources.push([tile + AIMap.GetTileIndex(return_path, -3), tile + AIMap.GetTileIndex(return_path, -2)]);
		} else if (AIRail.IsRailTile(tile3) && AICompany.IsMine(AITile.GetOwner(tile3)) && !AIRail.IsRailStationTile(tile3) && (AIRail.GetRailTracks(tile3) & AIRail.RAILTRACK_NW_SW) != 0) {
			sources.push([tile + AIMap.GetTileIndex(return_path, platform_length + 2), tile + AIMap.GetTileIndex(return_path, platform_length + 1)]);
		}
	} else {
		local tile2 = tile + AIMap.GetTileIndex(-1, 0);
		local tile3 = tile + AIMap.GetTileIndex(platform_length, 0);
		if (AIRail.IsRailTile(tile2) && AICompany.IsMine(AITile.GetOwner(tile2)) && !AIRail.IsRailStationTile(tile2) && (AIRail.GetRailTracks(tile2) & AIRail.RAILTRACK_NE_SW) != 0) {
			sources.push([tile + AIMap.GetTileIndex(-3, return_path), tile + AIMap.GetTileIndex(-2, return_path)]);
		} else if (AIRail.IsRailTile(tile3) && AICompany.IsMine(AITile.GetOwner(tile3)) && !AIRail.IsRailStationTile(tile3) && (AIRail.GetRailTracks(tile3) & AIRail.RAILTRACK_NE_SW) != 0) {
			sources.push([tile + AIMap.GetTileIndex(platform_length + 2, return_path), tile + AIMap.GetTileIndex(platform_length + 1, return_path)]);
		}
	}
	tile = AIStation.GetLocation(station_b);
	if (AIRail.GetRailTracks(tile) == AIRail.RAILTRACK_NW_SE) {
		local tile2 = tile + AIMap.GetTileIndex(0, -1);
		local tile3 = tile + AIMap.GetTileIndex(0, platform_length);
		if (AIRail.IsRailTile(tile2) && AICompany.IsMine(AITile.GetOwner(tile2)) && !AIRail.IsRailStationTile(tile2) && (AIRail.GetRailTracks(tile2) & AIRail.RAILTRACK_NW_SW) != 0) {
			goals.push([tile + AIMap.GetTileIndex(return_path, -3), tile + AIMap.GetTileIndex(return_path, -2)]);
		} else if (AIRail.IsRailTile(tile3) && AICompany.IsMine(AITile.GetOwner(tile3)) && !AIRail.IsRailStationTile(tile3) && (AIRail.GetRailTracks(tile3) & AIRail.RAILTRACK_NW_SW) != 0) {
			goals.push([tile + AIMap.GetTileIndex(return_path, platform_length + 2), tile + AIMap.GetTileIndex(return_path, platform_length + 1)]);
		}
	} else {
		local tile2 = tile + AIMap.GetTileIndex(-1, 0);
		local tile3 = tile + AIMap.GetTileIndex(platform_length, 0);
		if (AIRail.IsRailTile(tile2) && AICompany.IsMine(AITile.GetOwner(tile2)) && !AIRail.IsRailStationTile(tile2) && (AIRail.GetRailTracks(tile2) & AIRail.RAILTRACK_NE_SW) != 0) {
			goals.push([tile + AIMap.GetTileIndex(-3, return_path), tile + AIMap.GetTileIndex(-2, return_path)]);
		} else if (AIRail.IsRailTile(tile3) && AICompany.IsMine(AITile.GetOwner(tile3)) && !AIRail.IsRailStationTile(tile3) && (AIRail.GetRailTracks(tile3) & AIRail.RAILTRACK_NE_SW) != 0) {
			goals.push([tile + AIMap.GetTileIndex(platform_length + 2, return_path), tile + AIMap.GetTileIndex(platform_length + 1, return_path)]);
		}
	}
	if (sources.len() == 0) return -7;
	if (goals.len() == 0) return -8;
	if (return_path == 0) {
		pf.InitializePath(sources, goals, [], new_type);
	} else {
		pf.InitializePath(goals, sources, [], new_type);
	}
	local path = pf.FindPath(200000);
	if (path == null) {
		if (AIController.GetSetting("debug_signs")) {
			foreach (t in sources) {
				AISign.BuildSign(t[1], "source");
			}
			foreach (t in goals) {
				AISign.BuildSign(t[1], "goal");
			}
		}
		return -3;
	}

	while (path != null) {
		local tile = path.GetTile();
		if (!AITile.HasTransportType(tile, AITile.TRANSPORT_RAIL)) return -2;
		if (AIRail.GetRailType(tile) == new_type || AIRail.TrainHasPowerOnRail(new_type, AIRail.GetRailType(tile))) {
			path = path.GetParent();
			continue;
		}
		if (!AIRail.TrainHasPowerOnRail(AIRail.GetRailType(tile), new_type)) return -2;
		if (!AIRail.ConvertRailType(tile, tile, new_type)) {
			assert(AIError.GetLastError() == AIError.ERR_NOT_ENOUGH_CASH);
			return -1;
		}
		path = path.GetParent();
	}
	return 0;
}

/*
 * return:
 * 0: all ok.
 * -1: need more money.
 * < -1: other error.
 */
function TrainLine::_UpdateRailType()
{
	local rail_type_list = AIRailTypeList();
	rail_type_list.Valuate(TrainLine._RailTypeCompatible, this._rail_type);
	rail_type_list.KeepValue(1);
	rail_type_list.Valuate(TrainManager.RailTypeValuator, this._cargo);
	rail_type_list.RemoveValue(-1);
	if (rail_type_list.Count() == 0) return -4;
	rail_type_list.Sort(AIAbstractList.SORT_BY_VALUE, AIAbstractList.SORT_DESCENDING);
	local new_type = rail_type_list.Begin();
	if (this._rail_type == new_type) return 0;
	if (!this._station_from.ConvertRailType(new_type)) return -5;
	if (!this._station_to.ConvertRailType(new_type)) return -5;

	local station_a = this._station_from.GetStationID();
	local station_b = this._station_to.GetStationID();

	local ret = this.ConvertRoute(station_a, station_b, 0, new_type);
	if (ret != 0) return ret;
	ret = this.ConvertRoute(station_a, station_b, 1, new_type);
	if (ret != 0) return ret;

	foreach (tile in this._depot_tiles) {
		if (tile == null) continue;
		if (AIRail.GetRailType(tile) == new_type) continue;
		if (AIRail.TrainHasPowerOnRail(new_type, AIRail.GetRailType(tile))) continue;
		if (!AIRail.TrainHasPowerOnRail(AIRail.GetRailType(tile), new_type)) return -2;
		if (!AIRail.ConvertRailType(tile, tile, new_type)) {
			assert(AIError.GetLastError() == AIError.ERR_NOT_ENOUGH_CASH);
			return -1;
		}
	}

	foreach (tile in this._depot_tiles) {
		if (tile == null) continue;
		tile = AIRail.GetRailDepotFrontTile(tile);
		if (AIRail.GetRailType(tile) == new_type) continue;
		if (AIRail.TrainHasPowerOnRail(new_type, AIRail.GetRailType(tile))) continue;
		if (!AIRail.TrainHasPowerOnRail(AIRail.GetRailType(tile), new_type)) return -2;
		if (!AIRail.ConvertRailType(tile, tile, new_type)) {
			assert(AIError.GetLastError() == AIError.ERR_NOT_ENOUGH_CASH);
			return -1;
		}
	}


	this._rail_type = new_type;
	return 0;
}

function TrainLine::CheckVehicles()
{
	if (!this._valid) return false;
	if (this._UpdateRailType() == -1) return true;
	this._UpdateVehicleList();
	if (!AIIndustry.IsValidIndustry(this._ind_from) || (this._ind_to != null && !AIIndustry.IsValidIndustry(this._ind_to))) {
		this.CloseRoute();
		return false;
	}

	local list = AIList();
	list.AddList(this._vehicle_list);
	list.Valuate(AIVehicle.GetAge);
	list.KeepAboveValue(720);
	list.Valuate(AIVehicle.GetProfitLastYear);
	list.KeepBelowValue(1000);

	if (list.Count() > 0 ) {
		foreach (v, _ in list) this.SellVehicle(v);
		::main_instance.SendVehicleToSellToDepot();
		/* Only build new vehicles if we didn't sell any. */
		return false;
	}

	foreach (v, dummy in this._vehicle_list) {
		if (AIVehicle.GetState(v) == AIVehicle.VS_STOPPED) AIVehicle.StartStopVehicle(v);
	}

	list = AIList();
	list.AddList(this._vehicle_list);
	foreach (v, d in list) {
		list.SetValue(v, AIOrder.GetOrderDestination(v, AIOrder.ResolveOrderPosition(v, AIOrder.ORDER_CURRENT)));
	}
	list.KeepValue(AIStation.GetLocation(this._station_from.GetStationID()));
	list.Valuate(Utils_Tile.VehicleManhattanDistanceToTile, AIStation.GetLocation(this._station_from.GetStationID()));
	list.KeepBelowValue(15);
	if (list.Count() >= 4) {
		AILog.Warning("Detected jam near " + AIStation.GetName(this._station_from.GetStationID()));
		list.Valuate(AIVehicle.GetCargoLoad, this._cargo);
		list.Sort(AIAbstractList.SORT_BY_VALUE, AIAbstractList.SORT_ASCENDING);
		local v = list.Begin();
		this.SellVehicle(v);
		::main_instance.SendVehicleToSellToDepot();
		/* Don't buy a new train, we just sold one. */
		return false;
	}

	this._FindEngineID();
	if (this._engine_id != null && this._wagon_engine_id != null) {
		if (this._vehicle_list.Count() < 1) return !this.BuildVehicles(1);
		local cargo_waiting = AIStation.GetCargoWaiting(this._station_from.GetStationID(), this._cargo);
		list = AIList();
		list.AddList(this._vehicle_list);
		list.Valuate(AIVehicle.GetAge);
		list.KeepBelowValue(350);
		if (list.Count() > 0) return false;

		local target_rating = 50;
		if (AITown.HasStatue(AIStation.GetNearestTown(this._station_from.GetStationID()))) target_rating += 10;
		local veh_speed = AIEngine.GetMaxSpeed(this._engine_id);
		if (veh_speed > 85) target_rating += min(17, (veh_speed - 85) / 4);

		local cargo_per_train = this._vehicle_list.Count() > 0 ? AIVehicle.GetCapacity(this._vehicle_list.Begin(), this._cargo) : -1;
		if (AIStation.GetCargoRating(this._station_from.GetStationID(), this._cargo) < target_rating || cargo_per_train == -1 || cargo_waiting > 1.5 * cargo_per_train) {
			return !this.BuildVehicles(1);
		}
	}
	/* We didn't build any new vehicles, so we don't need more money. */
	return false;
}

function TrainLine::_AutoReplace(old_vehicle_id, new_engine_id)
{
	AIGroup.SetAutoReplace(this._group_id, old_vehicle_id, new_engine_id);
}


function TrainLine::_RenameGroup()
{
	local new_name = AICargo.GetCargoLabel(this._cargo) + ": " + AIStation.GetName(this._station_from.GetStationID()) + " - " + AIStation.GetName(this._station_to.GetStationID());
	new_name = new_name.slice(0, min(new_name.len(), 30));
	AIGroup.SetName(this._group_id, new_name);
}

function TrainLine::GetStationFrom()
{
	return this._station_from;
}

function TrainLine::GetStationTo()
{
	return this._station_to;
}

function TrainLine::_UpdateVehicleList()
{
	this._vehicle_list = AIList();
	this._vehicle_list.AddList(AIVehicleList_Station(this._station_from.GetStationID()));
	this._vehicle_list.RemoveList(::main_instance.sell_vehicles);
}

function TrainLine::_SortEngineList(engine_id, max_wagon_speed, max_engine_price)
{
	local max_speed = min(AIEngine.GetMaxSpeed(engine_id), max_wagon_speed);
	return max_speed - max_speed * AIEngine.GetPrice(engine_id) / max_engine_price;
}

function TrainLine::_SortEngineWagonList(engine_id)
{
	return AIEngine.GetCapacity(engine_id);
}

function TrainLine::_FindEngineID()
{
	local list = AIEngineList(AIVehicle.VT_RAIL);
	list.Valuate(AIEngine.CanRunOnRail, this._rail_type);
	list.KeepValue(1);
	list.Valuate(AIEngine.IsWagon);
	list.KeepValue(1);
	list.Valuate(AIEngine.CanRefitCargo, this._cargo);
	list.KeepValue(1);
	Utils_Valuator.Valuate(list, this._SortEngineWagonList);
	list.Sort(AIAbstractList.SORT_BY_VALUE, AIAbstractList.SORT_DESCENDING);
	this._wagon_engine_id = list.Count() == 0 ? null : list.Begin();
	if (this._wagon_engine_id == null) {
		this._engine_id = null;
		return;
	}
	local wagon_speed = AIEngine.GetMaxSpeed(this._wagon_engine_id);
	if (AIGameSettings.GetValue("vehicle.wagon_speed_limits") || wagon_speed == 0) wagon_speed = 65536;
	if (AIRail.GetMaxSpeed(this._rail_type) != 0) wagon_speed = min(wagon_speed, AIRail.GetMaxSpeed(this._rail_type));

	this._UpdateVehicleList();
	local list = AIEngineList(AIVehicle.VT_RAIL);
	list.Valuate(AIEngine.HasPowerOnRail, this._rail_type);
	list.KeepValue(1);
	list.Valuate(AIEngine.IsWagon);
	list.KeepValue(0);
	list.Valuate(AIEngine.CanPullCargo, this._cargo);
	list.KeepValue(1);
	local max_price = 0;
	foreach (engine, dummy in list) {
		max_price = max(max_price, AIEngine.GetPrice(engine));
	}
	Utils_Valuator.Valuate(list, this._SortEngineList, wagon_speed, max_price);
	list.Sort(AIAbstractList.SORT_BY_VALUE, AIAbstractList.SORT_DESCENDING);
	local new_engine_id = list.Begin();
	if (this._engine_id != null && this._engine_id != new_engine_id) {
		this._AutoReplace(this._engine_id, new_engine_id);
	}
	this._engine_id = new_engine_id;
}
