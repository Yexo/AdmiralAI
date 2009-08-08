class AdmiralAI extends AIInfo {
	function GetAuthor()      { return "Thijs Marinussen"; }
	function GetName()        { return "AdmiralAI"; }
	function GetDescription() { return "Some random road-building AI"; }
	function GetVersion()     { return 6; }
	function GetDate()        { return "2008-07-17"; }
	function CreateInstance() { return "AdmiralAI"; }
};

RegisterAI(AdmiralAI());
