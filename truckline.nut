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
		this.BuildVehicles(4);
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
	_vehicle_list = null; ///< An AIList() containing all vehicles on this route.
	_depot_tile = null;   ///< A TileIndex indicating the depot that is used by this route (both to build new vehicles and to service existing ones).
	_cargo = null;        ///< The CargoID we are transporting.
	_engine_id = null;    ///< The EngineID of the vehicles on this route.

};

function TruckLine::BuildVehicles(num)
{
	local max_to_build = min(min(this._station_from.CanAddTrucks(num), this._station_to.CanAddTrucks(num)), num);
	if (max_to_build == 0) return;
	this._FindEngineID();
	for (local i = 0; i < max_to_build; i++) {
		local v = AIVehicle.BuildVehicle(this._depot_tile, this._engine_id);
		if (!AIVehicle.IsValidVehicle(v)) {
			if (AIError.GetLastError() == AIError.ERR_NOT_ENOUGH_CASH) return false;
			continue;
		}
		if (this._vehicle_list.Count() > 0) {
			AIOrder.ShareOrders(v, this._vehicle_list.Begin());
		} else {
			AIOrder.AppendOrder(v, AIStation.GetLocation(this._station_from.GetStationID()), AIOrder.AIOF_FULL_LOAD);
			AIOrder.AppendOrder(v, AIStation.GetLocation(this._station_to.GetStationID()), AIOrder.AIOF_UNLOAD);
			AIOrder.AppendOrder(v, this._depot_tile, AIOrder.AIOF_NONE);
			AIOrder.ChangeOrder(v, 2, AIOrder.AIOF_SERVICE_IF_NEEDED);
		}
		this._vehicle_list.AddItem(v, 0);
		this._station_from.AddTrucks(1);
		this._station_to.AddTrucks(1);
		AIVehicle.StartStopVehicle(v);
	}
	return true;
}

function TruckLine::CheckVehicles()
{
	if (this._vehicle_list == null) return;
	this._vehicle_list.Valuate(AIVehicle.IsValidVehicle);
	this._vehicle_list.KeepValue(1);
	local list = AIList();
	list.AddList(this._vehicle_list);
	list.Valuate(AIVehicle.GetAge);
	list.KeepAboveValue(700);
	list.Valuate(AIVehicle.GetProfitLastYear);
	list.KeepBelowValue(0);

	for (local v = list.Begin(); list.HasNext(); list.Next()) {
		this._vehicle_list.RemoveItem(v);
		AIVehicle.SendVehicleToDepot(v);
		::vehicles_to_sell.AddItem(v, 0);
	}

	for (local v = this._vehicle_list.Begin(); this._vehicle_list.HasNext(); this._vehicle_list.Next()) {
		if (AIVehicle.GetState(v) == AIVehicle.VS_STOPPED) AIVehicle.StartStopVehicle(v);
	}

	/* Only build new vehicles if we didn't sell any. */
	if (list.Count() == 0) {
		local cargo_waiting = AIStation.GetCargoWaiting(this._station_from.GetStationID(), this._cargo);
		local num_new =  0;
		if (cargo_waiting > 150) {
			list = AIList();
			list.AddList(this._vehicle_list);
			list.Valuate(AIVehicle.GetAge);
			list.KeepBelowValue(250);
			local num_young_vehicles = list.Count();
			num_new = cargo_waiting / 60 - max(0, num_young_vehicles);
			num_new = min(num_new, 8); // Don't build more than 8 new vehicles a time.
		}
		if (num_new > 0) return !this.BuildVehicles(num_new);
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
	local list = AIEngineList(AIVehicle.VEHICLE_ROAD);
	list.Valuate(AIEngine.CanRefitCargo, this._cargo);
	list.KeepValue(1);
	list.Valuate(TruckLine._SortEngineList);
	list.Sort(AIAbstractList.SORT_BY_VALUE, false);
	this._engine_id = list.Begin();
}
