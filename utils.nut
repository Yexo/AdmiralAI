class Utils
{
	/* Set's the company name to the first item from name_list that's possible.
	 * If all company names in name_list are taken already, try appending them
	 * with " #1", " #2", etc. */
	function SetCompanyName(name_list);

	/* Randomly reorder all elements in a list.
	 * @param list The list to reorder.
	 * @return A list containing all elements from the input list, but reordered.
	 * @note It returns the new list, the parameter is destroyed.*/
	function RandomReorder(list);

	/* Convert an array to a human-readable string. */
	function ArrayToString(list);
};

function Utils::SetCompanyName(name_list)
{
	local counter = 0;
	do {
		foreach (name in name_list) {
			if (counter > 0) {
				name = name + " #" + counter;
			}
			if (AICompany.SetCompanyName(name)) return;
		}
		counter++;
	} while(true);
};

function Utils::RandomReorder(list)
{
	local ret = [];
	while (list.len() > 0) {
		local index = AIBase.RandRange(list.len());
		ret.push(list[index]);
		list.remove(index);
	}
	return ret;
}

function Utils::TableToString(list)
{
	if (typeof(list) != "table") throw("Utils::TableToString(): argument has to be an table.");
	local ret = "[";
	foreach (a, b in list) {
		ret += a + "=>" + b + ", ";
	}
	ret += "]";
	return ret;
}

function Utils::ArrayToString(list)
{
	if (typeof(list) != "array") throw("Utils::ArrayToString(): argument has to be an array.");
	local ret = "[";
	if (list.len() > 0) {
		ret += list[0];
		for (local i = 1; i < list.len(); i++) {
			ret += ", " + list[i];
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
