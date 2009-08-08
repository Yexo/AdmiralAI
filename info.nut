class AdmiralAI extends AIInfo {
	function GetAuthor()      { return "Thijs Marinussen"; }
	function GetName()        { return "AdmiralAI"; }
	function GetDescription() { return "Some random road-building AI"; }
	function GetVersion()     { return 5; }
	function GetDate()        { return "2008-07-15"; }
	function CreateInstance() { return "AdmiralAI"; }
};

RegisterAI(AdmiralAI());
