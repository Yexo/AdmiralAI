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

/** @file roadnetwork.nut Implements the RoadNetwork class. */

/**
 * Class that keeps track of all existing roads and possible new connections.
 * This makes it easy to compute new road routes even over long distances.
 */
class RoadNetwork
{
/* private: */
	connections = null; ///< All possible connections between cities.
};

function RoadNetwork::InitNetwork(connect_func)
{
	local town_list = AITownList();
	local points = [];
	foreach (town_id, dummy in town_list) {
		points.append(Town(town_id));
	}
	local width = max(1, AIMap.GetMapSizeX() / 256);
	local height = max(1, AIMap.GetMapSizeY() / 256);
	local areas = [];
	local areasx = [];
	local areasy = [];
	for (local i = 0; i < width * height; i++) {
		areas.append([]);
		areasx.append([]);
		areasy.append([]);
	}
	foreach (point in points) {
		local x = AIMap.GetTileX(point.tile) / 256;
		local y = AIMap.GetTileY(point.tile) / 256;
		areas[x * height + y].append(point);
		local offset_x = AIMap.GetTileX(point.tile) - x * 256;
		local offset_y = AIMap.GetTileY(point.tile) - y * 256;
		if (offset_x > 256 - 64 && x < width - 1) areasx[x * height + y].append(point);
		if (offset_x < 64 && x > 0) areasx[(x - 1) * height + y].append(point);
		if (offset_y > 256 - 64 && y < height - 1) areasy[x * height + y].append(point);
		if (offset_y < 64 && y > 0) areasy[x * height + y - 1].append(point);
	}

	local conns = [];
	foreach (area in areas) {
		conns.append(CreateSpanningTree(area));
	}
	foreach (area in areasx) {
		conns.append(CreateSpanningTree(area));
	}
	foreach (area in areasy) {
		conns.append(CreateSpanningTree(area));
	}

	this.connections = {};
	foreach (c in conns) {
		foreach (p, list in c) {
			if (!this.connections.rawin(p)) {
				this.connections.rawset(p, list);
			} else {
				foreach (p2, v in list) {
					if (v == 1 && !this.connections[p].rawin(p2)) {
						this.connections[p].rawset(p2, v);
					}
				}
			}
		}
	}
	RemoveCrossings(this.connections);

	if (connect_func != null) {
		foreach (p, list in this.connections) {
			foreach (p2, v in list) {
				if (v == 1) connect_func(p.tile, p2.tile);
			}
		}
	}
}

function RoadNetwork::ConnectWithSigns(tile_a, tile_b)
{
	local x1 = AIMap.GetTileX(tile_a);
	local y1 = AIMap.GetTileY(tile_a);
	local x2 = AIMap.GetTileX(tile_b);
	local y2 = AIMap.GetTileY(tile_b);
	local dx = x2 - x1;
	local dy = y2 - y1;
	local num = AIMap.DistanceManhattan(tile_a, tile_b) / 2;
	for (local cur = 0; cur < num; cur++) {
		AISign.BuildSign(AIMap.GetTileIndex(x1 + dx * cur / num, y1 + dy * cur / num), "!");
	}
}

function RoadNetwork::ConnectWithRoads(tile_a, tile_b)
{
	RouteBuilder.BuildRoadRoute(RPF(), [tile_a], [tile_b], 1.2, 20);
}
