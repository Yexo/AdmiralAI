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

/** @file trainline.nut Implementation of TrainLine. */

/**
 * Class that controls a train line between two industries. It can buy and
 *  sell vehicles to keep up with the demand.
 */
class TrainLine
{
/* public: */

	/**
	 * Create a new train line.
	 * @param ind_from The IndustryID we are transporting cargo from.
	 * @param station_from A StationManager that controls the station we are transporting cargo from.
	 * @param ind_to The IndustryID we are transporting cargo to.
	 * @param station_to A StationManager that controls the station we are transporting cargo to.
	 * @param depot_tile A TileIndex of the depot tile.
	 * @param cargo The CargoID we are transporting.
	 */
	constructor(ind_from, station_from, ind_to, station_to, depot_tile, cargo, loaded, platform_length) {
		this._ind_from = ind_from;
		this._station_from = station_from;
		this._ind_to = ind_to;
		this._station_to = station_to;
		this._depot_tile = depot_tile;
		this._cargo = cargo;
		this._platform_length = platform_length;
		this._valid = true;
		if (!loaded) {
			this._group_id = AIGroup.CreateGroup(AIVehicle.VEHICLE_RAIL);
			this.RenameGroup();
			this.BuildVehicles(2);
		}
	}

	/**
	 * Get the IndustryID of the station this line was transporting cargo from.
	 * @return The IndustryID.
	 */
	function GetIndustryFrom();

	/**
	 * Get the IndustryID of the station this line was transporting cargo to.
	 * @return The IndustryID.
	 */
	function GetIndustryTo();

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

	_ind_from = null;     ///< The IndustryID where we are transporting cargo from.
	_ind_to = null;       ///< The IndustryID where we are transporting cargo to.
	_valid = null;
	_station_from = null; ///< The StationManager managing the first station.
	_station_to = null;   ///< The StationManager managing the second station.
	_vehicle_list = null; ///< An AIList() containing all vehicles on this route.
	_depot_tile = null;   ///< A TileIndex indicating the depot that is used by this route (both to build new vehicles and to service existing ones).
	_cargo = null;        ///< The CargoID of the cargo we'll transport.
	_engine_id = null;    ///< The EngineID of the vehicles on this route.
	_wagon_engine_id = null;
	_group_id = null;     ///< The GroupID of the group all vehicles from this route are in.
	_platform_length = null;
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

function TrainLine::CloseRoute()
{
	if (!this._valid) return;
	AILog.Warning("Closing down train route");
	this.UpdateVehicleList();
	::vehicles_to_sell.AddList(this._vehicle_list);
	AdmiralAI.SendVehicleToSellToDepot();
	this._valid = false;
}

function TrainLine::BuildVehicles(num)
{
	AILog.Info("TrainLine.BuildVehicles(" + num + ")");
	if (!this._valid) return true;
	this.UpdateVehicleList();
	this._FindEngineID();
	if (this._engine_id == null || this._wagon_engine_id == null) {
		AILog.Warning("No vehicles id found");
		return false;
	}
	local max_veh_speed = AIEngine.GetMaxSpeed(this._engine_id);

	for (local i = 0; i < num; i++) {
		local v = AIVehicle.BuildVehicle(this._depot_tile, this._engine_id);
		if (!AIVehicle.IsValidVehicle(v)) {
			if (AIError.GetLastError() == AIError.ERR_NOT_ENOUGH_CASH) return false;
			AILog.Warning("Error building train engine: " + AIError.GetLastErrorString());
			return true;
		}
		local last_length = AIVehicle.GetLength(v);
		while (last_length <= 16 * this._platform_length) {
			local wagon_id = AIVehicle.BuildVehicle(this._depot_tile, this._wagon_engine_id);
			/* Check if the wagon was already added to the engine. */
			if (AIVehicle.GetLength(v) == last_length) {
				if (!AIVehicle.IsValidVehicle(wagon_id)) {
					quit();
					AIVehicle.SellVehicle(v);
					if (AIError.GetLastError() == AIError.ERR_NOT_ENOUGH_CASH) return false;
					AILog.Warning("Error building train wagon: " + AIError.GetLastErrorString());
					return true;
				}
				AIVehicle.MoveWagon(wagon_id, 0, false, v, 0);
				AILog.Warning(AIError.GetLastErrorString());
			}
			last_length = AIVehicle.GetLength(v);
		}
		AIVehicle.SellWagon(v, 1, false);
		if (!AIVehicle.RefitVehicle(v, this._cargo)) {
			AIVehicle.SellVehicle(v);
			return false;
		}
		if (this._vehicle_list.Count() > 0) {
			AIOrder.ShareOrders(v, this._vehicle_list.Begin());
		} else {
			AIOrder.AppendOrder(v, AIStation.GetLocation(this._station_from.GetStationID()), AIOrder.AIOF_FULL_LOAD);
			AIOrder.AppendOrder(v, AIStation.GetLocation(this._station_to.GetStationID()), AIOrder.AIOF_UNLOAD | AIOrder.AIOF_NO_LOAD);
			AIOrder.AppendOrder(v, this._depot_tile, AIOrder.AIOF_SERVICE_IF_NEEDED);
		}
		AIGroup.MoveVehicle(this._group_id, v);
		AIVehicle.StartStopVehicle(v);
		this._vehicle_list.AddItem(v, 0);
	}
	return true;
}

function TrainLine::CheckVehicles()
{
	if (!this._valid) return;
	this.UpdateVehicleList();
	if (!AIIndustry.IsValidIndustry(this._ind_from) || (this._ind_to != null && !AIIndustry.IsValidIndustry(this._ind_to))) {
		this.CloseRoute();
		return;
	}

	local list = AIList();
	list.AddList(this._vehicle_list);
	list.Valuate(AIVehicle.GetAge);
	list.KeepAboveValue(720);
	list.Valuate(AIVehicle.GetProfitLastYear);
	list.KeepBelowValue(1000);

	foreach (v, profit in list) {
		this._vehicle_list.RemoveItem(v);
		AIVehicle.SendVehicleToDepot(v);
		::vehicles_to_sell.AddItem(v, 0);
	}

	foreach (v, dummy in this._vehicle_list) {
		if (AIVehicle.GetState(v) == AIVehicle.VS_STOPPED) AIVehicle.StartStopVehicle(v);
	}

	/* Only build new vehicles if we didn't sell any. */
	this._FindEngineID();
	if (this._engine_id != null && this._wagon_engine_id != null) {
		if (this._vehicle_list.Count() < 2) return !this.BuildVehicles(2 - this._vehicle_list.Count());
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


function TrainLine::RenameGroup()
{
	AIGroup.SetName(this._group_id, AICargo.GetCargoLabel(this._cargo) + ": " + AIStation.GetName(this._station_from.GetStationID()) + " - " + AIStation.GetName(this._station_to.GetStationID()));
}

function TrainLine::GetStationFrom()
{
	return this._station_from;
}

function TrainLine::GetStationTo()
{
	return this._station_to;
}

function TrainLine::UpdateVehicleList()
{
	this._vehicle_list = AIList();
	this._vehicle_list.AddList(AIVehicleList_Station(this._station_from.GetStationID()));
	this._vehicle_list.RemoveList(::vehicles_to_sell);
}

function TrainLine::_SortEngineList(engine_id)
{
	return AIEngine.GetMaxSpeed(engine_id);
}

function TrainLine::_SortEngineWagonList(engine_id)
{
	return AIEngine.GetCapacity(engine_id);
}

function TrainLine::_FindEngineID()
{
	this.UpdateVehicleList();
	local list = AIEngineList(AIVehicle.VEHICLE_RAIL);
	list.Valuate(AIEngine.HasPowerOnRail, AIRail.GetCurrentRailType());
	list.KeepValue(1);
	list.Valuate(AIEngine.IsWagon);
	list.KeepValue(0);
	list.Valuate(this._SortEngineList);
	list.Sort(AIAbstractList.SORT_BY_VALUE, false);
	local new_engine_id = null;
	if (list.Count() != 0) {
		new_engine_id = list.Begin();
	}
	if (this._engine_id != null && new_engine_id != null && this._engine_id != new_engine_id) {
		this._AutoReplace(this._engine_id, new_engine_id);
	}
	this._engine_id = new_engine_id;

	local list = AIEngineList(AIVehicle.VEHICLE_RAIL);
	list.Valuate(AIEngine.CanRunOnRail, AIRail.GetCurrentRailType());
	list.KeepValue(1);
	list.Valuate(AIEngine.IsWagon);
	list.KeepValue(1);
	list.Valuate(AIEngine.CanRefitCargo, this._cargo);
	list.KeepValue(1);
	list.Valuate(this._SortEngineWagonList);
	list.Sort(AIAbstractList.SORT_BY_VALUE, false);
	this._wagon_engine_id = list.Count() == 0 ? null : list.Begin();
}
