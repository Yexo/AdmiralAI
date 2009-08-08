/** @file busline.nut Implementation of BusLine. */

/**
 * Class that controls a line between two bus stops. It can buy and
 *  sell vehicles to keep up with the demand.
 * @todo merge large parts of this class with TruckLine.
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
	constructor(station_from, station_to, depot_tile, cargo, loaded)
	{
		::RoadLine.constructor(station_from, station_to, depot_tile, cargo, true);
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
		AIOrder.InsertOrder(v, 0, AIStation.GetLocation(new_station.GetStationID()), AIOrder.AIOF_NONE);
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
		AIOrder.InsertOrder(v, 1, AIStation.GetLocation(new_station.GetStationID()), AIOrder.AIOF_NONE);
	}
	this._station_to = new_station;
	this._distance = AIMap.DistanceManhattan(AIStation.GetLocation(this._station_from.GetStationID()), AIStation.GetLocation(this._station_to.GetStationID()));
}

function BusLine::BuildVehicles(num)
{
	this.UpdateVehicleList();
	this._FindEngineID();
	if (this._engine_id == null) return;
	local max_speed = AIEngine.GetMaxSpeed(this._engine_id);
	local max_to_build = min(min(this._station_from.CanAddBusses(num, this._distance, max_speed), this._station_to.CanAddBusses(num, this._distance, max_speed)), num);
	if (max_to_build == 0) return;
	if (max_to_build < 0) {
		this._vehicle_list.Valuate(AIVehicle.GetAge);
		this._vehicle_list.Sort(AIAbstractList.SORT_BY_VALUE, true);
		this._vehicle_list.KeepTop(abs(max_to_build));
		foreach (v, dummy in this._vehicle_list) {
			AIVehicle.SendVehicleToDepot(v);
			::vehicles_to_sell.AddItem(v, 0);
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
			AIVehicle.SellVehicle(v);
			return false;
		}
		if (this._vehicle_list.Count() > 0) {
			AIOrder.ShareOrders(v, this._vehicle_list.Begin());
		} else {
			local acceptance_from = AITile.GetCargoAcceptance(AIStation.GetLocation(this._station_from.GetStationID()), this._cargo, 1, 1, AIStation.GetCoverageRadius(AIStation.STATION_BUS_STOP));
			local acceptance_to = AITile.GetCargoAcceptance(AIStation.GetLocation(this._station_to.GetStationID()), this._cargo, 1, 1, AIStation.GetCoverageRadius(AIStation.STATION_BUS_STOP));
			AIOrder.AppendOrder(v, AIStation.GetLocation(this._station_from.GetStationID()), AIOrder.AIOF_NONE);
			AIOrder.AppendOrder(v, AIStation.GetLocation(this._station_to.GetStationID()), AIOrder.AIOF_NONE);
			AIOrder.AppendOrder(v, this._depot_tile, AIOrder.AIOF_SERVICE_IF_NEEDED);
		}
		if (i % 2) AIVehicle.SkipToVehicleOrder(v, 1);
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
		::vehicles_to_sell.AddItem(v, 0);
		local max_speed = AIEngine.GetMaxSpeed(AIVehicle.GetVehicleType(v));
		this._station_from.RemoveBusses(1, this._distance, max_speed);
		this._station_to.RemoveBusses(1, this._distance, max_speed);
		build_new = false;
	}

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
		if (num_new > 0) this.BuildVehicles(num_new);
	}
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
