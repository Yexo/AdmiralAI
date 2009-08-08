/* TODO:
 *  - make TryBuildExtraTruckStops terraform / demolishtile when needed.
 *  - Add bus support.
 *  - Change _num_trucks into some other value that depends on the distance the trucks drive.
 */


class StationManager
{
	_station_id = null;
	_num_truck_stops = null;
	_num_trucks = null;
	_num_busses = null;

	constructor(station_id) {
		this._station_id = station_id;
		this._num_truck_stops = 1;
		this._num_trucks = 0;
		this._num_busses = 0;
	}
}

function StationManager::CanAddTrucks(num)
{
	local max_trucks = this._num_truck_stops * 15;
	if (max_trucks - this._num_trucks >= num) return num;
	local num_too_many = num - (max_trucks - this._num_trucks);
	this.TryBuildExtraTruckStops(((num_too_many + 14) / 15).tointeger());
	return this._num_truck_stops * 15 - this._num_trucks;
}

function StationManager::GetNumBusses()
{
	return this._num_busses;
}

function StationManager::CanAddBusses(num)
{
	return (12 - this._num_busses) > num;
}

function StationManager::AddBusses(num)
{
	this._num_busses += num;
}

function StationManager::AddTrucks(num)
{
	this._num_trucks += num;
}

function StationManager::GetStationID()
{
	return this._station_id;
}

function StationManager::TryBuildExtraTruckStops(num_to_build)
{
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
	AILog.Info("TryBuildExtraTruckStops(" + num_to_build + "): " + Utils.AIListToString(list));
	while (num_to_build > 0) {
		if (list.Count() == 0) return;
		local best_min_distance = 999;
		local best_tile, best_front;
		{
			local test = AITestMode();
			foreach (tile, dummy in list) {
				foreach (offset in offsets) {
					if (!AIRoad.IsRoadTile(tile + offset)) continue;
					if (!AIRoad.BuildRoadStation(tile, tile + offset, true, false)) continue;
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
		if (best_min_distance == 999) return;
		if (!AIRoad.BuildRoad(best_tile, best_front)) return;
		if (!AIRoad.BuildRoadStation(best_tile, best_front, true, false)) return;
		this._num_truck_stops++;
		front_tiles.AddTile(best_front);
		foreach (offset in diagoffsets) {
			if (AIRoad.IsRoadTile(best_tile + offset) || (AITile.GetOwner(best_tile + offset) >= AICompany.FIRST_COMPANY &&
			    AITile.GetOwner(best_tile + offset) <= AICompany.LAST_COMPANY)) continue;
			list.AddTile(best_tile + offset);
		}
		num_to_build--;
	}
}
