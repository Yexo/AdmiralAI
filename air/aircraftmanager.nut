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
 * Copyright 2008-2009 Thijs Marinussen
 */

/** @file aircraftmanager.nut Implemenation of AircraftManager. */

/**
 * Class that manages all aircraft routes.
 */
class AircraftManager
{
	_small_engine_id = null;    ///< The EngineID of newly build small planes.
	_engine_id = null;          ///< The EngineID of newly build big planes.
	_small_engine_group = null; ///< The GroupID of all small planes.
	_big_engine_group = null;   ///< The GroupID of all big planes.

/* public: */

	/**
	 * Create a aircraft manager.
	 */
	constructor()
	{
		this._engine_id = null;
	}

	/**
	 * Load all information not specially saved by the AI. This way it's easier
	 *  to load a savegame saved by another AI.
	 */
	function AfterLoad();

	/**
	 * Build a new air route. First all existing airports are scanned if some of
	 *  them need more planes, if not, more airports are build.
	 * @return True if and only if a new route was succesfully created.
	 */
	function BuildNewRoute();

/* private: */

	/**
	 * A valuator for planes engines. Currently it depends linearly on both
	 *  capacity and speed, but this will change in the future.
	 * @return A higher value if the engine is better.
	 */
	function _SortEngineList(engine_id);

	/**
	 * Find out what the best EngineID is and store it in _engine_id and
	 *  _small_engine_id. If the EngineID changes, set autoreplace from the old
	 *  to the new type.
	 */
	function _FindEngineID();

	/**
	 * A valuator to determine the order in which towns are searched. The value
	 *  is random but with respect to the town population.
	 * @param town_id The town to get a value for.
	 * @return A value for the town.
	 */
	function _TownValuator(town_id);
};

function AircraftManager::AfterLoad()
{
	/* (Re)create the groups so we can seperatly autoreplace big and small planes. */
	this._small_engine_group = AIGroup.CreateGroup(AIVehicle.VT_AIR);
	AIGroup.SetName(this._small_engine_group, "Small planes");
	this._big_engine_group = AIGroup.CreateGroup(AIVehicle.VT_AIR);
	AIGroup.SetName(this._big_engine_group, "Big planes");

	/* Add all existing airports to the relevant townmanager. */
	local station_list = AIStationList(AIStation.STATION_AIRPORT);
	station_list.Valuate(AIStation.GetNearestTown);
	foreach (station_id, town_id in station_list) {
		if (Utils_Airport.IsHeliport(station_id)) {
			/* We don't support heliports, so sell it. */
			::main_instance.sell_stations.append([station_id, AIStation.STATION_AIRPORT]);
		} else {
			::main_instance._town_managers[town_id]._airports.push(station_id);
		}
	}

	/* Move all planes in the relevant groups. Because helicopters are not
	 * supported they are all sold. */
	/* TODO: check if any big planes are going to small airports and
	 * reroute or replace them? */
	/* TODO: evaluate airport orders (they might be from another AI. */
	local vehicle_list = AIVehicleList();
	vehicle_list.Valuate(AIVehicle.GetVehicleType);
	vehicle_list.KeepValue(AIVehicle.VT_AIR);
	vehicle_list.Valuate(AIVehicle.GetEngineType);
	foreach (v, engine in vehicle_list) {
		if (AIEngine.GetPlaneType(engine) == AIAirport.PT_BIG_PLANE) {
			AIGroup.MoveVehicle(this._big_engine_group, v);
		} else if (AIEngine.GetPlaneType(engine) == AIAirport.PT_SMALL_PLANE) {
			AIGroup.MoveVehicle(this._small_engine_group, v);
		} else {
			::main_instance.sell_vehicles.AddItem(v, 0);
		}
	}
}

function AircraftManager::_TownValuator(town_id)
{
	return AIBase.RandRange(AITown.GetPopulation(town_id));
}

function AircraftManager::BuildPlanes(station_a, station_b)
{
	local small_airport = Utils_Airport.IsSmallAirport(station_a) || Utils_Airport.IsSmallAirport(station_b);

	/* Make sure we have enough money to buy two planes. */
	/* TODO: there is no check if enough money is available, so possible
	 * we can't even buy one plane (if they are really expensive. */
	Utils_General.GetMoney(2 * AIEngine.GetPrice(small_airport ? this._small_engine_id : this._engine_id));

	/* Build the first plane at the first airport. */
	local v = AIVehicle.BuildVehicle(AIAirport.GetHangarOfAirport(AIStation.GetLocation(station_a)), small_airport ? this._small_engine_id : this._engine_id);
	if (!AIVehicle.IsValidVehicle(v)) {
		AILog.Error("Building plane failed: " + AIError.GetLastErrorString());
		return false;
	}
	/* Add the vehicle to the right group. */
	AIGroup.MoveVehicle(small_airport ? this._small_engine_group : this._big_engine_group, v);
	/* Add the orders to the vehicle. */
	AIOrder.AppendOrder(v, AIStation.GetLocation(station_a), AIOrder.AIOF_NONE);
	AIOrder.AppendOrder(v, AIStation.GetLocation(station_b), AIOrder.AIOF_NONE);
	AIVehicle.StartStopVehicle(v);

	/* Clone the first plane, but build it at the second airport. */
	v = AIVehicle.CloneVehicle(AIAirport.GetHangarOfAirport(AIStation.GetLocation(station_b)), v, false);
	if (!AIVehicle.IsValidVehicle(v)) {
		AILog.Warning("Cloning plane failed: " + AIError.GetLastErrorString());
		/* Since the first plane was build succesfully, return true. */
		return true;
	}
	/* Add the vehicle to the right group. */
	AIGroup.MoveVehicle(small_airport ? this._small_engine_group : this._big_engine_group, v);
	/* Start with going to the second airport. */
	AIVehicle.SkipToVehicleOrder(v, 1);
	AIVehicle.StartStopVehicle(v);

	return true;
}

function AircraftManager::MinimumPassengerAcceptance(airport_type)
{
	if (!AIGameSettings.GetValue("station.modified_catchment")) return 40;
	switch (airport_type) {
		case AIAirport.AT_SMALL:         return 40;
		case AIAirport.AT_LARGE:         return 80;
		case AIAirport.AT_METROPOLITAN:  return 80;
		case AIAirport.AT_INTERNATIONAL: return 100;
		case AIAirport.AT_COMMUTER:      return 40;
		case AIAirport.AT_INTERCON:      return 100;
		default: throw("AircraftManager::MinimumPassengerAcceptance for unknown airport type");
	}
}

function AircraftManager::BuildNewRoute()
{
	/* First update the type of vehicle we will build. */
	this._FindEngineID();
	if (this._engine_id == null) return;

	/* We want to search all towns for highest to lowest population but in a
	 * somewhat random order. */
	local town_list = AITownList();
	Utils_Valuator.Valuate(town_list, this._TownValuator);
	town_list.Sort(AIAbstractList.SORT_BY_VALUE, false);
	local town_list2 = AIList();
	town_list2.AddList(town_list);

	/* Check if we can add planes to some already existing airports. */
	foreach (town_from, d in town_list) {
		/* Check if there is an airport in the first town that needs extra planes. */
		local manager = ::main_instance._town_managers[town_from];
		local station_a = manager.GetExistingAirport(this._small_engine_id != null);
		if (station_a == null) continue;

		foreach (town_to, d in town_list2) {
			/* Check the distance between the towns. */
			local distance = AIMap.DistanceManhattan(AITown.GetLocation(town_from), AITown.GetLocation(town_to));
			if (distance < 150 || distance > 300) continue;

			/* Check if there is an airport in the second town that needs extra planes. */
			local manager2 = ::main_instance._town_managers[town_to];
			local station_b = manager2.GetExistingAirport(this._small_engine_id != null);
			if (station_b == null) continue;

			return this.BuildPlanes(station_a, station_b);
		}
	}

	local skip_towns = AIList();
	/* If there is an exising airport that can use more planes, build a new one
	 * so more planes can be added to the existing one. */
	foreach (town_from, d in town_list) {
		/* Check if there is an airport in the first town that needs extra planes. */
		local manager = ::main_instance._town_managers[town_from];
		local station_a = manager.GetExistingAirport(this._small_engine_id != null);
		if (station_a == null) continue;
		skip_towns.AddItem(town_from, 0);

		foreach (town_to, d in town_list2) {
			/* Check the distance between the towns. */
			local distance = AIMap.DistanceManhattan(AITown.GetLocation(town_from), AITown.GetLocation(town_to));
			if (distance < 150 || distance > 300) continue;

			/* Check if an airport can be build in the second town. */
			local manager2 = ::main_instance._town_managers[town_to];
			if (!manager2.CanBuildAirport(this._small_engine_id != null)) continue;

			/* Build the new airport. */
			local station_b = manager2.BuildAirport(this._small_engine_id != null);
			if (station_b == null) continue;

			return this.BuildPlanes(station_a, station_b);
		}
	}

	town_list.RemoveList(skip_towns);
	town_list2.RemoveList(skip_towns);
	foreach (town_from, d in town_list) {
		/* Check if an airport can be build in the first town. */
		local manager = ::main_instance._town_managers[town_from];
		if (!manager.CanBuildAirport(this._small_engine_id != null)) continue;

		foreach (town_to, d in town_list2) {
			/* Check the distance between the towns. */
			local distance = AIMap.DistanceManhattan(AITown.GetLocation(town_from), AITown.GetLocation(town_to));
			if (distance < 150 || distance > 300) continue;

			/* Check if an airport can be build in the second town. */
			local manager2 = ::main_instance._town_managers[town_to];
			if (!manager2.CanBuildAirport(this._small_engine_id != null)) continue;

			/* Build both airports. */
			local station_a = manager.BuildAirport(this._small_engine_id != null);
			if (station_a == null) break;
			local station_b = manager2.BuildAirport(this._small_engine_id != null);
			if (station_b == null) continue;

			return this.BuildPlanes(station_a, station_b);
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
	/* First find the EngineID for new big planes. */
	local list = AIEngineList(AIVehicle.VT_AIR);
	Utils_Valuator.Valuate(list, this._SortEngineList);
	list.Sort(AIAbstractList.SORT_BY_VALUE, false);
	local new_engine_id = null;
	if (list.Count() != 0) {
		new_engine_id = list.Begin();
		/* If both the old and the new id are valid and they are different,
		 *  initiate autoreplace from the old to the new type. */
		if (this._engine_id != null && new_engine_id != null && this._engine_id != new_engine_id) {
			AIGroup.SetAutoReplace(this._big_engine_group, this._engine_id, new_engine_id);
		}
	}
	this._engine_id = new_engine_id;

	/* And now also for small planes. */
	local list = AIEngineList(AIVehicle.VT_AIR);
	/* Only small planes allowed, no big planes or helicopters. */
	list.Valuate(AIEngine.GetPlaneType);
	list.RemoveValue(AIAirport.PT_BIG_PLANE);
	Utils_Valuator.Valuate(list, this._SortEngineList);
	list.Sort(AIAbstractList.SORT_BY_VALUE, false);
	local new_engine_id = null;
	if (list.Count() != 0) {
		new_engine_id = list.Begin();
		/* If both the old and the new id are valid and they are different,
		 *  initiate autoreplace from the old to the new type. */
		if (this._small_engine_id != null && new_engine_id != null && this._small_engine_id != new_engine_id) {
			AIGroup.SetAutoReplace(this._small_engine_group, this._small_engine_id, new_engine_id);
		}
	}
	this._small_engine_id = new_engine_id;
}
