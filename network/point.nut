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

/** @file point.nut Some basic classes. */

/**
 * A point is a tile->value pair. Hihger values mean the tile is
 * more important.
 */
class Point
{
	tile = null;
	value = null;
	constructor(tile, value)
	{
		this.tile = tile;
		this.value = value;
	}
}

/**
 * Extension of the tile class, this stores the town_id as well. The
 * default value is the town population.
 */
class Town extends Point
{
	town_id = null;
	constructor(town)
	{
		::Point.constructor(AITown.GetLocation(town), AITown.GetPopulation(town));
		this.town_id = town;
	}
}
