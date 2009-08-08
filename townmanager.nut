/** @file townmanager.nut Implementation of TownManager. */

/** @todo Be able to bulid multiple bus stops in one town.
/*
 * Some notes for that:
 *  - bus stops should be a miminum of DistanceSquare 40 apart.
 *  - For inner-town routes, the bus stops should be at least DistanceManhattan 12 apart.
 *  - CargoAcceptance for passenger cargo should be at least 35 (and be tested, maybe 40 is better).
 */

/**
 * Class that manages building multiple bus stations in a town.
 */
class TownManager
{
/* public: */

	/**
	 * Create a new TownManager.
	 * @param town_id The TownID this TownManager is going to manage.
	 */
	constructor(town_id) {
		this._town_id = town_id;
		this._stations = [];
		this._depot_tile = null;
	}

	/**
	 * Get the TileIndex from a road depot within this town. Build a depot if needed.
	 * @param station_manager The StationManager of the station we want a depot near.
	 * @return The TileIndex of a road depot tile within the town.
	 */
	function GetDepot(station_manager);

	/**
	 * Is it possible to build an extra station within this town?
	 * @return True if and only if an extra bus stop can be build.
	 */
	function CanGetStation();

	/**
	 * Build a new station in the neighbourhood of a given tile.
	 * @param around_tile The tile we want a station nearby.
	 * @return The StationManager of the newly build station or null if no
	 *  station could be build.
	 */
	function GetStation(around_tile);

/* private: */

	_town_id = null;    ///< The TownID this TownManager is managing.
	_stations = null;   ///< An array with all StationManagers within this town.
	_depot_tile = null; ///< The TileIndex of a road depot tile inside this town.
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
	AILog.Error("no staton build in " + AITown.GetName(this._town_id));
	return null;
}
