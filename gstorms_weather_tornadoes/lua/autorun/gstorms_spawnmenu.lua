if SERVER then return end

local function GStormsListSet(entry, class)
    list.Set("GStormsMenu", class, entry)
end

local categories = {

    Vortices = {
		{ Name = "EF-0 Tornado", Class = "gstorms_weather_ef0", killIcon = "other/killicons/gstorms_killicon_tornado.png"},
		{ Name = "EF-1 Tornado", Class = "gstorms_weather_ef1", killIcon = "other/killicons/gstorms_killicon_tornado.png"},
		{ Name = "EF-2 Tornado", Class = "gstorms_weather_ef2", killIcon = "other/killicons/gstorms_killicon_tornado.png"},
		{ Name = "EF-3 Tornado", Class = "gstorms_weather_ef3", killIcon = "other/killicons/gstorms_killicon_tornado.png"},
		{ Name = "EF-4 Tornado", Class = "gstorms_weather_ef4", killIcon = "other/killicons/gstorms_killicon_tornado.png"},
		{ Name = "EF-5 Tornado", Class = "gstorms_weather_ef5", killIcon = "other/killicons/gstorms_killicon_tornado.png"},
		{ Name = "Spout Tornado", Class = "gstorms_weather_spout", killIcon = "other/killicons/gstorms_killicon_tornado.png", Icon = "entities/spout_generic.png"},
		{ Name = "Dust Devil", Class = "gstorms_weather_dust_devil", Icon = "entities/dustdevil_generic.png"},
    },

    Weather = {
		{ Name = "Sandstorm", Class = "gstorms_weather_sandstorm"},
		{ Name = "Lightning Bolt", Class = "gstorms_lightning_entity", killIcon = "other/killicons/gstorms_killicon_lightning.png"},
		{ Name = "Rainstorm", Class = "gstorms_weather_rainstorm", Icon = "entities/rainstorm_generic.png"},
		{ Name = "Thunderstorm", Class = "gstorms_weather_thunderstorm", Icon = "entities/thunderstorm_generic.png"},
		{ Name = "Derecho", Class = "gstorms_weather_derecho", Icon = "entities/derecho_generic.png"},
		{ Name = "Tropical Depression", Class = "gstorms_weather_tropical_depression", Icon = "entities/hurricane_generic.png"},
		{ Name = "Tropical Storm", Class = "gstorms_weather_tropical_storm", Icon = "entities/hurricane_generic.png"},
		{ Name = "C-1 Hurricane", Class = "gstorms_weather_c1", Icon = "entities/hurricane_generic.png"},
		{ Name = "C-2 Hurricane", Class = "gstorms_weather_c2", Icon = "entities/hurricane_generic.png"},
		{ Name = "C-3 Hurricane", Class = "gstorms_weather_c3", Icon = "entities/hurricane_generic.png"},
		{ Name = "C-4 Hurricane", Class = "gstorms_weather_c4", Icon = "entities/hurricane_generic.png"},
		{ Name = "C-5 Hurricane", Class = "gstorms_weather_c5", Icon = "entities/hurricane_generic.png"},
    },

	Disasters = {
		{ Name = "Volcano", Class = "gstorms_volcano"},
		{ Name = "Pyroclastic Flow", Class = "gstorms_weather_pyroclastic_flow"},
		{ Name = "M-1 Earthquake", Class = "gstorms_earthquake_m1", Icon = "entities/earthquake_generic.png"},
		{ Name = "M-2 Earthquake", Class = "gstorms_earthquake_m2", Icon = "entities/earthquake_generic.png"},
		{ Name = "M-3 Earthquake", Class = "gstorms_earthquake_m3", Icon = "entities/earthquake_generic.png"},
		{ Name = "M-4 Earthquake", Class = "gstorms_earthquake_m4", Icon = "entities/earthquake_generic.png"},
		{ Name = "M-5 Earthquake", Class = "gstorms_earthquake_m5", Icon = "entities/earthquake_generic.png"},
		{ Name = "M-6 Earthquake", Class = "gstorms_earthquake_m6", Icon = "entities/earthquake_generic.png"},
		{ Name = "M-7 Earthquake", Class = "gstorms_earthquake_m7", Icon = "entities/earthquake_generic.png"},
		{ Name = "M-8 Earthquake", Class = "gstorms_earthquake_m8", Icon = "entities/earthquake_generic.png"},
		{ Name = "M-9 Earthquake", Class = "gstorms_earthquake_m9", Icon = "entities/earthquake_generic.png"},
	},

    Dynamic = {
		{ Name = "[D] Rainstorm", Class = "gstorms_weather_rainstorm_dynamic", Icon = "entities/rainstorm_generic.png"},
		{ Name = "[D] Thunderstorm", Class = "gstorms_weather_thunderstorm_dynamic", Icon = "entities/thunderstorm_generic.png"},
		{ Name = "[D] Tornado", Class = "gstorms_weather_efu_dynamic", killIcon = "other/killicons/gstorms_killicon_tornado.png"},
		{ Name = "[D] Spout", Class = "gstorms_weather_spout_dynamic", killIcon = "other/killicons/gstorms_killicon_tornado.png", Icon = "entities/spout_generic.png"},
		{ Name = "[D] Dust Devil", Class = "gstorms_weather_dust_devil_dynamic", Icon = "entities/dustdevil_generic.png"},
		{ Name = "[D] Derecho", Class = "gstorms_weather_derecho_dynamic", Icon = "entities/derecho_generic.png"},
		{ Name = "[D] Hurricane", Class = "gstorms_weather_hurricane_dynamic", Icon = "entities/hurricane_generic.png"},
		{ Name = "[D] Tropical System", Class = "gstorms_weather_tropical_system_dynamic", Icon = "entities/hurricane_generic.png"}
    },

    Equipment = {
		{ Name = "WSR-88D Radar", Class = "gstorms_radar_wsr88d"},
		{ Name = "TDWR Radar", Class = "gstorms_radar_tdwr"},
		{ Name = "Mobile Radar", Class = "gstorms_radar_mobileradar"},
		{ Name = "Computer", Class = "gstorms_computer"},
		{ Name = "Tornado Siren", Class = "gstorms_tornado_siren"},
		{ Name = "Radio (EAS)", Class = "gstorms_radio"},
		{ Name = "Probe", Class = "gstorms_probe"},
		{ Name = "Thermometer", Class = "gstorms_thermometer"},
		{ Name = "Seismograph", Class = "gstorms_seismograph"},
    },

}

function GSGetCategoriesSpawnmenu() return categories end

local categoryMap = {
    Vortices = {
        name = "GStorms: Vortices",
        icon = "materials/entities/GS_Icon_Vortices.png",
    },

    Weather = {
        name = "GStorms: Weather",
        icon = "materials/entities/GS_Icon-07-18-Small.png",
    },

	Disasters = {
        name = "GStorms: Disasters",
        icon = "materials/entities/GS_Icon_Disasters.png",
    },

	Dynamic = {
        name = "GStorms: Dynamic",
        icon = "materials/entities/GS_Icon_Dynamic.png",
    },

    Equipment = {
        name = "GStorms: Equipment",
        icon = "materials/entities/GS_Icon_Equipment.png",
    },
}

local categoryOrder = {
    "Vortices",
    "Weather",
	"Disasters",
    "Dynamic",
    "Equipment",
}

for order, category in ipairs(categoryOrder) do

    local items = categories[category]
    local categoryData = categoryMap[category]
    local categoryName = categoryData.name
    local categoryIcon = categoryData.icon

    for i, item in ipairs(items) do
        GStormsListSet({ Name = item.Name, Class = item.Class, Icon = item.Icon, Category = categoryName, CategoryIcon = categoryIcon, CategoryOrder = order, Order = i }, item.Class)
    end
	
end

hook.Add("PopMenuGStorms", "AddToMenuGStorms", function(pnlContent, tree, node)

	local GStormsMenuList = list.Get("GStormsMenu")
	local Categories = {}

	for k, entity in pairs(GStormsMenuList) do

		local Category = entity.Category or "Other"
		local Tab = Categories[Category] or { Items = {}, Icon = entity.CategoryIcon or "materials/entities/GS_Icon-07-18-Small.png", Order = entity.CategoryOrder}
	
		Tab.Items[k] = entity
		Categories[Category] = Tab
	
	end

	for CategoryName, v in SortedPairsByMemberValue(Categories, "Order") do

		local node = tree:AddNode(CategoryName, v.Icon)
	
		node.DoPopulate = function(self)
	
			if self.PropPanel then return end
	
			self.PropPanel = vgui.Create("ContentContainer", pnlContent)
			self.PropPanel:SetVisible(true)
			self.PropPanel:SetTriggerSpawnlistChange(false)
	
			for name, ent in SortedPairsByMemberValue(v.Items, "Order") do
				local className = name
				local icon = spawnmenu.CreateContentIcon(ent.ScriptedEntityType or "entity", self.PropPanel, {nicename = ent.Name or className, spawnname = className, material = ent.Icon or "entities/" .. className .. ".png", weapon = ent.Weapons})
			
				icon.DoClick = function(self)
					net.Start("gs_spawn_entity")
					net.WriteString(className)
					net.SendToServer()
				end
			end
	
		end

		node.DoClick = function(self)

			self:DoPopulate()

			pnlContent:SwitchPanel(self.PropPanel)

		end

	end

	local FirstNode = tree:Root():GetChildNode(0)

	if FirstNode:IsValid() then
		FirstNode:InternalDoClick()
	end

end)

spawnmenu.AddCreationTab("GStorms", function()

	local ctrl = vgui.Create("SpawnmenuContentPanel")

	ctrl:EnableSearch("entity", "PopMenuGStorms")
	ctrl:CallPopulateHook("PopMenuGStorms")
	
	return ctrl

end, "materials/entities/GS_Icon-07-18-Small.png", 50)
