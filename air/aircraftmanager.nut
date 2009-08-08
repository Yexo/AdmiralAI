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

/** @file aircraftmanager.nut Implemenation of AircraftManager. */

/**
 * Class that manages all aircraft routes.
 */
class AircraftManager
{
/* public: */

	/**
	 * Create a aircraft manager.
	 */
	constructor(town_manager_table)
	{
		local cargo_list = AICargoList();
		cargo_list.Valuate(AICargo.HasCargoClass, AICargo.CC_PASSENGERS);
		if (cargo_list.Count() == 0) {
			/* There is no passenger cargo, so AircraftManager is useless. */
			this._cargo_id = null;
			return;
		}
		if (cargo_list.Count() > 1) {
			local town_list = AITownList();
			town_list.Valuate(AITown.GetPopulation);
			town_list.Sort(AIAbstractList.SORT_BY_VALUE, false);
			local best_cargo = null;
			local best_cargo_acceptance = 0;
			foreach (cargo, dummy in cargo_list) {
				local acceptance = AITile.GetCargoAcceptance(AITown.GetLocation(town_list.Begin()), cargo, 1, 1, 5);
				if (acceptance > best_cargo_acceptance) {
					best_cargo_acceptance = acceptance;
					best_cargo = cargo;
				}
			}
			this._cargo_id = best_cargo;
		} else {
			this._cargo_id = cargo_list.Begin();
		}
		this._town_managers = town_manager_table;
		this._engine_id = null;
	}

/* private: */

	_town_managers = null;
	_cargo_id = null;
	_small_engine_id = null;
	_engine_id = null;
	_small_engine_group = null;
	_big_engine_group = null;
};

function AircraftManager::AfterLoad()
{
	this._small_engine_group = AIGroup.CreateGroup(AIVehicle.VEHICLE_AIR);
	AIGroup.SetName(this._small_engine_group, "Small planes");
	this._big_engine_group = AIGroup.CreateGroup(AIVehicle.VEHICLE_AIR);
	AIGroup.SetName(this._big_engine_group, "Big planes");

	local station_list = AIStationList(AIStation.STATION_AIRPORT);
	station_list.Valuate(AIStation.GetNearestTown);
	foreach (station_id, town_id in station_list) {
		this._town_managers[town_id]._airports.push(station_id);
	}

	local vehicle_list = AIVehicleList();
	vehicle_list.Valuate(AIVehicle.GetVehicleType);
	vehicle_list.KeepValue(AIVehicle.VEHICLE_AIR);
	vehicle_list.Valuate(AIVehicle.GetEngineType);
	foreach (v, engine in vehicle_list) {
		if (AIEngine.IsBigPlane(engine)) {
			AIGroup.MoveVehicle(this._big_engine_group, v);
		} else {
			AIGroup.MoveVehicle(this._small_engine_group, v);
		}
	}
}

function AircraftManager::IsSmallAirport(airport)
{
	local type = AIAirport.GetAirportType(AIStation.GetLocation(airport));
	return type == AIAirport.AT_SMALL || type == AIAirport.AT_COMMUTER;
}

function AircraftManager::BuildNewRoute()
{
	this._FindEngineID();
	if (this._engine_id == null) return;

	foreach (manager in this._town_managers) {
		if (!manager.CanBuildAirport(this._cargo_id, this._small_engine_id != null)) continue;
		foreach (manager2 in this._town_managers) {
			local distance = AIMap.DistanceManhattan(AITown.GetLocation(manager._town_id), AITown.GetLocation(manager2._town_id));
			if (distance < 150 || distance > 300) continue;
			if (!manager2.CanBuildAirport(this._cargo_id, this._small_engine_id != null)) continue;
			AdmiralAI.Sleep(50);
			AILog.Info("From " + AITown.GetName(manager._town_id) + ", to " + AITown.GetName(manager2._town_id));
			local station_a = manager.BuildAirport(this._cargo_id, this._small_engine_id != null);
			if (station_a == null) break;
			local station_b = manager2.BuildAirport(this._cargo_id, this._small_engine_id != null);
			if (station_b == null) continue;

			local small_airport = this.IsSmallAirport(station_a) || this.IsSmallAirport(station_b);

			AdmiralAI.GetMoney(2 * AIEngine.GetPrice(small_airport ? this._small_engine_id : this._engine_id));
			local v = AIVehicle.BuildVehicle(AIAirport.GetHangarOfAirport(AIStation.GetLocation(station_a)), small_airport ? this._small_engine_id : this._engine_id);
			if (!AIVehicle.IsValidVehicle(v)) {
				AILog.Info("Building plane failed: " + AIError.GetLastErrorString());
				return false;
			}
			AIOrder.AppendOrder(v, AIStation.GetLocation(station_a), AIOrder.AIOF_NONE);
			AIOrder.AppendOrder(v, AIStation.GetLocation(station_b), AIOrder.AIOF_NONE);
			AIVehicle.StartStopVehicle(v);
			v = AIVehicle.BuildVehicle(AIAirport.GetHangarOfAirport(AIStation.GetLocation(station_b)), small_airport ? this._small_engine_id : this._engine_id);
			if (!AIVehicle.IsValidVehicle(v)) {
				AILog.Info("Building plane failed: " + AIError.GetLastErrorString());
				return false;
			}
			AIOrder.AppendOrder(v, AIStation.GetLocation(station_b), AIOrder.AIOF_NONE);
			AIOrder.AppendOrder(v, AIStation.GetLocation(station_a), AIOrder.AIOF_NONE);
			AIVehicle.StartStopVehicle(v);
			return true;
		}
	}
	return false;
}

function AircraftManager::_SortEngineList(engine_id)
{
	return AIEngine.GetCapacity(engine_id) * AIEngine.GetMaxSpeed(engine_id);
}

function AircraftManager::_FindEngineID()
{
	local list = AIEngineList(AIVehicle.VEHICLE_AIR);
	list.Valuate(AIEngine.GetPlaneType);
	list.RemoveValue(AIAirport.PT_HELICOPTER);
	list.Valuate(this._SortEngineList);
	list.Sort(AIAbstractList.SORT_BY_VALUE, false);
	local new_engine_id = null;
	if (list.Count() != 0) {
		new_engine_id = list.Begin();
		if (this._engine_id != null && this._engine_id != new_engine_id) {
			AIGroup.SetAutoReplace(this._big_engine_group, this._engine_id, new_engine_id);
		}
	}
	this._engine_id = new_engine_id;

	local list = AIEngineList(AIVehicle.VEHICLE_AIR);
	list.Valuate(AIEngine.GetPlaneType);
	list.KeepValue(AIAirport.PT_SMALL_PLANE);
	list.Valuate(this._SortEngineList);
	list.Sort(AIAbstractList.SORT_BY_VALUE, false);
	local new_engine_id = null;
	if (list.Count() != 0) {
		new_engine_id = list.Begin();
		if (this._small_engine_id != null && this._small_engine_id != new_engine_id) {
			AIGroup.SetAutoReplace(this._small_engine_group, this._small_engine_id, new_engine_id);
		}
	}
	this._small_engine_id = new_engine_id;
}

function AircraftManager::_AutoReplace(old_engine_id, new_engine_id)
{
	AIGroup.SetAutoReplace(AIGroup.ALL_GROUP, old_engine_id, new_engine_id);
}
