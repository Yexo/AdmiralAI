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

/** @file busline.nut Implementation of BusLine. */

/**
 * Class that controls a line between two bus stops. It can buy and
 *  sell vehicles to keep up with the demand.
 */
class BusLine extends RoadLine
{
/* public: */

	/**
	 * Create a new bus line.
	 * @param station_from A StationManager corresponding with the first bus stop.
	 * @param station_to A StationManager corresponding with the second bus stop.
	 * @param depot_tile A TileIndex on which a road depot has been built.
	 * @param cargo The CargoID of the passengers we'll transport.
	 */
	constructor(station_from, station_to, depot_tile, cargo, loaded, support_articulated = false)
	{
		::RoadLine.constructor(station_from, station_to, depot_tile, cargo, true, support_articulated);
		if (!loaded) this.BuildVehicles(2);
	}

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
	 *  they all do and there are surplus passengers at of the stations,
	 * build some new vehicles.
	 * @return True if and only if we need more money to complete the function.
	 */
	function CheckVehicles();
};

function BusLine::GetDistance()
{
	return this._distance;
}

function BusLine::ChangeStationFrom(new_station)
{
	this.UpdateVehicleList();
	local max_speed = AIEngine.GetMaxSpeed(this._engine_id);
	this._station_from.RemoveBusses(this._vehicle_list.Count(), this._distance, max_speed);
	new_station.AddBusses(this._vehicle_list.Count(), this._distance, max_speed);
	if (this._vehicle_list.Count() > 0) {
		local v = this._vehicle_list.Begin();
		AIOrder.RemoveOrder(v, 0);
		AIOrder.InsertOrder(v, 0, AIStation.GetLocation(new_station.GetStationID()), AIOrder.AIOF_NON_STOP_INTERMEDIATE);
	}
	this._station_from = new_station;
	this._distance = AIMap.DistanceManhattan(AIStation.GetLocation(this._station_from.GetStationID()), AIStation.GetLocation(this._station_to.GetStationID()));
}

function BusLine::ChangeStationTo(new_station)
{
	this.UpdateVehicleList();
	local max_speed = AIEngine.GetMaxSpeed(this._engine_id);
	this._station_to.RemoveBusses(this._vehicle_list.Count(), this._distance, max_speed);
	new_station.AddBusses(this._vehicle_list.Count(), this._distance, max_speed);
	if (this._vehicle_list.Count() > 0) {
		local v = this._vehicle_list.Begin();
		AIOrder.RemoveOrder(v, 1);
		AIOrder.InsertOrder(v, 1, AIStation.GetLocation(new_station.GetStationID()), AIOrder.AIOF_NON_STOP_INTERMEDIATE);
	}
	this._station_to = new_station;
	this._distance = AIMap.DistanceManhattan(AIStation.GetLocation(this._station_from.GetStationID()), AIStation.GetLocation(this._station_to.GetStationID()));
}

function BusLine::BuildVehicles(num)
{
	this.UpdateVehicleList();
	this._FindEngineID();
	if (this._engine_id == null) return true;
	local max_speed = AIEngine.GetMaxSpeed(this._engine_id);
	local max_to_build = min(min(this._station_from.CanAddBusses(num, this._distance, max_speed), this._station_to.CanAddBusses(num, this._distance, max_speed)), num);
	if (max_to_build == 0) return true;
	if (max_to_build < 0) {
		this._vehicle_list.Valuate(AIVehicle.GetAge);
		this._vehicle_list.Sort(AIAbstractList.SORT_BY_VALUE, AIAbstractList.SORT_ASCENDING);
		this._vehicle_list.KeepTop(abs(max_to_build));
		foreach (v, dummy in this._vehicle_list) {
			AIVehicle.SendVehicleToDepot(v);
			::main_instance.sell_vehicles.AddItem(v, 0);
			this._station_from.RemoveBusses(1, this._distance, max_speed);
			this._station_to.RemoveBusses(1, this._distance, max_speed);
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
			AIOrder.AppendOrder(v, AIStation.GetLocation(this._station_from.GetStationID()), AIOrder.AIOF_NON_STOP_INTERMEDIATE);
			AIOrder.AppendOrder(v, AIStation.GetLocation(this._station_to.GetStationID()), AIOrder.AIOF_NON_STOP_INTERMEDIATE);
			AIOrder.AppendOrder(v, this._depot_tile, AIOrder.AIOF_SERVICE_IF_NEEDED | AIOrder.AIOF_NON_STOP_INTERMEDIATE);
		}
		if (i % 2) AIOrder.SkipToOrder(v, 1);
		this._station_from.AddBusses(1, this._distance, max_speed);
		this._station_to.AddBusses(1, this._distance, max_speed);
		AIGroup.MoveVehicle(this._group_id, v);
		AIVehicle.StartStopVehicle(v);
		this._vehicle_list.AddItem(v, 0);
	}
	return true;
}

function BusLine::CheckVehicles()
{
	this.UpdateVehicleList();
	local build_new = true;
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
		local max_speed = AIEngine.GetMaxSpeed(veh_id);
		this._station_from.RemoveBusses(1, this._distance, max_speed);
		this._station_to.RemoveBusses(1, this._distance, max_speed);
		build_new = false;
	}
	this.UpdateVehicleList();

	this._vehicle_list.Valuate(AIVehicle.GetState);
	foreach (vehicle, state in this._vehicle_list) {
		switch (state) {
			case AIVehicle.VS_RUNNING:
				/*local list = AIList();
				list.AddList(this._vehicle_list);
				list.Valuate(BusLineManager._ValuatorReturnItem);
				list.KeepAboveValue(vehicle);*/
				/* Same OrderPosition means same order, since the orders are shared. */
				/*list.Valuate(AIOrder.ResolveOrderPosition, AIOrder.CURRENT_ORDER);
				list.KeepValue(AIOrder.ResolveOrderPosition(vehicle, AIOrder.CURRENT_ORDER));
				local route = RouteFinder.FindRouteBetweenRects(AIVehicle.GetLocation(vehicle), AIOrder.GetOrderDestination(vehicle, AIOrder.CURRENT_ORDER), 0);
				if (route == null) continue;

				list.Valuate(BusLine._VehicleRouteDistanceToTile, AIVehicle.GetLocation(vehicle));
				list.KeepBelowValue(5);
				if (list.Count() > 0) {
					AIVehicle.StartStopVehicle(vehicle);
					build_new = false;
				}*/
				break;

			case AIVehicle.VS_STOPPED:
				AIVehicle.StartStopVehicle(vehicle);
				build_new = false;
				break;

			case AIVehicle.VS_IN_DEPOT:
			case AIVehicle.VS_AT_STATION:
			case AIVehicle.VS_BROKEN:
			case AIVehicle.VS_CRASHED:
				break;
		}
	}

	this._FindEngineID();
	if (build_new && this._engine_id != null) {
		local cargo_waiting_a = AIStation.GetCargoWaiting(this._station_from.GetStationID(), this._cargo);
		local cargo_waiting_b = AIStation.GetCargoWaiting(this._station_to.GetStationID(), this._cargo);
		local num_new =  0;
		list = AIList();
		list.AddList(this._vehicle_list);
		list.Valuate(AIVehicle.GetAge);
		list.KeepBelowValue(100);
		local num_young_vehicles = list.Count();
		if (max(cargo_waiting_a, cargo_waiting_b) > 100) {
			num_new = max(cargo_waiting_a, cargo_waiting_b) / 60 - max(0, num_young_vehicles);
			num_new = min(num_new, 8); // Don't build more than 8 new vehicles a time.
		}
		local rating = min(AIStation.GetCargoRating(this._station_from.GetStationID(), this._cargo),
		                   AIStation.GetCargoRating(this._station_to.GetStationID(), this._cargo));
		local target_rating = 60;
		if (AITown.HasStatue(AIStation.GetNearestTown(this._station_from.GetStationID()))) target_rating += 10;
		local veh_speed = AIEngine.GetMaxSpeed(this._engine_id);
		if (veh_speed > 85) target_rating += min(17, (veh_speed - 85) / 4);
		if (rating < target_rating && num_young_vehicles == 0 && num_new == 0) num_new = 1;
		if (rating < target_rating - 20 && num_young_vehicles + num_new <= 1) num_new++;
		if (num_new > 0) return !this.BuildVehicles(num_new);
	}
	return false;
}

function BusLine::_AutoReplace(old_vehicle_id, new_engine_id)
{
	AIGroup.SetAutoReplace(this._group_id, old_vehicle_id, new_engine_id);
	this._station_from.RemoveBusses(this._vehicle_list.Count(), this._distance, AIEngine.GetMaxSpeed(old_vehicle_id));
	this._station_to.RemoveBusses(this._vehicle_list.Count(), this._distance, AIEngine.GetMaxSpeed(old_vehicle_id));
	this._station_from.AddBusses(this._vehicle_list.Count(), this._distance, AIEngine.GetMaxSpeed(new_engine_id));
	this._station_to.AddBusses(this._vehicle_list.Count(), this._distance, AIEngine.GetMaxSpeed(new_engine_id));
}

function BusLine::_VehicleRouteDistanceToTile(vehicle_id, tile)
{
	return AIMap.DistanceManhattan(tile, AIVehicle.GetLocation(vehicle_id));
}
