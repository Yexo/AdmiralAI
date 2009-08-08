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

 /** @file utils.nut Implementation of Utils. */

/**
 * A general class containing some utility functions.
 */
class Utils
{
/* public: */

	/**
	 * Set the company name to the first item from name_list that is possible.
	 *  If all company names in name_list are taken already, try appending them
	 *  with " #1", " #2", etc.
	 * @param name_array An array with strings that are possible names.
	 */
	static function SetCompanyName(name_array);

	/**
	 * Randomly reorder all elements in an array.
	 * @param array The array to reorder.
	 * @return An array containing all elements from the input array, but reordered.
	 * @note It returns a new array, the array give is destroyed.
	 */
	static function RandomReorder(array);

	/**
	 * Convert a squirrel table to a human-readable string.
	 * @param table The table to convert.
	 * @return A string containing all item => value pairs from the table.
	 */
	static function TableToString(table);

	/**
	 * Convert an array to a human-readable string.
	 * @param array The array to convert.
	 * @return A string containing all information from the array.
	 */
	static function ArrayToString(array);

	/**
	 * Convert an AIList to a human-readable string.
	 * @param list The AIList to convert.
	 * @return A string containing all item => value pairs from the list.
	 */
	static function AIListToString(list);

	/**
	 * Check if all settings are valid and throw an error if one or more is not valid.
	 * @param list An array of strings to check.
	 * @return No value is returned, but an exception is thrown if at least one setting is invalid.
	 */
	static function CheckSettings(list);
};

function Utils::SetCompanyName(name_array)
{
	local counter = 0;
	do {
		foreach (name in name_array) {
			if (counter > 0) {
				name = name + " #" + counter;
			}
			if (AICompany.SetName(name)) return;
		}
		counter++;
	} while(true);
}

function Utils::RandomReorder(array)
{
	local ret = [];
	while (array.len() > 0) {
		local index = AIBase.RandRange(array.len());
		ret.push(array[index]);
		array.remove(index);
	}
	return ret;
}

function Utils::TableToString(table)
{
	if (typeof(table) != "table") throw("Utils::TableToString(): argument has to be a table.");
	local ret = "[";
	foreach (a, b in table) {
		ret += a + "=>" + b + ", ";
	}
	ret += "]";
	return ret;
}

function Utils::ArrayToString(array)
{
	if (typeof(array) != "array") throw("Utils::ArrayToString(): argument has to be an array.");
	local ret = "[";
	if (array.len() > 0) {
		ret += array[0];
		for (local i = 1; i < array.len(); i++) {
			ret += ", " + array[i];
		}
	}
	ret += "]";
	return ret;
}

function Utils::AIListToString(list)
{
	local ret = "[";
	if (!list.IsEmpty()) {
		local a = list.Begin()
		ret += a + "=>" + list.GetValue(a);
		if (list.HasNext()) {
			for (local i = list.Next(); list.HasNext(); i = list.Next()) {
				ret += ", " + i + "=>" + list.GetValue(i);
			}
		}
	}
	ret += "]";
	return ret;
}

function Utils::IsNearlyFlatTile(tile)
{
	local slope = AITile.GetSlope(tile);
	return slope == AITile.SLOPE_FLAT || slope == AITile.SLOPE_NWS || slope == AITile.SLOPE_WSE ||
			slope == AITile.SLOPE_SEN || slope == AITile.SLOPE_ENW;
}

function Utils::VehicleManhattanDistanceToTile(vehicle, tile)
{
	return AIMap.DistanceManhattan(AIVehicle.GetLocation(vehicle), tile);
}

function Utils::CheckSettings(list)
{
	foreach (setting in list) {
		if (!AIGameSettings.IsValid(setting)) throw("Setting is invalid: " + setting);
	}
}
