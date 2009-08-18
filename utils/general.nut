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

 /** @file utils/general.nut General utility functions. */

/**
 * A utility class containing some general functions.
 */
class Utils_General
{
/* public: */

	/**
	 * Set the company name to the first item from name_list that is possible.
	 *  If all company names in name_list are taken already, try appending them
	 *  with " #1", " #2", etc.
	 * @param name_prefix The prefix for the company name.
	 * @param name_suffixes An array with strings that can be appended to the prefix.
	 */
	static function SetCompanyName(name_prefix, name_suffixes);

	/**
	 * Try to get a specified amount of money.
	 * @param amount The amount of money we want.
	 * @note This function doesn't return anything. You'll have to check yourself if you have got enough.
	 */
	static function GetMoney(amount);

	 /**
	  * Check if all game settings are valid in the current openttd version.
	  * @param array An array with the settings to check.
	  * @return True if all settings are valid.
	  * @exception If one of the settings is not valid.
	  */
	static function CheckSettings(array);

	/**
	 * Get the CargoID of passengers.
	 * @return The CargoID of passengers.
	 */
	static function GetPassengerCargoID();
};

function Utils_General::SetCompanyName(name_prefix, name_suffixes)
{
	local counter = 0;
	// We need a cutoff in case all names fail because they're too long
	while (counter < 16) {
		foreach (name_suffix in name_array) {
			local name = name_prefix + name_suffix;
			if (counter > 0) {
				name = name + " #" + counter;
			}
			if (AICompany.SetName(name)) return;
		}
		counter++;
	}
}

function Utils_General::GetMoney(amount)
{
	local bank = AICompany.GetBankBalance(AICompany.COMPANY_SELF);
	local loan = AICompany.GetLoanAmount();
	local maxloan = AICompany.GetMaxLoanAmount();
	if (bank > amount) {
		if (loan > 0) AICompany.SetMinimumLoanAmount(max(loan - (bank - amount) + 10000, 0));
	} else {
		AICompany.SetMinimumLoanAmount(min(maxloan, loan + amount - bank + 10000));
	}
}

function Utils_General::CheckSettings(array)
{
	foreach (setting in array) {
		if (!AIGameSettings.IsValid(setting)) throw("Setting is invalid: " + setting);
	}
}

function Utils_General::GetPassengerCargoID()
{
	local cargo_list = AICargoList();
	cargo_list.Valuate(AICargo.HasCargoClass, AICargo.CC_PASSENGERS);
	if (cargo_list.Count() == 0) {
		throw("No passenger cargo found.");
	}
	if (cargo_list.Count() == 1) return cargo_list.Begin();

	/* There is more then one CargoID that represents passengers,
	 * we pick the one with the highest acceptence in the center
	 * of the largest town. */
	local town_list = AITownList();
	town_list.Valuate(AITown.GetPopulation);
	town_list.Sort(AIAbstractList.SORT_BY_VALUE, false);
	local best_cargo = null;
	local best_cargo_acceptance = 0;
	foreach (cargo, dummy in cargo_list) {
		local acceptance = AITile.GetCargoAcceptance(AITown.GetLocation(town_list.Begin()), cargo, 1, 1, 5);
		if (acceptance > best_cargo_acceptance) {
			best_cargo_acceptance = acceptance;
			best_cargo = cargo;
		}
	}
	return best_cargo;
}
