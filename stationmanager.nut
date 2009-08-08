/** @file stationmanager.nut Implementation of StationManager. */

/**
 * Class that manages extending existing stations.
 */
class StationManager
{
/* public: */

	/**
	 * Create a new StationManager.
	 * @param station_id The StationID of the station to manage.
	 */
	constructor(station_id, truckline_manager) {
		this._station_id = station_id;
		this._truck_points = 0;
		this._bus_points = 0;
		this._truckline_manager = truckline_manager;
		this._is_drop_station = false;
	}

	/**
	 * Close down this stations if there are no more trucks using it.
	 */
	function CloseStation();

	/**
	 * Get the StationID of the station this StationManager is managing.
	 * @return The StationID for this station.
	 */
	function GetStationID();

	/**
	 * Is it possible to add some extra trucks to this station?
	 * @param num The amount of trucks we want to add.
	 * @return The maximum number of trucks that can be added. If there
	 *   are currently to many trucks visiting this station, it'll return
	 *   a negative number indicating the amount of vehicles that need to
	 *   be sold.
	 * @note The return value can be higher then num.
	 */
	function CanAddTrucks(num, distance, speed);

	/**
	 * Notify the StationManager that some trucks were added to this station.
	 * @param num The amount of trucks that were added.
	 */
	function AddTrucks(num, distance, speed);

	/**
	 * Notify the StationManager that some trucks were removed from this station.
	 * @param num The amount of trucks that were removed.
	 */
	function RemoveTrucks(num, distance, speed);

	/**
	 * Get if their are any busses with this station in their order list.
	 */
	function HasBusses();

	/**
	 * Is it possible to add some extra busses to this station?
	 * @param num The amount of busses we want to add.
	 * @return The maximum number of busses that can be added. If there are
	 *   currently to many busses visiting this station, it'll return a
	 *   negative number indicating the amount of vehicles that need to
	 *   be sold.
	 * @note The return value can be higher then num.
	 */
	function CanAddBusses(num, distance, speed);

	/**
	 * Notify the StationManager that some busses were added to this station.
	 * @param num The amount of busses that were added.
	 */
	function AddBusses(num, distance, speed);

	/**
	 * Notify the StationManager that some busses were removed from this station.
	 * @param num The amount of busses that were removed.
	 */
	function RemoveBusses(num, distance, speed);

/* private: */

	/**
	 * Try to build some extra truck stops to be able to accomodate extra trucks.
	 * @param num_to_build The amount of truck stops to build.
	 * @param delete_tiles Are we allowed to demolish tiles to extend the station?
	 * @note Always call with delete_tiles  = false. The function will call itself
	 * again with delete_tiles = true if building without demolising failed.
	 */
	function _TryBuildExtraTruckStops(num_to_build, delete_tiles);

	_station_id = null;      ///< The StationID of the station this StationManager manages.
	_truck_points = null;    ///< The total truck points of trucks that have this station in their order list.
	_bus_points = null;      ///< The total bus points of busses that have this station in their order list.
	_is_drop_station = null; ///< True if this stations is used for dropping cargo. (passengers don't count)
	_truckline_manager = null;
};

function StationManager::SetCargoDrop(is_drop_station)
{
	this._is_drop_station = is_drop_station;
}

function StationManager::IsCargoDrop()
{
	return this._is_drop_station;
}

function StationManager::GetPoints(distance, speed)
{
	distance = min(200, distance); //Distances over 200 don't work in this formula. High speeds do work.
	local ret = 5254 - 109 * distance + 0.426016 * distance * distance + 47.5406 * speed + 1.42885 * distance * speed -
			0.00784304 * distance * distance * speed + 0.486821 * speed * speed - 0.0161983 * distance * speed * speed +
			0.0000698203 * distance * distance * speed * speed;
	return ret.tointeger();
}

function StationManager::CloseStation()
{
	if (this._truck_points > 0) return;
	local list = AITileList_StationType(this._station_id, AIStation.STATION_TRUCK_STOP);
	foreach (tile, dummy in list) {
		local tries = 10;
		while (tries-- > 0) {
			if (!AITile.DemolishTile(tile)) {
				switch (AIError.GetLastError()) {
					case AIError.ERR_UNKNOWN:
					case AIError.ERR_VEHICLE_IN_THE_WAY:
					case AIError.ERR_NOT_ENOUGH_CASH:
						AIController.Sleep(100);
						continue;
				}
			}
			break;
		}
	}
	this._truckline_manager.ClosedStation(this);
}

function StationManager::GetStationID()
{
	return this._station_id;
}

function StationManager::CanAddTrucks(num, distance, speed)
{
	local station_max_points = 90000;
	if (this._is_drop_station) station_max_points = 80000;
	local station_tilelist = AITileList_StationType(this._station_id, AIStation.STATION_TRUCK_STOP)
	local num_truck_stops = station_tilelist.Count();
	local points_per_truck = StationManager.GetPoints(distance, speed);
	local max_points = station_max_points * num_truck_stops;
	if (max_points - this._truck_points >= points_per_truck * num) return num;
	local points_too_many = points_per_truck * num + this._truck_points - max_points;
	this._TryBuildExtraTruckStops(((points_too_many + station_max_points - 1) / station_max_points).tointeger(), false);
	station_tilelist = AITileList_StationType(this._station_id, AIStation.STATION_TRUCK_STOP)
	num_truck_stops = station_tilelist.Count();
	max_points = station_max_points * num_truck_stops;
	if (this._truck_points < max_points) return ((max_points - this._truck_points) / points_per_truck).tointeger();
	return ((this._truck_points - max_points + points_per_truck - 1) / points_per_truck).tointeger();
}

function StationManager::AddTrucks(num, distance, speed)
{
	local points_per_truck = StationManager.GetPoints(distance, speed);
	this._truck_points += num * points_per_truck;
}

function StationManager::RemoveTrucks(num, distance, speed)
{
	local points_per_truck = StationManager.GetPoints(distance, speed);
	this._truck_points -= num * points_per_truck;
}

function StationManager::HasBusses()
{
	return this._bus_points != 0;
}

function StationManager::CanAddBusses(num, distance, speed)
{
	local points_per_bus = StationManager.GetPoints(distance, speed);
	if (this._bus_points < 70000) return ((70000 - this._bus_points) / points_per_bus).tointeger();
	return ((this._bus_points - 70000 + points_per_bus - 1) / points_per_bus).tointeger()
}

function StationManager::AddBusses(num, distance, speed)
{
	local points_per_bus = StationManager.GetPoints(distance, speed);
	this._bus_points += num * points_per_bus;
}

function StationManager::RemoveBusses(num, distance, speed)
{
	local points_per_bus = StationManager.GetPoints(distance, speed);
	this._bus_points -= num * points_per_bus;
}

function StationManager::_TryBuildExtraTruckStops(num_to_build, delete_tiles)
{
	if (AITown.GetRating(AIStation.GetNearestTown(this._station_id), AICompany.MY_COMPANY) <= AITown.TOWN_RATING_VERY_POOR) return;
	local diagoffsets = [AIMap.GetTileIndex(0, 1), AIMap.GetTileIndex(0, -1),
	                 AIMap.GetTileIndex(1, 0), AIMap.GetTileIndex(-1, 0),
	                 AIMap.GetTileIndex(-1, -1), AIMap.GetTileIndex(-1, 1),
	                 AIMap.GetTileIndex(1, -1), AIMap.GetTileIndex(1, 1)];
	local offsets = [AIMap.GetTileIndex(0, 1), AIMap.GetTileIndex(0, -1),
	                 AIMap.GetTileIndex(1, 0), AIMap.GetTileIndex(-1, 0)];
	local tilelist = AITileList_StationType(this._station_id, AIStation.STATION_TRUCK_STOP);
	tilelist.Valuate(AIRoad.GetRoadStationFrontTile);
	local front_tiles = AITileList();
	local list = AITileList();
	foreach (station_tile, front_tile in tilelist) {
		front_tiles.AddTile(front_tile);
		foreach (offset in diagoffsets) {
			list.AddTile(station_tile + offset);
		}
	}
	list.Valuate(AIRoad.IsRoadTile);
	list.KeepValue(0);
	list.Valuate(AITile.GetOwner);
	list.RemoveBetweenValue(AICompany.FIRST_COMPANY - 1, AICompany.LAST_COMPANY + 1);
	AILog.Info("TryBuildExtraTruckStops for station " + AIStation.GetName(this._station_id));
	while (num_to_build > 0) {
		if (list.Count() == 0) break;
		local best_min_distance = 999;
		local best_tile, best_front;
		{
			local test = AITestMode();
			foreach (tile, dummy in list) {
				foreach (offset in offsets) {
					if (!AIRoad.IsRoadTile(tile + offset)) continue;
					if (delete_tiles) {
						local exec = AIExecMode();
						if (!AITile.DemolishTile(tile)) continue;
					}
					{
						local exec = AIExecMode();
						AITile.RaiseTile(tile + offset, AITile.GetComplementSlope(AITile.GetSlope(tile + offset)));
						if (AdmiralAI.GetRealHeight(tile) > AdmiralAI.GetRealHeight(tile + offset)) {
							AITile.LowerTile(tile, AITile.GetSlope(tile));
						}
					}
					if (!AIRoad.BuildRoadStation(tile, tile + offset, true, false, true)) continue;
					front_tiles.Valuate(AIMap.DistanceManhattan, tile + offset);
					local min_distance = front_tiles.GetValue(front_tiles.Begin());
					if (min_distance < best_min_distance) {
						best_min_distance = min_distance;
						best_tile = tile;
						best_front = tile + offset;
					}
				}
			}
		}
		if (best_min_distance == 999) break;
		if (!AIRoad.BuildRoad(best_tile, best_front)) return;
		if (!AIRoad.BuildRoadStation(best_tile, best_front, true, false, true)) return;
		front_tiles.AddTile(best_front);
		foreach (offset in diagoffsets) {
			if (AIRoad.IsRoadTile(best_tile + offset) || (AITile.GetOwner(best_tile + offset) >= AICompany.FIRST_COMPANY &&
			    AITile.GetOwner(best_tile + offset) <= AICompany.LAST_COMPANY)) continue;
			list.AddTile(best_tile + offset);
		}
		num_to_build--;
	}
	if (num_to_build > 0 && !delete_tiles) {
		this._TryBuildExtraTruckStops(num_to_build, true);
	}
}
