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
};

function RailRouteBuilder::DetectPlatformLength(station)
{
	local tile = AIStation.GetLocation(station);
	local length = 0;
	if (AIRail.GetRailTracks(tile) == AIRail.RAILTRACK_NW_SE) {
		local tile_before = tile + AIMap.GetTileIndex(0, -1);
		while (AIStation.GetStationID(tile) == station && AIRail.GetRailTracks(tile) == AIRail.RAILTRACK_NW_SE) {
			length++;
			tile += AIMap.GetTileIndex(0, 1);
		}
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
	AILog.Info("BuildTrackNearStation");
	if (AIRail.GetRailTracks(tile) == AIRail.RAILTRACK_NW_SE) {
		if (start_tile > tile) {
			AIRail.RemoveRailStationTileRect(tile + AIMap.GetTileIndex(0, platform_length), tile + AIMap.GetTileIndex(1, platform_length + 1));
			local tile2 = tile + AIMap.GetTileIndex(0, platform_length)
			if (AITile.GetSlope(tile2) != AITile.SLOPE_FLAT) {
				if (!AITile.RaiseTile(tile2, AITile.GetComplementSlope(AITile.GetSlope(tile2)))) return false;
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
			AIRail.RemoveRailStationTileRect(tile, tile + AIMap.GetTileIndex(1, 1));
			tile = tile + AIMap.GetTileIndex(0, 2);
			local tile2 = tile + AIMap.GetTileIndex(0, -1)
			if (AITile.GetSlope(tile2) != AITile.SLOPE_FLAT) {
				if (!AITile.RaiseTile(tile2, AITile.GetComplementSlope(AITile.GetSlope(tile2)))) return false;
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
			AIRail.RemoveRailStationTileRect(tile + AIMap.GetTileIndex(platform_length, 0), tile + AIMap.GetTileIndex(platform_length + 1, 1));
			local tile2 = tile + AIMap.GetTileIndex(platform_length, 0)
			if (AITile.GetSlope(tile2) != AITile.SLOPE_FLAT) {
				if (!AITile.RaiseTile(tile2, AITile.GetComplementSlope(AITile.GetSlope(tile2)))) return false;
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
			AIRail.RemoveRailStationTileRect(tile, tile + AIMap.GetTileIndex(1, 1));
			tile = tile + AIMap.GetTileIndex(2, 0);
			local tile2 = tile + AIMap.GetTileIndex(-1, 0)
			if (AITile.GetSlope(tile2) != AITile.SLOPE_FLAT) {
				if (!AITile.RaiseTile(tile2, AITile.GetComplementSlope(AITile.GetSlope(tile2)))) return false;
			}
			if (!AIRail.BuildRailTrack(tile + AIMap.GetTileIndex(-1, 0), AIRail.RAILTRACK_NE_SW)) return false;
			if (!AIRail.BuildRailTrack(tile + AIMap.GetTileIndex(-1, 1), AIRail.RAILTRACK_NE_SW)) return false;
			if (!AIRail.BuildRailTrack(tile + AIMap.GetTileIndex(-2, 0), AIRail.RAILTRACK_NE_SW)) return false;
			if (!AIRail.BuildRailTrack(tile + AIMap.GetTileIndex(-2, 1), AIRail.RAILTRACK_NE_SW)) return false;

			if (!AIRail.BuildRailTrack(tile + AIMap.GetTileIndex(-1, 0), AIRail.RAILTRACK_SW_SE)) return false;
			if (!AIRail.BuildRailTrack(tile + AIMap.GetTileIndex(-1, 1), AIRail.RAILTRACK_NW_NE)) return false;

			if (!AIRail.BuildRailTrack(tile + AIMap.GetTileIndex(-1, 1), AIRail.RAILTRACK_NE_SE)) return false;
			if (!AIRail.BuildRailTrack(tile + AIMap.GetTileIndex(-1, 0), AIRail.RAILTRACK_NW_SW)) return false;

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
			sources.push([tile + AIMap.GetTileIndex(0, -3), tile + AIMap.GetTileIndex(0, -2)]);
		} else if (AIRail.IsRailTile(tile3) && AICompany.IsMine(AITile.GetOwner(tile3)) && !AIRail.IsRailStationTile(tile3) && (AIRail.GetRailTracks(tile3) & AIRail.RAILTRACK_NW_SW) != 0) {
			track_near_station_a_already_build = true;
			sources.push([tile + AIMap.GetTileIndex(0, platform_length + 2), tile + AIMap.GetTileIndex(0, platform_length + 1)]);
		} else {
			if (AITile.IsBuildableRectangle(tile + AIMap.GetTileIndex(0, -1), 2, 1)) {
				sources.push([tile + AIMap.GetTileIndex(0, -1), tile + AIMap.GetTileIndex(0, 0)]);
			}
			if (AITile.IsBuildableRectangle(tile + AIMap.GetTileIndex(0, platform_length + 2), 2, 1)) {
				sources.push([tile + AIMap.GetTileIndex(0, platform_length + 2), tile + AIMap.GetTileIndex(0, platform_length + 1)]);
			}
			ignored.AddRectangle(tile + AIMap.GetTileIndex(1, -2), tile + AIMap.GetTileIndex(2, -1));
			ignored.AddRectangle(tile + AIMap.GetTileIndex(1, platform_length + 2), tile + AIMap.GetTileIndex(2, platform_length + 3));
		}
	} else {
		local tile2 = tile + AIMap.GetTileIndex(-1, 0);
		local tile3 = tile + AIMap.GetTileIndex(platform_length, 0);
		if (AIRail.IsRailTile(tile2) && AICompany.IsMine(AITile.GetOwner(tile2)) && !AIRail.IsRailStationTile(tile2) && (AIRail.GetRailTracks(tile2) & AIRail.RAILTRACK_NE_SW) != 0) {
			track_near_station_a_already_build = true;
			sources.push([tile + AIMap.GetTileIndex(-3, 0), tile + AIMap.GetTileIndex(-2, 0)]);
		} else if (AIRail.IsRailTile(tile3) && AICompany.IsMine(AITile.GetOwner(tile3)) && !AIRail.IsRailStationTile(tile3) && (AIRail.GetRailTracks(tile3) & AIRail.RAILTRACK_NE_SW) != 0) {
			track_near_station_a_already_build = true;
			sources.push([tile + AIMap.GetTileIndex(platform_length + 2, 0), tile + AIMap.GetTileIndex(platform_length + 1, 0)]);
		} else {
			if (AITile.IsBuildableRectangle(tile + AIMap.GetTileIndex(-1, 0), 1, 2)) {
				sources.push([tile + AIMap.GetTileIndex(-1, 0), tile + AIMap.GetTileIndex(0, 0)]);
			}
			if (AITile.IsBuildableRectangle(tile + AIMap.GetTileIndex(platform_length + 2, 0), 1, 2)) {
				sources.push([tile + AIMap.GetTileIndex(platform_length + 2, 0), tile + AIMap.GetTileIndex(platform_length + 1, 0)]);
			}
			ignored.AddRectangle(tile + AIMap.GetTileIndex(-2, 1), tile + AIMap.GetTileIndex(-1, 2));
			ignored.AddRectangle(tile + AIMap.GetTileIndex(platform_length + 2, 1), tile + AIMap.GetTileIndex(platform_length + 3, 2));
		}
	}
	tile = AIStation.GetLocation(station_b);
	if (AIRail.GetRailTracks(tile) == AIRail.RAILTRACK_NW_SE) {
		local tile2 = tile + AIMap.GetTileIndex(0, -1);
		local tile3 = tile + AIMap.GetTileIndex(0, platform_length);
		if (AIRail.IsRailTile(tile2) && AICompany.IsMine(AITile.GetOwner(tile2)) && !AIRail.IsRailStationTile(tile2) && (AIRail.GetRailTracks(tile2) & AIRail.RAILTRACK_NW_SW) != 0) {
			track_near_station_b_already_build = true;
			goals.push([tile + AIMap.GetTileIndex(0, -3), tile + AIMap.GetTileIndex(0, -2)]);
		} else if (AIRail.IsRailTile(tile3) && AICompany.IsMine(AITile.GetOwner(tile3)) && !AIRail.IsRailStationTile(tile3) && (AIRail.GetRailTracks(tile3) & AIRail.RAILTRACK_NW_SW) != 0) {
			track_near_station_b_already_build = true;
			goals.push([tile + AIMap.GetTileIndex(0, platform_length + 2), tile + AIMap.GetTileIndex(0, platform_length + 1)]);
		} else {
			if (AITile.IsBuildableRectangle(tile + AIMap.GetTileIndex(0, -1), 2, 1)) {
				goals.push([tile + AIMap.GetTileIndex(0, -1), tile + AIMap.GetTileIndex(0, 0)]);
			}
			if (AITile.IsBuildableRectangle(tile + AIMap.GetTileIndex(0, platform_length + 2), 2, 1)) {
				goals.push([tile + AIMap.GetTileIndex(0, platform_length + 2), tile + AIMap.GetTileIndex(0, platform_length + 1)]);
			}
			ignored.AddRectangle(tile + AIMap.GetTileIndex(1, -2), tile + AIMap.GetTileIndex(2, -1));
			ignored.AddRectangle(tile + AIMap.GetTileIndex(1, platform_length + 2), tile + AIMap.GetTileIndex(2, platform_length + 3));
		}
	} else {
		local tile2 = tile + AIMap.GetTileIndex(-1, 0);
		local tile3 = tile + AIMap.GetTileIndex(platform_length, 0);
		if (AIRail.IsRailTile(tile2) && AICompany.IsMine(AITile.GetOwner(tile2)) && !AIRail.IsRailStationTile(tile2) && (AIRail.GetRailTracks(tile2) & AIRail.RAILTRACK_NE_SW) != 0) {
			track_near_station_b_already_build = true;
			goals.push([tile + AIMap.GetTileIndex(-3, 0), tile + AIMap.GetTileIndex(-2, 0)]);
		} else if (AIRail.IsRailTile(tile3) && AICompany.IsMine(AITile.GetOwner(tile3)) && !AIRail.IsRailStationTile(tile3) && (AIRail.GetRailTracks(tile3) & AIRail.RAILTRACK_NE_SW) != 0) {
			track_near_station_b_already_build = true;
			goals.push([tile + AIMap.GetTileIndex(platform_length + 2, 0), tile + AIMap.GetTileIndex(platform_length + 1, 0)]);
		} else {
			if (AITile.IsBuildableRectangle(tile + AIMap.GetTileIndex(-1, 0), 1, 2)) {
				goals.push([tile + AIMap.GetTileIndex(1, 0), tile + AIMap.GetTileIndex(0, 0)]);
			}
			if (AITile.IsBuildableRectangle(tile + AIMap.GetTileIndex(platform_length + 2, 0), 1, 2)) {
				goals.push([tile + AIMap.GetTileIndex(platform_length + 2, 0), tile + AIMap.GetTileIndex(platform_length + 1, 0)]);
			}
			ignored.AddRectangle(tile + AIMap.GetTileIndex(-2, 1), tile + AIMap.GetTileIndex(-1, 2));
			ignored.AddRectangle(tile + AIMap.GetTileIndex(platform_length + 2, 1), tile + AIMap.GetTileIndex(platform_length + 3, 2));
		}
	}
	if (sources.len() == 0 || goals.len() == 0) return -1;
	ignored.Valuate(AdmiralAI.ItemValuator);
	pf.cost.max_cost = AIMap.DistanceManhattan(sources[0][0], goals[0][0]) * 1.5 * (pf.cost.tile + pf.cost.new_rail);
	pf.InitializePath(sources, goals, ignored);
	local path = pf.FindPath(200000);
	local first_path = path;
	if (path == null || path == false) return -7;
	local num_retries = 3;
	local building_ok = false;
	while (num_retries-- > 0) {
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
	if (!building_ok) return -2;
	RailRouteBuilder.SignalPath(path);
	local end_tile = path.GetTile();
	while (path.GetParent() != null) path = path.GetParent();
	local start_tile = path.GetTile();
	local tile = AIStation.GetLocation(station_a);
	if (!track_near_station_a_already_build && !RailRouteBuilder.BuildTrackNearStation(tile, start_tile, platform_length, false)) return -3;
	local tile = AIStation.GetLocation(station_b);
	if (!track_near_station_b_already_build && !RailRouteBuilder.BuildTrackNearStation(tile, end_tile, platform_length, true)) return -4;

	//pathfind the way back
	local sources = [];
	local goals = [];
	local ignored = AITileList();
	local tile = AIStation.GetLocation(station_a);
	if (AIRail.GetRailTracks(tile) == AIRail.RAILTRACK_NW_SE) {
		if (start_tile < tile) {
			goals.push([tile + AIMap.GetTileIndex(1, -3), tile + AIMap.GetTileIndex(1, -2)]);
		} else {
			goals.push([tile + AIMap.GetTileIndex(1, platform_length + 2), tile + AIMap.GetTileIndex(1, platform_length + 1)]);
		}
		ignored.AddTile(tile + AIMap.GetTileIndex(0, -1));
		ignored.AddTile(tile + AIMap.GetTileIndex(0, -2));
		ignored.AddTile(tile + AIMap.GetTileIndex(0,  platform_length + 2));
		ignored.AddTile(tile + AIMap.GetTileIndex(0,  platform_length + 3));
	} else {
		if (start_tile < tile) {
			goals.push([tile + AIMap.GetTileIndex(-3, 1), tile + AIMap.GetTileIndex(-2, 1)]);
		} else {
			goals.push([tile + AIMap.GetTileIndex(platform_length + 2, 1), tile + AIMap.GetTileIndex(platform_length + 1, 1)]);
		}
		ignored.AddTile(tile + AIMap.GetTileIndex(-1, 0));
		ignored.AddTile(tile + AIMap.GetTileIndex(-2, 0));
		ignored.AddTile(tile + AIMap.GetTileIndex(platform_length + 2, 0));
		ignored.AddTile(tile + AIMap.GetTileIndex(platform_length + 3, 0));
	}
	tile = AIStation.GetLocation(station_b);
	if (AIRail.GetRailTracks(tile) == AIRail.RAILTRACK_NW_SE) {
		if (end_tile < tile) {
			sources.push([tile + AIMap.GetTileIndex(1, -3), tile + AIMap.GetTileIndex(1, -2)]);
		} else {
			sources.push([tile + AIMap.GetTileIndex(1, platform_length + 2), tile + AIMap.GetTileIndex(1, platform_length + 1)]);
		}
		ignored.AddTile(tile + AIMap.GetTileIndex(0, -1));
		ignored.AddTile(tile + AIMap.GetTileIndex(0, -2));
		ignored.AddTile(tile + AIMap.GetTileIndex(0,  platform_length + 2));
		ignored.AddTile(tile + AIMap.GetTileIndex(0,  platform_length + 3));
	} else {
		if (end_tile < tile) {
			sources.push([tile + AIMap.GetTileIndex(-3, 1), tile + AIMap.GetTileIndex(-2, 1)]);
		} else {
			sources.push([tile + AIMap.GetTileIndex(platform_length + 2, 1), tile + AIMap.GetTileIndex(platform_length + 1, 1)]);
		}
		ignored.AddTile(tile + AIMap.GetTileIndex(-1, 0));
		ignored.AddTile(tile + AIMap.GetTileIndex(-2, 0));
		ignored.AddTile(tile + AIMap.GetTileIndex(platform_length + 2, 0));
		ignored.AddTile(tile + AIMap.GetTileIndex(platform_length + 3, 0));
	}
	ignored.Valuate(AdmiralAI.ItemValuator);
	pf.cost.max_cost = AIMap.DistanceManhattan(sources[0][0], goals[0][0]) * 1.5 * (pf.cost.tile + pf.cost.new_rail);
	pf.InitializePath(sources, goals, ignored);
	local path = pf.FindPath(200000);
	if (path == null || path == false) return -8;
	local num_retries = 3;
	local building_ok = false;
	while (num_retries-- > 0) {
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
	local depot1 = RailRouteBuilder.BuildDepot(path);
	local depot2 = RailRouteBuilder.BuildDepot(first_path);
	if (depot1 == null && depot2 == null) {
		AILog.Error("COuldn't find a place for a rail depot!");
		return -6;
	}
	RailRouteBuilder.SignalPath(path);
	return [depot1, depot2];
}

function RailRouteBuilder::TestBuildPath(path)
{
	local test = AITestMode();
	return RailRouteBuilder.BuildPath(path);
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
					if (!AITunnel.BuildTunnel(AIVehicle.VEHICLE_RAIL, prev)) {
						if (AIError.GetLastError() != AIError.ERR_ALREADY_BUILT || !AICompany.IsMine(AITile.GetOwner(prev))) {
							AILog.Error("1 " + AIError.GetLastErrorString());
							return false;
						}
					}
				} else {
					local bridge_list = AIBridgeList_Length(AIMap.DistanceManhattan(path.GetTile(), prev) + 1);
					bridge_list.Valuate(AIBridge.GetMaxSpeed);
					bridge_list.Sort(AIAbstractList.SORT_BY_VALUE, false);
					if (!AIBridge.BuildBridge(AIVehicle.VEHICLE_RAIL, bridge_list.Begin(), prev, path.GetTile())) {
						if (AIError.GetLastError() != AIError.ERR_ALREADY_BUILT || !AICompany.IsMine(AITile.GetOwner(prev))) {
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
						local num_tries = 3;
						local ok = false;
						while (AIError.GetLastError() == AIError.ERR_VEHICLE_IN_THE_WAY && num_tries-- > 0) {
							AIController.Sleep(200);
							if (AIRail.BuildRail(prevprev, prev, path.GetTile())) { ok = true; break; }
						}
						if (!ok) {
							AILog.Error(prevprev + "   " + prev + "   " + path.GetTile());
							AILog.Error("3 " + AIError.GetLastErrorString());
							AISign.BuildSign(prevprev, "1");
							AISign.BuildSign(prev, "2");
							AISign.BuildSign(path.GetTile(),  "3");
							return false;
						}
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

function RailRouteBuilder::BuildDepot(path)
{
	local prev = null;
	local pp = null;
	local ppp = null;
	local pppp = null;
	local ppppp = null;
	while (path != null) {
		if (ppppp != null) {
			if (ppppp - pppp == pppp - ppp && pppp - ppp == ppp - pp && ppp - pp == pp - prev && pp - prev == prev - path.GetTile()) {
				local offsets = [AIMap.GetTileIndex(0, 1), AIMap.GetTileIndex(0, -1),
				                 AIMap.GetTileIndex(1, 0), AIMap.GetTileIndex(-1, 0)];
				foreach (offset in offsets) {
					if (AdmiralAI.GetRealHeight(ppp + offset) != AdmiralAI.GetRealHeight(ppp)) continue;
					if (AIRail.BuildRailDepot(ppp + offset, ppp)) {
						switch (offset) {
							case -1:
								if (!AIRail.BuildRailTrack(ppp, AIRail.RAILTRACK_NW_NE)) {
									AITile.DemolishTile(ppp + offset);
									continue;
								}
								if (!AIRail.BuildRailTrack(ppp, AIRail.RAILTRACK_NE_SE)) {
									AITile.DemolishTile(ppp + offset);
									continue;
								}
								break;
							case 1:
								if (!AIRail.BuildRailTrack(ppp, AIRail.RAILTRACK_NW_SW)) {
									AITile.DemolishTile(ppp + offset);
									continue;
								}
								if (!AIRail.BuildRailTrack(ppp, AIRail.RAILTRACK_SW_SE)) {
									AITile.DemolishTile(ppp + offset);
									continue;
								}
								break;
							case -AIMap.GetMapSizeX():
								if (!AIRail.BuildRailTrack(ppp, AIRail.RAILTRACK_NW_NE)) {
									AITile.DemolishTile(ppp + offset);
									continue;
								}
								if (!AIRail.BuildRailTrack(ppp, AIRail.RAILTRACK_NW_SW)) {
									AITile.DemolishTile(ppp + offset);
									continue;
								}
								break;
							case AIMap.GetMapSizeX():
								if (!AIRail.BuildRailTrack(ppp, AIRail.RAILTRACK_NE_SE)) {
									AITile.DemolishTile(ppp + offset);
									continue;
								}
								if (!AIRail.BuildRailTrack(ppp, AIRail.RAILTRACK_SW_SE)) {
									AITile.DemolishTile(ppp + offset);
									continue;
								}
								break;
						}
						return ppp + offset;
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
