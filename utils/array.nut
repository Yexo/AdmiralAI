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

 /** @file utils/array.nut Array utility functions. */

/**
 * A general class containing some utility functions for arrays, lists and tables.
 */
class Utils_Array
{
/* public: */

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
};

function Utils_Array::RandomReorder(array)
{
	local ret = [];
	while (array.len() > 0) {
		local index = AIBase.RandRange(array.len());
		ret.push(array[index]);
		array.remove(index);
	}
	return ret;
}

function Utils_Array::TableToString(table)
{
	if (typeof(table) != "table") throw("Utils::TableToString(): argument has to be a table.");
	local ret = "[";
	foreach (a, b in table) {
		ret += a + "=>" + b + ", ";
	}
	ret += "]";
	return ret;
}

function Utils_Array::ArrayToString(array)
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

function Utils_Array::AIListToString(list)
{
	if (typeof(list) != "instance") throw("Utils::AIListToString(): argument has to be an instance of AIAbstractList.");
	local ret = "[";
	if (!list.IsEmpty()) {
		local a = list.Begin();
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
