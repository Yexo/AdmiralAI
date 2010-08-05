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
 * Copyright 2008-2010 Thijs Marinussen
 */

/** @file railroutebuilder.nut Some rail route building functions. */

/**
 * Class that handles rail building.
 */
class RailRouteBuilder
{
/* public: */

	/**
	 * Connect two stations.
	 * @param station_a The StationID of the first station to connect.
	 * @param station_b The StationID of the second station to connect.
	 * @return One of the following:
	 *  -  0 If the route was build without any problems.
	 *  - -1 If no path was found by the pathfinder.
	 *  - -2 If the AI didn't have enough money to build the route.
	 */
	static function ConnectRailStations(station_a, station_b);

	/**
	 * Determine the platform length of a train station.
	 * @param station The StationID of the station.
	 * @return The length in tiles of the station.
	 */
	static function DetectPlatformLength(station);

	/**
	 * Build a few track tiles connecting the station to
	 *  incoming/outgoing rails.
	 * @param tile TODO: what is this?
	 * @param start_tile TODO: what is this?
	 * @param platform_length The length of one platform in tiles.
	 * @param second_station Is this a pickup or a drop station?
	 * @return Whether the track building succeeded.
	 * @note: if this function returns false, the station + nearby
	 *  are in an unknown state, so they should be deleted.
	 */
	static function BuildTrackNearStation(tile, start_tile, platform_length, second_station);
};

function RailRouteBuilder::DetectPlatformLength(station)
{
	/* TODO: make this function work when AIStation.GetLocation doesn't
	 * return a rail tile or returns a rail tile in the middle of the
	 * platform. */
	local tile = AIStation.GetLocation(station);
	local length = 0;
	if (AIRail.GetRailTracks(tile) == AIRail.RAILTRACK_NW_SE) {
		local tile_before = tile + AIMap.GetTileIndex(0, -1);
		while (AIStation.GetStationID(tile) == station && AIRail.GetRailTracks(tile) == AIRail.RAILTRACK_NW_SE) {
			length++;
			tile += AIMap.GetTileIndex(0, 1);
		}
		/* TODO: Remove this ugly hack. */
		length -= 2;
		if (((!AIRail.IsRailStationTile(tile_before)) && AICompany.IsMine(AITile.GetOwner(tile_before)) && AIRail.IsRailTile(tile_before) &&
				(AIRail.GetRailTracks(tile_before) & AIRail.RAILTRACK_NW_SE) != 0) ||
				((!AIRail.IsRailStationTile(tile)) && AICompany.IsMine(AITile.GetOwner(tile)) && AIRail.IsRailTile(tile) &&
				(AIRail.GetRailTracks(tile) & AIRail.RAILTRACK_NW_SE) != 0)) {
			length += 2;
		}
	} else {
		local tile_before = tile + AIMap.GetTileIndex(-1, 0);
		while (AIStation.GetStationID(tile) == station && AIRail.GetRailTracks(tile) == AIRail.RAILTRACK_NE_SW) {
			length++;
			tile += AIMap.GetTileIndex(1, 0);
		}
		length -= 2;
		if ((!AIRail.IsRailStationTile(tile_before) && AICompany.IsMine(AITile.GetOwner(tile_before)) && AIRail.IsRailTile(tile_before) &&
				(AIRail.GetRailTracks(tile_before) & AIRail.RAILTRACK_NE_SW) != 0) ||
				(!AIRail.IsRailStationTile(tile) && AICompany.IsMine(AITile.GetOwner(tile)) && AIRail.IsRailTile(tile) &&
				(AIRail.GetRailTracks(tile) & AIRail.RAILTRACK_NE_SW) != 0)) {
			length += 2;
		}
	}
	return length;
}

function RailRouteBuilder::BuildTrackNearStation(tile, start_tile, platform_length, second_station)
{
	if (AIRail.GetRailTracks(tile) == AIRail.RAILTRACK_NW_SE) {
		if (start_tile > tile) {
			AIRail.RemoveRailStationTileRectangle(tile + AIMap.GetTileIndex(0, platform_length), tile + AIMap.GetTileIndex(1, platform_length + 1), false);
			local tile2 = tile + AIMap.GetTileIndex(0, platform_length)
			if (AITile.GetSlope(tile2) != AITile.SLOPE_FLAT) {
				AITile.RaiseTile(tile2, AITile.GetComplementSlope(AITile.GetSlope(tile2)));
			}
			if (!AIRail.BuildRailTrack(tile + AIMap.GetTileIndex(0, platform_length), AIRail.RAILTRACK_NW_SE)) return false;
			if (!AIRail.BuildRailTrack(tile + AIMap.GetTileIndex(1, platform_length), AIRail.RAILTRACK_NW_SE)) return false;
			if (!AIRail.BuildRailTrack(tile + AIMap.GetTileIndex(0, 1 + platform_length), AIRail.RAILTRACK_NW_SE)) return false;
			if (!AIRail.BuildRailTrack(tile + AIMap.GetTileIndex(1, 1 + platform_length), AIRail.RAILTRACK_NW_SE)) return false;

			if (!AIRail.BuildRailTrack(tile + AIMap.GetTileIndex(0, platform_length), AIRail.RAILTRACK_NW_SW)) return false;
			if (!AIRail.BuildRailTrack(tile + AIMap.GetTileIndex(1, platform_length), AIRail.RAILTRACK_NE_SE)) return false;

			if (!AIRail.BuildRailTrack(tile + AIMap.GetTileIndex(1, platform_length), AIRail.RAILTRACK_NW_NE)) return false;
			if (!AIRail.BuildRailTrack(tile + AIMap.GetTileIndex(0, platform_length), AIRail.RAILTRACK_SW_SE)) return false;

			if (!AIRail.BuildSignal(tile + AIMap.GetTileIndex(second_station ? 0 : 1, platform_length + 1), tile + AIMap.GetTileIndex(second_station ? 0 : 1, platform_length + 2), AIRail.SIGNALTYPE_PBS_ONEWAY)) return false;
		} else {
			AIRail.RemoveRailStationTileRectangle(tile, tile + AIMap.GetTileIndex(1, 1), false);
			tile = tile + AIMap.GetTileIndex(0, 2);
			local tile2 = tile + AIMap.GetTileIndex(0, -1)
			if (AITile.GetSlope(tile2) != AITile.SLOPE_FLAT) {
				AITile.RaiseTile(tile2, AITile.GetComplementSlope(AITile.GetSlope(tile2)));
			}
			if (!AIRail.BuildRailTrack(tile + AIMap.GetTileIndex(0, -1), AIRail.RAILTRACK_NW_SE)) return false;
			if (!AIRail.BuildRailTrack(tile + AIMap.GetTileIndex(1, -1), AIRail.RAILTRACK_NW_SE)) return false;
			if (!AIRail.BuildRailTrack(tile + AIMap.GetTileIndex(0, -2), AIRail.RAILTRACK_NW_SE)) return false;
			if (!AIRail.BuildRailTrack(tile + AIMap.GetTileIndex(1, -2), AIRail.RAILTRACK_NW_SE)) return false;

			if (!AIRail.BuildRailTrack(tile + AIMap.GetTileIndex(0, -1), AIRail.RAILTRACK_SW_SE)) return false;
			if (!AIRail.BuildRailTrack(tile + AIMap.GetTileIndex(1, -1), AIRail.RAILTRACK_NW_NE)) return false;

			if (!AIRail.BuildRailTrack(tile + AIMap.GetTileIndex(1, -1), AIRail.RAILTRACK_NE_SE)) return false;
			if (!AIRail.BuildRailTrack(tile + AIMap.GetTileIndex(0, -1), AIRail.RAILTRACK_NW_SW)) return false;

			if (!AIRail.BuildSignal(tile + AIMap.GetTileIndex(second_station ? 0 : 1, -2), tile + AIMap.GetTileIndex(second_station ? 0 : 1, -3), AIRail.SIGNALTYPE_PBS_ONEWAY)) return false;
		}
	} else {
		if (start_tile > tile) {
			AIRail.RemoveRailStationTileRectangle(tile + AIMap.GetTileIndex(platform_length, 0), tile + AIMap.GetTileIndex(platform_length + 1, 1), false);
			local tile2 = tile + AIMap.GetTileIndex(platform_length, 0)
			if (AITile.GetSlope(tile2) != AITile.SLOPE_FLAT) {
				AITile.RaiseTile(tile2, AITile.GetComplementSlope(AITile.GetSlope(tile2)));
			}
			if (!AIRail.BuildRailTrack(tile + AIMap.GetTileIndex(platform_length, 0), AIRail.RAILTRACK_NE_SW)) return false;
			if (!AIRail.BuildRailTrack(tile + AIMap.GetTileIndex(platform_length, 1), AIRail.RAILTRACK_NE_SW)) return false;
			if (!AIRail.BuildRailTrack(tile + AIMap.GetTileIndex(1 + platform_length, 0), AIRail.RAILTRACK_NE_SW)) return false;
			if (!AIRail.BuildRailTrack(tile + AIMap.GetTileIndex(1 + platform_length, 1), AIRail.RAILTRACK_NE_SW)) return false;

			if (!AIRail.BuildRailTrack(tile + AIMap.GetTileIndex(platform_length, 0), AIRail.RAILTRACK_NE_SE)) return false;
			if (!AIRail.BuildRailTrack(tile + AIMap.GetTileIndex(platform_length, 1), AIRail.RAILTRACK_NW_SW)) return false;

			if (!AIRail.BuildRailTrack(tile + AIMap.GetTileIndex(platform_length, 1), AIRail.RAILTRACK_NW_NE)) return false;
			if (!AIRail.BuildRailTrack(tile + AIMap.GetTileIndex(platform_length, 0), AIRail.RAILTRACK_SW_SE)) return false;

			if (!AIRail.BuildSignal(tile + AIMap.GetTileIndex(platform_length + 1, second_station ? 0 : 1), tile + AIMap.GetTileIndex(platform_length + 2, second_station ? 0 : 1), AIRail.SIGNALTYPE_PBS_ONEWAY)) return false;
		} else {
			AIRail.RemoveRailStationTileRectangle(tile, tile + AIMap.GetTileIndex(1, 1), false);
			tile = tile + AIMap.GetTileIndex(2, 0);
			local tile2 = tile + AIMap.GetTileIndex(-1, 0)
			if (AITile.GetSlope(tile2) != AITile.SLOPE_FLAT) {
				AITile.RaiseTile(tile2, AITile.GetComplementSlope(AITile.GetSlope(tile2)));
			}
			if (!AIRail.BuildRailTrack(tile + AIMap.GetTileIndex(-1, 0), AIRail.RAILTRACK_NE_SW)) return false;
			if (!AIRail.BuildRailTrack(tile + AIMap.GetTileIndex(-1, 1), AIRail.RAILTRACK_NE_SW)) return false;
			if (!AIRail.BuildRailTrack(tile + AIMap.GetTileIndex(-2, 0), AIRail.RAILTRACK_NE_SW)) return false;
			if (!AIRail.BuildRailTrack(tile + AIMap.GetTileIndex(-2, 1), AIRail.RAILTRACK_NE_SW)) return false;

			if (!AIRail.BuildRailTrack(tile + AIMap.GetTileIndex(-1, 0), AIRail.RAILTRACK_SW_SE)) return false;
			if (!AIRail.BuildRailTrack(tile + AIMap.GetTileIndex(-1, 1), AIRail.RAILTRACK_NW_NE)) return false;

			if (!AIRail.BuildRailTrack(tile + AIMap.GetTileIndex(-1, 1), AIRail.RAILTRACK_NW_SW)) return false;
			if (!AIRail.BuildRailTrack(tile + AIMap.GetTileIndex(-1, 0), AIRail.RAILTRACK_NE_SE)) return false;

			if (!AIRail.BuildSignal(tile + AIMap.GetTileIndex(-2, second_station ? 0 : 1), tile + AIMap.GetTileIndex(-3, second_station ? 0 : 1), AIRail.SIGNALTYPE_PBS_ONEWAY)) return false;
		}
	}
	return true;
}

function RailRouteBuilder::ConnectRailStations(station_a, station_b)
{
	local ignored = AITileList();
	local pf = RailPF();
	local sources = [];
	local goals = [];
	local tile = AIStation.GetLocation(station_a);
	local platform_length = RailRouteBuilder.DetectPlatformLength(station_a);
	local track_near_station_a_already_build = false;
	local track_near_station_b_already_build = false;
	if (AIRail.GetRailTracks(tile) == AIRail.RAILTRACK_NW_SE) {
		local tile2 = tile + AIMap.GetTileIndex(0, -1);
		local tile3 = tile + AIMap.GetTileIndex(0, platform_length);
		if (AIRail.IsRailTile(tile2) && AICompany.IsMine(AITile.GetOwner(tile2)) && !AIRail.IsRailStationTile(tile2) && (AIRail.GetRailTracks(tile2) & AIRail.RAILTRACK_NW_SW) != 0) {
			track_near_station_a_already_build = true;
			if (AIRail.IsRailTile(tile + AIMap.GetTileIndex(0, -3)) || AITile.IsBuildableRectangle(tile + AIMap.GetTileIndex(-1, -4), 2, 2)) {
				sources.push([tile + AIMap.GetTileIndex(0, -3), tile + AIMap.GetTileIndex(0, -2)]);
			}
		} else if (AIRail.IsRailTile(tile3) && AICompany.IsMine(AITile.GetOwner(tile3)) && !AIRail.IsRailStationTile(tile3) && (AIRail.GetRailTracks(tile3) & AIRail.RAILTRACK_NW_SW) != 0) {
			track_near_station_a_already_build = true;
			if (AIRail.IsRailTile(tile + AIMap.GetTileIndex(0, platform_length + 2)) || AITile.IsBuildableRectangle(tile + AIMap.GetTileIndex(-1, platform_length + 2), 2, 2)) {
				sources.push([tile + AIMap.GetTileIndex(0, platform_length + 2), tile + AIMap.GetTileIndex(0, platform_length + 1)]);
			}
		} else {
			if (AITile.IsBuildableRectangle(tile + AIMap.GetTileIndex(-1, -2), 4, 2)) {
				sources.push([tile + AIMap.GetTileIndex(0, -1), tile + AIMap.GetTileIndex(0, 0)]);
			}
			if (AITile.IsBuildableRectangle(tile + AIMap.GetTileIndex(-1, platform_length + 2), 4, 2)) {
				sources.push([tile + AIMap.GetTileIndex(0, platform_length + 2), tile + AIMap.GetTileIndex(0, platform_length + 1)]);
			}
		}
		ignored.AddRectangle(tile + AIMap.GetTileIndex(1, -2), tile + AIMap.GetTileIndex(2, -1));
		ignored.AddRectangle(tile + AIMap.GetTileIndex(1, platform_length + 2), tile + AIMap.GetTileIndex(2, platform_length + 3));
	} else {
		local tile2 = tile + AIMap.GetTileIndex(-1, 0);
		local tile3 = tile + AIMap.GetTileIndex(platform_length, 0);
		if (AIRail.IsRailTile(tile2) && AICompany.IsMine(AITile.GetOwner(tile2)) && !AIRail.IsRailStationTile(tile2) && (AIRail.GetRailTracks(tile2) & AIRail.RAILTRACK_NE_SW) != 0) {
			track_near_station_a_already_build = true;
			if (AIRail.IsRailTile(tile + AIMap.GetTileIndex(-3, 0)) || AITile.IsBuildableRectangle(tile + AIMap.GetTileIndex(-4, -1), 2, 2)) {
				sources.push([tile + AIMap.GetTileIndex(-3, 0), tile + AIMap.GetTileIndex(-2, 0)]);
			}
		} else if (AIRail.IsRailTile(tile3) && AICompany.IsMine(AITile.GetOwner(tile3)) && !AIRail.IsRailStationTile(tile3) && (AIRail.GetRailTracks(tile3) & AIRail.RAILTRACK_NE_SW) != 0) {
			track_near_station_a_already_build = true;
			if (AIRail.IsRailTile(tile + AIMap.GetTileIndex(platform_length + 2, 0)) || AITile.IsBuildableRectangle(tile + AIMap.GetTileIndex(platform_length + 2, -1), 2, 2)) {
				sources.push([tile + AIMap.GetTileIndex(platform_length + 2, 0), tile + AIMap.GetTileIndex(platform_length + 1, 0)]);
			}
		} else {
			if (AITile.IsBuildableRectangle(tile + AIMap.GetTileIndex(-2, -1), 2, 4)) {
				sources.push([tile + AIMap.GetTileIndex(-1, 0), tile + AIMap.GetTileIndex(0, 0)]);
			}
			if (AITile.IsBuildableRectangle(tile + AIMap.GetTileIndex(platform_length + 2, -1), 2, 4)) {
				sources.push([tile + AIMap.GetTileIndex(platform_length + 2, 0), tile + AIMap.GetTileIndex(platform_length + 1, 0)]);
			}
		}
		ignored.AddRectangle(tile + AIMap.GetTileIndex(-2, 1), tile + AIMap.GetTileIndex(-1, 2));
		ignored.AddRectangle(tile + AIMap.GetTileIndex(platform_length + 2, 1), tile + AIMap.GetTileIndex(platform_length + 3, 2));
	}
	tile = AIStation.GetLocation(station_b);
	if (AIRail.GetRailTracks(tile) == AIRail.RAILTRACK_NW_SE) {
		local tile2 = tile + AIMap.GetTileIndex(0, -1);
		local tile3 = tile + AIMap.GetTileIndex(0, platform_length);
		if (AIRail.IsRailTile(tile2) && AICompany.IsMine(AITile.GetOwner(tile2)) && !AIRail.IsRailStationTile(tile2) && (AIRail.GetRailTracks(tile2) & AIRail.RAILTRACK_NW_SW) != 0) {
			track_near_station_b_already_build = true;
			if (AIRail.IsRailTile(tile + AIMap.GetTileIndex(0, -3)) || AITile.IsBuildableRectangle(tile + AIMap.GetTileIndex(-1, -4), 2, 2)) {
				goals.push([tile + AIMap.GetTileIndex(0, -3), tile + AIMap.GetTileIndex(0, -2)]);
			}
		} else if (AIRail.IsRailTile(tile3) && AICompany.IsMine(AITile.GetOwner(tile3)) && !AIRail.IsRailStationTile(tile3) && (AIRail.GetRailTracks(tile3) & AIRail.RAILTRACK_NW_SW) != 0) {
			track_near_station_b_already_build = true;
			if (AIRail.IsRailTile(tile + AIMap.GetTileIndex(0, platform_length + 2)) || AITile.IsBuildableRectangle(tile + AIMap.GetTileIndex(-1, platform_length + 2), 2, 2)) {
				goals.push([tile + AIMap.GetTileIndex(0, platform_length + 2), tile + AIMap.GetTileIndex(0, platform_length + 1)]);
			}
		} else {
			if (AITile.IsBuildableRectangle(tile + AIMap.GetTileIndex(-1, -2), 4, 2)) {
				goals.push([tile + AIMap.GetTileIndex(0, -1), tile + AIMap.GetTileIndex(0, 0)]);
			}
			if (AITile.IsBuildableRectangle(tile + AIMap.GetTileIndex(-1, platform_length + 2), 4, 2)) {
				goals.push([tile + AIMap.GetTileIndex(0, platform_length + 2), tile + AIMap.GetTileIndex(0, platform_length + 1)]);
			}
		}
		ignored.AddRectangle(tile + AIMap.GetTileIndex(1, -2), tile + AIMap.GetTileIndex(2, -1));
		ignored.AddRectangle(tile + AIMap.GetTileIndex(1, platform_length + 2), tile + AIMap.GetTileIndex(2, platform_length + 3));
	} else {
		local tile2 = tile + AIMap.GetTileIndex(-1, 0);
		local tile3 = tile + AIMap.GetTileIndex(platform_length, 0);
		if (AIRail.IsRailTile(tile2) && AICompany.IsMine(AITile.GetOwner(tile2)) && !AIRail.IsRailStationTile(tile2) && (AIRail.GetRailTracks(tile2) & AIRail.RAILTRACK_NE_SW) != 0) {
			track_near_station_b_already_build = true;
			if (AIRail.IsRailTile(tile + AIMap.GetTileIndex(-3, 0)) || AITile.IsBuildableRectangle(tile + AIMap.GetTileIndex(-4, -1), 2, 2)) {
				goals.push([tile + AIMap.GetTileIndex(-3, 0), tile + AIMap.GetTileIndex(-2, 0)]);
			}
		} else if (AIRail.IsRailTile(tile3) && AICompany.IsMine(AITile.GetOwner(tile3)) && !AIRail.IsRailStationTile(tile3) && (AIRail.GetRailTracks(tile3) & AIRail.RAILTRACK_NE_SW) != 0) {
			track_near_station_b_already_build = true;
			if (AIRail.IsRailTile(tile + AIMap.GetTileIndex(platform_length + 2, 0)) || AITile.IsBuildableRectangle(tile + AIMap.GetTileIndex(platform_length + 2, -1), 2, 2)) {
				goals.push([tile + AIMap.GetTileIndex(platform_length + 2, 0), tile + AIMap.GetTileIndex(platform_length + 1, 0)]);
			}
		} else {
			if (AITile.IsBuildableRectangle(tile + AIMap.GetTileIndex(-2, -1), 2, 4)) {
				goals.push([tile + AIMap.GetTileIndex(-1, 0), tile + AIMap.GetTileIndex(0, 0)]);
			}
			if (AITile.IsBuildableRectangle(tile + AIMap.GetTileIndex(platform_length + 2, -1), 2, 4)) {
				goals.push([tile + AIMap.GetTileIndex(platform_length + 2, 0), tile + AIMap.GetTileIndex(platform_length + 1, 0)]);
			}
		}
		ignored.AddRectangle(tile + AIMap.GetTileIndex(-2, 1), tile + AIMap.GetTileIndex(-1, 2));
		ignored.AddRectangle(tile + AIMap.GetTileIndex(platform_length + 2, 1), tile + AIMap.GetTileIndex(platform_length + 3, 2));
	}
	if (sources.len() == 0) return -1;
	if (goals.len() == 0) return -2;
	ignored.Valuate(Utils_Valuator.ItemValuator);

	local pf2 = RailPF();
	pf2.cost.reverse_signals = true;
	pf2.InitializePath(goals, sources, ignored);
	local path2 = pf2.FindPath(200);
	if (path2 == null) return -10;

	pf.cost.max_cost = AIMap.DistanceManhattan(sources[0][0], goals[0][0]) * 1.5 * (pf.cost.tile + pf.cost.new_rail);
	pf.InitializePath(sources, goals, ignored);
	local path = pf.FindPath(200000);
	local first_path = path;
	if (path == null || path == false) return -7;
	local num_retries = 3;
	local building_ok = false;
	while (num_retries-- > 0) {
		RailRouteBuilder.ImprovePath(path);
		if (RailRouteBuilder.TestBuildPath(path)) {
			if (RailRouteBuilder.BuildPath(path)) {
				building_ok = true;
				break;
			}
		}
		pf.InitializePath(sources, goals, ignored);
		path = pf.FindPath(200000);
		first_path = path;
		if (path == null || path == false) return -7;
	}
	if (!building_ok) return -9;
	RailRouteBuilder.SignalPath(path);
	local end_tile = path.GetTile();
	while (path.GetParent() != null) path = path.GetParent();
	local start_tile = path.GetTile();
	local tile = AIStation.GetLocation(station_a);
	if (!track_near_station_a_already_build && !RailRouteBuilder.BuildTrackNearStation(tile, start_tile, platform_length, false)) return -1;
	local tile = AIStation.GetLocation(station_b);
	if (!track_near_station_b_already_build && !RailRouteBuilder.BuildTrackNearStation(tile, end_tile, platform_length, true)) return -2;

	//pathfind the way back
	local sources = [];
	local goals = [];
	local ignored = AITileList();
	local tile = AIStation.GetLocation(station_a);
	if (AIRail.GetRailTracks(tile) == AIRail.RAILTRACK_NW_SE) {
		if (start_tile < tile) {
			if (AIRail.IsRailTile(tile + AIMap.GetTileIndex(1, -3)) || AITile.IsBuildableRectangle(tile + AIMap.GetTileIndex(1, -4), 2, 2)) {
				goals.push([tile + AIMap.GetTileIndex(1, -3), tile + AIMap.GetTileIndex(1, -2)]);
			}
		} else {
			if (AIRail.IsRailTile(tile + AIMap.GetTileIndex(1, platform_length + 2)) || AITile.IsBuildableRectangle(tile + AIMap.GetTileIndex(1, platform_length + 2), 2, 2)) {
				goals.push([tile + AIMap.GetTileIndex(1, platform_length + 2), tile + AIMap.GetTileIndex(1, platform_length + 1)]);
			}
		}
		ignored.AddTile(tile + AIMap.GetTileIndex(0, -1));
		ignored.AddTile(tile + AIMap.GetTileIndex(0, -2));
		ignored.AddTile(tile + AIMap.GetTileIndex(0,  platform_length + 2));
		ignored.AddTile(tile + AIMap.GetTileIndex(0,  platform_length + 3));
	} else {
		if (start_tile < tile) {
			if (AIRail.IsRailTile(tile + AIMap.GetTileIndex(-3, 1)) || AITile.IsBuildableRectangle(tile + AIMap.GetTileIndex(-4, 1), 2, 2)) {
				goals.push([tile + AIMap.GetTileIndex(-3, 1), tile + AIMap.GetTileIndex(-2, 1)]);
			}
		} else {
			if (AIRail.IsRailTile(tile + AIMap.GetTileIndex(platform_length + 2, 1)) || AITile.IsBuildableRectangle(tile + AIMap.GetTileIndex(platform_length + 2, 1), 2, 2)) {
				goals.push([tile + AIMap.GetTileIndex(platform_length + 2, 1), tile + AIMap.GetTileIndex(platform_length + 1, 1)]);
			}
		}
		ignored.AddTile(tile + AIMap.GetTileIndex(-1, 0));
		ignored.AddTile(tile + AIMap.GetTileIndex(-2, 0));
		ignored.AddTile(tile + AIMap.GetTileIndex(platform_length + 2, 0));
		ignored.AddTile(tile + AIMap.GetTileIndex(platform_length + 3, 0));
	}
	tile = AIStation.GetLocation(station_b);
	if (AIRail.GetRailTracks(tile) == AIRail.RAILTRACK_NW_SE) {
		if (end_tile < tile) {
			if (AIRail.IsRailTile(tile + AIMap.GetTileIndex(1, -3)) || AITile.IsBuildableRectangle(tile + AIMap.GetTileIndex(1, -4), 2, 2)) {
				sources.push([tile + AIMap.GetTileIndex(1, -3), tile + AIMap.GetTileIndex(1, -2)]);
			}
		} else {
			if (AIRail.IsRailTile(tile + AIMap.GetTileIndex(1, platform_length + 2)) || AITile.IsBuildableRectangle(tile + AIMap.GetTileIndex(1, platform_length + 2), 2, 2)) {
				sources.push([tile + AIMap.GetTileIndex(1, platform_length + 2), tile + AIMap.GetTileIndex(1, platform_length + 1)]);
			}
		}
		ignored.AddTile(tile + AIMap.GetTileIndex(0, -1));
		ignored.AddTile(tile + AIMap.GetTileIndex(0, -2));
		ignored.AddTile(tile + AIMap.GetTileIndex(0,  platform_length + 2));
		ignored.AddTile(tile + AIMap.GetTileIndex(0,  platform_length + 3));
	} else {
		if (end_tile < tile) {
			if (AIRail.IsRailTile(tile + AIMap.GetTileIndex(-3, 1)) || AITile.IsBuildableRectangle(tile + AIMap.GetTileIndex(-4, 1), 2, 2)) {
				sources.push([tile + AIMap.GetTileIndex(-3, 1), tile + AIMap.GetTileIndex(-2, 1)]);
			}
		} else {
			if (AIRail.IsRailTile(tile + AIMap.GetTileIndex(platform_length + 2, 1)) || AITile.IsBuildableRectangle(tile + AIMap.GetTileIndex(platform_length + 2, 1), 2, 2)) {
				sources.push([tile + AIMap.GetTileIndex(platform_length + 2, 1), tile + AIMap.GetTileIndex(platform_length + 1, 1)]);
			}
		}
		ignored.AddTile(tile + AIMap.GetTileIndex(-1, 0));
		ignored.AddTile(tile + AIMap.GetTileIndex(-2, 0));
		ignored.AddTile(tile + AIMap.GetTileIndex(platform_length + 2, 0));
		ignored.AddTile(tile + AIMap.GetTileIndex(platform_length + 3, 0));
	}
	if (goals.len() == 0) return -1;
	if (sources.len() == 0) return -2;
	ignored.Valuate(Utils_Valuator.ItemValuator);

	local pf2 = RailPF();
	pf2.cost.reverse_signals = true;
	pf2.InitializePath(goals, sources, ignored);
	local path2 = pf2.FindPath(200);
	if (path2 == null) return -11;

	pf.cost.max_cost = AIMap.DistanceManhattan(sources[0][0], goals[0][0]) * 1.5 * (pf.cost.tile + pf.cost.new_rail);
	pf.InitializePath(sources, goals, ignored);
	local path = pf.FindPath(200000);
	if (path == null || path == false) return -8;
	local num_retries = 3;
	local building_ok = false;
	while (num_retries-- > 0) {
		RailRouteBuilder.ImprovePath(path);
		if (RailRouteBuilder.TestBuildPath(path)) {
			if (RailRouteBuilder.BuildPath(path)) {
				building_ok = true;
				break;
			}
		}
		pf.InitializePath(sources, goals, ignored);
		path = pf.FindPath(200000);
		if (path == null || path == false) return -8;
	}
	if (!building_ok) return -5;
	local depot1 = RailRouteBuilder.BuildDepot(path, AIController.GetSetting("depot_near_station"));
	local depot2 = RailRouteBuilder.BuildDepot(first_path, AIController.GetSetting("depot_near_station"));
	if (depot1 == null && depot2 == null) {
		AILog.Error("COuldn't find a place for a rail depot!");
		return -6;
	}
	RailRouteBuilder.SignalPath(path);
	return [depot1, depot2];
}

/**
 * Get the slope if a rail is build on certain tile.
 * Return 0 if not sloped,
 * 1 if end > start,
 * 2 if end < start.
 */
function RailRouteBuilder::GetSlope(start, middle, end)
{
	local NW = 0; // Set to true if we want to build a rail to / from the north-west
	local NE = 0; // Set to true if we want to build a rail to / from the north-east
	local SW = 0; // Set to true if we want to build a rail to / from the south-west
	local SE = 0; // Set to true if we want to build a rail to / from the south-east

	if (middle - AIMap.GetMapSizeX() == start || middle - AIMap.GetMapSizeX() == end) NW = 1;
	if (middle - 1 == start || middle - 1 == end) NE = 1;
	if (middle + AIMap.GetMapSizeX() == start || middle + AIMap.GetMapSizeX() == end) SE = 1;
	if (middle + 1 == start || middle + 1 == end) SW = 1;

	/* If there is a turn in the current tile, it can't be sloped. */
	if ((NW || SE) && (NE || SW)) return 0;

	local slope = AITile.GetSlope(middle);
	/* A rail on a steep slope is always sloped. */
	if (AITile.IsSteepSlope(slope)) {
		switch (slope) {
			case AITile.SLOPE_STEEP_W: slope = AITile.SLOPE_W; break;
			case AITile.SLOPE_STEEP_S: slope = AITile.SLOPE_S; break;
			case AITile.SLOPE_STEEP_E: slope = AITile.SLOPE_E; break;
			case AITile.SLOPE_STEEP_N: slope = AITile.SLOPE_N; break;
			default: throw("Not reached");
		}
	}

	/* If only one corner is raised, the rail is sloped. */
	switch (slope) {
		case AITile.SLOPE_N: return (end < start) ? 1 : 2;
		case AITile.SLOPE_S: return (end < start) ? 2 : 1;
		case AITile.SLOPE_E:
			if (abs(start - end) == 2) {
				return (end < start) ? 1 : 2;
			} else {
				return (end < start) ? 2 : 1;
			}
		case AITile.SLOPE_W:
			if (abs(start - end) == 2) {
				return (end < start) ? 2 : 1;
			} else {
				return (end < start) ? 1 : 2;
			}
	}

	if (NW && (slope == AITile.SLOPE_NW)) return (end < start) ? 1 : 2;
	if (NW && (slope == AITile.SLOPE_SE)) return (end < start) ? 2 : 1;
	if (NE && (slope == AITile.SLOPE_NE)) return (end < start) ? 1 : 2;
	if (NE && (slope == AITile.SLOPE_SW)) return (end < start) ? 2 : 1;

	return 0;
}

function RailRouteBuilder::ImprovePath(path)
{
	local p1 = null;
	local p2 = null;
	local p3 = null;
	local p4 = null;
	while (path != null) {
		local p0 = path.GetTile();
		if (p1 != null && AIMap.DistanceManhattan(p0, p1) != 1) {
			p0 = null;
			p1 = null;
			p2 = null;
			p3 = null;
			p4 = null;
		}
		if (p4 != null) {
			local s1 = RailRouteBuilder.GetSlope(p0, p1, p2);
			local s2 = RailRouteBuilder.GetSlope(p1, p2, p3);
			local s3 = RailRouteBuilder.GetSlope(p2, p3, p4);
			if (s2 == 0 && s1 != 0 && s3 != 0 && s1 != s3) {
				if (s1 == 2) {
					AITile.RaiseTile(p2, AITile.GetComplementSlope(AITile.GetSlope(p2)));
				} else {
					local slope = AITile.GetSlope(p2);
					if (slope == AITile.SLOPE_FLAT) slope = AITile.SLOPE_ELEVATED;
					AITile.LowerTile(p2, slope);
				}
			}
		}
		if (p3 != null) {
			local s1 = RailRouteBuilder.GetSlope(p0, p1, p2);
			local s2 = RailRouteBuilder.GetSlope(p1, p2, p3);
			if (s1 != 0 && s2 != 0 && s1 != s2) {
				if (s1 == 2) {
					AITile.RaiseTile(p1, AITile.GetComplementSlope(AITile.GetSlope(p1)));
				} else {
					AITile.LowerTile(p1, AITile.GetSlope(p1));
				}
			}
		}
		p4 = p3;
		p3 = p2;
		p2 = p1;
		p1 = p0;
		path = path.GetParent();
	}
}

function RailRouteBuilder::TestBuildPath(path)
{
	local test = AITestMode();
	local res = RailRouteBuilder.BuildPath(path);
	return res;
}

function RailRouteBuilder::BuildPath(path)
{
	if (path == null) return false;
	local prev = null;
	local prevprev = null;
	local orig_path = path;
	while (path != null) {
		//AISign.BuildSign(path.GetTile(), "" + path.GetCost());
		if (prevprev != null) {
			if (AIMap.DistanceManhattan(prev, path.GetTile()) > 1) {
				if (AITunnel.GetOtherTunnelEnd(prev) == path.GetTile()) {
					if (AITunnel.IsTunnelTile(prev)) {
						if (AIRail.GetCurrentRailType() != AIRail.GetRailType(prev)) {
							assert(AIRail.TrainHasPowerOnRail(AIRail.GetRailType(prev), AIRail.GetCurrentRailType()));
							if (!AIRail.ConvertRailType(prev, prev, AIRail.GetCurrentRailType())) {
								AILog.Error("4 " + AIError.GetLastErrorString());
								return false;
							}
						}
					} else if (!AITunnel.BuildTunnel(AIVehicle.VT_RAIL, prev)) {
						AILog.Error("1 " + AIError.GetLastErrorString());
						return false;
					}
				} else {
					if (AIBridge.IsBridgeTile(prev)) {
						if (AIRail.GetCurrentRailType() != AIRail.GetRailType(prev)) {
							assert(AIRail.TrainHasPowerOnRail(AIRail.GetRailType(prev), AIRail.GetCurrentRailType()));
							if (!AIRail.ConvertRailType(prev, prev, AIRail.GetCurrentRailType())) {
								AILog.Error("5 " + AIError.GetLastErrorString());
								return false;
							}
						}
					} else {
						local bridge_list = AIBridgeList_Length(AIMap.DistanceManhattan(path.GetTile(), prev) + 1);
						bridge_list.Valuate(AIBridge.GetMaxSpeed);
						bridge_list.Sort(AIAbstractList.SORT_BY_VALUE, AIAbstractList.SORT_DESCENDING);
						if (!AIBridge.BuildBridge(AIVehicle.VT_RAIL, bridge_list.Begin(), prev, path.GetTile())) {
							AILog.Error("2 " + AIError.GetLastErrorString());
							return false;
						}
					}
				}
				prevprev = prev;
				prev = path.GetTile();
				path = path.GetParent();
			} else {
				if (AIRail.IsRailTile(prev) && !AICompany.IsMine(AITile.GetOwner(prev))) return false;
				if (!AIRail.AreTilesConnected(prevprev, prev, path.GetTile())) {
					if (!AIRail.BuildRail(prevprev, prev, path.GetTile())) {
						local num_tries = 20;
						local ok = false;
						while (AIError.GetLastError() == AIError.ERR_VEHICLE_IN_THE_WAY && num_tries-- > 0) {
							AIController.Sleep(74);
							if (AIRail.BuildRail(prevprev, prev, path.GetTile())) { ok = true; break; }
						}
						if (!ok) {
							AILog.Error(prevprev + "   " + prev + "   " + path.GetTile());
							AILog.Error("3 " + AIError.GetLastErrorString());
							if (AIController.GetSetting("debug_signs")) {
								AISign.BuildSign(prevprev, "1");
								AISign.BuildSign(prev, "2");
								AISign.BuildSign(path.GetTile(),  "3");
							}
							return false;
						}
					}
				} else if (AIRail.GetRailType(prev) != AIRail.GetCurrentRailType()) {
						assert(AIRail.TrainHasPowerOnRail(AIRail.GetRailType(prev), AIRail.GetCurrentRailType()));
						if (!AIRail.ConvertRailType(prev, prev, AIRail.GetCurrentRailType())) {
							AILog.Error("6 " + AIError.GetLastErrorString());
							if (AIController.GetSetting("debug_signs")) AISign.BuildSign(prev, "!! " + AIRail.GetRailType(prev) + "  " + AIRail.GetCurrentRailType());
							return false;
						}
				}
			}
		}
		if (path != null) {
			prevprev = prev;
			prev = path.GetTile();
			path = path.GetParent();
		}
	}
	return true;
}

function RailRouteBuilder::SignalPath(path)
{
	local prev = null;
	local prevprev = null;
	local tiles_skipped = 39;
	local lastbuild_tile = null;
	local lastbuild_front_tile = null;
	while (path != null) {
		if (prevprev != null) {
			if (AIMap.DistanceManhattan(prev, path.GetTile()) > 1) {
				tiles_skipped += 10 * AIMap.DistanceManhattan(prev, path.GetTile());
			} else {
				if (path.GetTile() - prev != prev - prevprev) {
					tiles_skipped += 7;
				} else {
					tiles_skipped += 10;
				}
				if (AIRail.GetSignalType(prev, path.GetTile()) != AIRail.SIGNALTYPE_NONE) tiles_skipped = 0;
				if (tiles_skipped > 49 && path.GetParent() != null) {
					if (AIRail.BuildSignal(prev, path.GetTile(), AIRail.SIGNALTYPE_PBS)) {
						tiles_skipped = 0;
						lastbuild_tile = prev;
						lastbuild_front_tile = path.GetTile();
					}
				}
			}
		}
		prevprev = prev;
		prev = path.GetTile();
		path = path.GetParent();
	}
	/* Although this provides better signalling (trains cannot get stuck half in the station),
	 * it is also the cause of using the same track of rails both ways, possible causing deadlocks.
	if (tiles_skipped < 50 && lastbuild_tile != null) {
		AIRail.RemoveSignal(lastbuild_tile, lastbuild_front_tile);
	}*/
}

class RPathItem
{
	_tile = null;
	_parent = null;

	constructor(tile)
	{
		this._tile = tile;
	}

	function GetTile()
	{
		return this._tile;
	}

	function GetParent()
	{
		return this._parent;
	}
};

function ConnectDepotDiagonal(tile_a, tile_b, tile_c)
{
	if (!AITile.IsBuildable(tile_c) && (!AIRail.IsRailTile(tile_c) || !AICompany.IsMine(AITile.GetOwner(tile_c)))) return null;
	local offset1 = (tile_c - tile_a) / 2;
	local offset2 = (tile_c - tile_b) / 2;
	local depot_tile = null;
	local depot_build = false;
	local tiles = [];
	tiles.append([tile_a, tile_a + offset1, tile_c]);
	tiles.append([tile_b, tile_b + offset2, tile_c]);
	if (AIRail.IsRailDepotTile(tile_c + offset1) && AIRail.GetRailDepotFrontTile(tile_c + offset1) == tile_c &&
			AIRail.TrainHasPowerOnRail(AIRail.GetRailType(tile_c + offset1), AIRail.GetCurrentRailType())) {
		/* If we can't build trains for the current rail type in the depot, see if we can
		 * convert it without problems. */
		if (!AIRail.TrainHasPowerOnRail(AIRail.GetCurrentRailType(), AIRail.GetRailType(tile_c + offset1))) {
			if (!AIRail.ConvertRailType(tile_c + offset1, tile_c + offset1, AIRail.GetCurrentRailType())) return null;
		}
		depot_tile = tile_c + offset1;
		depot_build = true;
		tiles.append([tile_a + offset1, tile_c, tile_c + offset1]);
		tiles.append([tile_b + offset2, tile_c, tile_c + offset1]);
	} else if (AIRail.IsRailDepotTile(tile_c + offset2) && AIRail.GetRailDepotFrontTile(tile_c + offset2) == tile_c &&
			AIRail.TrainHasPowerOnRail(AIRail.GetRailType(tile_c + offset2), AIRail.GetCurrentRailType())) {
		/* If we can't build trains for the current rail type in the depot, see if we can
		 * convert it without problems. */
		if (!AIRail.TrainHasPowerOnRail(AIRail.GetCurrentRailType(), AIRail.GetRailType(tile_c + offset2))) {
			if (!AIRail.ConvertRailType(tile_c + offset2, tile_c + offset2, AIRail.GetCurrentRailType())) return null;
		}
		depot_tile = tile_c + offset2;
		depot_build = true;
		tiles.append([tile_a + offset1, tile_c, tile_c + offset2]);
		tiles.append([tile_b + offset2, tile_c, tile_c + offset2]);
	} else if (AITile.IsBuildable(tile_c + offset1)) {
		if (AITile.GetMaxHeight(tile_c) != AITile.GetMaxHeight(tile_a) &&
			!AITile.RaiseTile(tile_c, AITile.GetComplementSlope(AITile.GetSlope(tile_c)))) return null;
		if (AITile.GetMaxHeight(tile_c) != AITile.GetMaxHeight(tile_a) &&
			!AITile.RaiseTile(tile_c, AITile.GetComplementSlope(AITile.GetSlope(tile_c)))) return null;
		depot_tile = tile_c + offset1;
		tiles.append([tile_a + offset1, tile_c, tile_c + offset1]);
		tiles.append([tile_b + offset2, tile_c, tile_c + offset1]);
	} else if (AITile.IsBuildable(tile_c + offset2)) {
		if (AITile.GetMaxHeight(tile_c) != AITile.GetMaxHeight(tile_a) &&
			!AITile.RaiseTile(tile_c, AITile.GetComplementSlope(AITile.GetSlope(tile_c)))) return null;
		if (AITile.GetMaxHeight(tile_c) != AITile.GetMaxHeight(tile_a) &&
			!AITile.RaiseTile(tile_c, AITile.GetComplementSlope(AITile.GetSlope(tile_c)))) return null;
		depot_tile = tile_c + offset2;
		tiles.append([tile_a + offset1, tile_c, tile_c + offset2]);
		tiles.append([tile_b + offset2, tile_c, tile_c + offset2]);
	} else {
		return null;
	}
	{
		local test = AITestMode();
		foreach (t in tiles) {
			if (!AIRail.AreTilesConnected(t[0], t[1], t[2]) && !AIRail.BuildRail(t[0], t[1], t[2])) return null;
		}
		if (!depot_build && !AIRail.BuildRailDepot(depot_tile, tile_c)) return null;
	}
	foreach (t in tiles) {
		if (!AIRail.AreTilesConnected(t[0], t[1], t[2]) && !AIRail.BuildRail(t[0], t[1], t[2])) return null;
	}
	if (!depot_build && !AIRail.BuildRailDepot(depot_tile, tile_c)) return null;
	return depot_tile;
}

function RailRouteBuilder::BuildDepot(path, reverse)
{
	if (reverse) {
		local rpath = RPathItem(path.GetTile());
		while (path.GetParent() != null) {
			path = path.GetParent();
			local npath = RPathItem(path.GetTile());
			npath._parent = rpath;
			rpath = npath;
		}
		path = rpath;
	}
	local prev = null;
	local pp = null;
	local ppp = null;
	local pppp = null;
	local ppppp = null;
	while (path != null) {
		if (ppppp != null) {
			if (ppppp - pppp == pppp - ppp && pppp - ppp == ppp - pp && ppp - pp == pp - prev) {
				local offsets = [AIMap.GetTileIndex(0, 1), AIMap.GetTileIndex(0, -1),
				                 AIMap.GetTileIndex(1, 0), AIMap.GetTileIndex(-1, 0)];
				foreach (offset in offsets) {
					if (AITile.GetMaxHeight(ppp + offset) != AITile.GetMaxHeight(ppp)) continue;
					local depot_build = false;
					if (AIRail.IsRailDepotTile(ppp + offset)) {
						if (AIRail.GetRailDepotFrontTile(ppp + offset) != ppp) continue;
						if (!AIRail.TrainHasPowerOnRail(AIRail.GetRailType(ppp + offset), AIRail.GetCurrentRailType())) continue;
						/* If we can't build trains for the current rail type in the depot, see if we can
						 * convert it without problems. */
						if (!AIRail.TrainHasPowerOnRail(AIRail.GetCurrentRailType(), AIRail.GetRailType(ppp + offset))) {
							if (!AIRail.ConvertRailType(ppp + offset, ppp + offset, AIRail.GetCurrentRailType())) continue;
						}
						depot_build = true;
					} else {
						local test = AITestMode();
						if (!AIRail.BuildRailDepot(ppp + offset, ppp)) continue;
					}
					if (!AIRail.AreTilesConnected(pp, ppp, ppp + offset) && !AIRail.BuildRail(pp, ppp, ppp + offset)) continue;
					if (!AIRail.AreTilesConnected(pppp, ppp, ppp + offset) && !AIRail.BuildRail(pppp, ppp, ppp + offset)) continue;
					if (depot_build || AIRail.BuildRailDepot(ppp + offset, ppp)) return ppp + offset;
				}
			} else if (ppppp - ppp == ppp - prev && ppppp - pppp != pp - prev) {
				local offsets = null;
				if (abs(ppppp - ppp) == AIMap.GetTileIndex(1, 1)) {
					if (ppppp - pppp == AIMap.GetTileIndex(1, 0) || prev - pp == AIMap.GetTileIndex(1, 0)) {
						local d = ConnectDepotDiagonal(prev, ppppp, max(prev, ppppp) + AIMap.GetTileIndex(-2, 0));
						if (d != null) return d;
					} else {
						local d = ConnectDepotDiagonal(prev, ppppp, max(prev, ppppp) + AIMap.GetTileIndex(0, -2));
						if (d != null) return d;
					}
				} else {
					if (ppppp - pppp == AIMap.GetTileIndex(0, -1) || prev - pp == AIMap.GetTileIndex(0, -1)) {
						local d = ConnectDepotDiagonal(prev, ppppp, max(prev, ppppp) + AIMap.GetTileIndex(2, 0));
						if (d != null) return d;
					} else {
						local d = ConnectDepotDiagonal(prev, ppppp, max(prev, ppppp) + AIMap.GetTileIndex(0, -2));
						if (d != null) return d;
					}
				}
			}
		}
		ppppp = pppp;
		pppp = ppp;
		ppp = pp;
		pp = prev;
		prev = path.GetTile();
		path = path.GetParent();
	}
	return null;
}
