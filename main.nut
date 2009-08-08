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

/*
 * TODO:
 *  - More error checking / handling.
 *  - Use AITransactionMode in RepairRoute to check for the costs.
 *  - If depot building fails, check if we can find a solution by demolishing a tile
 *     or by terraforming.
 *  - Look into building a statue in towns.
 *  - Create custon IsBuildableRectangle function (return 1-4 = offset in cargo_station_offsets, return 0 = invalid)
 *  - Only start building a route if an engine is available for that cargo.
 *  - Goods routes to towns.
 *  - Inner town routes.
 *  - Bug in building connection from depot to station.
 *  - When starting the AI: create a graph of all towns and create
 *     routes already, but don't build them untill we want to.
 *  - Do same as above for industries. Keep track of them with
 *     Event industry new/close.
 *  - Seperate RoadLine to RoadPaxLine and RoadCargoLine.
 *  - Build more trucks on cargo lines initially. Amount of trucks
 *     should depend not only on distance but also on production.
 *
 * Create custom pathfinder:
 *  - optimize estimate function by adding 1 turn and height difference. (could be committed)
 *  - Don't use flat tile with height 0.
 */

vehicles_to_sell <- null;

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

function AdmiralAI::BuildDepot_old(location)
{
	local tile_list = AITileList();
	tile_list.AddRectangle(location + AIMap.GetTileIndex(-5, -5), location + AIMap.GetTileIndex(5, 5));
	tile_list.Valuate(AIRoad.GetNeighbourRoadCount);
	tile_list.KeepAboveValue(0);
	//tile_list.Valuate(AIRoad.IsRoadTile);
	//tile_list.KeepValue(0);
	local list = AIList();
	list.AddList(tile_list);
	list.Valuate(AIRoad.IsRoadDepotTile);
	list.KeepValue(1);
	list.Valuate(AITile.GetOwner);
	list.KeepValue(AICompany.ResolveCompanyID(AICompany.MY_COMPANY));
	if (list.Count() >= 1) return;
	for (local t = tile_list.Begin(); tile_list.HasNext(); t = tile_list.Next()) {
		if (AICompany.IsMine(AITile.GetOwner(t))) continue;
		{
			local testmode = AITestMode();
			if (!AITile.DemolishTile(t)) continue;
		}
		local offsets = [AIMap.GetTileIndex(0,1), AIMap.GetTileIndex(0, -1),
		                 AIMap.GetTileIndex(1,0), AIMap.GetTileIndex(-1,0)];
		foreach (offset in offsets) {
			if (AIRoad.IsRoadTile(t + offset)) {
				{
					local testmode = AITestMode();
					if (!AIRoad.BuildRoad(t, t + offset)) continue;
					//if (!AIRoad.BuildRoadDepot(t, t + offset)) continue;
				}
				AITile.DemolishTile(t);
				AIRoad.BuildRoad(t, t + offset);
				AIRoad.BuildRoadDepot(t, t + offset);
				if (AIRoad.IsRoadDepotTile(t)) return t;
			}
		}
	}
	return null;
}

function AdmiralAI::BuildStation(town_id)
{
	local depot_tile = this.BuildDepot_old(AITown.GetLocation(town_id));
	if (depot_tile == null) {
		AILog.Warning("Couldn't bulid depot near " + AITown.GetName(town_id));
		return -1;
	}
	local town_loc = AITown.GetLocation(town_id);
	local tile_list = AITileList();
	tile_list.AddRectangle(town_loc + AIMap.GetTileIndex(-5, -5), town_loc + AIMap.GetTileIndex(5, 5));
	tile_list.Valuate(AIRoad.GetNeighbourRoadCount);
	tile_list.KeepAboveValue(0);
	tile_list.Valuate(AIRoad.IsRoadTile);
	tile_list.KeepValue(0);
	tile_list.Valuate(AIMap.DistanceManhattan, town_loc);
	tile_list.Sort(AIAbstractList.SORT_BY_VALUE, true);
	for (local t = tile_list.Begin(); tile_list.HasNext(); t = tile_list.Next()) {
		if (AICompany.IsMine(AITile.GetOwner(t))) continue;
		if (!AITile.DemolishTile(t)) continue;
		local offsets = [AIMap.GetTileIndex(0,1), AIMap.GetTileIndex(0, -1),
		                 AIMap.GetTileIndex(1,0), AIMap.GetTileIndex(-1,0)];
		foreach (offset in offsets) {
			if (AIRoad.IsRoadTile(t + offset)) {
				{
					local testmode = AITestMode();
					if (!AIRoad.BuildRoad(t, t + offset)) continue;
					if (!AIRoad.BuildRoadStation(t, t + offset, false, false)) continue;
				}
				AIRoad.BuildRoad(t, t + offset);
				AIRoad.BuildRoadStation(t, t + offset, false, false);
				RouteBuilder.BuildRoadRoute(RPF(), [t], [depot_tile]);
				return AIStation.GetStationID(t);
			}
		}
	}
	AILog.Error("Couldn't find a place to build a station within " + AITown.GetName(town_id));
	// We assume this never fails.
	return -1;
}

function AdmiralAI::CloseDownRoute(line)
{
	for (local i = 0; i < this._lines.len(); i++) {
		if (this._lines[i] == line) {
			this._lines.remove(i);
			return;
		}
	}
}

function AdmiralAI::GetRealHeight(tile)
{
	local height = AITile.GetHeight(tile);
	if (AITile.GetSlope(tile) & AITile.SLOPE_N) height--;
	return height;
}

function AdmiralAI::BuildBusRoute()
{
	/* Startup a new bus route. */
	local best_value = 0, best_town_from, best_town_to;
	for (local town = this._free_towns.Begin(); this._free_towns.HasNext(); town = this._free_towns.Next()) {
		local townlist = AIList();
		townlist.AddList(this._free_towns);
		townlist.Valuate(AITown.GetDistanceManhattanToTile, AITown.GetLocation(town));
		townlist.KeepBetweenValue(30, 80);
		for (local t = townlist.Begin(); townlist.HasNext(); t = townlist.Next()) {
			local value = AITown.GetPopulation(town) + AITown.GetPopulation(t);
			if (value > best_value) {
				best_value = value;
				best_town_from = town;
				best_town_to = t;
			}
		}
	}
	if (best_value > 0) {
		this._free_towns.RemoveItem(best_town_from);
		this._free_towns.RemoveItem(best_town_to);
		local station_from = this.BuildStation(best_town_from);
		local station_to = this.BuildStation(best_town_to);
		if (!AIStation.IsValidStation(station_from) || !AIStation.IsValidStation(station_to)) return false;
		AILog.Info("New line from " + AIStation.GetName(station_from) + " to " + AIStation.GetName(station_to) + " " + best_town_from + " " + best_town_to);
		local route = RoadLine(station_from, station_to, AIOrder.AIOF_NONE, AIOrder.AIOF_NONE, this, this._pass_cargo, AIStation.STATION_BUS_STOP);
		this._lines.push(route);
		local ret = route.RepairRoute();
		if (ret == -2) {
			this.GetMoney(200000);
			ret = line.RepairRoute();
		}
		if (ret == 0) {
			route.FindEngineID();
			route.CheckVehicles();
		}
		return true;
	}
	return false;
}

function AdmiralAI::TryBuildTruckRoute(ind_a, ind_b, cargo)
{
	AILog.Info("Trying to connect " + AIIndustry.GetName(ind_a) + " with " + AIIndustry.GetName(ind_b));

	local cov_rad = AIStation.GetCoverageRadius(AIStation.STATION_TRUCK_STOP);
	local station_from = -1, station_to = -1;
	if (this._ind_station.HasItem(ind_a)) {
		station_from = this._ind_station.GetValue(ind_a);
		if (station_from == -1) return -1;
	} else {
		local tilelist = AITileList_IndustryProducing(ind_a, cov_rad);
		tilelist.Valuate(AITile.IsBuildableRectangle, 3, 3);
		tilelist.KeepValue(1);
		tilelist.Valuate(AIIndustry.GetDistanceManhattanToTile, AIIndustry.GetLocation(ind_b));
		tilelist.Sort(AIAbstractList.SORT_BY_VALUE, true);
		foreach (tile, value in tilelist) {
			station_from = this.BuildCargoStation(tile);
			if (AIStation.IsValidStation(station_from)) {
				this._ind_station.AddItem(ind_a, station_from);
				break;
			}
		}
		if (station_from == -1) {
			this._ind_serviced.AddItem(ind_a, -1);
			return -1;
		}
	}

	if (this._ind_station.HasItem(ind_b)) {
		station_to = this._ind_station.GetValue(ind_b);
		if (station_to == -1) return -2;
	} else {
		local tilelist = AITileList_IndustryAccepting(ind_b, cov_rad);
		tilelist.Valuate(AITile.IsBuildableRectangle, 3, 3);
		tilelist.KeepValue(1);
		tilelist.Valuate(AIIndustry.GetDistanceManhattanToTile, AIIndustry.GetLocation(ind_a));
		tilelist.Sort(AIAbstractList.SORT_BY_VALUE, true);
		foreach (tile, value in tilelist) {
			station_to = this.BuildCargoStation(tile);
			if (AIStation.IsValidStation(station_to)) {
				this._ind_station.AddItem(ind_b, station_to);
				break;
			}
		}
		if (station_to == -1) {
			AILog.Warning("Unable to build an accepting cargo station near " + AIIndustry.GetName(ind_b));
			this._ind_dont_use.AddItem(ind_b, -1);
			return -2;
		}
	}

	AILog.Info("New line from " + AIStation.GetName(station_from) + " (" + AIStation.GetLocation(station_from)+") to " + AIStation.GetName(station_to)+ " (" + AIStation.GetLocation(station_to)+")");
	local route = RoadLine(station_from, station_to, AIOrder.AIOF_FULL_LOAD, AIOrder.AIOF_UNLOAD | AIOrder.AIOF_NO_LOAD, this, cargo, AIStation.STATION_TRUCK_STOP, 4, 8);
	this._ind_serviced.AddItem(ind_a, station_from);
	this._lines.push(route);
	local ret = route.RepairRoute();
	if (ret == -2) {
		AILog.Warning("Not enough money to build route");
		this.GetMoney(200000);
		ret = line.RepairRoute();
	}
	if (ret == 0) {
		route.FindEngineID();
		route.CheckVehicles();
	} else {
		AILog.Error("Something went wrong with initial RepairRoute(), returned: " + ret);
		return -3;
	}
	return 0;
}

function AdmiralAI::CargoProducing(ind_id, cargo)
{
	return AIIndustry.GetLastMonthProduction(ind_id, cargo) - AIIndustry.GetLastMonthTransported(ind_id, cargo);
}

function AdmiralAI::BuildTruckRoute()
{
	local cargo_list = AICargoList();
	cargo_list.Valuate(AICargo.IsFreight);
	cargo_list.KeepValue(1);
	cargo_list.Valuate(AICargo.GetCargoIncome, 80, 40);
	cargo_list.Sort(AIAbstractList.SORT_BY_VALUE, false);

	foreach (cargo, dummy in cargo_list) {
		local ind_list = AIIndustryList_CargoProducing(cargo);
		ind_list.RemoveList(this._ind_serviced);
		ind_list.Valuate(AdmiralAI.CargoProducing, cargo);
		ind_list.Sort(AIAbstractList.SORT_BY_VALUE, false);
		ind_list.KeepAboveValue(50);

		foreach (ind_prod, value in ind_list) {
			local ind_list2 = AIIndustryList_CargoAccepting(cargo);
			ind_list2.RemoveList(this._ind_dont_use);
			ind_list2.Valuate(AIIndustry.GetDistanceManhattanToTile, AIIndustry.GetLocation(ind_prod));
			ind_list2.KeepBelowValue(this._max_route_length);
			ind_list2.Sort(AIAbstractList.SORT_BY_VALUE, true);
			foreach (ind_acc, value2 in ind_list2) {
				if (ind_prod == ind_acc) continue; //for example possible with banks.
				local try_next = true;
				local ret = this.TryBuildTruckRoute(ind_prod, ind_acc, cargo);
				switch (ret) {
					case  0: return true;
					case -1: try_next = false; break;
					case -2: continue;
					case -3: continue;
					default: throw("Unexpected return value");
				}
				if (!try_next) break;
			}
		}
	}
	return false;
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
			/*if (AICompany.GetBankBalance(AICompany.MY_COMPANY) >= 250000) {
				while(this.BuildBusRoute() && AICompany.GetBankBalance(AICompany.MY_COMPANY) >= 100000);
				//while(this.BuildTruckRoute() && AICompany.GetBankBalance(AICompany.MY_COMPANY) >= 100000);
			}*/
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
