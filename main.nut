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

import("queue.fibonacci_heap", "FibonacciHeap", 1);

require("utils.nut");
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
RailPF <- Rail;
require("rail/trainmanager.nut");
require("rail/railroutebuilder.nut");
require("rail/trainline.nut");


/**
 * @todo
 *  - Use %AITransactionMode in RepairRoute to check for the costs.
 *  - Inner town routes. Not that important since we have multiple bus stops per town.
 *  - Amount of trucks build initially should depend not only on distance but also on production.
 *  - optimize rpf estimate function by adding 1 turn and height difference. (could be committed)
 *  - If we can't transport more cargo to a certain station, try to find / build a new station we can transport
 *     the goods to and split it.
 *  - Try to stationwalk.
 *  - Build road stations up or down a hill.
 *  - Check if a station stopped accepting a certain cargo: if so, stop accepting more trucks for that cargo
 *     and send a few of the existing trucks to another destination.
 *  - Experiment with giving busses a full load order on one of the two busstations.
 *  - Try to transport oil from oilrigs to the coast with ships, and then to a refinery with road vehicles. Better
 *     yet would be to directly transport it to oilrigs if distances is small enough, otherwise option 1.
 * @bug
 *  - Don't start / end with building a bridge / tunnel, as the tile before it might not be free.
 *  - When building a truck station near a city, connecting it with the road may fail. Either demolish some tiles
 *     or just pathfind from station to other industry, so even though the first part was difficult, a route is build.
 *  - Upon loading a game, scan all vehicles and set autoreplace for those types we don't choose as new engine_id.
 *  - If building a truck station near an industry failed, don't try again. Better yet: pathfind first, if succesfull
 *     try to build a truck station and connect it with the endpoint, if twice successfull (both stations), then build the route
 */

/**
 * The main class of AdmiralAI.
 */
class AdmiralAI extends AIController
{
/* public: */

	constructor() {
		this._truck_manager = TruckLineManager();
		this._bus_manager = BusLineManager();
		this._aircraft_manager = AircraftManager(this._bus_manager.GetTownManagerTable());
		this._train_manager = TrainManager();
		this._pending_events = [];

		if (::vehicles_to_sell == null) {
			::vehicles_to_sell = AIList();
		}

		this._save_data = null;
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
	 * Try to get a specifeid amount of money.
	 * @param amount The amount of money we want.
	 * @note This function doesn't return anything. You'll have to check yourself if you have got enough.
	 */
	static function GetMoney(amount);

	/**
	 * Get the real tile height of a tile. The real tile hight is the base tile hight plus 1 if
	 *   the tile is a non-flat tile.
	 * @param tile The tile to get the height for.
	 * @return The height of the tile.
	 * @note The base tile hight is not the same as AITile.GetHeight. The value returned by
	 *   AITile.GetHeight is one too high in case the north corner is raised.
	 */
	static function GetRealHeight(tile);

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
	 * Add a square around a tile to an AITileList.
	 * @param tile_list The AITileList to add the tiles to.
	 * @param center_tile The center where the square should be created around.
	 * @param radius Half of the diameter of the square.
	 * @note The square ranges from (centertile - (radius, radius)) to (centertile + (radius, radius)).
	 */
	static function AddSquare(tile_list, center_tile, radius);

	/**
	 * A safe implementation of AITileList.AddRectangle. In effect if center_tile - (x_min, y_min)
	 * and centertile + (x_plus, y_plus) are still valid. Only valid tiles are added.
	 * @param tile_list The AITileList to add the tiles to.
	 * @param center_tile The center of the rectangle.
	 * @param x_min The amount of tiles to the north-east, relative to center_tile.
	 * @param y_min The amount of tiles to the north-west, relative to center_tile.
	 * @param x_plus The amount of tiles to the south-west, relative to center_tile.
	 * @param y_plus The amount of tiles to the south-east, relative to center_tile.
	 */
	static function AddRectangleSafe(tile_list, center_tile, x_min, y_min, x_plus, y_plus);

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
	 * A valuator that always returns 0.
	 * @param item unused.
	 */
	static function NulValuator(item);

	/**
	 * The mainloop.
	 * @note This is called by OpenTTD, no need to call from within the AI.
	 */
	function Start();

/* private: */

	_truck_manager = null; ///< The TruckLineManager managing all truck lines.
	_bus_manager = null;   ///< The BusLineManager managing all bus lines.
	_aircraft_manager = null; ///< The AircraftManager managing all air routes.
	_train_manager = null;  ///< The TrainManager managing all train routes.
	_pending_events = null; ///< An array containing [EventType, value] pairs of unhandles events.
	_save_data = null;      ///< Cache of save data during load.
};

function AdmiralAI::Save()
{
	if (this._save_data != null) return this._save_data;

	local data = {};
	local to_sell = [];
	foreach (veh, dummy in ::vehicles_to_sell) {
		to_sell.push(veh);
	}
	data.rawset("vehicles_to_sell", to_sell);
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

	if (data.rawin("vehicles_to_sell")) {
		foreach (v in data.rawget("vehicles_to_sell")) {
			if (AIVehicle.IsValidVehicle(v)) ::vehicles_to_sell.AddItem(v, 0);
		}
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

function AdmiralAI::GetMoney(amount)
{
	local bank = AICompany.GetBankBalance(AICompany.MY_COMPANY);
	local loan = AICompany.GetLoanAmount();
	local maxloan = AICompany.GetMaxLoanAmount();
	if (bank > amount) {
		if (loan > 0) AICompany.SetMinimumLoanAmount(max(loan - (bank - amount) + 10000, 0));
	} else {
		AICompany.SetMinimumLoanAmount(min(maxloan, loan + amount - bank + 10000));
	}
}

function AdmiralAI::GetRealHeight(tile)
{
	local height = AITile.GetHeight(tile);
	if (AITile.GetSlope(tile) & AITile.SLOPE_N) height--;
	if (AITile.GetSlope(tile) != AITile.SLOPE_FLAT) height++;
	return height;
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
			if (AIRoad.IsRoadTile(cur_tile + offset)) continue
			if (!AITile.DemolishTile(cur_tile + offset)) continue;
			local h = AdmiralAI.GetRealHeight(cur_tile);
			local h2 = AdmiralAI.GetRealHeight(cur_tile + offset);
			if (h2 > h) AITile.LowerTile(cur_tile + offset, AITile.GetSlope(cur_tile + offset));
			if (h > h2) AITile.RaiseTile(cur_tile + offset, AITile.GetComplementSlope(AITile.GetSlope(cur_tile + offset)));
			if (!AIRoad.BuildRoad(cur_tile + offset, cur_tile)) continue;
			if (AIRoad.BuildRoadDepot(cur_tile + offset, cur_tile)) return cur_tile + offset;
		}
	}
	AILog.Error("Should never come here, unable to build depot!");
	return null;
}

function AdmiralAI::AddSquare(tile_list, center_tile, radius)
{
	AdmiralAI.AddRectangleSafe(tile_list, center_tile, radius, radius, radius, radius);
}

function AdmiralAI::AddRectangleSafe(tile_list, center_tile, x_min, y_min, x_plus, y_plus)
{
	local tile_x = AIMap.GetTileX(center_tile);
	local tile_y = AIMap.GetTileY(center_tile);
	local tile_from = AIMap.GetTileIndex(max(1, tile_x - x_min), max(1, tile_y - y_min));
	local tile_to = AIMap.GetTileIndex(min(AIMap.GetMapSizeX() - 2, tile_x + x_plus), min(AIMap.GetMapSizeY() - 2, tile_y + y_plus));
	tile_list.AddRectangle(tile_from, tile_to);
}

function AdmiralAI::RemoveRectangleSafe(tile_list, center_tile, x_min, y_min, x_plus, y_plus)
{
	local tile_x = AIMap.GetTileX(center_tile);
	local tile_y = AIMap.GetTileY(center_tile);
	local tile_from = AIMap.GetTileIndex(max(1, tile_x - x_min), max(1, tile_y - y_min));
	local tile_to = AIMap.GetTileIndex(min(AIMap.GetMapSizeX() - 2, tile_x + x_plus), min(AIMap.GetMapSizeY() - 2, tile_y + y_plus));
	tile_list.RemoveRectangle(tile_from, tile_to);
}

function AdmiralAI::HandleEvents()
{
	foreach (event_pair in this._pending_events) {
		switch (event_pair[0]) {
			case AIEvent.AI_ET_VEHICLE_WAITING_IN_DEPOT:
				if (::vehicles_to_sell.HasItem(event_pair[1])) {
					AIVehicle.SellVehicle(event_pair[1]);
					::vehicles_to_sell.RemoveItem(event_pair[1]);
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
	::vehicles_to_sell.Valuate(AIVehicle.IsValidVehicle);
	::vehicles_to_sell.KeepValue(1);
	foreach (vehicle, dummy in ::vehicles_to_sell) {
		if (!AIRoad.IsRoadDepotTile(AIOrder.GetOrderDestination(vehicle, AIOrder.CURRENT_ORDER))) {
			if (!AIVehicle.SendVehicleToDepot(vehicle)) {
				AIVehicle.ReverseVehicle(vehicle);
				AIController.Sleep(50);
				AIVehicle.SendVehicleToDepot(vehicle);
			}
		}
	}
}

function AdmiralAI::NulValuator(item)
{
	return 0;
}

function AdmiralAI::ItemValuator(item)
{
	return item;
}

function AdmiralAI::TransportCargo(cargo, ind)
{
	main_instance._truck_manager.TransportCargo(cargo, ind);
	main_instance._train_manager.TransportCargo(cargo, ind);
}

function AdmiralAI::Start()
{
	Utils.CheckSettings(["vehicle.max_roadveh", "vehicle.max_aircraft", "vehicle.max_trains", "difficulty.vehicle_breakdowns"]);
	main_instance = this;

	if (AICompany.GetName(AICompany.MY_COMPANY).find("AdmiralAI") == null) {
		Utils.SetCompanyName(Utils.RandomReorder(["AdmiralAI"]));
		AILog.Info(AICompany.GetName(AICompany.MY_COMPANY) + " has just started!");
	}

	if (AIGameSettings.GetValue("difficulty.vehicle_breakdowns") >= 1 || this.GetSetting("always_autorenew")) {
		AILog.Info("Breakdowns are on or the setting always_autorenew is on, so enabling autorenew");
		AICompany.SetAutoRenewMonths(-3);
		AICompany.SetAutoRenewStatus(true);
	} else {
		AILog.Info("Breakdowns are off, so disabling autorenew");
		AICompany.SetAutoRenewStatus(false);
	}

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

	local last_vehicle_check = 0;
	local last_cash_output = AIDate.GetCurrentDate();
	local last_improve_buslines_date = 0;
	local build_busses = false;
	local need_vehicle_check = false;
	local build_road_route = 3;
	while(1) {
		this.GetEvents();
		this.HandleEvents();
		this.SendVehicleToSellToDepot();
		if (AIDate.GetCurrentDate() - last_cash_output > 90) {
			local curdate = AIDate.GetCurrentDate();
			AILog.Info("Current date: " + AIDate.GetYear(curdate) + "-" + AIDate.GetMonth(curdate) + "-" + AIDate.GetDayOfMonth(curdate));
			AILog.Info("Cash - loan: " + AICompany.GetBankBalance(AICompany.MY_COMPANY) + " - " + AICompany.GetLoanAmount());
			last_cash_output = AIDate.GetCurrentDate();
		}
		this.GetMoney(200000);
		if (AIDate.GetCurrentDate() - last_improve_buslines_date > 200) {
			this._bus_manager.ImproveLines();
			last_improve_buslines_date = AIDate.GetCurrentDate();
		}
		this.GetMoney(200000);
		if (AICompany.GetBankBalance(AICompany.MY_COMPANY) < 15000) {this.Sleep(5); continue;}
		if (AIDate.GetCurrentDate() - last_vehicle_check > 11 || need_vehicle_check) {
			this.GetMoney(200000);
			local ret1 = this._bus_manager.CheckRoutes();
			local ret2 = this._truck_manager.CheckRoutes();
			local ret3 = this._train_manager.CheckRoutes();
			last_vehicle_check = AIDate.GetCurrentDate();
			need_vehicle_check = ret1 || ret2 || ret3;
		}
		if (need_vehicle_check) {
			this.Sleep(20);
			continue;
		}
		local build_route = false;
		this.GetMoney(200000);
		if (AICompany.GetBankBalance(AICompany.MY_COMPANY) >= 180000) {
			local veh_list = AIVehicleList();
			veh_list.Valuate(AIVehicle.GetVehicleType);
			veh_list.KeepValue(AIVehicle.VEHICLE_RAIL);
			local new_train_route = AIGameSettings.GetValue("vehicle.max_trains") * 0.9 > veh_list.Count() && this.GetSetting("use_trains");
			local veh_list = AIVehicleList();
			veh_list.Valuate(AIVehicle.GetVehicleType);
			veh_list.KeepValue(AIVehicle.VEHICLE_AIR);
			if (AIGameSettings.GetValue("vehicle.max_aircraft") * 0.9 > veh_list.Count() && this.GetSetting("use_planes")) {
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
		this.GetMoney(200000);
		local veh_list = AIVehicleList();
		veh_list.Valuate(AIVehicle.GetVehicleType);
		veh_list.KeepValue(AIVehicle.VEHICLE_ROAD);
		if (!build_route && build_road_route > 0 && AIGameSettings.GetValue("vehicle.max_roadveh") * 0.9 > veh_list.Count()) {
			if (AICompany.GetBankBalance(AICompany.MY_COMPANY) >= 30000) {
				if (build_busses) {
					if (this.GetSetting("use_busses")) build_route = this._bus_manager.NewLineExistingRoad();
					if (this.GetSetting("use_trucks")) if (!build_route) build_route = this._truck_manager.NewLineExistingRoad();
				} else {
					if (this.GetSetting("use_trucks")) build_route = this._truck_manager.NewLineExistingRoad();
					if (this.GetSetting("use_busses")) if (!build_route) build_route = build_route = this._bus_manager.NewLineExistingRoad();
				}
			}
			if (!build_route && AICompany.GetBankBalance(AICompany.MY_COMPANY) >= 80000) {
				if (build_busses) {
					if (this.GetSetting("use_busses")) build_route = this._bus_manager.BuildNewLine();
					if (this.GetSetting("use_trucks")) if (!build_route) build_route = this._truck_manager.BuildNewLine();
				} else {
					if (this.GetSetting("use_trucks")) build_route = this._truck_manager.BuildNewLine();
					if (this.GetSetting("use_busses")) if (!build_route) build_route = this._bus_manager.BuildNewLine();
				}
			}
			// By commenting the next line out AdmiralAI will first build truck routes before it starts on bus routes.
			//build_busses = !build_busses;
			if (build_route) build_road_route--;
		}
		if (this.GetSetting("build_statues")) {
			if (AICompany.GetBankBalance(AICompany.MY_COMPANY) + AICompany.GetMaxLoanAmount() - AICompany.GetLoanAmount() > 500000) this.GetMoney(1000000);
			if (AICompany.GetBankBalance(AICompany.MY_COMPANY) > 500000) {
				local town_list = AITownList();
				town_list.Valuate(AITown.HasStatue);
				town_list.RemoveValue(1);
				town_list.Valuate(AdmiralAI.NulValuator);
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
		this.GetMoney(200000);
		this.Sleep(10);
	}
};

vehicles_to_sell <- null;
main_instance <- null;
