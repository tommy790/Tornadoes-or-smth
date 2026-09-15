if GS_GStormsInit then return end
GS_GStormsInit = true

if SERVER then AddCSLuaFile() end

local filter = {"gstorms_", "gmod_wire_gstorms"}

local addCSLuaDirs = {
    {path = "autorun", match = "gstorms_api.lua"},
    {path = "gstorms_funcs"},
    {path = "autorun/client", filtered = true},
    {path = "gstorms_computer_applications"},
    {path = "entities", filtered = true},
    {path = "weapons/gmod_tool/stools", filtered = true},
}

local function GSMatchesFilter(name)
    for i = 1, #filter do
        if string.StartWith(name, filter[i]) then return true end
    end

    return false
end

local function GSAddCSLuaDir(dir, match, filtered, passedFilter)
    if match then
        local files = file.Find(dir.."/"..match, "LUA")
        for i = 1, #files do AddCSLuaFile(dir.."/"..files[i]) end
        return
    end

    local files, dirs = file.Find(dir.."/*.lua", "LUA")

    for i = 1, #files do
        if !filtered or passedFilter or GSMatchesFilter(files[i]) then AddCSLuaFile(dir.."/"..files[i]) end
    end

    for i = 1, #dirs do
        if !filtered or passedFilter or GSMatchesFilter(dirs[i]) then GSAddCSLuaDir(dir.."/"..dirs[i], nil, filtered, true) end
    end
end

if SERVER then
    for i = 1, #addCSLuaDirs do
        local data = addCSLuaDirs[i]
        GSAddCSLuaDir(data.path, data.match, data.filtered)
    end

    RunConsoleCommand("gmod_mcore_test", "1")
end

if !GS_GStormsSharedInit then GS_GStormsSharedInit = true end
if SERVER and !GS_GStormsServerInit then GS_GStormsServerInit = true end
if CLIENT and !GS_GStormsClientInit then GS_GStormsClientInit = true end