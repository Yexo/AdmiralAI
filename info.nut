class AdmiralAI extends AIInfo {
	function GetAuthor()      { return "Thijs Marinussen"; }
	function GetName()        { return "AdmiralAI"; }
	function GetDescription() { return "Some random road-building ai"; }
	function GetVersion()     { return 2; }
	function GetDate()        { return "2008-06-12"; }
	function CreateInstance() { return "AdmiralAI"; }
}

RegisterAI(AdmiralAI());
