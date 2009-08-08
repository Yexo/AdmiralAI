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

/** @file main.nut Implementation of AdmiralAI, containing the main loop. */

main_instance <- null;
//local main_instance;

import("queue.fibonacci_heap", "FibonacciHeap", 1);

require("utils/airport.nut");
require("utils/array.nut");
require("utils/general.nut");
require("utils/tile.nut");
require("utils/valuator.nut");

require("stationmanager.nut");
require("townmanager.nut");
require("aystar.nut");

require("air/aircraftmanager.nut");

require("road/rpf.nut");
require("road/routebuilder.nut");
require("road/routefinder.nut");
require("road/roadline.nut");
require("road/busline.nut");
require("road/truckline.nut");
require("road/buslinemanager.nut");
require("road/trucklinemanager.nut");

require("rail/railpathfinder.nut");
require("rail/railfollower.nut");
require("rail/trainmanager.nut");
require("rail/railroutebuilder.nut");
require("rail/trainline.nut");


/**
 * @todo
 *  - Inner town routes. Not that important since we have multiple bus stops per town.
 *  - Amount of vehicles build initially should depend not only on distance but also on production.
 *  - optimize rpf estimate function by adding 1 turn and height difference. (could be committed)
 *  - If we can't transport more cargo to a certain station, try to find / build a new station we can transport
 *     the goods to and split it.
 *  - Try to stationwalk.
 *  - Build road stations up or down a hill.
 *  - Check if a station stopped accepting a certain cargo: if so, stop accepting more trucks for that cargo
 *     and send a few of the existing trucks to another destination.
 *  - Try to transport oil from oilrigs to the coast with ships, and then to a refinery with road vehicles. Better
 *     yet would be to directly transport it to oilrigs if distances is small enough, otherwise option 1.
 * @bug
 *  - When building a truck station near a city, connecting it with the road may fail. Either demolish some tiles
 *     or just pathfind from station to other industry, so even though the first part was difficult, a route is build.
 *  - If building a truck station near an industry failed, don't try again. Better yet: pathfind first, if succesfull
 *     try to build a truck station and connect it with the endpoint, if twice successfull (both stations), then build the route
 *  - Don't keep trying to connect a station when pathfinding has already failed a few times (ie a station on an island).
 */

/**
 * The main class of AdmiralAI.
 */
class AdmiralAI extends AIController
{
/* private: */

	_passenger_cargo_id = null;        ///< The CargoID of the main passenger cargo.
	_town_managers = null;             ///< A table mapping TownID to TownManager.
	_truck_manager = null; ///< The TruckLineManager managing all truck lines.
	_bus_manager = null;   ///< The BusLineManager managing all bus lines.
	_aircraft_manager = null; ///< The AircraftManager managing all air routes.
	_train_manager = null;  ///< The TrainManager managing all train routes.
	_pending_events = null; ///< An array containing [EventType, value] pairs of unhandles events.
	_save_data = null;      ///< Cache of save data during load.
	last_vehicle_check = null;
	last_cash_output = null;
	last_improve_buslines_date = null;
	need_vehicle_check = null;
	sell_stations = null;
	sell_vehicles = null;
	_sorted_cargo_list = null;
	_sorted_cargo_list_updated = null;

/* public: */

	constructor() {
		main_instance = this;
		local cargo_list = AICargoList();
		cargo_list.Valuate(AICargo.HasCargoClass, AICargo.CC_PASSENGERS);
		if (cargo_list.Count() == 0) {
			throw("No passenger cargo found.");
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
			this._passenger_cargo_id = best_cargo;
		} else {
			this._passenger_cargo_id = cargo_list.Begin();
		}

		this._town_managers = {};
		local town_list = AITownList();
		foreach (town, dummy in town_list) {
			this._town_managers.rawset(town, TownManager(town));
		}

		this._truck_manager = TruckLineManager();
		this._bus_manager = BusLineManager();
		this._aircraft_manager = AircraftManager();
		this._train_manager = TrainManager();
		this._pending_events = [];

		this._save_data = null;

		this.last_vehicle_check = 0;
		this.last_cash_output = AIDate.GetCurrentDate();
		this.last_improve_buslines_date = 0;
		this.need_vehicle_check = false;
		this.sell_stations = [];
		this.sell_vehicles = AIList();
		this._sorted_cargo_list_updated = 0;
	}

	/**
	 * Save all data we need to be able to resume later.
	 * @return A table containing all data that needs to be saved.
	 * @note This is called by OpenTTD, no need to call from within the AI.
	 */
	function Save();

	/**
	 * Try to resume given the data in the savegame.
	 * @param data The data that was stored by Save().
	 * @note The data might have been saved by another AI, so check all
	 *   values for sanity. Don't asume the savegame data is from this AI.
	 */
	function Load(data);

	/**
	 * Get all events from AIEventController and store them in an
	 *   in an internal array.
	 */
	function GetEvents();

	/**
	 * Try to find a connected depot in the neighbourhood of a tile.
	 * @param roadtile The tile to start searching.
	 * @return Either a TileIndex of a depot or null.
	 */
	static function ScanForDepot(roadtile);

	/**
	 * Try to build a depot in the neighbourhood of a tile.
	 * @param roadtile The tile to build a depot near.
	 * @return The TileIndex of a depot or null.
	 * @note This calls AdmiralAI::ScanForDepot first, so there is no need to
	 *   do that explicitly.
	 */
	static function BuildDepot(roadtile);

	/**
	 * Handle all pending events. Events are stored internal in the _pending_events
	 *  array as [AIEventType, value] pair. The value that is saved depends on the
	 *  events. For example, for AI_ET_INDUSTRY_CLOSE the IndustryID is saved in value.
	 */
	function HandleEvents();

	/**
	 * Try to send all vehicles that will be sold off to a depot. If this fails try
	 *   to turn a vehicles and then send it again to a depot.
	 */
	static function SendVehicleToSellToDepot();

	/**
	 * The mainloop.
	 * @note This is called by OpenTTD, no need to call from within the AI.
	 */
	function Start();
};

function AdmiralAI::CargoValuator(cargo_id)
{
	local val = AICargo.GetCargoIncome(cargo_id, 80, 40);
	return val + (AIBase.RandRange(val) / 5);
}

function AdmiralAI::GetSortedCargoList()
{
	if (AIDate.GetCurrentDate() - this._sorted_cargo_list_updated > 200) {
		this._sorted_cargo_list = AICargoList();
		this._sorted_cargo_list.Valuate(AdmiralAI.CargoValuator);
		this._sorted_cargo_list.Sort(AIAbstractList.SORT_BY_VALUE, false);
	}
	return this._sorted_cargo_list;
}

function AdmiralAI::Save()
{
	if (this._save_data != null) return this._save_data;

	local data = {};
	local to_sell = [];
	foreach (veh, dummy in this.sell_vehicles) {
		to_sell.push(veh);
	}
	data.rawset("admiralai_version", "17");
	data.rawset("vehicles_to_sell", to_sell);
	data.rawset("stations_to_sell", this.sell_stations);
	data.rawset("trucklinemanager", this._truck_manager.Save());
	data.rawset("buslinemanager", this._bus_manager.Save());
	data.rawset("trainmanager", this._train_manager.Save());

	this.GetEvents();
	data.rawset("pending_events", this._pending_events);

	return data;
}

function AdmiralAI::Load(data)
{
	this._save_data = data;

	if (data.rawin("admiralai_version")) {
		AILog.Info("Loading savegame saved with AdmiralAI " + data.rawget("admiralai_version"));
	} else {
		AILog.Warning("Loading savegame saved with AdmiralAI v16.2 or older or with another AI.");
	}

	if (data.rawin("vehicles_to_sell")) {
		foreach (v in data.rawget("vehicles_to_sell")) {
			if (AIVehicle.IsValidVehicle(v)) this.sell_vehicles.AddItem(v, 0);
		}
	}

	if (data.rawin("stations_to_sell")) {
		this.sell_stations = data.rawget("stations_to_sell");
	}

	if (data.rawin("trucklinemanager")) {
		this._truck_manager.Load(data.rawget("trucklinemanager"));
	}

	if (data.rawin("buslinemanager")) {
		this._bus_manager.Load(data.rawget("buslinemanager"));
	}

	if (data.rawin("trainmanager")) {
		this._train_manager.Load(data.rawget("trainmanager"));
	}

	if (data.rawin("pending_events")) {
		this._pending_events = data.rawget("pending_events");
	}
}

function AdmiralAI::GetEvents()
{
	while (AIEventController.IsEventWaiting()) {
		local e = AIEventController.GetNextEvent();
		switch (e.GetEventType()) {
			case AIEvent.AI_ET_VEHICLE_WAITING_IN_DEPOT:
				local c = AIEventVehicleWaitingInDepot.Convert(e);
				this._pending_events.push([AIEvent.AI_ET_VEHICLE_WAITING_IN_DEPOT, c.GetVehicleID()]);
				break;

			case AIEvent.AI_ET_INDUSTRY_CLOSE:
				local ind = AIEventIndustryClose.Convert(e).GetIndustryID();
				this._pending_events.push([AIEvent.AI_ET_INDUSTRY_CLOSE, ind]);
				break;

			case AIEvent.AI_ET_INDUSTRY_OPEN:
				local ind = AIEventIndustryOpen.Convert(e).GetIndustryID();
				this._pending_events.push([AIEvent.AI_ET_INDUSTRY_OPEN, ind]);
				break;
		}
	}
}

function AdmiralAI::ScanForDepot(roadtile)
{
	local offsets = [AIMap.GetTileIndex(0,1), AIMap.GetTileIndex(0, -1),
	                 AIMap.GetTileIndex(1,0), AIMap.GetTileIndex(-1,0)];
	local tile_to_try = [roadtile];
	local tried = AIList();
	while (tile_to_try.len() > 0) {
		local cur_tile;
		cur_tile = tile_to_try[0];
		tile_to_try.remove(0);
		tried.AddItem(cur_tile, 0);
		foreach (offset in offsets) {
			if (AIRoad.AreRoadTilesConnected(cur_tile, cur_tile + offset)) {
				if (AIRoad.IsRoadDepotTile(cur_tile + offset) && AICompany.IsMine(AITile.GetOwner(cur_tile + offset))) return cur_tile + offset;
				if (!tried.HasItem(cur_tile + offset)) tile_to_try.push(cur_tile + offset);
				continue;
			}
		}
		if (AIMap.DistanceManhattan(roadtile, cur_tile) > 10) return null;
	}
	return null;
}

function AdmiralAI::BuildDepot(roadtile)
{
	local depot = AdmiralAI.ScanForDepot(roadtile);
	if (depot != null) return depot;
	local offsets = [AIMap.GetTileIndex(0,1), AIMap.GetTileIndex(0, -1),
	                 AIMap.GetTileIndex(1,0), AIMap.GetTileIndex(-1,0)];
	local tile_to_try = [roadtile];
	local tried = AIList();
	local to_skip = 15;
	while (tile_to_try.len() > 0) {
		local cur_tile;
		cur_tile = tile_to_try[0];
		tile_to_try.remove(0);
		tried.AddItem(cur_tile, 0);
		if (AIBridge.IsBridgeTile(cur_tile)) {
			cur_tile = AIBridge.GetOtherBridgeEnd(cur_tile);
			tried.AddItem(cur_tile, 0);
		}
		if (AITunnel.IsTunnelTile(cur_tile)) {
			cur_tile = AITunnel.GetOtherTunnelEnd(cur_tile);
			tried.AddItem(cur_tile, 0);
		}
		foreach (offset in offsets) {
			if (AIRoad.AreRoadTilesConnected(cur_tile, cur_tile + offset)) {
				if (AIRoad.IsRoadDepotTile(cur_tile + offset) && AICompany.IsMine(AITile.GetOwner(cur_tile + offset))) return cur_tile + offset;
				if (!tried.HasItem(cur_tile + offset)) tile_to_try.push(cur_tile + offset);
				continue;
			}
			if (to_skip > 0) {
				to_skip--;
				continue;
			}
			if (AICompany.IsMine(AITile.GetOwner(cur_tile + offset))) continue;
			if (AIRoad.IsRoadTile(cur_tile + offset)) continue;
			if (!AITile.DemolishTile(cur_tile + offset)) continue;
			local h = Utils_Tile.GetRealHeight(cur_tile);
			local h2 = Utils_Tile.GetRealHeight(cur_tile + offset);
			if (h2 > h) AITile.LowerTile(cur_tile + offset, AITile.GetSlope(cur_tile + offset));
			if (h > h2) AITile.RaiseTile(cur_tile + offset, AITile.GetComplementSlope(AITile.GetSlope(cur_tile + offset)));
			if (!AIRoad.BuildRoad(cur_tile + offset, cur_tile)) continue;
			if (!AITile.DemolishTile(cur_tile + offset)) continue;
			if (AIRoad.BuildRoadDepot(cur_tile + offset, cur_tile)) return cur_tile + offset;
		}
	}
	AILog.Error("Should never come here, unable to build depot!");
	return null;
}

function AdmiralAI::HandleEvents()
{
	foreach (event_pair in this._pending_events) {
		switch (event_pair[0]) {
			case AIEvent.AI_ET_VEHICLE_WAITING_IN_DEPOT:
				if (this.sell_vehicles.HasItem(event_pair[1])) {
					AIVehicle.SellVehicle(event_pair[1]);
					this.sell_vehicles.RemoveItem(event_pair[1]);
				}
				break;

			case AIEvent.AI_ET_INDUSTRY_CLOSE:
				this._truck_manager.IndustryClose(event_pair[1]);
				this._train_manager.IndustryClose(event_pair[1]);
				break;

			case AIEvent.AI_ET_INDUSTRY_OPEN:
				this._truck_manager.IndustryOpen(event_pair[1]);
				this._train_manager.IndustryOpen(event_pair[1]);
				break;
		}
	}
	this._pending_events = [];
}

function AdmiralAI::SendVehicleToSellToDepot()
{
	this.sell_vehicles.Valuate(AIVehicle.IsValidVehicle);
	this.sell_vehicles.KeepValue(1);
	foreach (vehicle, dummy in this.sell_vehicles) {
		local tile = AIOrder.GetOrderDestination(vehicle, AIOrder.CURRENT_ORDER);
		local dest_is_depot = false;
		switch (AIVehicle.GetVehicleType(vehicle)) {
			case AIVehicle.VEHICLE_RAIL:
				dest_is_depot = AIRail.IsRailDepotTile(tile);
				break;
			case AIVehicle.VEHICLE_ROAD:
				dest_is_depot = AIRoad.IsRoadDepotTile(tile);
				break;
			case AIVehicle.VEHICLE_WATER:
				dest_is_depot = AIMarine.IsWaterDepotTile(tile);
				break;
			case AIVehicle.VEHICLE_AIR:
				dest_is_depot = AIAirport.IsHangarTile(tile);
				break;
		}
		if (!dest_is_depot) {
			if (!AIVehicle.SendVehicleToDepot(vehicle)) {
				AIVehicle.ReverseVehicle(vehicle);
				AIController.Sleep(50);
				AIVehicle.SendVehicleToDepot(vehicle);
			}
		}
	}
}

function AdmiralAI::TransportCargo(cargo, ind)
{
	::main_instance._truck_manager.TransportCargo(cargo, ind);
	::main_instance._train_manager.TransportCargo(cargo, ind);
}

function AdmiralAI::UseVehicleType(vehicle_type)
{
	switch (vehicle_type) {
		case "planes": return !AIGameSettings.IsDisabledVehicleType(AIVehicle.VEHICLE_AIR) && this.GetSetting("use_planes") && AIGameSettings.GetValue("vehicle.max_aircraft") > 0;
		case "trains": return !AIGameSettings.IsDisabledVehicleType(AIVehicle.VEHICLE_RAIL) && this.GetSetting("use_trains") && AIGameSettings.GetValue("vehicle.max_trains") > 0;
		case "trucks": return !AIGameSettings.IsDisabledVehicleType(AIVehicle.VEHICLE_ROAD) && this.GetSetting("use_trucks") && AIGameSettings.GetValue("vehicle.max_roadveh") > 0;
		case "busses": return !AIGameSettings.IsDisabledVehicleType(AIVehicle.VEHICLE_ROAD) && this.GetSetting("use_busses") && AIGameSettings.GetValue("vehicle.max_roadveh") > 0;
		case "ships":  return !AIGameSettings.IsDisabledVehicleType(AIVehicle.VEHICLE_WATER) && this.GetSetting("use_ships") && AIGameSettings.GetValue("vehicle.max_ships") > 0;
	}
}

function AdmiralAI::SomeVehicleTypeAvailable()
{
	return this.UseVehicleType("planes") || this.UseVehicleType("trains") ||
		this.UseVehicleType("trucks") || this.UseVehicleType("busses");
	/* TODO: add ships here as soon as support for them is implemented. */
}

function AdmiralAI::DoMaintenance()
{
	this.GetEvents();
	this.HandleEvents();
	this.SendVehicleToSellToDepot();
	if (AIDate.GetCurrentDate() - this.last_cash_output > 90) {
		local curdate = AIDate.GetCurrentDate();
		AILog.Info("Current date: " + AIDate.GetYear(curdate) + "-" + AIDate.GetMonth(curdate) + "-" + AIDate.GetDayOfMonth(curdate));
		AILog.Info("Cash - loan: " + AICompany.GetBankBalance(AICompany.MY_COMPANY) + " - " + AICompany.GetLoanAmount());
		this.last_cash_output = AIDate.GetCurrentDate();
	}
	Utils_General.GetMoney(200000);
	if (AIDate.GetCurrentDate() - this.last_improve_buslines_date > 200) {
		this._bus_manager.ImproveLines();
		this.last_improve_buslines_date = AIDate.GetCurrentDate();
	}
	Utils_General.GetMoney(200000);
	if (AIDate.GetCurrentDate() - this.last_vehicle_check > 11 || this.need_vehicle_check) {
		local ret1 = this._bus_manager.CheckRoutes();
		local ret2 = this._truck_manager.CheckRoutes();
		local ret3 = this._train_manager.CheckRoutes();
		this.last_vehicle_check = AIDate.GetCurrentDate();
		this.need_vehicle_check = ret1 || ret2 || ret3;
	}
	local removed = [];
	foreach (idx, pair in this.sell_stations) {
		local tiles = AITileList_StationType(pair[0], pair[1]);
		tiles.Valuate(AITile.DemolishTile);
		tiles.Valuate(AITile.IsStationTile);
		tiles.KeepValue(0);
		if (!AIStation.IsValidStation(pair[0]) || tiles.Count() == 0) {
			removed.append(idx);
		}
	}
	for (local i = removed.len() - 1; i >= 0; i--) {
		this.sell_stations.remove(removed[i]);
	}
}

function AdmiralAI::Start()
{
	Utils_General.CheckSettings(["vehicle.max_roadveh", "vehicle.max_aircraft", "vehicle.max_trains", "vehicle.max_ships",
		"difficulty.vehicle_breakdowns", "construction.build_on_slopes", "station.modified_catchment"]);
	if (!this.SomeVehicleTypeAvailable()) {
		AILog.Error("No supported vehicle type is available.");
		AILog.Error("Quitting.");
		return;
	}
	local start_tick = this.GetTick();

	if (AICompany.GetName(AICompany.MY_COMPANY).find("AdmiralAI") == null) {
		Utils_General.SetCompanyName(Utils_Array.RandomReorder(["AdmiralAI"]));
		AILog.Info(AICompany.GetName(AICompany.MY_COMPANY) + " has just started!");
	}

	AIGroup.EnableWagonRemoval(true);

	if (AIGameSettings.GetValue("difficulty.vehicle_breakdowns") >= 1 || this.GetSetting("always_autorenew")) {
		AILog.Info("Breakdowns are on or the setting always_autorenew is on, so enabling autorenew");
		AICompany.SetAutoRenewMonths(-3);
		AICompany.SetAutoRenewStatus(true);
	} else {
		AILog.Info("Breakdowns are off, so disabling autorenew");
		AICompany.SetAutoRenewStatus(false);
	}

	/* All vehicle groups are deleted after load and recreated in all AfterLoad
	 * functions. This is done so we don't have so save the GroupIDs and can
	 * easier load savegames saved by other AIs that use a different group
	 * structure. */
	local group_list = AIGroupList();
	foreach (group, dummy in group_list) {
		AIGroup.DeleteGroup(group);
	}

	this._bus_manager.AfterLoad();
	this._truck_manager.AfterLoad();
	this._aircraft_manager.AfterLoad();
	this._train_manager.AfterLoad();
	this._save_data = null;
	AILog.Info("Loading done");

	local build_busses = false;
	local build_road_route = 3;
	local last_type = AIRoad.ROADTYPE_ROAD;
	AIRoad.SetCurrentRoadType(AIRoad.ROADTYPE_ROAD);
	/* Before starting the main loop, sleep a bit to prevent problems with ecs */
	this.Sleep(max(1, 260 - (this.GetTick() - start_tick)));
	while(1) {
		this.DoMaintenance();
		if (this.need_vehicle_check) {
			this.Sleep(20);
			continue;
		}
		last_type = last_type == AIRoad.ROADTYPE_ROAD ? AIRoad.ROADTYPE_TRAM : AIRoad.ROADTYPE_ROAD;
		if (AIRoad.IsRoadTypeAvailable(last_type)) AIRoad.SetCurrentRoadType(last_type);
		local build_route = false;
		Utils_General.GetMoney(200000);
		if (AICompany.GetBankBalance(AICompany.MY_COMPANY) >= 390000) {
			local veh_list = AIVehicleList();
			veh_list.Valuate(AIVehicle.GetVehicleType);
			veh_list.KeepValue(AIVehicle.VEHICLE_AIR);
			if (this.UseVehicleType("planes") && AIGameSettings.GetValue("vehicle.max_aircraft") * 0.9 > veh_list.Count()) {
				build_route = this._aircraft_manager.BuildNewRoute();
				Utils_General.GetMoney(200000);
			}
			veh_list = AIVehicleList();
			veh_list.Valuate(AIVehicle.GetVehicleType);
			veh_list.KeepValue(AIVehicle.VEHICLE_RAIL);
			if (this.UseVehicleType("trains") && AIGameSettings.GetValue("vehicle.max_trains") * 0.9 > veh_list.Count()) {
				build_route = this._train_manager.BuildNewRoute() || build_route;
			}
			build_road_route = 3;
		} else if (AICompany.GetBankBalance(AICompany.MY_COMPANY) >= 180000) {
			local veh_list = AIVehicleList();
			veh_list.Valuate(AIVehicle.GetVehicleType);
			veh_list.KeepValue(AIVehicle.VEHICLE_RAIL);
			local new_train_route = this.UseVehicleType("trains") && AIGameSettings.GetValue("vehicle.max_trains") * 0.9 > veh_list.Count();
			local veh_list = AIVehicleList();
			veh_list.Valuate(AIVehicle.GetVehicleType);
			veh_list.KeepValue(AIVehicle.VEHICLE_AIR);
			if (this.UseVehicleType("planes") && AIGameSettings.GetValue("vehicle.max_aircraft") * 0.9 > veh_list.Count()) {
				if (new_train_route && AIBase.RandRange(2) == 0) {
					build_route = this._train_manager.BuildNewRoute();
				} else {
					build_route = this._aircraft_manager.BuildNewRoute();
				}
			} else if (new_train_route) {
				build_route = this._train_manager.BuildNewRoute();
			}
			build_road_route = 3;
		}
		Utils_General.GetMoney(200000);
		local veh_list = AIVehicleList();
		veh_list.Valuate(AIVehicle.GetVehicleType);
		veh_list.KeepValue(AIVehicle.VEHICLE_ROAD);
		if (!build_route && build_road_route > 0 && AIGameSettings.GetValue("vehicle.max_roadveh") * 0.9 > veh_list.Count()) {
			if (AICompany.GetBankBalance(AICompany.MY_COMPANY) >= 30000) {
				if (build_busses) {
					if (this.UseVehicleType("busses")) build_route = this._bus_manager.NewLineExistingRoad();
					if (this.UseVehicleType("trucks") && !build_route) build_route = this._truck_manager.NewLineExistingRoad();
				} else {
					if (this.UseVehicleType("trucks")) build_route = this._truck_manager.NewLineExistingRoad();
					if (this.UseVehicleType("busses") && !build_route) build_route = this._bus_manager.NewLineExistingRoad();
				}
			}
			if (!build_route && AICompany.GetBankBalance(AICompany.MY_COMPANY) >= 80000) {
				if (build_busses) {
					if (this.UseVehicleType("busses")) build_route = this._bus_manager.BuildNewLine();
					if (this.UseVehicleType("trucks") && !build_route) build_route = this._truck_manager.BuildNewLine();
				} else {
					if (this.UseVehicleType("trucks")) build_route = this._truck_manager.BuildNewLine();
					if (this.UseVehicleType("busses") && !build_route) build_route = this._bus_manager.BuildNewLine();
				}
			}
			// By commenting the next line out AdmiralAI will first build truck routes before it starts on bus routes.
			//build_busses = !build_busses;
			if (build_route) build_road_route--;
		}
		Utils_General.GetMoney(200000);
		if (this.GetSetting("build_statues")) {
			if (AICompany.GetLoanAmount() == 0 && AICompany.GetBankBalance(AICompany.MY_COMPANY) > 200000) {
				local town_list = AITownList();
				town_list.Valuate(AITown.HasStatue);
				town_list.RemoveValue(1);
				town_list.Valuate(Utils_Valuator.NulValuator);
				local station_list = AIStationList(AIStation.STATION_ANY);
				station_list.Valuate(AIStation.GetNearestTown);
				foreach (station, town in station_list) {
					if (town_list.HasItem(town)) {
						town_list.SetValue(town, town_list.GetValue(town) + 1);
					}
				}
				town_list.KeepAboveValue(0);
				if (town_list.Count() > 0) {
					town_list.Sort(AIAbstractList.SORT_BY_VALUE, false);
					local town = town_list.Begin();
					if (AITown.PerformTownAction(town, AITown.TOWN_ACTION_BUILD_STATUE)) {
						AILog.Info("Build a statue in " + AITown.GetName(town));
					}
				}
			}
		}
		Utils_General.GetMoney(200000);
		this.Sleep(10);
	}
};

