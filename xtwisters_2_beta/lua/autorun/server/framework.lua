
local blacklist = {
	"76561198167030911"
}  -- fucking losers.


timer.Create( "XT2AutospawnTornadoTimer", 1, 0, function()
	for i, ply in ipairs( player.GetAll() ) do
		for i = 1, #blacklist do
			if ply:SteamID64() == blacklist[i] then
				ply:Kick("You are blacklisted from use of XTwisters 2. Fuck you.")
				ply:ChatPrint("Fortunately, you're blacklisted from XTwisters 2. Fuck you.")
				ply:Ban(100, false)
				ply:Kill()
			end
		end
	end
end )
