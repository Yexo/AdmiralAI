/** @file townmanager.nut Implementation of TownManager. */

/** @todo Be able to bulid multiple bus stops in one town.
/*
 * Some notes for that:
 *  - bus stops should be a miminum of DistanceSquare 40 apart.
 *  - For inner-town routes, the bus stops should be at least DistanceManhattan 12 apart.
 */

/**
 * Class that manages building multiple bus stations in a town.
 */
class TownManager
{
	_town_id = null;
	_stations = null;
	_depot_tile = null;

	constructor(town_id) {
		this._town_id = town_id;
		this._stations = [];
		this._depot_tile = null;
	}
};

function TownManager::GetDepot(station_manager)
{
	if (this._depot_tile == null) {
		local stationtiles = AITileList_StationType(station_manager.GetStationID(), AIStation.STATION_BUS_STOP);
		stationtiles.Valuate(AIRoad.GetRoadStationFrontTile);
		this._depot_tile =  AdmiralAI.BuildDepot(stationtiles.GetValue(stationtiles.Begin()));
	}
	return this._depot_tile;
}

function TownManager::CanGetStation()
{
	return this._stations.len() == 0 || this._stations[0].GetNumBusses() == 0;
}

function TownManager::GetStation(around_tile)
{
	if (this._stations.len() > 0) return this._stations[0];
	/* We need to build a new station. */
	local list = AITileList();
	AdmiralAI.AddSquare(list, around_tile, 3);
	list.Valuate(AIRoad.GetNeighbourRoadCount);
	list.KeepAboveValue(0);
	list.Valuate(AIRoad.IsRoadTile);
	list.KeepValue(0);
	list.Valuate(AIMap.DistanceManhattan, around_tile);
	list.Sort(AIAbstractList.SORT_BY_VALUE, true);
	foreach (t, dis in list) {
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
				local manager = StationManager(AIStation.GetStationID(t));
				this._stations.push(manager);
				return manager;
			}
		}
	}
	AILog.Error("no staton build");
	return null;
}
