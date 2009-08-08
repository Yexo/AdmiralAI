class BusLine
{
	_station_from = null;
	_station_to = null;
	_vehicle_list = null;
	_depot_tile = null;
	_cargo = null;
	_engine_id = null;
	_depot_tile = null;

	constructor(station_from, station_to, depot_tile, cargo)
	{
		this._station_from = station_from;
		this._station_to = station_to;
		this._vehicle_list = AIList();
		this._depot_tile = depot_tile;
		this._cargo = cargo;
		this.BuildVehicles(6);
	}

	function CheckVehicles();
}

function BusLine::_SortEngineList(engine_id)
{
	return AIEngine.GetCapacity(engine_id) * AIEngine.GetMaxSpeed(engine_id);
}

function BusLine::_FindEngineID()
{
	local list = AIEngineList(AIVehicle.VEHICLE_ROAD);
	list.Valuate(AIEngine.CanRefitCargo, this._cargo);
	list.KeepValue(1);
	list.Valuate(this._SortEngineList);
	list.Sort(AIAbstractList.SORT_BY_VALUE, false);
	this._engine_id = list.Begin();
}

function BusLine::BuildVehicles(num)
{
	local max_to_build = min(min(this._station_from.CanAddBusses(num), this._station_to.CanAddBusses(num)), num);
	if (max_to_build == 0) return;
	this._FindEngineID();
	for (local i = 0; i < num; i++) {
		local v = AIVehicle.BuildVehicle(this._depot_tile, this._engine_id);
		if (!AIVehicle.IsValidVehicle(v)) continue;
		if (this._vehicle_list.Count() > 0) {
			AIOrder.ShareOrders(v, this._vehicle_list.Begin());
		} else {
			AIOrder.AppendOrder(v, AIStation.GetLocation(this._station_from.GetStationID()), AIOrder.AIOF_NONE);
			AIOrder.AppendOrder(v, AIStation.GetLocation(this._station_to.GetStationID()), AIOrder.AIOF_NONE);
			AIOrder.AppendOrder(v, this._depot_tile, AIOrder.AIOF_NONE);
			AIOrder.ChangeOrder(v, 2, AIOrder.AIOF_SERVICE_IF_NEEDED);
		}
		this._vehicle_list.AddItem(v, 0);
		this._station_from.AddBusses(1);
		this._station_to.AddBusses(1);
		AIVehicle.StartStopVehicle(v)
	}
}

function BusLine::CheckVehicles()
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

	if (list.Count() == 0) {
		local cargo_waiting_a = AIStation.GetCargoWaiting(this._station_from.GetStationID(), this._cargo);
		local cargo_waiting_b = AIStation.GetCargoWaiting(this._station_to.GetStationID(), this._cargo);
		local num_new =  0;
		if (max(cargo_waiting_a, cargo_waiting_b) > 150) {
			list = AIList();
			list.AddList(this._vehicle_list);
			list.Valuate(AIVehicle.GetAge);
			list.KeepBelowValue(250);
			local num_young_vehicles = list.Count();
			num_new = max(cargo_waiting_a, cargo_waiting_b) / 60 - max(0, num_young_vehicles);
			num_new = min(num_new, 8); // Don't build more than 8 new vehicles a time.
		}
		if (num_new > 0) this.BuildVehicles(num_new);
	}
}
