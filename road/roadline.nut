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

/** @file roadline.nut Implementation of RoadLine. */

/**
 * Base class for BusLine and TruckLine.
 */
class RoadLine
{
	_station_from = null; ///< The StationManager managing the first station.
	_station_to = null;   ///< The StationManager managing the second station.
	_vehicle_list = null; ///< An AIList() containing all vehicles on this route.
	_depot_tile = null;   ///< A TileIndex indicating the depot that is used by this route (both to build new vehicles and to service existing ones).
	_cargo = null;        ///< The CargoID of the cargo we'll transport.
	_engine_id = null;    ///< The EngineID of the vehicles on this route.
	_group_id = null;     ///< The GroupID of the group all vehicles from this route are in.
	_distance = null;     ///< The manhattan distance between the two stations.
	_support_articulated = null;
	_road_type = null;

/* public: */

	/**
	 * Create a road vehicle line.
	 * @param station_from A StationManager corresponding with the first station.
	 * @param station_to A StationManager corresponding with the second station.
	 * @param depot_tile A TileIndex on which a road depot has been built.
	 * @param cargo The CargoID of the cargo we'll transport.
	 */
	constructor(station_from, station_to, depot_tile, cargo, create_group, support_articulated = false, road_type = null)
	{
		this._station_from = station_from;
		this._station_to = station_to;
		this._vehicle_list = AIList();
		this._depot_tile = depot_tile;
		this._cargo = cargo;
		this._support_articulated = support_articulated;
		this._road_type = road_type == null ? AIRoad.GetCurrentRoadType() : road_type;
		if (create_group) {
			this._group_id = AIGroup.CreateGroup(AIVehicle.VT_ROAD);
			this.RenameGroup();
		}
		this._distance = AIMap.DistanceManhattan(AIStation.GetLocation(station_from.GetStationID()), AIStation.GetLocation(station_to.GetStationID()));
	}

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
};

function RoadLine::RenameGroup()
{
	local new_name = AICargo.GetCargoLabel(this._cargo) + ": " + AIStation.GetName(this._station_from.GetStationID()) + " - " + AIStation.GetName(this._station_to.GetStationID());
	new_name = new_name.slice(0, min(new_name.len(), 30));
	AIGroup.SetName(this._group_id, new_name);
}

function RoadLine::GetStationFrom()
{
	return this._station_from;
}

function RoadLine::GetStationTo()
{
	return this._station_to;
}

function RoadLine::UpdateVehicleList()
{
	this._vehicle_list = AIList();
	this._vehicle_list.AddList(AIVehicleList_Station(this._station_from.GetStationID()));
	this._vehicle_list.RemoveList(::main_instance.sell_vehicles);
}

function RoadLine::_SortEngineList(engine_id)
{
	return AIEngine.GetCapacity(engine_id) * AIEngine.GetMaxSpeed(engine_id);
}

function RoadLine::_FindEngineID()
{
	this.UpdateVehicleList();
	local list = AIEngineList(AIVehicle.VT_ROAD);
	list.Valuate(AIEngine.GetRoadType);
	list.KeepValue(this._road_type);
	if (!this._support_articulated) {
		list.Valuate(AIEngine.IsArticulated);
		list.KeepValue(0);
	}
	list.Valuate(AIEngine.CanRefitCargo, this._cargo);
	list.KeepValue(1);
	Utils_Valuator.Valuate(list, this._SortEngineList);
	list.Sort(AIAbstractList.SORT_BY_VALUE, AIAbstractList.SORT_DESCENDING);
	local new_engine_id = null;
	if (list.Count() != 0) {
		new_engine_id = list.Begin();
	}
	if (this._engine_id != null && new_engine_id != null && this._engine_id != new_engine_id) {
		this._AutoReplace(this._engine_id, new_engine_id);
	}
	this._engine_id = new_engine_id;
}

function RoadLine::InitiateAutoReplace()
{
	this._FindEngineID();
	if (this._engine_id == null) return;

	this.UpdateVehicleList();
	this._vehicle_list.Valuate(AIVehicle.GetEngineType);
	local old_engines = AIList();
	foreach (v, engine_id in this._vehicle_list) {
		old_engines.AddItem(engine_id, 0);
	}
	old_engines.RemoveItem(this._engine_id);
	foreach (engine_id, dummy in old_engines) {
		this._AutoReplace(engine_id, this._engine_id);
	}
}
