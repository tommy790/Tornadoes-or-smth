include("gstorms_funcs/gstorms_shared.lua")
include("autorun/gstorms_spawnmenu.lua")

local function AddParticles(lst)
    local addedParticles = {}
    for k, v in ipairs(lst) do
        if !table.HasValue(addedParticles, v) then
            game.AddParticles(v)
            table.insert(addedParticles, v)
        end
    end
end

local function SetupKillicons()
	if SERVER then return end

	local white = Color(255,255,255,255)

	for _, lst in pairs(GSGetCategoriesSpawnmenu()) do
		for _, e in ipairs(lst) do
			if e.killIcon then 
                killicon.Add(e.Class, e.killIcon, white)
            else
				language.Add(e.Class, e.Name)
            end
            language.Add("gstorms_weather_efu_custom", "Tornado") -- Edge case since custom tornado isn't spawnable from the spawnmenu
            killicon.Add("gstorms_weather_efu_custom", "other/killicons/gstorms_killicon_tornado.png", white)
		end
	end
end

AddParticles(
    {
        "particles/GStorms_Weather.pcf", 
        "particles/GStorms_Weather_2.pcf", 
        "particles/GStorms_Effects.pcf"
    }
)

SetupKillicons()