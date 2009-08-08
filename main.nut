/** @file main.nut Implementation of AdmiralAI, containing the main loop. */

import("pathfinder.road", "RPF", 3);
import("graph.aystar", "AyStar", 4);
require("utils.nut");
require("routefinder.nut");
require("routebuilder.nut");
require("trucklinemanager.nut");
require("truckline.nut");
require("stationmanager.nut");
require("buslinemanager.nut");
require("busline.nut");
require("townmanager.nut");

/**
 * @todo
 *  - Build our own routes.
 *  - More error checking / handling.
 *  - Use %AITransactionMode in RepairRoute to check for the costs.
 *  - If depot building fails, check if we can find a solution by demolishing a tile
 *     or by terraforming.
 *  - Look into building a statue in towns.
 *  - Only start building a route if an engine is available for that cargo.
 *  - Goods routes to towns.
 *  - Inner town routes.
 *  - Don't build depot next to stations, but some (4 or 5 tiles should do) distance.
 *  - Keep track of industries with event industry new/close.
 *  - Amount of trucks build initially should depend not only on distance but also on production.
 *  - Create custom pathfinder:
 *   - optimize estimate function by adding 1 turn and height difference. (could be committed)
 *   - Don't use flat tiles with height 0.
 *  - Fix the double depot for farms.
 */


/**
 * The main class of AdmiralAI.
 */
class AdmiralAI extends AIController
{
	_lines = null;
	_rescan_engines = null;
	_free_towns = null;
	_pass_cargo = null;
	_ind_serviced = null;
	_ind_dont_use = null;
	_ind_station = null;
	_max_route_length = null;

	constructor() {
		this._lines = [];
		this._rescan_engines = false;
		this._free_towns = AIList()
		this._free_towns.AddList(AITownList());
		local cargo_list = AICargoList();
		cargo_list.Valuate(AICargo.HasCargoClass,AICargo.CC_PASSENGERS);
		if (cargo_list.Count() == 0) AILog.Error("No passenger cargo found!");
		this._pass_cargo = cargo_list.Begin();
		this._ind_serviced = AIList();
		this._ind_dont_use = AIList();
		this._ind_station = AIList();
		this._max_route_length = 160;

		if (::vehicles_to_sell == null) {
			::vehicles_to_sell = AIList();
		}
	}
};

function AdmiralAI::CheckEvents()
{
	while (AIEventController.IsEventWaiting()) {
		local e = AIEventController.GetNextEvent();
		switch (e.GetEventType()) {
			case AIEvent.AI_ET_VEHICLE_WAITING_IN_DEPOT:
				local c = AIEventVehicleWaitingInDepot.Convert(e);
				if (::vehicles_to_sell.HasItem(c.GetVehicleID())) {
					AIVehicle.SellVehicle(c.GetVehicleID());
					::vehicles_to_sell.RemoveItem(c.GetVehicleID());
				}
				break;
			case AIEvent.AI_ET_ENGINE_AVAILABLE:
				this._rescan_engines = true;
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
	return height;
}

function AdmiralAI::BuildDepot(roadtile)
{
	local offsets = [AIMap.GetTileIndex(0,1), AIMap.GetTileIndex(0, -1),
	                 AIMap.GetTileIndex(1,0), AIMap.GetTileIndex(-1,0)];
	local tile_to_try = [roadtile];
	local tried = AIList();
	while (tile_to_try.len() > 0) {
		local cur_tile;
		do {
			cur_tile = tile_to_try[0];
			tile_to_try.remove(0);
		} while (tried.HasItem(cur_tile));
		tried.AddItem(cur_tile, 0);
		foreach (offset in offsets) {
			if (AIRoad.AreRoadTilesConnected(cur_tile, cur_tile + offset)) {
				if (!tried.HasItem(cur_tile + offset)) tile_to_try.push(cur_tile + offset);
				continue;
			}
			if (AICompany.IsMine(AITile.GetOwner(cur_tile + offset))) continue;
			if (AIRoad.IsRoadTile(cur_tile + offset)) continue;
			if (!AITile.DemolishTile(cur_tile + offset)) continue;
			local h = AdmiralAI.GetRealHeight(cur_tile);
			if (AITile.GetSlope(cur_tile) != AITile.SLOPE_FLAT) h++;
			local h2 = AdmiralAI.GetRealHeight(cur_tile + offset);
			if (AITile.GetSlope(cur_tile) != AITile.SLOPE_FLAT) h++;
			if (h2 > h) AITile.LowerTile(cur_tile + offset, AITile.GetSlope(cur_tile + offset));
			if (h > h2) AITile.RaiseTile(cur_tile + offset, AITile.GetComplementSlope(AITile.GetSlope(cur_tile + offset)));
			if (!AIRoad.BuildRoad(cur_tile + offset, cur_tile)) continue;
			if (AIRoad.BuildRoadDepot(cur_tile + offset, cur_tile)) return cur_tile + offset;
		}
	}
	throw("Should never come here, unable to build depot!");
}

function AdmiralAI::AddSquare(tile_list, center_tile, radius)
{
	AdmiralAI.AddRectangleSafe(tile_list, center_tile, -radius, -radius, radius, radius);
}

function AdmiralAI::AddRectangleSafe(tile_list, center_tile, x_min, y_min, x_plus, y_plus)
{
	local tile_x = AIMap.GetTileX(center_tile);
	local tile_y = AIMap.GetTileY(center_tile);
	local tile_from = AIMap.GetTileIndex(max(1, tile_x + x_min), max(1, tile_y + y_min));
	local tile_to = AIMap.GetTileIndex(min(AIMap.GetMapSizeX() - 2, tile_x + x_plus), min(AIMap.GetMapSizeY() - 2, tile_y + y_plus));
	tile_list.AddRectangle(tile_from, tile_to);
}

function AdmiralAI::Start()
{
	for(local i=0; i<AISign.GetMaxSignID(); i++) {
		if (AISign.IsValidSign(i))
			AISign.RemoveSign(i);
	}
	local truck_manager = TruckLineManager();
	local bus_manager = BusLineManager();

	Utils.SetCompanyName(Utils.RandomReorder(["AdmiralAI", "Yexo's ai"]));
	AILog.Info(AICompany.GetCompanyName(AICompany.MY_COMPANY) + " has just started!");

	local last_vehicle_check = AIDate.GetCurrentDate();
	local last_cash_output = AIDate.GetCurrentDate();
	local build_busses = false;
	local need_vehicle_check = false;
	while(1) {
		this.CheckEvents();
		if (AIDate.GetCurrentDate() - last_cash_output > 100) {
			AILog.Info("Cash - loan: " + AICompany.GetBankBalance(AICompany.MY_COMPANY) + " - " + AICompany.GetLoanAmount());
			last_cash_output = AIDate.GetCurrentDate();
		}
		this.GetMoney(200000);
		if (AICompany.GetBankBalance(AICompany.MY_COMPANY) < 15000) {this.Sleep(5); continue;}
		if (AIDate.GetCurrentDate() - last_vehicle_check > 11 || need_vehicle_check) {
			this.GetMoney(200000);
			local ret1 = bus_manager.CheckRoutes();
			local ret2 = truck_manager.CheckRoutes();
			last_vehicle_check = AIDate.GetCurrentDate();
			need_vehicle_check = ret1 || ret2;
		}
		local build_route = true;
		this.GetMoney(200000);
		if (AICompany.GetBankBalance(AICompany.MY_COMPANY) >= 80000 && build_route && !need_vehicle_check) {
			if (build_busses) {
				build_route = bus_manager.NewLineExistingRoad();
				if (!build_route) build_route = truck_manager.NewLineExistingRoad();
			} else {
				build_route = truck_manager.NewLineExistingRoad();
				if (!build_route) build_route = build_route = bus_manager.NewLineExistingRoad();
			}
			if (!build_route) {
				if (build_busses) {
					build_route = bus_manager.BuildNewLine();
					if (!build_route) build_route = truck_manager.BuildNewLine();
				} else {
					build_route = truck_manager.BuildNewLine();
					if (!build_route) build_route = bus_manager.BuildNewLine();
				}
			}
			build_busses = !build_busses;
		} else if (AICompany.GetBankBalance(AICompany.MY_COMPANY) >= 30000 && !need_vehicle_check) {
			if (build_busses) {
				build_route = bus_manager.NewLineExistingRoad();
				if (!build_route) build_route = truck_manager.NewLineExistingRoad();
			} else {
				build_route = truck_manager.NewLineExistingRoad();
				if (!build_route) build_route = build_route = bus_manager.NewLineExistingRoad();
			}
		}
		this.Sleep(1);
	}
};

vehicles_to_sell <- null;
