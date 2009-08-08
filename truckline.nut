/** @file truckline.nut Implementation of TruckLine. */

/**
 * Class that controls a line between two industries. It can buy and
 *  sell vehicles to keep up with the demand.
 */
class TruckLine
{
/* public: */

	/**
	 * Create a new truck line.
	 * @param ind_from The IndustryID we are transporting cargo from.
	 * @param station_from A StationManager that controls the station we are transporting cargo from.
	 * @param ind_to The IndustryID we are transporting cargo to.
	 * @param station_to A StationManager that controls the station we are transporting cargo to.
	 * @param depot_tile A TileIndex of a depot tile near one of the stations.
	 * @param cargo The CargoID we are transporting.
	 */
	constructor(ind_from, station_from, ind_to, station_to, depot_tile, cargo) {
		this._ind_from = ind_from;
		this._station_from = station_from;
		this._ind_to = ind_to;
		this._station_to = station_to;
		this._vehicle_list = AIList();
		this._depot_tile = depot_tile;
		this._cargo = cargo;
		this._engine_id = null;
		this._valid = true;
		this._group_id = AIGroup.CreateGroup(AIVehicle.VEHICLE_ROAD);
		AIGroup.SetName(this._group_id, AICargo.GetCargoLabel(cargo) + ": " + AIStation.GetName(station_from.GetStationID()) + " - " + AIStation.GetName(station_to.GetStationID()));
		local station_id_from = station_from.GetStationID();
		local station_id_to = station_to.GetStationID();
		local loc_from = AIStation.GetLocation(station_id_from);
		local loc_to = AIStation.GetLocation(station_id_to);
		this._distance = AIMap.DistanceManhattan(loc_from, loc_to);
		this.BuildVehicles(3);
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

	/**
	 * A valuator used in _FindEngineID().
	 * @param engine_id The EngineID to valuate.
	 * @return A value for the given EngineID.
	 */
	static function _SortEngineList(engine_id);

	/**
	 * Find the best EngineID for this route. The EngineID is stored
	 *  in this._engine_id.
	 */
	function _FindEngineID();

	_ind_from = null;     ///< The IndustryID where we are transporting cargo from.
	_station_from = null; ///< The StationManager managing the source station.
	_ind_to = null;       ///< The IndustryID where we are transporting cargo to.
	_station_to = null;   ///< The StationManager managing the station we are transporting cargo to.
	_distance = null;
	_vehicle_list = null; ///< An AIList() containing all vehicles on this route.
	_depot_tile = null;   ///< A TileIndex indicating the depot that is used by this route (both to build new vehicles and to service existing ones).
	_cargo = null;        ///< The CargoID we are transporting.
	_engine_id = null;    ///< The EngineID of the vehicles on this route.
	_group_id = null;     ///< The GroupID of the group all vehicles from this route are in.
	_valid = null;
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
	this._vehicle_list = AIVehicleList_Station(this._station_from.GetStationID());
	foreach (vehicle, dummy in this._vehicle_list) {
		AIVehicle.SendVehicleToDepot(vehicle);
		::vehicles_to_sell.AddItem(vehicle, 0);
		this._station_from.RemoveTrucks(1, this._distance, AIEngine.GetMaxSpeed(this._engine_id));
		this._station_to.RemoveTrucks(1, this._distance, AIEngine.GetMaxSpeed(this._engine_id));
	}
	this._station_from.CloseStation();
	this._station_to.CloseStation();
	this._valid = false;
}

function TruckLine::BuildVehicles(num)
{
	this._vehicle_list = AIVehicleList_Station(this._station_from.GetStationID());
	if (!this._valid) return true;
	this._FindEngineID();
	if (this._engine_id == null) return;
	local max_veh_speed = AIEngine.GetMaxSpeed(this._engine_id);
	local max_to_build = min(min(this._station_from.CanAddTrucks(num, this._distance, max_veh_speed), this._station_to.CanAddTrucks(num, this._distance, max_veh_speed)), num);
	if (max_to_build == 0) return true;
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
			AIOrder.AppendOrder(v, AIStation.GetLocation(this._station_from.GetStationID()), AIOrder.AIOF_FULL_LOAD);
			AIOrder.AppendOrder(v, AIStation.GetLocation(this._station_to.GetStationID()), AIOrder.AIOF_UNLOAD | AIOrder.AIOF_NO_LOAD);
			AIOrder.AppendOrder(v, this._depot_tile, AIOrder.AIOF_SERVICE_IF_NEEDED);
		}
		this._station_from.AddTrucks(1, this._distance, AIEngine.GetMaxSpeed(this._engine_id));
		this._station_to.AddTrucks(1, this._distance, AIEngine.GetMaxSpeed(this._engine_id));
		AIGroup.MoveVehicle(this._group_id, v);
		AIVehicle.StartStopVehicle(v);
	}
	return true;
}

function TruckLine::CheckVehicles()
{
	this._vehicle_list = AIList(); // This is so we can use RemoveItem later on.
	this._vehicle_list.AddList(AIVehicleList_Station(this._station_from.GetStationID()));
	if (!this._valid) return;
	if (!AIIndustry.IsValidIndustry(this._ind_from) || (this._ind_to != null && !AIIndustry.IsValidIndustry(this._ind_to))) {
		this.CloseRoute();
		return;
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
		::vehicles_to_sell.AddItem(v, 0);
		this._station_from.RemoveTrucks(1, this._distance, AIEngine.GetMaxSpeed(this._engine_id));
		this._station_to.RemoveTrucks(1, this._distance, AIEngine.GetMaxSpeed(this._engine_id));
	}

	local list = AIList();
	list.AddList(this._vehicle_list);
	list.Valuate(AIOrder.GetOrderDestination, AIOrder.CURRENT_ORDER);
	list.KeepValue(AIStation.GetLocation(this._station_from.GetStationID()));
	list.Valuate(AIVehicle.GetCurrentSpeed);
	list.KeepBelowValue(10);
	list.Valuate(Utils.VehicleManhattanDistanceToTile, AIStation.GetLocation(this._station_from.GetStationID()));
	list.KeepBelowValue(7);
	list.Valuate(AIVehicle.GetState);
	list.KeepValue(AIVehicle.VS_RUNNING);
	if (list.Count() > 2) {
		list.Valuate(AIVehicle.GetAge);
		list.Sort(AIAbstractList.SORT_BY_VALUE, false);
		local v = list.Begin();
		this._vehicle_list.RemoveItem(v);
		AIVehicle.SendVehicleToDepot(v);
		::vehicles_to_sell.AddItem(v, 0);
		this._station_from.RemoveTrucks(1, this._distance, AIEngine.GetMaxSpeed(this._engine_id));
		this._station_to.RemoveTrucks(1, this._distance, AIEngine.GetMaxSpeed(this._engine_id));
	}

	for (local v = this._vehicle_list.Begin(); this._vehicle_list.HasNext(); this._vehicle_list.Next()) {
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

function TruckLine::_SortEngineList(engine_id)
{
	return AIEngine.GetCapacity(engine_id) * AIEngine.GetMaxSpeed(engine_id);
}

function TruckLine::_FindEngineID()
{
	this._vehicle_list = AIVehicleList_Station(this._station_from.GetStationID());
	local list = AIEngineList(AIVehicle.VEHICLE_ROAD);
	list.Valuate(AIEngine.GetRoadType);
	list.KeepValue(AIRoad.ROADTYPE_ROAD);
	list.Valuate(AIEngine.IsArticulated);
	list.KeepValue(0);
	list.Valuate(AIEngine.CanRefitCargo, this._cargo);
	list.KeepValue(1);
	list.Valuate(TruckLine._SortEngineList);
	list.Sort(AIAbstractList.SORT_BY_VALUE, false);
	local new_engine_id = null;
	if (list.Count() != 0) {
		new_engine_id = list.Begin();
	}
	if (this._engine_id != null && new_engine_id != null && this._engine_id != new_engine_id) {
		AIGroup.SetAutoReplace(this._group_id, this._engine_id, new_engine_id);
		this._station_from.RemoveTrucks(this._vehicle_list.Count(), this._distance, AIEngine.GetMaxSpeed(this._engine_id));
		this._station_to.RemoveTrucks(this._vehicle_list.Count(), this._distance, AIEngine.GetMaxSpeed(this._engine_id));
		this._station_from.AddTrucks(this._vehicle_list.Count(), this._distance, AIEngine.GetMaxSpeed(new_engine_id));
		this._station_to.AddTrucks(this._vehicle_list.Count(), this._distance, AIEngine.GetMaxSpeed(new_engine_id));
	}
	this._engine_id = new_engine_id;
}
