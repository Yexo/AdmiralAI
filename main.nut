/** @file main.nut Implementation of AdmiralAI, containing the main loop. */

import("queue.binary_heap", "BinaryHeap", 1);
require("config.nut");
require("aystar.nut");
require("rpf.nut");
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
 *  - Use %AITransactionMode in RepairRoute to check for the costs.
 *  - Look into building a statue in towns: done, as in, it's usefull when enough money is available: code this.
 *  - Inner town routes. Not that important since we have multiple bus stops per town.
 *  - Amount of trucks build initially should depend not only on distance but also on production.
 *  - optimize rpf estimate function by adding 1 turn and height difference. (could be committed)
 *  - If we can't transport more cargo to a certain station, try to find / build a new station we can transport
 *     the goods to and split it.
 *  - Try to stationwalk.
 * @bug
 *  - Don't start / end with building a bridge / tunnel, as the tile before it might not be free.
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

		if (::vehicles_to_sell == null) {
			::vehicles_to_sell = AIList();
		}
	}

	/**
	 * Try to get a specifeid amount of money.
	 * @param amount The amount of money we want.
	 * @note This function doesn't return anything. You'll have to check yourself if you have got enough.
	 */
	static function GetMoney(amount);

	/**
	 * Get the real tile height of a tile. The real tile hight is the base tile hight plus 1 if
	 *  the tile is a non-flat tile.
	 * @param tile The tile to get the height for.
	 * @return The height of the tile.
	 * @note The base tile hight is not the same as AITile.GetHeight. The value returned by
	 *  AITile.GetHeight is one too high in case the north corner is raised.
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
	 *  do that explicitly.
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
	 * Handle all waiting events.
	 */
	function CheckEvents();

	/**
	 * The mainloop.
	 */
	function Start();

/* private: */

	_truck_manager = null; ///< The TruckLineManager managing all truck lines.
	_bus_manager = null;   ///< The BusLineManager managing all bus lines.
};

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

			case AIEvent.AI_ET_INDUSTRY_CLOSE:
				local ind = AIEventIndustryClose.Convert(e).GetIndustryID();
				this._truck_manager.IndustryClose(ind);
				break;

			case AIEvent.AI_ET_INDUSTRY_OPEN:
				local ind = AIEventIndustryOpen.Convert(e).GetIndustryID();
				this._truck_manager.IndustryOpen(ind);
				break;
		}
	}
}

function AdmiralAI::SendVehicleToSellToDepot()
{
	::vehicles_to_sell.Valuate(AIVehicle.IsValidVehicle);
	::vehicles_to_sell.KeepValue(1);
	foreach (vehicle, dummy in ::vehicles_to_sell) {
		if (!AIRoad.IsRoadDepotTile(AIOrder.GetOrderDestination(vehicle, AIOrder.CURRENT_ORDER))) {
			AIVehicle.SendVehicleToDepot(vehicle);
		}
	}
}

function AdmiralAI::Start()
{
	for(local i=0; i<AISign.GetMaxSignID(); i++) {
		if (AISign.IsValidSign(i))
			AISign.RemoveSign(i);
	}

	Utils.SetCompanyName(Utils.RandomReorder(["AdmiralAI"]));
	AILog.Info(AICompany.GetCompanyName(AICompany.MY_COMPANY) + " has just started!");

	if (!AIGameSettings.IsValid("difficulty.vehicle_breakdowns")) throw("difficulty.vehicle_breakdowns is not valid, please update!");
	if (AIGameSettings.GetValue("difficulty.vehicle_breakdowns") >= 1) {
		AILog.Info("Breakdowns are on, so enabling autorenew");
		AICompany.SetAutoRenewMonths(-3);
		AICompany.SetAutoRenewStatus(true);
	} else {
		AILog.Info("Breakdowns are off, so disabling autorenew");
		AICompany.SetAutoRenewStatus(false);
	}

	local last_vehicle_check = AIDate.GetCurrentDate();
	local last_cash_output = AIDate.GetCurrentDate();
	local build_busses = false;
	local need_vehicle_check = false;
	while(1) {
		this.CheckEvents();
		this.SendVehicleToSellToDepot();
		if (AIDate.GetCurrentDate() - last_cash_output > 90) {
			local curdate = AIDate.GetCurrentDate();
			AILog.Info("Current date: " + AIDate.GetYear(curdate) + "-" + AIDate.GetMonth(curdate) + "-" + AIDate.GetDayOfMonth(curdate));
			AILog.Info("Cash - loan: " + AICompany.GetBankBalance(AICompany.MY_COMPANY) + " - " + AICompany.GetLoanAmount());
			last_cash_output = AIDate.GetCurrentDate();
		}
		this.GetMoney(200000);
		if (AICompany.GetBankBalance(AICompany.MY_COMPANY) < 15000) {this.Sleep(5); continue;}
		if (AIDate.GetCurrentDate() - last_vehicle_check > 11 || need_vehicle_check) {
			this.GetMoney(200000);
			local ret1 = this._bus_manager.CheckRoutes();
			local ret2 = this._truck_manager.CheckRoutes();
			last_vehicle_check = AIDate.GetCurrentDate();
			need_vehicle_check = ret1 || ret2;
		}
		local build_route = false;
		this.GetMoney(200000);
		if (AICompany.GetBankBalance(AICompany.MY_COMPANY) >= 30000 && !need_vehicle_check) {
			if (build_busses) {
				if (Config.enable_busses) build_route = this._bus_manager.NewLineExistingRoad();
				if (Config.enable_trucks) if (!build_route) build_route = this._truck_manager.NewLineExistingRoad();
			} else {
				if (Config.enable_trucks) build_route = this._truck_manager.NewLineExistingRoad();
				if (Config.enable_busses) if (!build_route) build_route = build_route = this._bus_manager.NewLineExistingRoad();
			}
		}
		if (!build_route && AICompany.GetBankBalance(AICompany.MY_COMPANY) >= 80000 && !need_vehicle_check) {
			if (build_busses) {
				if (Config.enable_busses) build_route = this._bus_manager.BuildNewLine();
				if (Config.enable_trucks) if (!build_route) build_route = this._truck_manager.BuildNewLine();
			} else {
				if (Config.enable_trucks) build_route = this._truck_manager.BuildNewLine();
				if (Config.enable_busses) if (!build_route) build_route = this._bus_manager.BuildNewLine();
			}
		}
		// By commenting the next line out AdmiralAI will first build truck routes before it starts on bus routes.
		build_busses = !build_busses;
		this.Sleep(1);
	}
};

vehicles_to_sell <- null;
