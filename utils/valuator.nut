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

/** @file utils/valuator.nut Some general valuators. */

/**
 * A utility class containing some general valuators.
 */
class Utils_Valuator
{
/* public: */

	/**
	 * Call a function with the arguments given.
	 * @param func The function to call.
	 * @param args An array with all arguments for func.
	 * @pre args.len() <= 8.
	 * @return The return value from the called function.
	 */
	static function CallFunction(func, args);

	/**
	 * Apply a valuator function to every item of an AIAbstractList.
	 * @param list The AIAbstractList to apply the valuator to.
	 * @param valuator The function to apply.
	 * @param others Extra parameters for the valuator function).
	 */
	static function Valuate(list, valuator, ...);

	/**
	 * A valuator that always returns 0.
	 * @param item unused.
	 * @return 0.
	 */
	static function NulValuator(item);

	/**
	 * A valuator that areturns the item as value.
	 * @param item The value that will be returned.
	 * @return item.
	 */
	static function ItemValuator(item);

	/**
	 * A valuator that returns the distance between two tiles
	 *  and adds a bit randomness.
	 * @param item The first tile.
	 * @param tile The second tile.
	 * @param max_rand The maximum random offset.
	 * @return The distance plus some random offset.
	 */
	static function DistancePlusRandom(item, tile, max_rand);
};

function Utils_Valuator::CallFunction(func, args)
{
	switch (args.len()) {
		case 0: return func();
		case 1: return func(args[0]);
		case 2: return func(args[0], args[1]);
		case 3: return func(args[0], args[1], args[2]);
		case 4: return func(args[0], args[1], args[2], args[3]);
		case 5: return func(args[0], args[1], args[2], args[3], args[4]);
		case 6: return func(args[0], args[1], args[2], args[3], args[4], args[5]);
		case 7: return func(args[0], args[1], args[2], args[3], args[4], args[5], args[6]);
		case 8: return func(args[0], args[1], args[2], args[3], args[4], args[5], args[6], args[7]);
		default: throw "Too many arguments to CallFunction";
	}
}

function Utils_Valuator::Valuate(list, valuator, ...)
{
	assert(typeof(list) == "instance");
	assert(typeof(valuator) == "function");

	local args = [null];

	for(local c = 0; c < vargc; c++) {
		args.append(vargv[c]);
	}

	foreach(item, _ in list) {
		args[0] = item;
		local value = Utils_Valuator.CallFunction(valuator, args);
		if (typeof(value) == "bool") {
			value = value ? 1 : 0;
		} else if (typeof(value) != "integer") {
			throw("Invalid return type from valuator");
		}
		list.SetValue(item, value);
	}
}

function Utils_Valuator::NulValuator(item)
{
	return 0;
}

function Utils_Valuator::ItemValuator(item)
{
	return item;
}

function Utils_Valuator::DistancePlusRandom(item, tile, max_rand)
{
	return AIMap.DistanceManhattan(item, tile) + AIBase.RandRange(max_rand);
}
