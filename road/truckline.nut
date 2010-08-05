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

/** @file truckline.nut Implementation of TruckLine. */

/**
 * Class that controls a line between two industries. It can buy and
 *  sell vehicles to keep up with the demand.
 */
class TruckLine extends RoadLine
{
	_ind_from = null;     ///< The IndustryID where we are transporting cargo from.
	_ind_to = null;       ///< The IndustryID where we are transporting cargo to.
	_valid = null;

/* public: */

	/**
	 * Create a new truck line.
	 * @param ind_from The IndustryID we are transporting cargo from.
	 * @param station_from A StationManager that controls the station we are transporting cargo from.
	 * @param ind_to The IndustryID we are transporting cargo to.
	 * @param station_to A StationManager that controls the station we are transporting cargo to.
	 * @param depot_tile A TileIndex of a depot tile near one of the stations.
	 * @param cargo The CargoID we are transporting.
	 * @param loaded True if we loaded this line from a savegame, false if it's a new line.
	 */
	constructor(ind_from, station_from, ind_to, station_to, depot_tile, cargo, loaded) {
		::RoadLine.constructor(station_from, station_to, depot_tile, cargo, !loaded);
		this._ind_from = ind_from;
		this._ind_to = ind_to;
		this._valid = true;
		if (!loaded) this.BuildVehicles(3);
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
};

function TruckLine::GetIndustryFrom()
{
	if (!this._valid) return -1;
	return this._ind_from;
}

function TruckLine::GetIndustryTo()
{
	if (!this._valid) return -1;
	return this._ind_to;
}

function TruckLine::CloseRoute()
{
	if (!this._valid) return;
	AILog.Warning("Closing down cargo route");
	this.UpdateVehicleList();
	::main_instance.sell_vehicles.AddList(this._vehicle_list);
	foreach (v, dummy in this._vehicle_list) {
		local veh_id = this._engine_id == null ? AIVehicle.GetEngineType(v) : this._engine_id;
		this._station_from.RemoveTrucks(1, this._distance, veh_id);
		this._station_to.RemoveTrucks(1, this._distance, veh_id);
	}
	::main_instance.SendVehicleToSellToDepot();
	this._station_from.CloseTruckStation();
	this._station_to.CloseTruckStation();
	this._valid = false;
}

function TruckLine::ScanPoints()
{
	this.UpdateVehicleList();
	foreach (v, dummy in this._vehicle_list) {
		this._station_from.AddTrucks(1, this._distance, AIEngine.GetMaxSpeed(AIVehicle.GetEngineType(v)));
		this._station_to.AddTrucks(1, this._distance, AIEngine.GetMaxSpeed(AIVehicle.GetEngineType(v)));
	}
}

function TruckLine::BuildVehicles(num)
{
	if (!this._valid) return true;
	this.UpdateVehicleList();
	this._FindEngineID();
	if (this._engine_id == null) return true;
	local max_veh_speed = AIEngine.GetMaxSpeed(this._engine_id);
	local max_to_build = min(min(this._station_from.CanAddTrucks(num, this._distance, max_veh_speed), this._station_to.CanAddTrucks(num, this._distance, max_veh_speed)), num);
	if (max_to_build == 0) return true;
	if (max_to_build < 0) {
		this._vehicle_list.Valuate(AIVehicle.GetAge);
		this._vehicle_list.Sort(AIAbstractList.SORT_BY_VALUE, AIAbstractList.SORT_ASCENDING);
		this._vehicle_list.KeepTop(abs(max_to_build));
		foreach (v, dummy in this._vehicle_list) {
			AIVehicle.SendVehicleToDepot(v);
			::main_instance.sell_vehicles.AddItem(v, 0);
			this._station_from.RemoveTrucks(1, this._distance, max_speed);
			this._station_to.RemoveTrucks(1, this._distance, max_speed);
		}
		return true;
	}

	for (local i = 0; i < max_to_build; i++) {
		local v = AIVehicle.BuildVehicle(this._depot_tile, this._engine_id);
		if (!AIVehicle.IsValidVehicle(v)) {
			if (AIError.GetLastError() == AIError.ERR_NOT_ENOUGH_CASH) return false;
			continue;
		}
		if (!AIVehicle.RefitVehicle(v, this._cargo)) {
			local cash_shortage = AIError.GetLastError() == AIError.ERR_NOT_ENOUGH_CASH;
			AIVehicle.SellVehicle(v);
			return !cash_shortage;
		}
		if (this._vehicle_list.Count() > 0) {
			AIOrder.ShareOrders(v, this._vehicle_list.Begin());
		} else {
			AIOrder.AppendOrder(v, AIStation.GetLocation(this._station_from.GetStationID()), AIOrder.AIOF_FULL_LOAD_ANY | AIOrder.AIOF_NON_STOP_INTERMEDIATE);
			AIOrder.AppendOrder(v, this._depot_tile, AIOrder.AIOF_SERVICE_IF_NEEDED | AIOrder.AIOF_NON_STOP_INTERMEDIATE);
			AIOrder.AppendOrder(v, AIStation.GetLocation(this._station_to.GetStationID()), AIOrder.AIOF_UNLOAD | AIOrder.AIOF_NO_LOAD | AIOrder.AIOF_NON_STOP_INTERMEDIATE);
			AIOrder.AppendOrder(v, this._depot_tile, AIOrder.AIOF_SERVICE_IF_NEEDED | AIOrder.AIOF_NON_STOP_INTERMEDIATE);
		}
		this._station_from.AddTrucks(1, this._distance, AIEngine.GetMaxSpeed(this._engine_id));
		this._station_to.AddTrucks(1, this._distance, AIEngine.GetMaxSpeed(this._engine_id));
		AIGroup.MoveVehicle(this._group_id, v);
		AIVehicle.StartStopVehicle(v);
		this._vehicle_list.AddItem(v, 0);
	}
	return true;
}

function TruckLine::CheckVehicles()
{
	if (!this._valid) return false;
	this.UpdateVehicleList();
	if (!AIIndustry.IsValidIndustry(this._ind_from) || (this._ind_to != null && !AIIndustry.IsValidIndustry(this._ind_to))) {
		this.CloseRoute();
		return false;
	}

	local list = AIList();
	list.AddList(this._vehicle_list);
	list.Valuate(AIVehicle.GetAge);
	list.KeepAboveValue(720);
	list.Valuate(AIVehicle.GetProfitLastYear);
	list.KeepBelowValue(400);

	foreach (v, profit in list) {
		this._vehicle_list.RemoveItem(v);
		AIVehicle.SendVehicleToDepot(v);
		::main_instance.sell_vehicles.AddItem(v, 0);
		local veh_id = this._engine_id == null ? AIVehicle.GetEngineType(v) : this._engine_id;
		this._station_from.RemoveTrucks(1, this._distance, AIEngine.GetMaxSpeed(veh_id));
		this._station_to.RemoveTrucks(1, this._distance, AIEngine.GetMaxSpeed(veh_id));
	}

	local list = AIList();
	list.AddList(this._vehicle_list);
	list.Valuate(AIOrder.GetOrderDestination, AIOrder.ORDER_CURRENT);
	list.KeepValue(AIStation.GetLocation(this._station_from.GetStationID()));
	list.Valuate(AIVehicle.GetCurrentSpeed);
	list.KeepBelowValue(10);
	list.Valuate(Utils_Tile.VehicleManhattanDistanceToTile, AIStation.GetLocation(this._station_from.GetStationID()));
	list.KeepBelowValue(7);
	list.Valuate(AIVehicle.GetState);
	list.KeepValue(AIVehicle.VS_RUNNING);
	if (list.Count() > 2) {
		list.Valuate(AIVehicle.GetAge);
		list.Sort(AIAbstractList.SORT_BY_VALUE, AIAbstractList.SORT_DESCENDING);
		local v = list.Begin();
		this._vehicle_list.RemoveItem(v);
		AIVehicle.SendVehicleToDepot(v);
		::main_instance.sell_vehicles.AddItem(v, 0);
		local max_speed = AIEngine.GetMaxSpeed(AIVehicle.GetEngineType(v));
		this._station_from.RemoveTrucks(1, this._distance, max_speed);
		this._station_to.RemoveTrucks(1, this._distance, max_speed);
	}

	foreach (v, dummy in this._vehicle_list) {
		if (AIVehicle.GetState(v) == AIVehicle.VS_STOPPED) AIVehicle.StartStopVehicle(v);
	}

	/* Only build new vehicles if we didn't sell any. */
	this._FindEngineID();
	if (list.Count() == 0 && this._engine_id != null) {
		local cargo_waiting = AIStation.GetCargoWaiting(this._station_from.GetStationID(), this._cargo);
		local num_new =  0;
		list = AIList();
		list.AddList(this._vehicle_list);
		list.Valuate(AIVehicle.GetAge);
		list.KeepBelowValue(250);
		local num_young_vehicles = list.Count();
		local cargo_per_truck = this._vehicle_list.Count() > 0 ? AIVehicle.GetCapacity(this._vehicle_list.Begin(), this._cargo) : AIEngine.GetCapacity(this._engine_id);
		if (cargo_per_truck == 0) throw("Cargo_per_truck = 0. Engine: " + AIEngine.GetName(this._engine_id) + " ("+this._engine_id+"), veh engine = " +AIEngine.GetName(AIVehicle.GetEngineType(this._vehicle_list.Begin())) + " ("+this._vehicle_list.Begin()+")");
		if (cargo_waiting > 60 && cargo_waiting > 3 * cargo_per_truck) {
			num_new = (cargo_waiting / cargo_per_truck + 1) / 2- max(0, num_young_vehicles);
			num_new = min(num_new, 8); // Don't build more than 8 new vehicles a time.
		}
		local target_rating = 64;
		if (AITown.HasStatue(AIStation.GetNearestTown(this._station_from.GetStationID()))) target_rating += 10;
		local veh_speed = AIEngine.GetMaxSpeed(this._engine_id);
		if (veh_speed > 85) target_rating += min(17, (veh_speed - 85) / 4);
		if (AIStation.GetCargoRating(this._station_from.GetStationID(), this._cargo) < target_rating && num_young_vehicles == 0 && num_new == 0) num_new = 1;
		if (this._vehicle_list.Count() == 0) num_new = max(num_new, 2);

		list = AIList();
		list.AddList(this._vehicle_list);
		list.Valuate(AIVehicle.GetState);
		list.KeepValue(AIVehicle.VS_RUNNING);
		list.Valuate(AIVehicle.GetCurrentSpeed);
		list.KeepBelowValue(10);
		if (num_new > 0 && list.Count() <= this._vehicle_list.Count() / 3) return !this.BuildVehicles(num_new);
	}
	/* We didn't build any new vehicles, so we don't need more money. */
	return false;
}

function TruckLine::_AutoReplace(old_vehicle_id, new_engine_id)
{
	AIGroup.SetAutoReplace(this._group_id, old_vehicle_id, new_engine_id);
	this._station_from.RemoveTrucks(this._vehicle_list.Count(), this._distance, AIEngine.GetMaxSpeed(old_vehicle_id));
	this._station_to.RemoveTrucks(this._vehicle_list.Count(), this._distance, AIEngine.GetMaxSpeed(old_vehicle_id));
	this._station_from.AddTrucks(this._vehicle_list.Count(), this._distance, AIEngine.GetMaxSpeed(new_engine_id));
	this._station_to.AddTrucks(this._vehicle_list.Count(), this._distance, AIEngine.GetMaxSpeed(new_engine_id));
}
