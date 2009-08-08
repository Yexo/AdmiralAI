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

class AdmiralAI extends AIInfo {
	function GetAuthor()      { return "Thijs Marinussen"; }
	function GetName()        { return "AdmiralAI"; }
	function GetDescription() { return "An AI that uses several types of transport"; }
	function GetVersion()     { return 15; }
	function GetDate()        { return "2008-12-18"; }
	function CreateInstance() { return "AdmiralAI"; }
	function GetSettings() {
		SetSetting({name = "use_busses", description = "Set to 1 to enable busses", min_value = 0, max_value = 1, easy_value = 1, medium_value = 1, hard_value = 1, custom_value = 1, flags = 0});
		SetSetting({name = "use_trucks", description = "Set to 1 to enable trucks", min_value = 0, max_value = 1, easy_value = 1, medium_value = 1, hard_value = 1, custom_value = 1, flags = 0});
		SetSetting({name = "use_planes", description = "Set to 1 to enable aircraft", min_value = 0, max_value = 1, easy_value = 1, medium_value = 1, hard_value = 1, custom_value = 1, flags = 0});
		SetSetting({name = "use_trains", description = "Set to 1 to enable trains", min_value = 0, max_value = 1, easy_value = 1, medium_value = 1, hard_value = 1, custom_value = 1, flags = 0});
		SetSetting({name = "build_statues", description = "If set to 1, AdmiralAI will try to build statues as soon as is has enough money", min_value = 0, max_value = 1, easy_value = 0, medium_value = 1, hard_value = 1, custom_value = 1, flags = 0});
		SetSetting({name = "always_autorenew", description = "If set to 1, always use autoreplace regardless of the breakdown setting", min_value = 0, max_value = 1, easy_value = 0, medium_value = 0, hard_value = 0, custom_value = 0, flags = 0});
		SetSetting({name = "depot_near_station", description = "Set to 1 to build the depot near the loading station instead of near the dropoff station.", min_value = 0, max_value = 1, easy_value = 1, medium_value = 1, hard_value = 1, custom_value = 1, flags = 0});
		SetSetting({name = "debug_signs", description = "Set to 1 to enable building debug signs", min_value = 0, max_value = 1, easy_value = 0, medium_value = 0, hard_value = 0, custom_value = 0, flags = 0});
	}
};

RegisterAI(AdmiralAI());
