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
 * Copyright 2008-2009 Thijs Marinussen
 */

/** @file graph.nut Implementation of functions to create a spanning tree. */

function GetDir(tile_a, tile_b)
{
	if (tile_a == tile_b) return -1;
	local tx = AIMap.GetTileX(tile_b);
	local ty = AIMap.GetTileY(tile_b);
	if (AIMap.GetTileX(tile_a) < tx) {
		if (AIMap.GetTileY(tile_a) < ty) return 0;
		return 1;
	} else {
		if (AIMap.GetTileY(tile_a) < ty) return 2;
		return 3;
	}
}

function Direction(p1, p2, p3)
{
	local x1 = AIMap.GetTileX(p3) - AIMap.GetTileX(p1);
	local x2 = AIMap.GetTileX(p2) - AIMap.GetTileX(p1);
	local y1 = AIMap.GetTileY(p3) - AIMap.GetTileY(p1);
	local y2 = AIMap.GetTileY(p2) - AIMap.GetTileY(p1);
	return x1 * y2 - x2 * y1;
}

function SegmentIntersect(p1, p2, p3, p4)
{
	local d1 = Direction(p3, p4, p1);
	local d2 = Direction(p3, p4, p2);
	local d3 = Direction(p1, p2, p3);
	local d4 = Direction(p1, p2, p4);
	if (((d1 > 0 && d2 < 0) || (d1 < 0 && d2 > 0)) && ((d3 > 0 && d4 < 0) || (d3 < 0 && d4 > 0))) {
		return true;
	}
	return false;
}

function CreateSpanningTree(points)
{
	local conn = {};
	foreach (p in points) {
		local adj_list = [];
		foreach (dir in [0, 1, 2, 3]) {
			local q = FibonacciHeap();
			foreach (p2 in points) {
				if (GetDir(p2.tile, p.tile) == dir) q.Insert(p2, AIMap.DistanceManhattan(p2.tile, p.tile));
			}
			for (local i = 0; i < 5 && q.Count() > 0; i++) adj_list.append(q.Pop());
		}
		foreach (p2 in adj_list) {
			local d1 = AIMap.DistanceManhattan(p.tile, p2.tile);
			local do_connect = true;
			foreach (p3 in points) {
				if (p == p3 || p2 == p3) continue;
				local d2 = AIMap.DistanceManhattan(p.tile, p3.tile);
				local d3 = AIMap.DistanceManhattan(p2.tile, p3.tile);
				if ((d1 * 1.4).tointeger() > (d2 + d3) && d1 > d2 && d1 > d3) {
					do_connect = false;
				}
			}
			if (do_connect) {
				local a = p, b = p2;
				if (p.tile > p2.tile) { a = p2; b = p; }
				if (!conn.rawin(a)) conn.rawset(a, {});
				if (!conn[a].rawin(b)) conn[a].rawset(b, 0);
				conn[a][b] = 1;
			}
		}
	}
	AILog.Info("Creating connections done (" + ::main_instance.GetTick() + ")");
	return conn;
}

class Line
{
	constructor(a, b, t_l, t_r) {
		this.p_a = a;
		this.p_b = b;
		this.tile_left = t_l;
		this.tile_right = t_r;
		assert(t_l < t_r);
	}
	p_a = null;
	p_b = null;
	tile_left = null;
	tile_right = null;
}

class Event
{
	constructor(t, l)
	{
		this.type = t;
		this.line = l;
	}
	type = null;
	line = null;
}

function RemoveCrossings(conn)
{
	local events = FibonacciHeap();
	foreach (a, list in conn) {
		foreach (b, val in list) {
			if (val == 1) {
				local l = null;
				if (a.tile > b.tile) {
					l = Line(a, b, b.tile, a.tile);
				} else {
					l = Line(a, b, a.tile, b.tile);
				}
				events.Insert(Event("LEFT", l), l.tile_left);
				events.Insert(Event("RIGHT", l), l.tile_right);
			}
		}
	}
	local sw = {};
	AILog.Info("Deleting crossings (" + ::main_instance.GetTick() + ")");
	while (events.Count() > 0) {
		local e = events.Pop();
		if (e.type == "LEFT") {
			foreach (line, dummy in sw) {
				if (SegmentIntersect(e.line.tile_left, e.line.tile_right, line.tile_left, line.tile_right)) {
					if (AIMap.DistanceManhattan(e.line.tile_left, e.line.tile_right) > AIMap.DistanceManhattan(line.tile_left, line.tile_right)) {
						conn[e.line.p_a][e.line.p_b] = 0;
					} else {
						conn[line.p_a][line.p_b] = 0;
					}
				}
			}
			sw.rawset(e.line, 0);
		} else {
			assert(sw.rawin(e.line));
			sw.rawdelete(e.line);
		}
	}
	AILog.Info("Deleting crossings done (" + ::main_instance.GetTick() + ")");
}
