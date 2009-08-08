/** @file townmanager.nut Implementation of TownManager. */

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
		this._unused_stations = [];
		this._used_stations = [];
		this._depot_tile = null;
		this._station_failed_date = 0;
		this._airport_failed_date = 0;
		this._airports = [];
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
	 * @param pax_cargo_id The id of the passenger cargo.
	 * @return The StationManager of the newly build station or null if no
	 *  station could be build.
	 */
	function GetStation(pax_cargo_id);

/* private: */

	_town_id = null;             ///< The TownID this TownManager is managing.
	_unused_stations = null;     ///< An array with all StationManagers of unused stations within this town.
	_used_stations = null;       ///< An array with all StationManagers of in use stations within this town.
	_depot_tile = null;          ///< The TileIndex of a road depot tile inside this town.
	_station_failed_date = null; ///< Don't try to build a new station within 60 days of failing to build one.
	_airport_failed_date = null; ///< Don't try to build a new airport within 60 days of failing to build one.
	_airports = null;
};

function TownManager::GetAirport(cargo_id)
{
	if (this._airports.len() > 0) return this._airports[0];
	local airport =  this.TryBuildAirport([AIAirport.AT_INTERCON, AIAirport.AT_INTERNATIONAL, AIAirport.AT_METROPOLITAN, AIAirport.AT_LARGE, AIAirport.AT_COMMUTER, AIAirport.AT_SMALL], cargo_id);
	if (airport != null) this._airports.push(airport);
	return airport;
}

function TownManager::CanBuildAirport(cargo_id, allow_small_airport)
{
	foreach (airport in this._airports) {
		if (AIVehicleList_Station(airport).Count() <= 1 && (allow_small_airport || !AircraftManager.IsSmallAirport(airport))) return true;
		if ((AIStation.GetCargoWaiting(airport, cargo_id) > 500 ||
				(AIStation.GetCargoWaiting(airport, cargo_id) > 250 && allow_small_airport && AircraftManager.IsSmallAirport(airport))) &&
				this.CanBuildPlanes(airport)) return true;
	}
	if (this._airports.len() >= max(1, AITown.GetPopulation(this._town_id) / 2500)) return false;
	if (AIDate.GetCurrentDate() - this._airport_failed_date < 60) return false;
	return true;
}

function TownManager::CanBuildPlanes(airport)
{
	local max_planes = 0;
	switch (AIAirport.GetAirportType(AIStation.GetLocation(airport))) {
		case AIAirport.AT_SMALL:         max_planes =  4; break;
		case AIAirport.AT_LARGE:         max_planes =  6; break;
		case AIAirport.AT_METROPOLITAN:  max_planes = 10; break;
		case AIAirport.AT_INTERNATIONAL: max_planes = 16; break;
		case AIAirport.AT_COMMUTER:      max_planes =  8; break;
		case AIAirport.AT_INTERCON:      max_planes = 24; break;
	}
	return AIVehicleList_Station(airport).Count() + 2 <= max_planes;
}

function TownManager::BuildAirport(cargo_id, allow_small_airport)
{
	foreach (airport in this._airports) {
		if (AIVehicleList_Station(airport).Count() <= 1 && (allow_small_airport || !AircraftManager.IsSmallAirport(airport))) return airport;
		if ((AIStation.GetCargoWaiting(airport, cargo_id) > 500 ||
				(AIStation.GetCargoWaiting(airport, cargo_id) > 250 && allow_small_airport && AircraftManager.IsSmallAirport(airport))) &&
				this.CanBuildPlanes(airport)) return airport;
	}
	if (this._airports.len() >= max(1, AITown.GetPopulation(this._town_id) / 2500)) return null;
	if (AIDate.GetCurrentDate() - this._airport_failed_date < 60) return null;
	local airport =  this.TryBuildAirport([AIAirport.AT_INTERCON, AIAirport.AT_INTERNATIONAL, AIAirport.AT_METROPOLITAN, AIAirport.AT_LARGE], cargo_id);
	if (airport == null && allow_small_airport) airport = this.TryBuildAirport([AIAirport.AT_COMMUTER, AIAirport.AT_SMALL], cargo_id);
	if (airport != null) {
		this._airports.push(airport);
	} else {
		_airport_failed_date = AIDate.GetCurrentDate();
	}
	return airport;
}

function TownManager::ScanMap()
{
	local station_list = AIStationList(AIStation.STATION_BUS_STOP);
	station_list.Valuate(AIStation.GetNearestTown);
	station_list.KeepValue(this._town_id);

	foreach (station_id, dummy in station_list) {
		local vehicle_list = AIVehicleList_Station(station_id);
		vehicle_list.RemoveList(::vehicles_to_sell);
		if (vehicle_list.Count() > 0) {
			this._used_stations.push(StationManager(station_id, null));
		} else {
			this._unused_stations.push(StationManager(station_id, null));
		}
	}

	local depot_list = AIDepotList(AITile.TRANSPORT_ROAD);
	depot_list.Valuate(AITile.IsWithinTownInfluence, this._town_id);
	depot_list.KeepValue(1);
	depot_list.Valuate(AIMap.DistanceManhattan, AITown.GetLocation(this._town_id));
	depot_list.Sort(AIAbstractList.SORT_BY_VALUE, true);
	if (depot_list.Count() > 0) this._depot_tile = depot_list.Begin();
}

function TownManager::CanPlaceAirport(tile, type)
{
	if (!AITile.IsBuildableRectangle(tile, AIAirport.GetAirportWidth(type), AIAirport.GetAirportHeight(type))) return -1;
	local min_height = AdmiralAI.GetRealHeight(tile);
	local max_height = min_height;
	for (local x = AIMap.GetTileX(tile); x < AIMap.GetTileX(tile) + AIAirport.GetAirportWidth(type); x++) {
		for (local y = AIMap.GetTileY(tile); y < AIMap.GetTileY(tile) + AIAirport.GetAirportHeight(type); y++) {
			local h = AdmiralAI.GetRealHeight(AIMap.GetTileIndex(x, y));
			min_height = min(min_height, h);
			max_height = max(max_height, h);
			if (max_height - min_height > 2) return -1;
		}
	}
	local target_heights = [(max_height + min_height) / 2];
	if (max_height - min_height == 1) target_heights.push(max_height);
	foreach (height in target_heights) {
		if (height == 0) continue;
		local tf_ok = true;
		for (local x = AIMap.GetTileX(tile); tf_ok && x < AIMap.GetTileX(tile) + AIAirport.GetAirportWidth(type); x++) {
			for (local y = AIMap.GetTileY(tile); tf_ok && y < AIMap.GetTileY(tile) + AIAirport.GetAirportHeight(type); y++) {
				local t = AIMap.GetTileIndex(x, y);
				local h = AdmiralAI.GetRealHeight(t);
				if (h < height && !AITile.RaiseTile(t, AITile.GetComplementSlope(t))) {
					tf_ok = false;
					break;
				}
				local h = AdmiralAI.GetRealHeight(t);
				/* We need to check this twice, because the first one flattens the tile, and the second time it's raised. */
				if (h < height && !AITile.RaiseTile(t, AITile.GetComplementSlope(t))) {
					tf_ok = false;
					break;
				}
				if (h > height && !AITile.LowerTile(t, AITile.GetSlope(t) != AITile.SLOPE_FLAT ? AITile.GetSlope(t) : AITile.SLOPE_ELEVATED)) {
					tf_ok = false;
					break;
				}
			}
		}
		if (tf_ok) {
			return height;
		}
	}
	return -1;
}

function TownManager::AirportLocationValuator(tile, type, town_center)
{
	return AIMap.DistanceSquare(town_center, tile + AIMap.GetTileIndex(AIAirport.GetAirportWidth(type) / 2, AIAirport.GetAirportHeight(type) / 2));
}

function TownManager::PlaceAirport(tile, type, height)
{
	for (local x = AIMap.GetTileX(tile); x < AIMap.GetTileX(tile) + AIAirport.GetAirportWidth(type); x++) {
		for (local y = AIMap.GetTileY(tile); y < AIMap.GetTileY(tile) + AIAirport.GetAirportHeight(type); y++) {
			local rating = AITown.GetRating(this._town_id, AICompany.MY_COMPANY);
			if (rating != AITown.TOWN_RATING_NONE && rating < AITown.TOWN_RATING_POOR) return false;
			local t = AIMap.GetTileIndex(x, y);
			local h = AdmiralAI.GetRealHeight(t);
			if (h < height && !AITile.RaiseTile(t, AITile.GetComplementSlope(t))) return false;
			local h = AdmiralAI.GetRealHeight(t);
			/* We need to check this twice, because the first one flattens the tile, and the second time it's raised. */
			if (h < height && !AITile.RaiseTile(t, AITile.GetComplementSlope(t))) return false;
			if (h > height && !AITile.LowerTile(t, AITile.GetSlope(t) != AITile.SLOPE_FLAT ? AITile.GetSlope(t) : AITile.SLOPE_ELEVATED)) return false;
			/* TODO: check for build_on_slopes, and if off, also flatten tiles with the correct height. */
		}
	}
	return AIAirport.BuildAirport(tile, type, false);
}

function TownManager::TryBuildAirport(types, cargo_id)
{
	foreach (type in types) {
		if (!AIAirport.AirportAvailable(type)) continue;
		local tile_list = AITileList();
		AdmiralAI.AddSquare(tile_list, AITown.GetLocation(this._town_id), 20 + AITown.GetPopulation(this._town_id) / 3000);
		tile_list.Valuate(AITile.GetCargoAcceptance, cargo_id, AIAirport.GetAirportWidth(type), AIAirport.GetAirportHeight(type), AIAirport.GetAirportCoverageRadius(type));
		tile_list.KeepAboveValue(40);
		local station_list = AIStationList(AIStation.STATION_AIRPORT);
		station_list.Valuate(AIStation.GetLocation);
		foreach (station_id, location in station_list) {
			local airport_type = AIAirport.GetAirportType(AIStation.GetLocation(station_id));
			local max_radius = 2 + max(AIAirport.GetAirportCoverageRadius(airport_type), AIAirport.GetAirportCoverageRadius(type));
			AdmiralAI.RemoveRectangleSafe(tile_list, location, AIAirport.GetAirportWidth(airport_type) + max_radius, AIAirport.GetAirportWidth(type) + max_radius,
					 AIAirport.GetAirportHeight(airport_type) + max_radius, AIAirport.GetAirportHeight(type) + max_radius);
		}
		{
			local test = AITestMode();
			tile_list.Valuate(TownManager.CanPlaceAirport, type);
			tile_list.KeepAboveValue(-1);
		}
		if (tile_list.Count() == 0) continue;
		local list2 = AIList();
		list2.AddList(tile_list);
		list2.Valuate(TownManager.AirportLocationValuator, type, AITown.GetLocation(this._town_id));
		list2.Sort(AIAbstractList.SORT_BY_VALUE, true);
		foreach (t, dummy in list2) {
			if (this.PlaceAirport(t, type, tile_list.GetValue(t))) return AIStation.GetStationID(t);
		}
	}
	return null;
}

function TownManager::UseStation(station)
{
	foreach (idx, st in this._unused_stations)
	{
		if (st == station) {
			this._unused_stations.remove(idx);
			this._used_stations.push(station);
			return;
		}
	}
	throw("Trying to use a station that doesn't belong to this town!");
}

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
	if (this._unused_stations.len() > 0) return true;
	local rating = AITown.GetRating(this._town_id, AICompany.MY_COMPANY);
	if (rating != AITown.TOWN_RATING_NONE && rating < AITown.TOWN_RATING_MEDIOCRE) return false;
	if (AIDate.GetCurrentDate() - this._station_failed_date < 60) return false;
	if (max(1, (AITown.GetPopulation(this._town_id) / 300).tointeger()) > this._used_stations.len()) return true;
	return false;
}

function TownManager::GetStation(pax_cargo_id)
{
	local town_center = AITown.GetLocation(this._town_id);
	if (this._unused_stations.len() > 0) return this._unused_stations[0];
	/* We need to build a new station. */
	local rating = AITown.GetRating(this._town_id, AICompany.MY_COMPANY);
	if (rating != AITown.TOWN_RATING_NONE && rating < AITown.TOWN_RATING_MEDIOCRE) {
		AILog.Warning("Town rating: " + rating);
		AILog.Warning("Town rating is bad, not going to try building a station in " + AITown.GetName(this._town_id));
		return null;
	}

	local list = AITileList();
	local radius = 10;
	local population = AITown.GetPopulation(this._town_id);
	if (population > 10000) radius += 5;
	if (population > 15000) radius += 5;
	if (population > 25000) radius += 5;
	if (population > 35000) radius += 5;
	if (population > 45000) radius += 5;
	AdmiralAI.AddSquare(list, town_center, radius);
	list.Valuate(AIRoad.GetNeighbourRoadCount);
	list.KeepAboveValue(0);
	list.Valuate(AIRoad.IsRoadTile);
	list.KeepValue(0);
	list.Valuate(AdmiralAI.GetRealHeight);
	list.KeepAboveValue(0);
	list.Valuate(AITile.IsWithinTownInfluence, this._town_id);
	list.KeepValue(1);
	foreach (station in this._used_stations) {
		local station_id = station.GetStationID();
		list.Valuate(AIMap.DistanceSquare, AIStation.GetLocation(station_id));
		list.KeepAboveValue(35);
	}
	list.Valuate(AITile.GetCargoAcceptance, pax_cargo_id, 1, 1, AIStation.GetCoverageRadius(AIStation.STATION_BUS_STOP));
	list.KeepAboveValue(25);
	list.Valuate(AIMap.DistanceManhattan, town_center);
	list.Sort(AIAbstractList.SORT_BY_VALUE, true);
	foreach (t, dis in list) {
		if (AICompany.IsMine(AITile.GetOwner(t))) continue;
		local offsets = [AIMap.GetTileIndex(0,1), AIMap.GetTileIndex(0, -1),
		                 AIMap.GetTileIndex(1,0), AIMap.GetTileIndex(-1,0)];
		foreach (offset in offsets) {
			if (!AIRoad.IsRoadTile(t + offset)) continue;
			if (!Utils.IsNearlyFlatTile(t + offset)) continue;
			if (RouteFinder.FindRouteBetweenRects(t + offset, AITown.GetLocation(this._town_id), 0) == null) continue;
			if (!AITile.IsBuildable(t) && !AITile.DemolishTile(t)) continue;
			{
				local testmode = AITestMode();
				if (!AIRoad.BuildRoad(t, t + offset)) continue;
				if (!AIRoad.BuildRoadStation(t, t + offset, false, false, false)) continue;
			}
			if (!AIRoad.BuildRoad(t, t + offset)) continue;
			if (!AIRoad.BuildRoadStation(t, t + offset, false, false, false)) continue;
			local manager = StationManager(AIStation.GetStationID(t), null);
			this._unused_stations.push(manager);
			return manager;
		}
	}
	this._station_failed_date = AIDate.GetCurrentDate();
	AILog.Error("no staton build in " + AITown.GetName(this._town_id));
	return null;
}
