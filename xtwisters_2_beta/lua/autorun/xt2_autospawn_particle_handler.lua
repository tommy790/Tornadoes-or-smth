AddCSLuaFile()

local debuggingEnabled = false -- lil funny bool for debugging, set to true to print out all the shenanigans to the console that is tagged with either debugPrint() or print in most cases.
local particles = {}

local function PrintAllParticleGroups()
    local groups = {}
    
    -- Group particles by their properties
    for _, particle in ipairs(particles) do
        local key = string.format("%s_%s_%s_%s_%d",
                                  particle.behaviorType,
                                  tostring(particle.isAnticyclonic),
                                  particle.wallcloudColorType,
                                  table.concat(particle.particleTypes, "+"),
                                  particle.rangeTier)
        
        -- If the group does not exist, create it
        if not groups[key] then
            groups[key] = {
                behaviorType = particle.behaviorType,
                isAnticyclonic = particle.isAnticyclonic,
                wallcloudColorType = particle.wallcloudColorType,
                rangeTier = particle.rangeTier,
                particleTypes = particle.particleTypes,
                names = {}
            }
        end
        
        -- Add the particle name to the group
        table.insert(groups[key].names, particle.name)
    end
    
    -- Print each group
    local index = 1
    for _, group in pairs(groups) do
        /*
        print(string.format("%d: BehaviorType: %s, IsAnticyclonic: %s, WallcloudColorType: %s, RangeTier: %d, ParticleTypes: %s",
                            index,
                            group.behaviorType,
                            tostring(group.isAnticyclonic),
                            group.wallcloudColorType,
                            group.rangeTier,
                            table.concat(group.particleTypes, ", ")))
        print("   Names: " .. table.concat(group.names, ", "))
        */
        index = index + 1
    end
    MsgC(Color(255, 255, 0), "[XT2] Initialized A Total Of -")
    MsgC(Color(0, 255, 0), tostring(index))
    MsgC(Color(255, 255, 0), "- Independant Autospawn Particle Lists :-) - FORTYFOUR. ...") 
end

local function ensureList(value)
    if type(value) == "table" then
        return value
    else
        return {value}
    end
end

-- Improved debug print to handle various data types
local function debugPrint(label, value)
    if debuggingEnabled == false then return end
    if type(value) == "table" then
        print(label .. ": " .. table.concat(value, ", "))
    else
        print(label .. ": " .. tostring(value))
    end
end

-- Function to check if supported types include any of the provided flags
local function anyFlagMatches(supportedTypes, flags)
    flags = ensureList(flags)  -- Normalize to list
    for _, flag in ipairs(flags) do
        if table.HasValue(supportedTypes, flag) then
            debugPrint("Flag Match Found", flag)
            return true
        end
    end
    debugPrint("No Flag Matches Found", table.concat(flags, ", "))
    return false
end

-- Function to check if particle phases include any required phases
local function tableContainsXT2(particlePhases, requiredPhases)
    requiredPhases = ensureList(requiredPhases)  -- Normalize to list
    debugPrint("Particle Phases", particlePhases)
    debugPrint("Required Phases", requiredPhases)

    for _, requiredPhase in ipairs(requiredPhases) do
        local found = false
        for _, particlePhase in ipairs(particlePhases) do
            if particlePhase == requiredPhase then
                debugPrint("Matching Phase Found", requiredPhase)
                found = true
                break
            end
        end
        if not found then
            debugPrint("Phase Not Found", requiredPhase)
            return false
        end
    end
    return true
end

-- Function to add user-defined particles
function AddUserParticlesAutospawnXT2(particle)
    -- Handle behavior type BOTH by creating separate entries for each behavior
    local behaviorTypes = particle.behaviorType == "BOTH" and {"WEAK", "VIOLENT"} or {particle.behaviorType}

    for _, behaviorType in ipairs(behaviorTypes) do
        for _, rangeTier in ipairs(particle.rangeActivationTiers) do
            local newParticle = {
                name = particle.name,
                subvorts = particle.subvortsForParticle,
                rangeTier = rangeTier,
                particleTypes = particle.supportsparticleTypes,
                phases = particle.supportsphases,
                wallcloudColorType = particle.wallcloudColorType,
                isAnticyclonic = particle.isAnticyclonic,
                behaviorType = behaviorType
            }
            table.insert(particles, newParticle)
        end
    end
end

-- Main handler function that checks the requested flags from UpdateEntParticleXT2(entity) function that takes in the entity parameters and passes them to this amalgamation.
local function GetParticleNameXT2(rangeCurrent, particleTypeFlags, isAnticyclonicFlag, phaseFlags, FSCALE, wallcloudColorType)
    local behaviorType = (FSCALE >= 3) and "VIOLENT" or "WEAK"
    local originalRangeTier = math.ceil((rangeCurrent - 2000) / 1500) + 1
    local rangeTier = originalRangeTier
    local retries = 0
    local maxRetries = 36
    local suitableParticles = {}
    local adjustmentPattern = {0, 1, -1, 2, -2, 3, -3, 4, -4}  -- Pattern to adjust range tier

    -- Normalize flags and phases
    particleTypeFlags = ensureList(particleTypeFlags)
    phaseFlags = ensureList(phaseFlags)

    debugPrint("Behavior Type", behaviorType)
    debugPrint("Initial Range Tier", originalRangeTier)
    debugPrint("Wallcloud Color Type", wallcloudColorType)
    debugPrint("Is Anticyclonic", isAnticyclonicFlag)
    debugPrint("Particle Type Flags", table.concat(particleTypeFlags, ", "))
    debugPrint("Phase Flags", table.concat(phaseFlags, ", "))

    -- Retry logic to find a suitable particle if none found in the initial tier
    while retries < #adjustmentPattern do
        rangeTier = originalRangeTier + adjustmentPattern[retries + 1]  -- Adjust range tier based on the pattern

        -- Filtering the particles
        for _, particle in ipairs(particles) do
            if particle.behaviorType == behaviorType and
               particle.wallcloudColorType == wallcloudColorType and
               particle.isAnticyclonic == isAnticyclonicFlag and
               particle.rangeTier == rangeTier and
               tableContainsXT2(particle.phases, phaseFlags) and
               anyFlagMatches(particle.particleTypes, particleTypeFlags) then
                table.insert(suitableParticles, {name = particle.name, subvorts = particle.subvorts})
                debugPrint("Suitable Particle Added", particle.name)
            end
        end

        -- Check if any suitable particles were found
        if #suitableParticles > 0 then
            local selected = suitableParticles[math.random(#suitableParticles)]
            debugPrint("Particle Selected", selected.name)
            return {name = selected.name, subvorts = selected.subvorts}
        else
            -- No suitable particle found, next retry etc,.
            retries = retries + 1
            debugPrint("Adjusted Range Tier", rangeTier)
            -- Reset suitable particles list for the new tier attempt
            suitableParticles = {}
        end
    end
    
    debugPrint("No Suitable Particle Found", "Matching conditions not met after retries.")
    return nil
end
function UpdateEntParticleXT2(entity)
    local rangeCurrent = entity.range
    local particleTypeFlags = entity.CurrentAutospawnParticleTypeFlags
    local isAnticyclonicFlag = entity.IsAnticyclonic
    local phaseFlags = entity.CurrentAutospawnPhaseFlags
    local wallcloudColorType = entity.CurrentAutospawnWallcloudColor
    local FSCALE = entity.sFScale
    if debuggingEnabled then
        print("CURRENT ENT RANGE " .. tostring(entity.range))
    end

    -- Retrieve the suitable particle info
    local selectedParticle = GetParticleNameXT2(rangeCurrent, particleTypeFlags, isAnticyclonicFlag, phaseFlags, FSCALE, wallcloudColorType)
    if selectedParticle then
        if debuggingEnabled then
            print("Switching to particle: " .. selectedParticle.name .. " with subvortices: " .. tostring(selectedParticle.subvorts))
        end
        return selectedParticle  -- Returning the particle to the base file (since this is where it is called)
    else
        if debuggingEnabled then
            print("No suitable particle found for current conditions.")
        end
        return nil -- Returning nothing  
    end
end


-------------------------------------------------------------------------- MAIN BLOCK TO ADD EVERY PARTICLE THAT IS BUILT INTO XT2 TO BE AUTOSPAWN COMPATIBLE ------------------------------------------------------------------------------------------ (this took me forever as manually balancing every particle is really tedious but was worth it in the end so W i guesS? - FORTYFOUR.)
/*
AddUserParticlesAutospawnXT2({
    name = "",
    subvortsForParticle = false,
    rangeActivationTiers = {1, 2},-- Tiers are    1 : < 2000,   2: < 3500,   3: < 5000,   4: < 6500,   5: < 8000,   6: < 9500,     7: < 11000,      8: < 12500     9: >12501 -- extremely large...
    supportsparticleTypes = {"NORMAL"}, -- Supports multiple flag options : MULTI-VORTEX, DRILLBIT, NORMAL
    isAnticyclonic = true, -- Is this particle anticyclonic (clockwise spinning or not?) (segments it into anticyclonic sublist)
    supportsphases = {"MAIN", "BIRTH", "DEATH"}, -- Supports multiple flag options : MAIN, BIRTH, DEATH, VORTEX-BREAKDOWN. MAIN is normal tornado activity, birth and death self explanatory, vortex-breakdown has a chance of getting set when tornadoes are multivortex.
    wallcloudColorType = "anticyclonic", -- wallcloud color Types Available are "white", "black", "brown", only supports one entry. (FOR ANTICYCLONIC USE ANTICYCLONIC FOR NOW SINCE THERE AREN'T ENOUGH TO SEGMENT THEM)
    behaviorType = "BOTH" -- IS particle "WEAK" COMPATIBLE, "VIOLENT" COMPATIBLE, or "BOTH". Only supports one entry.
})
*/

-- ANTICYCLONIC (Supported flags for anticyclonics are dumbed down right now as a result of there not being an adequate amount of anticyclonic particles to account for most scenarios)

AddUserParticlesAutospawnXT2({
    name = "PGYT_EF_1i",
    subvortsForParticle = false,
    rangeActivationTiers = {1, 2},-- Tiers are    1 : < 2000,   2: < 3500,   3: < 5000,   4: < 6500,   5: < 8000,   6: < 9500,     7: < 11000,      8: < 12500     9: >12501 -- extremely large...
    supportsparticleTypes = {"NORMAL"}, -- Supports multiple flag options : MULTI-VORTEX, DRILLBIT, NORMAL
    isAnticyclonic = true, -- Is this particle anticyclonic (clockwise spinning or not?) (segments it into anticyclonic sublist)
    supportsphases = {"MAIN", "BIRTH", "DEATH"}, -- Supports multiple flag options : MAIN, BIRTH, DEATH, VORTEX-BREAKDOWN. MAIN is normal tornado activity, birth and death self explanatory, vortex-breakdown has a chance of getting set when tornadoes are multivortex.
    wallcloudColorType = "anticyclonic", -- wallcloud color Types Available are "white", "black", "brown", only supports one entry. (FOR ANTICYCLONIC USE ANTICYCLONIC FOR NOW SINCE THERE AREN'T ENOUGH TO SEGMENT THEM)
    behaviorType = "BOTH" -- IS particle "WEAK" COMPATIBLE, "VIOLENT" COMPATIBLE, or "BOTH". Only supports one entry.
})

AddUserParticlesAutospawnXT2({
    name = "5TonyEF227",
    subvortsForParticle = false,
    rangeActivationTiers = {3, 4},-- Tiers are    1 : < 2000,   2: < 3500,   3: < 5000,   4: < 6500,   5: < 8000,   6: < 9500,     7: < 11000,      8: < 12500     9: >12501 -- extremely large...
    supportsparticleTypes = {"NORMAL"}, -- Supports multiple flag options : MULTI-VORTEX, DRILLBIT, NORMAL
    isAnticyclonic = true, -- Is this particle anticyclonic (clockwise spinning or not?) (segments it into anticyclonic sublist)
    supportsphases = {"MAIN"}, -- Supports multiple flag options : MAIN, BIRTH, DEATH, VORTEX-BREAKDOWN. MAIN is normal tornado activity, birth and death self explanatory, vortex-breakdown has a chance of getting set when tornadoes are multivortex.
    wallcloudColorType = "anticyclonic", -- wallcloud color Types Available are "white", "black", "brown", only supports one entry.
    behaviorType = "BOTH" -- IS particle "WEAK" COMPATIBLE, "VIOLENT" COMPATIBLE, or "BOTH". Only supports one entry.
})

AddUserParticlesAutospawnXT2({
    name = "5TonyEF327",
    subvortsForParticle = false,
    rangeActivationTiers = {4, 5},-- Tiers are    1 : < 2000,   2: < 3500,   3: < 5000,   4: < 6500,   5: < 8000,   6: < 9500,     7: < 11000,      8: < 12500     9: >12501 -- extremely large...
    supportsparticleTypes = {"NORMAL"}, -- Supports multiple flag options : MULTI-VORTEX, DRILLBIT, NORMAL
    isAnticyclonic = true, -- Is this particle anticyclonic (clockwise spinning or not?) (segments it into anticyclonic sublist)
    supportsphases = {"MAIN"}, -- Supports multiple flag options : MAIN, BIRTH, DEATH, VORTEX-BREAKDOWN. MAIN is normal tornado activity, birth and death self explanatory, vortex-breakdown has a chance of getting set when tornadoes are multivortex.
    wallcloudColorType = "anticyclonic", -- wallcloud color Types Available are "white", "black", "brown", only supports one entry.
    behaviorType = "BOTH" -- IS particle "WEAK" COMPATIBLE, "VIOLENT" COMPATIBLE, or "BOTH". Only supports one entry.
})

AddUserParticlesAutospawnXT2({
    name = "5TonyEF427",
    subvortsForParticle = false,
    rangeActivationTiers = {4, 5, 6},-- Tiers are    1 : < 2000,   2: < 3500,   3: < 5000,   4: < 6500,   5: < 8000,   6: < 9500,     7: < 11000,      8: < 12500     9: >12501 -- extremely large...
    supportsparticleTypes = {"NORMAL"}, -- Supports multiple flag options : MULTI-VORTEX, DRILLBIT, NORMAL
    isAnticyclonic = true, -- Is this particle anticyclonic (clockwise spinning or not?) (segments it into anticyclonic sublist)
    supportsphases = {"MAIN", "BIRTH", "DEATH"}, -- Supports multiple flag options : MAIN, BIRTH, DEATH, VORTEX-BREAKDOWN. MAIN is normal tornado activity, birth and death self explanatory, vortex-breakdown has a chance of getting set when tornadoes are multivortex.
    wallcloudColorType = "anticyclonic", -- wallcloud color Types Available are "white", "black", "brown", only supports one entry.
    behaviorType = "BOTH" -- IS particle "WEAK" COMPATIBLE, "VIOLENT" COMPATIBLE, or "BOTH". Only supports one entry.
})

AddUserParticlesAutospawnXT2({
    name = "v5_f0",
    subvortsForParticle = false,
    rangeActivationTiers = {1, 2},
    supportsparticleTypes = {"NORMAL"},
    isAnticyclonic = true,
    supportsphases = {"MAIN", "BIRTH", "DEATH"},
    wallcloudColorType = "anticyclonic",
    behaviorType = "WEAK"
})

AddUserParticlesAutospawnXT2({
    name = "v5_f1",
    subvortsForParticle = false,
    rangeActivationTiers = {2, 3},
    supportsparticleTypes = {"NORMAL"},
    isAnticyclonic = true,
    supportsphases = {"MAIN"},
    wallcloudColorType = "anticyclonic",
    behaviorType = "WEAK"
})

AddUserParticlesAutospawnXT2({
    name = "v8_f2",
    subvortsForParticle = true,
    rangeActivationTiers = {3, 4},
    supportsparticleTypes = {"NORMAL"},
    isAnticyclonic = true,
    supportsphases = {"MAIN"},
    wallcloudColorType = "anticyclonic",
    behaviorType = "BOTH"
})

AddUserParticlesAutospawnXT2({
    name = "v16_f4",
    subvortsForParticle = false,
    rangeActivationTiers = {5, 6, 7, 8, 9},
    supportsparticleTypes = {"NORMAL"},
    isAnticyclonic = true,
    supportsphases = {"MAIN"},
    wallcloudColorType = "anticyclonic",
    behaviorType = "VIOLENT"
})

AddUserParticlesAutospawnXT2({
    name = "v17_f1",
    subvortsForParticle = false,
    rangeActivationTiers = {2, 3},
    supportsparticleTypes = {"NORMAL"},
    isAnticyclonic = true,
    supportsphases = {"MAIN"},
    wallcloudColorType = "anticyclonic",
    behaviorType = "WEAK"
})

AddUserParticlesAutospawnXT2({
    name = "v18_f3",
    subvortsForParticle = false,
    rangeActivationTiers = {3, 4},
    supportsparticleTypes = {"NORMAL"},
    isAnticyclonic = true,
    supportsphases = {"MAIN", "BIRTH", "DEATH"},
    wallcloudColorType = "anticyclonic",
    behaviorType = "VIOLENT"
})

AddUserParticlesAutospawnXT2({
    name = "v19_f2",
    subvortsForParticle = false,
    rangeActivationTiers = {3, 4},
    supportsparticleTypes = {"NORMAL"},
    isAnticyclonic = true,
    supportsphases = {"MAIN"},
    wallcloudColorType = "anticyclonic",
    behaviorType = "BOTH"
})

AddUserParticlesAutospawnXT2({
    name = "v19_f3",
    subvortsForParticle = false,
    rangeActivationTiers = {3, 4},
    supportsparticleTypes = {"NORMAL"},
    isAnticyclonic = true,
    supportsphases = {"MAIN"},
    wallcloudColorType = "anticyclonic",
    behaviorType = "VIOLENT"
})

AddUserParticlesAutospawnXT2({
    name = "v22_f3",
    subvortsForParticle = false,
    rangeActivationTiers = {5, 6},
    supportsparticleTypes = {"NORMAL"},
    isAnticyclonic = true,
    supportsphases = {"MAIN"},
    wallcloudColorType = "anticyclonic",
    behaviorType = "VIOLENT"
})

-- DRILLBITS

AddUserParticlesAutospawnXT2({
    name = "RDT1_EF5",
    subvortsForParticle = false,
    rangeActivationTiers = {2, 3, 4, 5, 6},
    supportsparticleTypes = {"DRILLBIT"},
    isAnticyclonic = true,
    supportsphases = {"MAIN"},
    wallcloudColorType = "white",
    behaviorType = "VIOLENT"
})

AddUserParticlesAutospawnXT2({
    name = "RDTX2_Drillbit1",
    subvortsForParticle = true,
    rangeActivationTiers = {2, 3, 4, 5, 6},
    supportsparticleTypes = {"DRILLBIT", "MULTI-VORTEX"}, -- Default Multi-Vortex Drillbit
    isAnticyclonic = true,
    supportsphases = {"MAIN", "VORTEX-BREAKDOWN"},
    wallcloudColorType = "white",
    behaviorType = "VIOLENT"
})

AddUserParticlesAutospawnXT2({
    name = "RDTX2_Drillbit1",
    subvortsForParticle = true,
    rangeActivationTiers = {2, 3, 4, 5, 6},
    supportsparticleTypes = {"DRILLBIT", "MULTI-VORTEX"},
    isAnticyclonic = false,
    supportsphases = {"MAIN", "VORTEX-BREAKDOWN"},
    wallcloudColorType = "black",
    behaviorType = "VIOLENT"
})

AddUserParticlesAutospawnXT2({
    name = "RDTX2_Drillbit1",
    subvortsForParticle = true,
    rangeActivationTiers = {2, 3, 4, 5, 6},
    supportsparticleTypes = {"DRILLBIT", "MULTI-VORTEX"},
    isAnticyclonic = false,
    supportsphases = {"MAIN", "VORTEX-BREAKDOWN"},
    wallcloudColorType = "brown",
    behaviorType = "VIOLENT"
})

AddUserParticlesAutospawnXT2({
    name = "5TonyEF515",
    subvortsForParticle = false,
    rangeActivationTiers = {2, 3, 4, 5, 6},
    supportsparticleTypes = {"DRILLBIT"},
    isAnticyclonic = false,
    supportsphases = {"MAIN"},
    wallcloudColorType = "black",
    behaviorType = "VIOLENT"
})

AddUserParticlesAutospawnXT2({
    name = "v14_f5",
    subvortsForParticle = false,
    rangeActivationTiers = {2, 3, 4, 5, 6},
    supportsparticleTypes = {"DRILLBIT"},
    isAnticyclonic = false,
    supportsphases = {"MAIN"},
    wallcloudColorType = "white",
    behaviorType = "VIOLENT"
})

AddUserParticlesAutospawnXT2({
    name = "v22_f5",
    subvortsForParticle = false,
    rangeActivationTiers = {2, 3, 4, 5, 6},
    supportsparticleTypes = {"DRILLBIT"},
    isAnticyclonic = false,
    supportsphases = {"MAIN"},
    wallcloudColorType = "black",
    behaviorType = "VIOLENT"
})


------------------------------ WHITE -----------------------------------------

-- SMALL

AddUserParticlesAutospawnXT2({
    name = "5TonyEF0",
    subvortsForParticle = false,
    rangeActivationTiers = {1, 2},
    supportsparticleTypes = {"NORMAL"},
    isAnticyclonic = false,
    supportsphases = {"MAIN"},
    wallcloudColorType = "white",
    behaviorType = "WEAK"
})

AddUserParticlesAutospawnXT2({
    name = "5TonyEF019",
    subvortsForParticle = false,
    rangeActivationTiers = {1, 2},
    supportsparticleTypes = {"NORMAL"},
    isAnticyclonic = false,
    supportsphases = {"MAIN", "BIRTH", "DEATH"},
    wallcloudColorType = "white",
    behaviorType = "WEAK"
})

AddUserParticlesAutospawnXT2({
    name = "PGYT_EF_0g",
    subvortsForParticle = false,
    rangeActivationTiers = {2, 3},
    supportsparticleTypes = {"NORMAL"},
    isAnticyclonic = false,
    supportsphases = {"MAIN"},
    wallcloudColorType = "white",
    behaviorType = "WEAK"
})

AddUserParticlesAutospawnXT2({
    name = "PGYT_EF_0f",
    subvortsForParticle = false,
    rangeActivationTiers = {1, 2},
    supportsparticleTypes = {"NORMAL"},
    isAnticyclonic = false,
    supportsphases = {"MAIN"},
    wallcloudColorType = "white",
    behaviorType = "WEAK"
})

AddUserParticlesAutospawnXT2({
    name = "5TonyEF014",
    subvortsForParticle = false,
    rangeActivationTiers = {2},
    supportsparticleTypes = {"NORMAL"},
    isAnticyclonic = false,
    supportsphases = {"MAIN"},
    wallcloudColorType = "white",
    behaviorType = "WEAK"
})

AddUserParticlesAutospawnXT2({
    name = "5TonyEF015",
    subvortsForParticle = false,
    rangeActivationTiers = {2},
    supportsparticleTypes = {"NORMAL"},
    isAnticyclonic = false,
    supportsphases = {"MAIN", "BIRTH", "DEATH"},
    wallcloudColorType = "white",
    behaviorType = "WEAK"
})

AddUserParticlesAutospawnXT2({
    name = "5TonyEF07",
    subvortsForParticle = false,
    rangeActivationTiers = {1, 2},
    supportsparticleTypes = {"NORMAL"},
    isAnticyclonic = false,
    supportsphases = {"MAIN"},
    wallcloudColorType = "white",
    behaviorType = "WEAK"
})

AddUserParticlesAutospawnXT2({
    name = "5TonyEF010",
    subvortsForParticle = false,
    rangeActivationTiers = {2, 3},
    supportsparticleTypes = {"NORMAL"},
    isAnticyclonic = false,
    supportsphases = {"MAIN", "BIRTH", "DEATH"},
    wallcloudColorType = "white",
    behaviorType = "WEAK"
})

AddUserParticlesAutospawnXT2({
    name = "5TonyEF05",
    subvortsForParticle = false,
    rangeActivationTiers = {2, 3},
    supportsparticleTypes = {"NORMAL"},
    isAnticyclonic = false,
    supportsphases = {"MAIN", "BIRTH", "DEATH"},
    wallcloudColorType = "white",
    behaviorType = "WEAK"
})

AddUserParticlesAutospawnXT2({
    name = "ff_ef0_a1",
    subvortsForParticle = false,
    rangeActivationTiers = {2, 3},
    supportsparticleTypes = {"NORMAL"},
    isAnticyclonic = false,
    supportsphases = {"MAIN", "BIRTH", "DEATH"},
    wallcloudColorType = "white",
    behaviorType = "WEAK"
})

AddUserParticlesAutospawnXT2({
    name = "5TonyEF13",
    subvortsForParticle = false,
    rangeActivationTiers = {2, 3},
    supportsparticleTypes = {"NORMAL"},
    isAnticyclonic = false,
    supportsphases = {"MAIN"},
    wallcloudColorType = "white",
    behaviorType = "WEAK"
})

AddUserParticlesAutospawnXT2({
    name = "PGYT_EF_1k",
    subvortsForParticle = false,
    rangeActivationTiers = {2, 3},
    supportsparticleTypes = {"NORMAL"},
    isAnticyclonic = false,
    supportsphases = {"MAIN"},
    wallcloudColorType = "white",
    behaviorType = "BOTH"
})

AddUserParticlesAutospawnXT2({
    name = "PGYT_EF_1l",
    subvortsForParticle = false,
    rangeActivationTiers = {2, 3},
    supportsparticleTypes = {"NORMAL"},
    isAnticyclonic = false,
    supportsphases = {"MAIN"},
    wallcloudColorType = "white",
    behaviorType = "BOTH"
})

AddUserParticlesAutospawnXT2({
    name = "PGYT_EF_1n",
    subvortsForParticle = false,
    rangeActivationTiers = {2, 3},
    supportsparticleTypes = {"NORMAL"},
    isAnticyclonic = false,
    supportsphases = {"MAIN"},
    wallcloudColorType = "white",
    behaviorType = "BOTH"
})

AddUserParticlesAutospawnXT2({
    name = "PGYT_EF_1p",
    subvortsForParticle = false,
    rangeActivationTiers = {2, 3},
    supportsparticleTypes = {"NORMAL"},
    isAnticyclonic = false,
    supportsphases = {"MAIN"},
    wallcloudColorType = "white",
    behaviorType = "WEAK"
})

AddUserParticlesAutospawnXT2({
    name = "PGYT_EF_1r",
    subvortsForParticle = false,
    rangeActivationTiers = {2, 3},
    supportsparticleTypes = {"NORMAL"},
    isAnticyclonic = false,
    supportsphases = {"MAIN"},
    wallcloudColorType = "white",
    behaviorType = "BOTH"
})

AddUserParticlesAutospawnXT2({
    name = "PGYT_EF_1f",
    subvortsForParticle = false,
    rangeActivationTiers = {2},
    supportsparticleTypes = {"NORMAL"},
    isAnticyclonic = false,
    supportsphases = {"MAIN"},
    wallcloudColorType = "white",
    behaviorType = "WEAK"
})

AddUserParticlesAutospawnXT2({
    name = "PGYT_EF_1h",
    subvortsForParticle = false,
    rangeActivationTiers = {3},
    supportsparticleTypes = {"NORMAL"},
    isAnticyclonic = false,
    supportsphases = {"MAIN"},
    wallcloudColorType = "white",
    behaviorType = "BOTH"
})

AddUserParticlesAutospawnXT2({
    name = "5TonyEF113",
    subvortsForParticle = false,
    rangeActivationTiers = {2, 3},
    supportsparticleTypes = {"NORMAL"},
    isAnticyclonic = false,
    supportsphases = {"MAIN"},
    wallcloudColorType = "white",
    behaviorType = "WEAK"
})

AddUserParticlesAutospawnXT2({
    name = "5TonyEF17",
    subvortsForParticle = false,
    rangeActivationTiers = {2, 3},
    supportsparticleTypes = {"NORMAL"},
    isAnticyclonic = false,
    supportsphases = {"MAIN"},
    wallcloudColorType = "white",
    behaviorType = "WEAK"
})

AddUserParticlesAutospawnXT2({
    name = "PGYT_EF_1",
    subvortsForParticle = false,
    rangeActivationTiers = {2},
    supportsparticleTypes = {"NORMAL"},
    isAnticyclonic = false,
    supportsphases = {"MAIN"},
    wallcloudColorType = "white",
    behaviorType = "BOTH"
})

AddUserParticlesAutospawnXT2({
    name = "PGYT_EF_1c",
    subvortsForParticle = false,
    rangeActivationTiers = {2, 3},
    supportsparticleTypes = {"NORMAL"},
    isAnticyclonic = false,
    supportsphases = {"MAIN"},
    wallcloudColorType = "white",
    behaviorType = "BOTH"
})

AddUserParticlesAutospawnXT2({
    name = "5TonyEF15",
    subvortsForParticle = false,
    rangeActivationTiers = {2, 3},
    supportsparticleTypes = {"NORMAL"},
    isAnticyclonic = false,
    supportsphases = {"MAIN"},
    wallcloudColorType = "white",
    behaviorType = "BOTH"
})

AddUserParticlesAutospawnXT2({
    name = "Twister_EF2",
    subvortsForParticle = false,
    rangeActivationTiers = {3, 4},
    supportsparticleTypes = {"NORMAL"},
    isAnticyclonic = false,
    supportsphases = {"MAIN"},
    wallcloudColorType = "white",
    behaviorType = "WEAK"
})

AddUserParticlesAutospawnXT2({
    name = "5TonyEF2",
    subvortsForParticle = false,
    rangeActivationTiers = {2, 3},
    supportsparticleTypes = {"NORMAL"},
    isAnticyclonic = false,
    supportsphases = {"MAIN"},
    wallcloudColorType = "white",
    behaviorType = "BOTH"
})

AddUserParticlesAutospawnXT2({
    name = "5TonyEF217",
    subvortsForParticle = false,
    rangeActivationTiers = {3, 4},
    supportsparticleTypes = {"NORMAL"},
    isAnticyclonic = false,
    supportsphases = {"MAIN"},
    wallcloudColorType = "white",
    behaviorType = "BOTH"
})

AddUserParticlesAutospawnXT2({
    name = "PGYT_EF_2l",
    subvortsForParticle = false,
    rangeActivationTiers = {2, 3},
    supportsparticleTypes = {"NORMAL"},
    isAnticyclonic = false,
    supportsphases = {"MAIN", "BIRTH", "DEATH"},
    wallcloudColorType = "white",
    behaviorType = "WEAK"
})

AddUserParticlesAutospawnXT2({
    name = "PGYT_EF_2m",
    subvortsForParticle = false,
    rangeActivationTiers = {1, 2},
    supportsparticleTypes = {"NORMAL"},
    isAnticyclonic = false,
    supportsphases = {"MAIN"},
    wallcloudColorType = "white",
    behaviorType = "BOTH"
})

AddUserParticlesAutospawnXT2({
    name = "5TonyEF221",
    subvortsForParticle = false,
    rangeActivationTiers = {2, 3},
    supportsparticleTypes = {"NORMAL"},
    isAnticyclonic = false,
    supportsphases = {"MAIN"},
    wallcloudColorType = "white",
    behaviorType = "BOTH"
})

AddUserParticlesAutospawnXT2({
    name = "5TonyEF222",
    subvortsForParticle = false,
    rangeActivationTiers = {2, 3},
    supportsparticleTypes = {"NORMAL"},
    isAnticyclonic = false,
    supportsphases = {"MAIN"},
    wallcloudColorType = "white",
    behaviorType = "BOTH"
})

AddUserParticlesAutospawnXT2({
    name = "5TonyEF218",
    subvortsForParticle = false,
    rangeActivationTiers = {3, 4},
    supportsparticleTypes = {"NORMAL"},
    isAnticyclonic = false,
    supportsphases = {"MAIN"},
    wallcloudColorType = "white",
    behaviorType = "BOTH"
})

AddUserParticlesAutospawnXT2({
    name = "5TonyEF219",
    subvortsForParticle = false,
    rangeActivationTiers = {2},
    supportsparticleTypes = {"NORMAL"},
    isAnticyclonic = false,
    supportsphases = {"MAIN"},
    wallcloudColorType = "white",
    behaviorType = "WEAK"
})

AddUserParticlesAutospawnXT2({
    name = "PGYT_EF_2f",
    subvortsForParticle = false,
    rangeActivationTiers = {2, 3},
    supportsparticleTypes = {"NORMAL"},
    isAnticyclonic = false,
    supportsphases = {"MAIN", "BIRTH", "DEATH"},
    wallcloudColorType = "white",
    behaviorType = "WEAK"
})

AddUserParticlesAutospawnXT2({
    name = "PGYT_EF_2g",
    subvortsForParticle = false,
    rangeActivationTiers = {2, 3},
    supportsparticleTypes = {"NORMAL"},
    isAnticyclonic = false,
    supportsphases = {"MAIN"},
    wallcloudColorType = "white",
    behaviorType = "WEAK"
})

AddUserParticlesAutospawnXT2({
    name = "PGYT_EF_2j",
    subvortsForParticle = false,
    rangeActivationTiers = {2, 3},
    supportsparticleTypes = {"NORMAL"},
    isAnticyclonic = false,
    supportsphases = {"MAIN"},
    wallcloudColorType = "white",
    behaviorType = "WEAK"
})

AddUserParticlesAutospawnXT2({
    name = "5TonyEF26",
    subvortsForParticle = false,
    rangeActivationTiers = {3, 4},
    supportsparticleTypes = {"NORMAL"},
    isAnticyclonic = false,
    supportsphases = {"MAIN"},
    wallcloudColorType = "white",
    behaviorType = "BOTH"
})

AddUserParticlesAutospawnXT2({
    name = "5TonyEF29",
    subvortsForParticle = false,
    rangeActivationTiers = {2, 3},
    supportsparticleTypes = {"NORMAL"},
    isAnticyclonic = false,
    supportsphases = {"MAIN", "BIRTH", "DEATH"},
    wallcloudColorType = "white",
    behaviorType = "WEAK"
})

AddUserParticlesAutospawnXT2({
    name = "5TonyEF32",
    subvortsForParticle = false,
    rangeActivationTiers = {3, 4},
    supportsparticleTypes = {"NORMAL"},
    isAnticyclonic = false,
    supportsphases = {"MAIN"},
    wallcloudColorType = "white",
    behaviorType = "BOTH"
})

AddUserParticlesAutospawnXT2({
    name = "5TonyEF33",
    subvortsForParticle = false,
    rangeActivationTiers = {3, 4},
    supportsparticleTypes = {"NORMAL"},
    isAnticyclonic = false,
    supportsphases = {"MAIN"},
    wallcloudColorType = "white",
    behaviorType = "BOTH"
})

AddUserParticlesAutospawnXT2({
    name = "5TonyEF319",
    subvortsForParticle = false,
    rangeActivationTiers = {3, 4},
    supportsparticleTypes = {"NORMAL"},
    isAnticyclonic = false,
    supportsphases = {"MAIN"},
    wallcloudColorType = "white",
    behaviorType = "BOTH"
})

AddUserParticlesAutospawnXT2({
    name = "PGYT_EF_3c",
    subvortsForParticle = false,
    rangeActivationTiers = {2, 3},
    supportsparticleTypes = {"NORMAL"},
    isAnticyclonic = false,
    supportsphases = {"MAIN"},
    wallcloudColorType = "white",
    behaviorType = "BOTH"
})

AddUserParticlesAutospawnXT2({
    name = "5TonyEF313",
    subvortsForParticle = false,
    rangeActivationTiers = {2, 3},
    supportsparticleTypes = {"NORMAL"},
    isAnticyclonic = false,
    supportsphases = {"MAIN"},
    wallcloudColorType = "white",
    behaviorType = "BOTH"
})

AddUserParticlesAutospawnXT2({
    name = "5TonyEF39",
    subvortsForParticle = false,
    rangeActivationTiers = {2, 3},
    supportsparticleTypes = {"NORMAL"},
    isAnticyclonic = false,
    supportsphases = {"MAIN"},
    wallcloudColorType = "white",
    behaviorType = "BOTH"
})

AddUserParticlesAutospawnXT2({
    name = "5TonyEF415",
    subvortsForParticle = false,
    rangeActivationTiers = {3, 4},
    supportsparticleTypes = {"NORMAL"},
    isAnticyclonic = false,
    supportsphases = {"MAIN"},
    wallcloudColorType = "white",
    behaviorType = "VIOLENT"
})

AddUserParticlesAutospawnXT2({
    name = "RDT2_EF4",
    subvortsForParticle = false,
    rangeActivationTiers = {4, 5},
    supportsparticleTypes = {"NORMAL"},
    isAnticyclonic = false,
    supportsphases = {"MAIN"},
    wallcloudColorType = "white",
    behaviorType = "BOTH"
})

AddUserParticlesAutospawnXT2({
    name = "5TonyEF43",
    subvortsForParticle = false,
    rangeActivationTiers = {3, 4},
    supportsparticleTypes = {"NORMAL"},
    isAnticyclonic = false,
    supportsphases = {"MAIN"},
    wallcloudColorType = "white",
    behaviorType = "VIOLENT"
})

AddUserParticlesAutospawnXT2({
    name = "PGYT_EF_4f",
    subvortsForParticle = false,
    rangeActivationTiers = {4, 5},
    supportsparticleTypes = {"NORMAL"},
    isAnticyclonic = false,
    supportsphases = {"MAIN"},
    wallcloudColorType = "white",
    behaviorType = "VIOLENT"
})

AddUserParticlesAutospawnXT2({
    name = "PGYT_EF_4g",
    subvortsForParticle = false,
    rangeActivationTiers = {4, 5},
    supportsparticleTypes = {"NORMAL"},
    isAnticyclonic = false,
    supportsphases = {"MAIN"},
    wallcloudColorType = "white",
    behaviorType = "BOTH"
})

AddUserParticlesAutospawnXT2({
    name = "PGYT_EF_4h",
    subvortsForParticle = false,
    rangeActivationTiers = {3, 4},
    supportsparticleTypes = {"NORMAL"},
    isAnticyclonic = false,
    supportsphases = {"MAIN"},
    wallcloudColorType = "white",
    behaviorType = "WEAK"
})

AddUserParticlesAutospawnXT2({
    name = "PGYT_EF_4i",
    subvortsForParticle = false,
    rangeActivationTiers = {4, 5},
    supportsparticleTypes = {"NORMAL"},
    isAnticyclonic = false,
    supportsphases = {"MAIN"},
    wallcloudColorType = "white",
    behaviorType = "VIOLENT"
})

AddUserParticlesAutospawnXT2({
    name = "5TonyEF419",
    subvortsForParticle = false,
    rangeActivationTiers = {4},
    supportsparticleTypes = {"NORMAL"},
    isAnticyclonic = false,
    supportsphases = {"MAIN"},
    wallcloudColorType = "white",
    behaviorType = "VIOLENT"
})

AddUserParticlesAutospawnXT2({
    name = "5TonyEF48",
    subvortsForParticle = false,
    rangeActivationTiers = {4},
    supportsparticleTypes = {"NORMAL"},
    isAnticyclonic = false,
    supportsphases = {"MAIN"},
    wallcloudColorType = "white",
    behaviorType = "VIOLENT"
})

AddUserParticlesAutospawnXT2({
    name = "5TonyEF520",
    subvortsForParticle = false,
    rangeActivationTiers = {5, 6},
    supportsparticleTypes = {"NORMAL"},
    isAnticyclonic = false,
    supportsphases = {"MAIN"},
    wallcloudColorType = "white",
    behaviorType = "BOTH"
})

AddUserParticlesAutospawnXT2({
    name = "PGYT_EF_5d", -- LEAVING THIS MARKER HERE TO INDICATE THAT IF THIS PARTICLE GETS UPDATED THEN I NEED TO CHANGE THIS...
    subvortsForParticle = false,
    rangeActivationTiers = {5, 6},
    supportsparticleTypes = {"NORMAL"},
    isAnticyclonic = false,
    supportsphases = {"MAIN", "BIRTH", "DEATH"},
    wallcloudColorType = "white",
    behaviorType = "BOTH"
})

AddUserParticlesAutospawnXT2({
    name = "5TonyEF521",
    subvortsForParticle = false,
    rangeActivationTiers = {4, 5},
    supportsparticleTypes = {"NORMAL"},
    isAnticyclonic = false,
    supportsphases = {"MAIN"},
    wallcloudColorType = "white",
    behaviorType = "VIOLENT"
})

AddUserParticlesAutospawnXT2({
    name = "5TonyEF57",
    subvortsForParticle = false,
    rangeActivationTiers = {5, 6},
    supportsparticleTypes = {"NORMAL"},
    isAnticyclonic = false,
    supportsphases = {"MAIN"},
    wallcloudColorType = "white",
    behaviorType = "VIOLENT"
})

AddUserParticlesAutospawnXT2({
    name = "5TonyEF58",
    subvortsForParticle = false,
    rangeActivationTiers = {5, 6},
    supportsparticleTypes = {"NORMAL"},
    isAnticyclonic = false,
    supportsphases = {"MAIN"},
    wallcloudColorType = "white",
    behaviorType = "VIOLENT"
})

AddUserParticlesAutospawnXT2({
    name = "PGYT_EF_5c",
    subvortsForParticle = false,
    rangeActivationTiers = {4, 5},
    supportsparticleTypes = {"NORMAL"},
    isAnticyclonic = false,
    supportsphases = {"MAIN"},
    wallcloudColorType = "white",
    behaviorType = "BOTH"
})

AddUserParticlesAutospawnXT2({
    name = "5TonyEF517",
    subvortsForParticle = false,
    rangeActivationTiers = {5, 6},
    supportsparticleTypes = {"NORMAL"},
    isAnticyclonic = false,
    supportsphases = {"MAIN"},
    wallcloudColorType = "white",
    behaviorType = "VIOLENT"
})

AddUserParticlesAutospawnXT2({
    name = "5TonyEF513",
    subvortsForParticle = false,
    rangeActivationTiers = {4, 5},
    supportsparticleTypes = {"NORMAL"},
    isAnticyclonic = false,
    supportsphases = {"MAIN"},
    wallcloudColorType = "white",
    behaviorType = "VIOLENT"
})

AddUserParticlesAutospawnXT2({
    name = "5TonyEF514",
    subvortsForParticle = false,
    rangeActivationTiers = {5, 6},
    supportsparticleTypes = {"NORMAL"},
    isAnticyclonic = false,
    supportsphases = {"MAIN"},
    wallcloudColorType = "white",
    behaviorType = "VIOLENT"
})



-- LARGE

AddUserParticlesAutospawnXT2({
    name = "PGYT_EF_0n",
    subvortsForParticle = false,
    rangeActivationTiers = {3},
    supportsparticleTypes = {"NORMAL"},
    isAnticyclonic = false,
    supportsphases = {"MAIN"},
    wallcloudColorType = "white",
    behaviorType = "WEAK"
})

AddUserParticlesAutospawnXT2({
    name = "PGYT_EF_0o",
    subvortsForParticle = false,
    rangeActivationTiers = {3, 4},
    supportsparticleTypes = {"NORMAL"},
    isAnticyclonic = false,
    supportsphases = {"MAIN"},
    wallcloudColorType = "white",
    behaviorType = "BOTH"
})

AddUserParticlesAutospawnXT2({
    name = "PGYT_EF_0b",
    subvortsForParticle = false,
    rangeActivationTiers = {2, 3},
    supportsparticleTypes = {"NORMAL"},
    isAnticyclonic = false,
    supportsphases = {"MAIN", "BIRTH", "DEATH"},
    wallcloudColorType = "white",
    behaviorType = "WEAK"
})

AddUserParticlesAutospawnXT2({
    name = "PGYT_EF_0q",
    subvortsForParticle = false,
    rangeActivationTiers = {2, 3},
    supportsparticleTypes = {"NORMAL"},
    isAnticyclonic = false,
    supportsphases = {"MAIN", "BIRTH", "DEATH"},
    wallcloudColorType = "white",
    behaviorType = "WEAK"
})

AddUserParticlesAutospawnXT2({
    name = "PGYT_EF_0r",
    subvortsForParticle = false,
    rangeActivationTiers = {3, 4},
    supportsparticleTypes = {"NORMAL"},
    isAnticyclonic = false,
    supportsphases = {"MAIN"},
    wallcloudColorType = "white",
    behaviorType = "BOTH"
})

AddUserParticlesAutospawnXT2({
    name = "PGYT_EF_0s",
    subvortsForParticle = false,
    rangeActivationTiers = {3},
    supportsparticleTypes = {"NORMAL"},
    isAnticyclonic = false,
    supportsphases = {"MAIN"},
    wallcloudColorType = "white",
    behaviorType = "WEAK"
})

AddUserParticlesAutospawnXT2({
    name = "PGYT_EF_0v",
    subvortsForParticle = false,
    rangeActivationTiers = {2, 3},
    supportsparticleTypes = {"NORMAL"},
    isAnticyclonic = false,
    supportsphases = {"MAIN"},
    wallcloudColorType = "white",
    behaviorType = "BOTH"
})

AddUserParticlesAutospawnXT2({
    name = "PGYT_EF_0x",
    subvortsForParticle = false,
    rangeActivationTiers = {2, 3},
    supportsparticleTypes = {"NORMAL"},
    isAnticyclonic = false,
    supportsphases = {"MAIN"},
    wallcloudColorType = "white",
    behaviorType = "WEAK"
})

AddUserParticlesAutospawnXT2({
    name = "5TonyEF020",
    subvortsForParticle = false,
    rangeActivationTiers = {2, 3},
    supportsparticleTypes = {"NORMAL"},
    isAnticyclonic = false,
    supportsphases = {"MAIN"},
    wallcloudColorType = "white",
    behaviorType = "WEAK"
})

AddUserParticlesAutospawnXT2({
    name = "PGYT_EF_0j",
    subvortsForParticle = false,
    rangeActivationTiers = {2, 3},
    supportsparticleTypes = {"NORMAL"},
    isAnticyclonic = false,
    supportsphases = {"MAIN"},
    wallcloudColorType = "white",
    behaviorType = "WEAK"
})

AddUserParticlesAutospawnXT2({
    name = "5TonyEF06",
    subvortsForParticle = false,
    rangeActivationTiers = {2},
    supportsparticleTypes = {"NORMAL"},
    isAnticyclonic = false,
    supportsphases = {"MAIN"},
    wallcloudColorType = "white",
    behaviorType = "BOTH"
})

AddUserParticlesAutospawnXT2({
    name = "PGYT_EF_0i",
    subvortsForParticle = false,
    rangeActivationTiers = {3, 4},
    supportsparticleTypes = {"NORMAL"},
    isAnticyclonic = false,
    supportsphases = {"MAIN", "BIRTH", "DEATH"},
    wallcloudColorType = "white",
    behaviorType = "WEAK"
})

AddUserParticlesAutospawnXT2({
    name = "PGYT_EF_0d",
    subvortsForParticle = false,
    rangeActivationTiers = {3},
    supportsparticleTypes = {"NORMAL"},
    isAnticyclonic = false,
    supportsphases = {"MAIN"},
    wallcloudColorType = "white",
    behaviorType = "BOTH"
})

AddUserParticlesAutospawnXT2({
    name = "PGYT_EF_0e",
    subvortsForParticle = false,
    rangeActivationTiers = {3, 4},
    supportsparticleTypes = {"NORMAL"},
    isAnticyclonic = false,
    supportsphases = {"MAIN"},
    wallcloudColorType = "white",
    behaviorType = "BOTH"
})

AddUserParticlesAutospawnXT2({
    name = "5TonyEF09",
    subvortsForParticle = false,
    rangeActivationTiers = {3, 4},
    supportsparticleTypes = {"NORMAL"},
    isAnticyclonic = false,
    supportsphases = {"MAIN"},
    wallcloudColorType = "white",
    behaviorType = "WEAK"
})

AddUserParticlesAutospawnXT2({
    name = "5TonyEF04",
    subvortsForParticle = false,
    rangeActivationTiers = {2, 3},
    supportsparticleTypes = {"NORMAL"},
    isAnticyclonic = false,
    supportsphases = {"MAIN"},
    wallcloudColorType = "white",
    behaviorType = "WEAK"
})

AddUserParticlesAutospawnXT2({
    name = "5TonyEF16",
    subvortsForParticle = false,
    rangeActivationTiers = {4, 5, 6},
    supportsparticleTypes = {"NORMAL"},
    isAnticyclonic = false,
    supportsphases = {"MAIN"},
    wallcloudColorType = "white",
    behaviorType = "WEAK"
})

AddUserParticlesAutospawnXT2({
    name = "5TonyEF120",
    subvortsForParticle = false,
    rangeActivationTiers = {3, 4},
    supportsparticleTypes = {"NORMAL"},
    isAnticyclonic = false,
    supportsphases = {"MAIN"},
    wallcloudColorType = "white",
    behaviorType = "BOTH"
})

AddUserParticlesAutospawnXT2({
    name = "PGYT_EF_1s",
    subvortsForParticle = true,
    rangeActivationTiers = {2, 3},
    supportsparticleTypes = {"NORMAL"},
    isAnticyclonic = false,
    supportsphases = {"MAIN"},
    wallcloudColorType = "white",
    behaviorType = "BOTH"
})

AddUserParticlesAutospawnXT2({
    name = "5TonyEF119",
    subvortsForParticle = false,
    rangeActivationTiers = {2, 3},
    supportsparticleTypes = {"NORMAL"},
    isAnticyclonic = false,
    supportsphases = {"MAIN"},
    wallcloudColorType = "white",
    behaviorType = "BOTH"
})

AddUserParticlesAutospawnXT2({
    name = "5TonyEF117",
    subvortsForParticle = false,
    rangeActivationTiers = {4, 5},
    supportsparticleTypes = {"NORMAL"},
    isAnticyclonic = false,
    supportsphases = {"MAIN"},
    wallcloudColorType = "white",
    behaviorType = "WEAK"
})

AddUserParticlesAutospawnXT2({
    name = "5TonyEF19",
    subvortsForParticle = true,
    rangeActivationTiers = {5, 6},
    supportsparticleTypes = {"NORMAL"},
    isAnticyclonic = false,
    supportsphases = {"MAIN", "BIRTH", "DEATH"},
    wallcloudColorType = "white",
    behaviorType = "WEAK"
})

AddUserParticlesAutospawnXT2({
    name = "5TonyEF22",
    subvortsForParticle = false,
    rangeActivationTiers = {3, 4},
    supportsparticleTypes = {"NORMAL"},
    isAnticyclonic = false,
    supportsphases = {"MAIN"},
    wallcloudColorType = "white",
    behaviorType = "BOTH"
})

AddUserParticlesAutospawnXT2({
    name = "PGYT_EF_2o",
    subvortsForParticle = false,
    rangeActivationTiers = {2, 3},
    supportsparticleTypes = {"NORMAL"},
    isAnticyclonic = false,
    supportsphases = {"MAIN"},
    wallcloudColorType = "white",
    behaviorType = "WEAK"
})

AddUserParticlesAutospawnXT2({
    name = "5TonyEF215",
    subvortsForParticle = false,
    rangeActivationTiers = {2, 3},
    supportsparticleTypes = {"NORMAL"},
    isAnticyclonic = false,
    supportsphases = {"MAIN", "BIRTH", "DEATH"},
    wallcloudColorType = "white",
    behaviorType = "WEAK"
})

AddUserParticlesAutospawnXT2({
    name = "5TonyEF213",
    subvortsForParticle = false,
    rangeActivationTiers = {3, 4},
    supportsparticleTypes = {"NORMAL"},
    isAnticyclonic = false,
    supportsphases = {"MAIN"},
    wallcloudColorType = "white",
    behaviorType = "BOTH"
})

AddUserParticlesAutospawnXT2({
    name = "5TonyEF36",
    subvortsForParticle = false,
    rangeActivationTiers = {4, 5},
    supportsparticleTypes = {"NORMAL"},
    isAnticyclonic = false,
    supportsphases = {"MAIN"},
    wallcloudColorType = "white",
    behaviorType = "BOTH"
})

AddUserParticlesAutospawnXT2({
    name = "5TonyEF318",
    subvortsForParticle = false,
    rangeActivationTiers = {4, 5, 6},
    supportsparticleTypes = {"NORMAL"},
    isAnticyclonic = false,
    supportsphases = {"MAIN"},
    wallcloudColorType = "white",
    behaviorType = "BOTH"
})

AddUserParticlesAutospawnXT2({
    name = "5TonyEF316",
    subvortsForParticle = false,
    rangeActivationTiers = {3, 4},
    supportsparticleTypes = {"NORMAL"},
    isAnticyclonic = false,
    supportsphases = {"MAIN"},
    wallcloudColorType = "white",
    behaviorType = "BOTH"
})

AddUserParticlesAutospawnXT2({
    name = "5TonyEF312",
    subvortsForParticle = false,
    rangeActivationTiers = {5, 6},
    supportsparticleTypes = {"NORMAL"},
    isAnticyclonic = false,
    supportsphases = {"MAIN"},
    wallcloudColorType = "white",
    behaviorType = "BOTH"
})

AddUserParticlesAutospawnXT2({
    name = "5TonyEF42",
    subvortsForParticle = false,
    rangeActivationTiers = {4, 5},
    supportsparticleTypes = {"NORMAL"},
    isAnticyclonic = false,
    supportsphases = {"MAIN"},
    wallcloudColorType = "white",
    behaviorType = "VIOLENT"
})

AddUserParticlesAutospawnXT2({
    name = "PGYT_EF_4j",
    subvortsForParticle = false,
    rangeActivationTiers = {4, 5},
    supportsparticleTypes = {"NORMAL"},
    isAnticyclonic = false,
    supportsphases = {"MAIN"},
    wallcloudColorType = "white",
    behaviorType = "BOTH"
})

AddUserParticlesAutospawnXT2({
    name = "5TonyEF414",
    subvortsForParticle = false,
    rangeActivationTiers = {3, 4},
    supportsparticleTypes = {"NORMAL"},
    isAnticyclonic = false,
    supportsphases = {"MAIN", "BIRTH", "DEATH"},
    wallcloudColorType = "white",
    behaviorType = "BOTH"
})

AddUserParticlesAutospawnXT2({
    name = "5TonyEF410",
    subvortsForParticle = false,
    rangeActivationTiers = {4, 5},
    supportsparticleTypes = {"NORMAL"},
    isAnticyclonic = false,
    supportsphases = {"MAIN"},
    wallcloudColorType = "white",
    behaviorType = "VIOLENT"
})



-- SMALL MULTIVORTEX TREE FROM OLD VER

AddUserParticlesAutospawnXT2({
    name = "5TonyEF02",
    subvortsForParticle = true,
    rangeActivationTiers = {2},-- Tiers are    1 : < 2000,   2: < 3500,   3: < 5000,   4: < 6500,   5: < 8000,   6: < 9500,     7: < 11000,      8: < 12500     9: >12501 -- extremely large...
    supportsparticleTypes = {"MULTI-VORTEX"}, -- Supports multiple flag options : MULTI-VORTEX, DRILLBIT, NORMAL
    isAnticyclonic = false, -- Is this particle anticyclonic (clockwise spinning or not?) (segments it into anticyclonic sublist)
    supportsphases = {"MAIN", "BIRTH", "DEATH", "VORTEX-BREAKDOWN"}, -- Supports multiple flag options : MAIN, BIRTH, DEATH, VORTEX-BREAKDOWN. MAIN is normal tornado activity, birth and death self explanatory, vortex-breakdown has a chance of getting set when tornadoes are multivortex.
    wallcloudColorType = "white", -- wallcloud color Types Available are "white", "black", "brown", only supports one entry.
    behaviorType = "WEAK" -- IS particle "WEAK" COMPATIBLE, "VIOLENT" COMPATIBLE, or "BOTH". Only supports one entry.
})
AddUserParticlesAutospawnXT2({
    name = "5TonyEF022",
    subvortsForParticle = true,
    rangeActivationTiers = {2},-- Tiers are    1 : < 2000,   2: < 3500,   3: < 5000,   4: < 6500,   5: < 8000,   6: < 9500,     7: < 11000,      8: < 12500     9: >12501 -- extremely large...
    supportsparticleTypes = {"MULTI-VORTEX"}, -- Supports multiple flag options : MULTI-VORTEX, DRILLBIT, NORMAL
    isAnticyclonic = false, -- Is this particle anticyclonic (clockwise spinning or not?) (segments it into anticyclonic sublist)
    supportsphases = {"MAIN", "BIRTH", "DEATH", "VORTEX-BREAKDOWN"}, -- Supports multiple flag options : MAIN, BIRTH, DEATH, VORTEX-BREAKDOWN. MAIN is normal tornado activity, birth and death self explanatory, vortex-breakdown has a chance of getting set when tornadoes are multivortex.
    wallcloudColorType = "white", -- wallcloud color Types Available are "white", "black", "brown", only supports one entry.
    behaviorType = "WEAK" -- IS particle "WEAK" COMPATIBLE, "VIOLENT" COMPATIBLE, or "BOTH". Only supports one entry.
})
AddUserParticlesAutospawnXT2({
    name = "PGYT_EF_0w",
    subvortsForParticle = true,
    rangeActivationTiers = {2},-- Tiers are    1 : < 2000,   2: < 3500,   3: < 5000,   4: < 6500,   5: < 8000,   6: < 9500,     7: < 11000,      8: < 12500     9: >12501 -- extremely large...
    supportsparticleTypes = {"MULTI-VORTEX"}, -- Supports multiple flag options : MULTI-VORTEX, DRILLBIT, NORMAL
    isAnticyclonic = false, -- Is this particle anticyclonic (clockwise spinning or not?) (segments it into anticyclonic sublist)
    supportsphases = {"MAIN", "VORTEX-BREAKDOWN"}, -- Supports multiple flag options : MAIN, BIRTH, DEATH, VORTEX-BREAKDOWN. MAIN is normal tornado activity, birth and death self explanatory, vortex-breakdown has a chance of getting set when tornadoes are multivortex.
    wallcloudColorType = "white", -- wallcloud color Types Available are "white", "black", "brown", only supports one entry.
    behaviorType = "WEAK" -- IS particle "WEAK" COMPATIBLE, "VIOLENT" COMPATIBLE, or "BOTH". Only supports one entry.
})
AddUserParticlesAutospawnXT2({
    name = "5TonyEF016",
    subvortsForParticle = true,
    rangeActivationTiers = {2},-- Tiers are    1 : < 2000,   2: < 3500,   3: < 5000,   4: < 6500,   5: < 8000,   6: < 9500,     7: < 11000,      8: < 12500     9: >12501 -- extremely large...
    supportsparticleTypes = {"MULTI-VORTEX"}, -- Supports multiple flag options : MULTI-VORTEX, DRILLBIT, NORMAL
    isAnticyclonic = false, -- Is this particle anticyclonic (clockwise spinning or not?) (segments it into anticyclonic sublist)
    supportsphases = {"MAIN", "BIRTH", "DEATH", "VORTEX-BREAKDOWN"}, -- Supports multiple flag options : MAIN, BIRTH, DEATH, VORTEX-BREAKDOWN. MAIN is normal tornado activity, birth and death self explanatory, vortex-breakdown has a chance of getting set when tornadoes are multivortex.
    wallcloudColorType = "white", -- wallcloud color Types Available are "white", "black", "brown", only supports one entry.
    behaviorType = "WEAK" -- IS particle "WEAK" COMPATIBLE, "VIOLENT" COMPATIBLE, or "BOTH". Only supports one entry.
})
AddUserParticlesAutospawnXT2({
    name = "5TonyEF012",
    subvortsForParticle = true,
    rangeActivationTiers = {1, 2},-- Tiers are    1 : < 2000,   2: < 3500,   3: < 5000,   4: < 6500,   5: < 8000,   6: < 9500,     7: < 11000,      8: < 12500     9: >12501 -- extremely large...
    supportsparticleTypes = {"MULTI-VORTEX"}, -- Supports multiple flag options : MULTI-VORTEX, DRILLBIT, NORMAL
    isAnticyclonic = false, -- Is this particle anticyclonic (clockwise spinning or not?) (segments it into anticyclonic sublist)
    supportsphases = {"MAIN", "BIRTH", "DEATH", "VORTEX-BREAKDOWN"}, -- Supports multiple flag options : MAIN, BIRTH, DEATH, VORTEX-BREAKDOWN. MAIN is normal tornado activity, birth and death self explanatory, vortex-breakdown has a chance of getting set when tornadoes are multivortex.
    wallcloudColorType = "white", -- wallcloud color Types Available are "white", "black", "brown", only supports one entry.
    behaviorType = "WEAK" -- IS particle "WEAK" COMPATIBLE, "VIOLENT" COMPATIBLE, or "BOTH". Only supports one entry.
})
AddUserParticlesAutospawnXT2({
    name = "PGYT_EF_1m",
    subvortsForParticle = true,
    rangeActivationTiers = {2, 3},-- Tiers are    1 : < 2000,   2: < 3500,   3: < 5000,   4: < 6500,   5: < 8000,   6: < 9500,     7: < 11000,      8: < 12500     9: >12501 -- extremely large...
    supportsparticleTypes = {"MULTI-VORTEX"}, -- Supports multiple flag options : MULTI-VORTEX, DRILLBIT, NORMAL
    isAnticyclonic = false, -- Is this particle anticyclonic (clockwise spinning or not?) (segments it into anticyclonic sublist)
    supportsphases = {"MAIN", "BIRTH", "DEATH", "VORTEX-BREAKDOWN"}, -- Supports multiple flag options : MAIN, BIRTH, DEATH, VORTEX-BREAKDOWN. MAIN is normal tornado activity, birth and death self explanatory, vortex-breakdown has a chance of getting set when tornadoes are multivortex.
    wallcloudColorType = "white", -- wallcloud color Types Available are "white", "black", "brown", only supports one entry.
    behaviorType = "WEAK" -- IS particle "WEAK" COMPATIBLE, "VIOLENT" COMPATIBLE, or "BOTH". Only supports one entry.
})
AddUserParticlesAutospawnXT2({
    name = "PGYT_EF_1g",
    subvortsForParticle = true,
    rangeActivationTiers = {2, 3},-- Tiers are    1 : < 2000,   2: < 3500,   3: < 5000,   4: < 6500,   5: < 8000,   6: < 9500,     7: < 11000,      8: < 12500     9: >12501 -- extremely large...
    supportsparticleTypes = {"MULTI-VORTEX"}, -- Supports multiple flag options : MULTI-VORTEX, DRILLBIT, NORMAL
    isAnticyclonic = false, -- Is this particle anticyclonic (clockwise spinning or not?) (segments it into anticyclonic sublist)
    supportsphases = {"MAIN", "BIRTH", "DEATH", "VORTEX-BREAKDOWN"}, -- Supports multiple flag options : MAIN, BIRTH, DEATH, VORTEX-BREAKDOWN. MAIN is normal tornado activity, birth and death self explanatory, vortex-breakdown has a chance of getting set when tornadoes are multivortex.
    wallcloudColorType = "white", -- wallcloud color Types Available are "white", "black", "brown", only supports one entry.
    behaviorType = "BOTH" -- IS particle "WEAK" COMPATIBLE, "VIOLENT" COMPATIBLE, or "BOTH". Only supports one entry.
})
AddUserParticlesAutospawnXT2({
    name = "PGYT_EF_1q",
    subvortsForParticle = true,
    rangeActivationTiers = {2, 3},-- Tiers are    1 : < 2000,   2: < 3500,   3: < 5000,   4: < 6500,   5: < 8000,   6: < 9500,     7: < 11000,      8: < 12500     9: >12501 -- extremely large...
    supportsparticleTypes = {"MULTI-VORTEX"}, -- Supports multiple flag options : MULTI-VORTEX, DRILLBIT, NORMAL
    isAnticyclonic = false, -- Is this particle anticyclonic (clockwise spinning or not?) (segments it into anticyclonic sublist)
    supportsphases = {"MAIN", "BIRTH", "DEATH", "VORTEX-BREAKDOWN"}, -- Supports multiple flag options : MAIN, BIRTH, DEATH, VORTEX-BREAKDOWN. MAIN is normal tornado activity, birth and death self explanatory, vortex-breakdown has a chance of getting set when tornadoes are multivortex.
    wallcloudColorType = "white", -- wallcloud color Types Available are "white", "black", "brown", only supports one entry.
    behaviorType = "BOTH" -- IS particle "WEAK" COMPATIBLE, "VIOLENT" COMPATIBLE, or "BOTH". Only supports one entry.
})
AddUserParticlesAutospawnXT2({
    name = "PGYT_EF_2q",
    subvortsForParticle = true,
    rangeActivationTiers = {2, 3},-- Tiers are    1 : < 2000,   2: < 3500,   3: < 5000,   4: < 6500,   5: < 8000,   6: < 9500,     7: < 11000,      8: < 12500     9: >12501 -- extremely large...
    supportsparticleTypes = {"MULTI-VORTEX"}, -- Supports multiple flag options : MULTI-VORTEX, DRILLBIT, NORMAL
    isAnticyclonic = false, -- Is this particle anticyclonic (clockwise spinning or not?) (segments it into anticyclonic sublist)
    supportsphases = {"MAIN", "BIRTH", "DEATH", "VORTEX-BREAKDOWN"}, -- Supports multiple flag options : MAIN, BIRTH, DEATH, VORTEX-BREAKDOWN. MAIN is normal tornado activity, birth and death self explanatory, vortex-breakdown has a chance of getting set when tornadoes are multivortex.
    wallcloudColorType = "white", -- wallcloud color Types Available are "white", "black", "brown", only supports one entry.
    behaviorType = "WEAK" -- IS particle "WEAK" COMPATIBLE, "VIOLENT" COMPATIBLE, or "BOTH". Only supports one entry.
})
AddUserParticlesAutospawnXT2({
    name = "PGYT_EF_2p",
    subvortsForParticle = true,
    rangeActivationTiers = {2, 3},-- Tiers are    1 : < 2000,   2: < 3500,   3: < 5000,   4: < 6500,   5: < 8000,   6: < 9500,     7: < 11000,      8: < 12500     9: >12501 -- extremely large...
    supportsparticleTypes = {"MULTI-VORTEX", "NORMAL"}, -- Supports multiple flag options : MULTI-VORTEX, DRILLBIT, NORMAL
    isAnticyclonic = false, -- Is this particle anticyclonic (clockwise spinning or not?) (segments it into anticyclonic sublist)
    supportsphases = {"MAIN", "VORTEX-BREAKDOWN"}, -- Supports multiple flag options : MAIN, BIRTH, DEATH, VORTEX-BREAKDOWN. MAIN is normal tornado activity, birth and death self explanatory, vortex-breakdown has a chance of getting set when tornadoes are multivortex.
    wallcloudColorType = "white", -- wallcloud color Types Available are "white", "black", "brown", only supports one entry.
    behaviorType = "BOTH" -- IS particle "WEAK" COMPATIBLE, "VIOLENT" COMPATIBLE, or "BOTH". Only supports one entry.
})
AddUserParticlesAutospawnXT2({
    name = "5TonyEF23",
    subvortsForParticle = true,
    rangeActivationTiers = {2, 3},-- Tiers are    1 : < 2000,   2: < 3500,   3: < 5000,   4: < 6500,   5: < 8000,   6: < 9500,     7: < 11000,      8: < 12500     9: >12501 -- extremely large...
    supportsparticleTypes = {"MULTI-VORTEX", "NORMAL"}, -- Supports multiple flag options : MULTI-VORTEX, DRILLBIT, NORMAL
    isAnticyclonic = false, -- Is this particle anticyclonic (clockwise spinning or not?) (segments it into anticyclonic sublist)
    supportsphases = {"MAIN", "VORTEX-BREAKDOWN"}, -- Supports multiple flag options : MAIN, BIRTH, DEATH, VORTEX-BREAKDOWN. MAIN is normal tornado activity, birth and death self explanatory, vortex-breakdown has a chance of getting set when tornadoes are multivortex.
    wallcloudColorType = "white", -- wallcloud color Types Available are "white", "black", "brown", only supports one entry.
    behaviorType = "BOTH" -- IS particle "WEAK" COMPATIBLE, "VIOLENT" COMPATIBLE, or "BOTH". Only supports one entry.
})
AddUserParticlesAutospawnXT2({
    name = "5TonyEF35",
    subvortsForParticle = true,
    rangeActivationTiers = {4, 5},-- Tiers are    1 : < 2000,   2: < 3500,   3: < 5000,   4: < 6500,   5: < 8000,   6: < 9500,     7: < 11000,      8: < 12500     9: >12501 -- extremely large...
    supportsparticleTypes = {"MULTI-VORTEX", "NORMAL"}, -- Supports multiple flag options : MULTI-VORTEX, DRILLBIT, NORMAL
    isAnticyclonic = false, -- Is this particle anticyclonic (clockwise spinning or not?) (segments it into anticyclonic sublist)
    supportsphases = {"MAIN", "VORTEX-BREAKDOWN", "BIRTH", "DEATH"}, -- Supports multiple flag options : MAIN, BIRTH, DEATH, VORTEX-BREAKDOWN. MAIN is normal tornado activity, birth and death self explanatory, vortex-breakdown has a chance of getting set when tornadoes are multivortex.
    wallcloudColorType = "white", -- wallcloud color Types Available are "white", "black", "brown", only supports one entry.
    behaviorType = "BOTH" -- IS particle "WEAK" COMPATIBLE, "VIOLENT" COMPATIBLE, or "BOTH". Only supports one entry.
})

AddUserParticlesAutospawnXT2({
    name = "5TonyEF418",
    subvortsForParticle = true,
    rangeActivationTiers = {5},-- Tiers are    1 : < 2000,   2: < 3500,   3: < 5000,   4: < 6500,   5: < 8000,   6: < 9500,     7: < 11000,      8: < 12500     9: >12501 -- extremely large...
    supportsparticleTypes = {"NORMAL"}, -- Supports multiple flag options : MULTI-VORTEX, DRILLBIT, NORMAL
    isAnticyclonic = false, -- Is this particle anticyclonic (clockwise spinning or not?) (segments it into anticyclonic sublist)
    supportsphases = {"MAIN"}, -- Supports multiple flag options : MAIN, BIRTH, DEATH, VORTEX-BREAKDOWN. MAIN is normal tornado activity, birth and death self explanatory, vortex-breakdown has a chance of getting set when tornadoes are multivortex.
    wallcloudColorType = "white", -- wallcloud color Types Available are "white", "black", "brown", only supports one entry.
    behaviorType = "VIOLENT" -- IS particle "WEAK" COMPATIBLE, "VIOLENT" COMPATIBLE, or "BOTH". Only supports one entry.
})
AddUserParticlesAutospawnXT2({
    name = "5TonyEF44",
    subvortsForParticle = true,
    rangeActivationTiers = {5, 6},-- Tiers are    1 : < 2000,   2: < 3500,   3: < 5000,   4: < 6500,   5: < 8000,   6: < 9500,     7: < 11000,      8: < 12500     9: >12501 -- extremely large...
    supportsparticleTypes = {"NORMAL"}, -- Supports multiple flag options : MULTI-VORTEX, DRILLBIT, NORMAL
    isAnticyclonic = false, -- Is this particle anticyclonic (clockwise spinning or not?) (segments it into anticyclonic sublist)
    supportsphases = {"MAIN"}, -- Supports multiple flag options : MAIN, BIRTH, DEATH, VORTEX-BREAKDOWN. MAIN is normal tornado activity, birth and death self explanatory, vortex-breakdown has a chance of getting set when tornadoes are multivortex.
    wallcloudColorType = "white", -- wallcloud color Types Available are "white", "black", "brown", only supports one entry.
    behaviorType = "VIOLENT" -- IS particle "WEAK" COMPATIBLE, "VIOLENT" COMPATIBLE, or "BOTH". Only supports one entry.
})
AddUserParticlesAutospawnXT2({
    name = "PGYT_EF_4e",
    subvortsForParticle = true,
    rangeActivationTiers = {5, 6},-- Tiers are    1 : < 2000,   2: < 3500,   3: < 5000,   4: < 6500,   5: < 8000,   6: < 9500,     7: < 11000,      8: < 12500     9: >12501 -- extremely large...
    supportsparticleTypes = {"MULTI-VORTEX"}, -- Supports multiple flag options : MULTI-VORTEX, DRILLBIT, NORMAL
    isAnticyclonic = false, -- Is this particle anticyclonic (clockwise spinning or not?) (segments it into anticyclonic sublist)
    supportsphases = {"MAIN", "VORTEX-BREAKDOWN"}, -- Supports multiple flag options : MAIN, BIRTH, DEATH, VORTEX-BREAKDOWN. MAIN is normal tornado activity, birth and death self explanatory, vortex-breakdown has a chance of getting set when tornadoes are multivortex.
    wallcloudColorType = "white", -- wallcloud color Types Available are "white", "black", "brown", only supports one entry.
    behaviorType = "BOTH" -- IS particle "WEAK" COMPATIBLE, "VIOLENT" COMPATIBLE, or "BOTH". Only supports one entry.
})
AddUserParticlesAutospawnXT2({
    name = "PGYT_EF_5d",
    subvortsForParticle = true,
    rangeActivationTiers = {6, 7},-- Tiers are    1 : < 2000,   2: < 3500,   3: < 5000,   4: < 6500,   5: < 8000,   6: < 9500,     7: < 11000,      8: < 12500     9: >12501 -- extremely large...
    supportsparticleTypes = {"NORMAL"}, -- Supports multiple flag options : MULTI-VORTEX, DRILLBIT, NORMAL
    isAnticyclonic = false, -- Is this particle anticyclonic (clockwise spinning or not?) (segments it into anticyclonic sublist)
    supportsphases = {"MAIN", "BIRTH", "DEATH"}, -- Supports multiple flag options : MAIN, BIRTH, DEATH, VORTEX-BREAKDOWN. MAIN is normal tornado activity, birth and death self explanatory, vortex-breakdown has a chance of getting set when tornadoes are multivortex.
    wallcloudColorType = "white", -- wallcloud color Types Available are "white", "black", "brown", only supports one entry.
    behaviorType = "BOTH" -- IS particle "WEAK" COMPATIBLE, "VIOLENT" COMPATIBLE, or "BOTH". Only supports one entry.
})

-- LARGE MULTIVORTEX TREE FROM OLD VER

AddUserParticlesAutospawnXT2({
    name = "PGYT_EF_0m",
    subvortsForParticle = true,
    rangeActivationTiers = {1, 2, 3},-- Tiers are    1 : < 2000,   2: < 3500,   3: < 5000,   4: < 6500,   5: < 8000,   6: < 9500,     7: < 11000,      8: < 12500     9: >12501 -- extremely large...
    supportsparticleTypes = {"NORMAL", "MULTI-VORTEX"}, -- Supports multiple flag options : MULTI-VORTEX, DRILLBIT, NORMAL
    isAnticyclonic = false, -- Is this particle anticyclonic (clockwise spinning or not?) (segments it into anticyclonic sublist)
    supportsphases = {"MAIN", "VORTEX-BREAKDOWN"}, -- Supports multiple flag options : MAIN, BIRTH, DEATH, VORTEX-BREAKDOWN. MAIN is normal tornado activity, birth and death self explanatory, vortex-breakdown has a chance of getting set when tornadoes are multivortex.
    wallcloudColorType = "white", -- wallcloud color Types Available are "white", "black", "brown", only supports one entry.
    behaviorType = "BOTH" -- IS particle "WEAK" COMPATIBLE, "VIOLENT" COMPATIBLE, or "BOTH". Only supports one entry.
})

AddUserParticlesAutospawnXT2({
    name = "PGYT_EF_0t",
    subvortsForParticle = true,
    rangeActivationTiers = {2, 3},-- Tiers are    1 : < 2000,   2: < 3500,   3: < 5000,   4: < 6500,   5: < 8000,   6: < 9500,     7: < 11000,      8: < 12500     9: >12501 -- extremely large...
    supportsparticleTypes = {"NORMAL", "MULTI-VORTEX"}, -- Supports multiple flag options : MULTI-VORTEX, DRILLBIT, NORMAL
    isAnticyclonic = false, -- Is this particle anticyclonic (clockwise spinning or not?) (segments it into anticyclonic sublist)
    supportsphases = {"MAIN", "VORTEX-BREAKDOWN"}, -- Supports multiple flag options : MAIN, BIRTH, DEATH, VORTEX-BREAKDOWN. MAIN is normal tornado activity, birth and death self explanatory, vortex-breakdown has a chance of getting set when tornadoes are multivortex.
    wallcloudColorType = "white", -- wallcloud color Types Available are "white", "black", "brown", only supports one entry.
    behaviorType = "BOTH" -- IS particle "WEAK" COMPATIBLE, "VIOLENT" COMPATIBLE, or "BOTH". Only supports one entry.
})

AddUserParticlesAutospawnXT2({
    name = "PGYT_EF_0y",
    subvortsForParticle = true,
    rangeActivationTiers = {2, 3},-- Tiers are    1 : < 2000,   2: < 3500,   3: < 5000,   4: < 6500,   5: < 8000,   6: < 9500,     7: < 11000,      8: < 12500     9: >12501 -- extremely large...
    supportsparticleTypes = {"NORMAL", "MULTI-VORTEX"}, -- Supports multiple flag options : MULTI-VORTEX, DRILLBIT, NORMAL
    isAnticyclonic = false, -- Is this particle anticyclonic (clockwise spinning or not?) (segments it into anticyclonic sublist)
    supportsphases = {"MAIN", "VORTEX-BREAKDOWN", "BIRTH", "DEATH"}, -- Supports multiple flag options : MAIN, BIRTH, DEATH, VORTEX-BREAKDOWN. MAIN is normal tornado activity, birth and death self explanatory, vortex-breakdown has a chance of getting set when tornadoes are multivortex.
    wallcloudColorType = "white", -- wallcloud color Types Available are "white", "black", "brown", only supports one entry.
    behaviorType = "WEAK" -- IS particle "WEAK" COMPATIBLE, "VIOLENT" COMPATIBLE, or "BOTH". Only supports one entry.
})

AddUserParticlesAutospawnXT2({
    name = "PGYT_EF_0z",
    subvortsForParticle = true,
    rangeActivationTiers = {2, 3, 4},-- Tiers are    1 : < 2000,   2: < 3500,   3: < 5000,   4: < 6500,   5: < 8000,   6: < 9500,     7: < 11000,      8: < 12500     9: >12501 -- extremely large...
    supportsparticleTypes = {"NORMAL"}, -- Supports multiple flag options : MULTI-VORTEX, DRILLBIT, NORMAL
    isAnticyclonic = false, -- Is this particle anticyclonic (clockwise spinning or not?) (segments it into anticyclonic sublist)
    supportsphases = {"MAIN", "BIRTH", "DEATH"}, -- Supports multiple flag options : MAIN, BIRTH, DEATH, VORTEX-BREAKDOWN. MAIN is normal tornado activity, birth and death self explanatory, vortex-breakdown has a chance of getting set when tornadoes are multivortex.
    wallcloudColorType = "white", -- wallcloud color Types Available are "white", "black", "brown", only supports one entry.
    behaviorType = "WEAK" -- IS particle "WEAK" COMPATIBLE, "VIOLENT" COMPATIBLE, or "BOTH". Only supports one entry.
})

AddUserParticlesAutospawnXT2({
    name = "5TonyEF011",
    subvortsForParticle = true,
    rangeActivationTiers = {2, 3, 4},-- Tiers are    1 : < 2000,   2: < 3500,   3: < 5000,   4: < 6500,   5: < 8000,   6: < 9500,     7: < 11000,      8: < 12500     9: >12501 -- extremely large...
    supportsparticleTypes = {"NORMAL"}, -- Supports multiple flag options : MULTI-VORTEX, DRILLBIT, NORMAL
    isAnticyclonic = false, -- Is this particle anticyclonic (clockwise spinning or not?) (segments it into anticyclonic sublist)
    supportsphases = {"MAIN", "BIRTH", "DEATH"}, -- Supports multiple flag options : MAIN, BIRTH, DEATH, VORTEX-BREAKDOWN. MAIN is normal tornado activity, birth and death self explanatory, vortex-breakdown has a chance of getting set when tornadoes are multivortex.
    wallcloudColorType = "white", -- wallcloud color Types Available are "white", "black", "brown", only supports one entry.
    behaviorType = "WEAK" -- IS particle "WEAK" COMPATIBLE, "VIOLENT" COMPATIBLE, or "BOTH". Only supports one entry.
})

AddUserParticlesAutospawnXT2({
    name = "5TonyEF013",
    subvortsForParticle = true,
    rangeActivationTiers = {2, 3},-- Tiers are    1 : < 2000,   2: < 3500,   3: < 5000,   4: < 6500,   5: < 8000,   6: < 9500,     7: < 11000,      8: < 12500     9: >12501 -- extremely large...
    supportsparticleTypes = {"NORMAL", "MULTI-VORTEX"}, -- Supports multiple flag options : MULTI-VORTEX, DRILLBIT, NORMAL
    isAnticyclonic = false, -- Is this particle anticyclonic (clockwise spinning or not?) (segments it into anticyclonic sublist)
    supportsphases = {"MAIN", "VORTEX-BREAKDOWN", "BIRTH", "DEATH"}, -- Supports multiple flag options : MAIN, BIRTH, DEATH, VORTEX-BREAKDOWN. MAIN is normal tornado activity, birth and death self explanatory, vortex-breakdown has a chance of getting set when tornadoes are multivortex.
    wallcloudColorType = "white", -- wallcloud color Types Available are "white", "black", "brown", only supports one entry.
    behaviorType = "WEAK" -- IS particle "WEAK" COMPATIBLE, "VIOLENT" COMPATIBLE, or "BOTH". Only supports one entry.
})

AddUserParticlesAutospawnXT2({
    name = "PGYT_EF_1t",
    subvortsForParticle = true,
    rangeActivationTiers = {3},-- Tiers are    1 : < 2000,   2: < 3500,   3: < 5000,   4: < 6500,   5: < 8000,   6: < 9500,     7: < 11000,      8: < 12500     9: >12501 -- extremely large...
    supportsparticleTypes = {"NORMAL", "MULTI-VORTEX"}, -- Supports multiple flag options : MULTI-VORTEX, DRILLBIT, NORMAL
    isAnticyclonic = false, -- Is this particle anticyclonic (clockwise spinning or not?) (segments it into anticyclonic sublist)
    supportsphases = {"MAIN", "VORTEX-BREAKDOWN", "BIRTH", "DEATH"}, -- Supports multiple flag options : MAIN, BIRTH, DEATH, VORTEX-BREAKDOWN. MAIN is normal tornado activity, birth and death self explanatory, vortex-breakdown has a chance of getting set when tornadoes are multivortex.
    wallcloudColorType = "white", -- wallcloud color Types Available are "white", "black", "brown", only supports one entry.
    behaviorType = "WEAK" -- IS particle "WEAK" COMPATIBLE, "VIOLENT" COMPATIBLE, or "BOTH". Only supports one entry.
})

AddUserParticlesAutospawnXT2({
    name = "5TonyEF122",
    subvortsForParticle = true,
    rangeActivationTiers = {3, 4},-- Tiers are    1 : < 2000,   2: < 3500,   3: < 5000,   4: < 6500,   5: < 8000,   6: < 9500,     7: < 11000,      8: < 12500     9: >12501 -- extremely large...
    supportsparticleTypes = {"NORMAL", "MULTI-VORTEX"}, -- Supports multiple flag options : MULTI-VORTEX, DRILLBIT, NORMAL
    isAnticyclonic = false, -- Is this particle anticyclonic (clockwise spinning or not?) (segments it into anticyclonic sublist)
    supportsphases = {"MAIN", "VORTEX-BREAKDOWN", "BIRTH", "DEATH"}, -- Supports multiple flag options : MAIN, BIRTH, DEATH, VORTEX-BREAKDOWN. MAIN is normal tornado activity, birth and death self explanatory, vortex-breakdown has a chance of getting set when tornadoes are multivortex.
    wallcloudColorType = "white", -- wallcloud color Types Available are "white", "black", "brown", only supports one entry.
    behaviorType = "BOTH" -- IS particle "WEAK" COMPATIBLE, "VIOLENT" COMPATIBLE, or "BOTH". Only supports one entry.
})

AddUserParticlesAutospawnXT2({
    name = "5TonyEF116",
    subvortsForParticle = true,
    rangeActivationTiers = {3, 4},-- Tiers are    1 : < 2000,   2: < 3500,   3: < 5000,   4: < 6500,   5: < 8000,   6: < 9500,     7: < 11000,      8: < 12500     9: >12501 -- extremely large...
    supportsparticleTypes = {"NORMAL", "MULTI-VORTEX"}, -- Supports multiple flag options : MULTI-VORTEX, DRILLBIT, NORMAL
    isAnticyclonic = false, -- Is this particle anticyclonic (clockwise spinning or not?) (segments it into anticyclonic sublist)
    supportsphases = {"MAIN", "VORTEX-BREAKDOWN", "BIRTH", "DEATH"}, -- Supports multiple flag options : MAIN, BIRTH, DEATH, VORTEX-BREAKDOWN. MAIN is normal tornado activity, birth and death self explanatory, vortex-breakdown has a chance of getting set when tornadoes are multivortex.
    wallcloudColorType = "white", -- wallcloud color Types Available are "white", "black", "brown", only supports one entry.
    behaviorType = "WEAK" -- IS particle "WEAK" COMPATIBLE, "VIOLENT" COMPATIBLE, or "BOTH". Only supports one entry.
})

AddUserParticlesAutospawnXT2({
    name = "5TonyEF14",
    subvortsForParticle = true,
    rangeActivationTiers = {3},-- Tiers are    1 : < 2000,   2: < 3500,   3: < 5000,   4: < 6500,   5: < 8000,   6: < 9500,     7: < 11000,      8: < 12500     9: >12501 -- extremely large...
    supportsparticleTypes = {"NORMAL", "MULTI-VORTEX"}, -- Supports multiple flag options : MULTI-VORTEX, DRILLBIT, NORMAL
    isAnticyclonic = false, -- Is this particle anticyclonic (clockwise spinning or not?) (segments it into anticyclonic sublist)
    supportsphases = {"MAIN", "VORTEX-BREAKDOWN", "BIRTH", "DEATH"}, -- Supports multiple flag options : MAIN, BIRTH, DEATH, VORTEX-BREAKDOWN. MAIN is normal tornado activity, birth and death self explanatory, vortex-breakdown has a chance of getting set when tornadoes are multivortex.
    wallcloudColorType = "white", -- wallcloud color Types Available are "white", "black", "brown", only supports one entry.
    behaviorType = "WEAK" -- IS particle "WEAK" COMPATIBLE, "VIOLENT" COMPATIBLE, or "BOTH". Only supports one entry.
})

AddUserParticlesAutospawnXT2({
    name = "5TonyEF28",
    subvortsForParticle = true,
    rangeActivationTiers = {4, 5},-- Tiers are    1 : < 2000,   2: < 3500,   3: < 5000,   4: < 6500,   5: < 8000,   6: < 9500,     7: < 11000,      8: < 12500     9: >12501 -- extremely large...
    supportsparticleTypes = {"NORMAL", "MULTI-VORTEX"}, -- Supports multiple flag options : MULTI-VORTEX, DRILLBIT, NORMAL
    isAnticyclonic = false, -- Is this particle anticyclonic (clockwise spinning or not?) (segments it into anticyclonic sublist)
    supportsphases = {"MAIN", "VORTEX-BREAKDOWN", "BIRTH", "DEATH"}, -- Supports multiple flag options : MAIN, BIRTH, DEATH, VORTEX-BREAKDOWN. MAIN is normal tornado activity, birth and death self explanatory, vortex-breakdown has a chance of getting set when tornadoes are multivortex.
    wallcloudColorType = "white", -- wallcloud color Types Available are "white", "black", "brown", only supports one entry.
    behaviorType = "BOTH" -- IS particle "WEAK" COMPATIBLE, "VIOLENT" COMPATIBLE, or "BOTH". Only supports one entry.
})

AddUserParticlesAutospawnXT2({
    name = "5TonyEF38",
    subvortsForParticle = true,
    rangeActivationTiers = {5, 6},-- Tiers are    1 : < 2000,   2: < 3500,   3: < 5000,   4: < 6500,   5: < 8000,   6: < 9500,     7: < 11000,      8: < 12500     9: >12501 -- extremely large...
    supportsparticleTypes = {"NORMAL", "MULTI-VORTEX"}, -- Supports multiple flag options : MULTI-VORTEX, DRILLBIT, NORMAL
    isAnticyclonic = false, -- Is this particle anticyclonic (clockwise spinning or not?) (segments it into anticyclonic sublist)
    supportsphases = {"MAIN", "VORTEX-BREAKDOWN", "BIRTH", "DEATH"}, -- Supports multiple flag options : MAIN, BIRTH, DEATH, VORTEX-BREAKDOWN. MAIN is normal tornado activity, birth and death self explanatory, vortex-breakdown has a chance of getting set when tornadoes are multivortex.
    wallcloudColorType = "white", -- wallcloud color Types Available are "white", "black", "brown", only supports one entry.
    behaviorType = "BOTH" -- IS particle "WEAK" COMPATIBLE, "VIOLENT" COMPATIBLE, or "BOTH". Only supports one entry.
})

AddUserParticlesAutospawnXT2({
    name = "5TonyEF417",
    subvortsForParticle = true,
    rangeActivationTiers = {7, 8},-- Tiers are    1 : < 2000,   2: < 3500,   3: < 5000,   4: < 6500,   5: < 8000,   6: < 9500,     7: < 11000,      8: < 12500     9: >12501 -- extremely large...
    supportsparticleTypes = {"NORMAL", "MULTI-VORTEX"}, -- Supports multiple flag options : MULTI-VORTEX, DRILLBIT, NORMAL
    isAnticyclonic = false, -- Is this particle anticyclonic (clockwise spinning or not?) (segments it into anticyclonic sublist)
    supportsphases = {"MAIN", "VORTEX-BREAKDOWN", "BIRTH", "DEATH"}, -- Supports multiple flag options : MAIN, BIRTH, DEATH, VORTEX-BREAKDOWN. MAIN is normal tornado activity, birth and death self explanatory, vortex-breakdown has a chance of getting set when tornadoes are multivortex.
    wallcloudColorType = "white", -- wallcloud color Types Available are "white", "black", "brown", only supports one entry.
    behaviorType = "VTP" -- IS particle "WEAK" COMPATIBLE, "VIOLENT" COMPATIBLE, or "BOTH". Only supports one entry.
})

------------------------------------ DARK GREY / BLACK TORNADOES ---------------------------------------

-- Small 

AddUserParticlesAutospawnXT2({
    name = "PGYT_EF_0k",
    subvortsForParticle = false,
    rangeActivationTiers = {1, 2},-- Tiers are    1 : < 2000,   2: < 3500,   3: < 5000,   4: < 6500,   5: < 8000,   6: < 9500,     7: < 11000,      8: < 12500     9: >12501 -- extremely large...
    supportsparticleTypes = {"NORMAL"}, -- Supports multiple flag options : MULTI-VORTEX, DRILLBIT, NORMAL
    isAnticyclonic = false, -- Is this particle anticyclonic (clockwise spinning or not?) (segments it into anticyclonic sublist)
    supportsphases = {"MAIN"}, -- Supports multiple flag options : MAIN, BIRTH, DEATH, VORTEX-BREAKDOWN. MAIN is normal tornado activity, birth and death self explanatory, vortex-breakdown has a chance of getting set when tornadoes are multivortex.
    wallcloudColorType = "black", -- wallcloud color Types Available are "white", "black", "brown", only supports one entry.
    behaviorType = "BOTH" -- IS particle "WEAK" COMPATIBLE, "VIOLENT" COMPATIBLE, or "BOTH". Only supports one entry.
})

AddUserParticlesAutospawnXT2({
    name = "5TonyEF017",
    subvortsForParticle = false,
    rangeActivationTiers = {1, 2},-- Tiers are    1 : < 2000,   2: < 3500,   3: < 5000,   4: < 6500,   5: < 8000,   6: < 9500,     7: < 11000,      8: < 12500     9: >12501 -- extremely large...
    supportsparticleTypes = {"NORMAL"}, -- Supports multiple flag options : MULTI-VORTEX, DRILLBIT, NORMAL
    isAnticyclonic = false, -- Is this particle anticyclonic (clockwise spinning or not?) (segments it into anticyclonic sublist)
    supportsphases = {"MAIN", "BIRTH", "DEATH"}, -- Supports multiple flag options : MAIN, BIRTH, DEATH, VORTEX-BREAKDOWN. MAIN is normal tornado activity, birth and death self explanatory, vortex-breakdown has a chance of getting set when tornadoes are multivortex.
    wallcloudColorType = "black", -- wallcloud color Types Available are "white", "black", "brown", only supports one entry.
    behaviorType = "WEAK" -- IS particle "WEAK" COMPATIBLE, "VIOLENT" COMPATIBLE, or "BOTH". Only supports one entry.
})

AddUserParticlesAutospawnXT2({
    name = "PGYT_EF_0",
    subvortsForParticle = false,
    rangeActivationTiers = {1, 2},-- Tiers are    1 : < 2000,   2: < 3500,   3: < 5000,   4: < 6500,   5: < 8000,   6: < 9500,     7: < 11000,      8: < 12500     9: >12501 -- extremely large...
    supportsparticleTypes = {"NORMAL"}, -- Supports multiple flag options : MULTI-VORTEX, DRILLBIT, NORMAL
    isAnticyclonic = false, -- Is this particle anticyclonic (clockwise spinning or not?) (segments it into anticyclonic sublist)
    supportsphases = {"MAIN"}, -- Supports multiple flag options : MAIN, BIRTH, DEATH, VORTEX-BREAKDOWN. MAIN is normal tornado activity, birth and death self explanatory, vortex-breakdown has a chance of getting set when tornadoes are multivortex.
    wallcloudColorType = "black", -- wallcloud color Types Available are "white", "black", "brown", only supports one entry.
    behaviorType = "WEAK" -- IS particle "WEAK" COMPATIBLE, "VIOLENT" COMPATIBLE, or "BOTH". Only supports one entry.
})

AddUserParticlesAutospawnXT2({
    name = "PGYT_EF_0u",
    subvortsForParticle = false,
    rangeActivationTiers = {1, 2},-- Tiers are    1 : < 2000,   2: < 3500,   3: < 5000,   4: < 6500,   5: < 8000,   6: < 9500,     7: < 11000,      8: < 12500     9: >12501 -- extremely large...
    supportsparticleTypes = {"NORMAL"}, -- Supports multiple flag options : MULTI-VORTEX, DRILLBIT, NORMAL
    isAnticyclonic = false, -- Is this particle anticyclonic (clockwise spinning or not?) (segments it into anticyclonic sublist)
    supportsphases = {"MAIN"}, -- Supports multiple flag options : MAIN, BIRTH, DEATH, VORTEX-BREAKDOWN. MAIN is normal tornado activity, birth and death self explanatory, vortex-breakdown has a chance of getting set when tornadoes are multivortex.
    wallcloudColorType = "black", -- wallcloud color Types Available are "white", "black", "brown", only supports one entry.
    behaviorType = "BOTH" -- IS particle "WEAK" COMPATIBLE, "VIOLENT" COMPATIBLE, or "BOTH". Only supports one entry.
})

AddUserParticlesAutospawnXT2({
    name = "Twister_EF1",
    subvortsForParticle = false,
    rangeActivationTiers = {2, 3},-- Tiers are    1 : < 2000,   2: < 3500,   3: < 5000,   4: < 6500,   5: < 8000,   6: < 9500,     7: < 11000,      8: < 12500     9: >12501 -- extremely large...
    supportsparticleTypes = {"NORMAL"}, -- Supports multiple flag options : MULTI-VORTEX, DRILLBIT, NORMAL
    isAnticyclonic = false, -- Is this particle anticyclonic (clockwise spinning or not?) (segments it into anticyclonic sublist)
    supportsphases = {"MAIN", "BIRTH", "DEATH"}, -- Supports multiple flag options : MAIN, BIRTH, DEATH, VORTEX-BREAKDOWN. MAIN is normal tornado activity, birth and death self explanatory, vortex-breakdown has a chance of getting set when tornadoes are multivortex.
    wallcloudColorType = "black", -- wallcloud color Types Available are "white", "black", "brown", only supports one entry.
    behaviorType = "WEAK" -- IS particle "WEAK" COMPATIBLE, "VIOLENT" COMPATIBLE, or "BOTH". Only supports one entry.
})

AddUserParticlesAutospawnXT2({
    name = "5TonyEF1",
    subvortsForParticle = false,
    rangeActivationTiers = {2, 3},-- Tiers are    1 : < 2000,   2: < 3500,   3: < 5000,   4: < 6500,   5: < 8000,   6: < 9500,     7: < 11000,      8: < 12500     9: >12501 -- extremely large...
    supportsparticleTypes = {"NORMAL"}, -- Supports multiple flag options : MULTI-VORTEX, DRILLBIT, NORMAL
    isAnticyclonic = false, -- Is this particle anticyclonic (clockwise spinning or not?) (segments it into anticyclonic sublist)
    supportsphases = {"MAIN"}, -- Supports multiple flag options : MAIN, BIRTH, DEATH, VORTEX-BREAKDOWN. MAIN is normal tornado activity, birth and death self explanatory, vortex-breakdown has a chance of getting set when tornadoes are multivortex.
    wallcloudColorType = "black", -- wallcloud color Types Available are "white", "black", "brown", only supports one entry.
    behaviorType = "WEAK" -- IS particle "WEAK" COMPATIBLE, "VIOLENT" COMPATIBLE, or "BOTH". Only supports one entry.
})

AddUserParticlesAutospawnXT2({
    name = "5TonyEF118",
    subvortsForParticle = false,
    rangeActivationTiers = {2, 3},-- Tiers are    1 : < 2000,   2: < 3500,   3: < 5000,   4: < 6500,   5: < 8000,   6: < 9500,     7: < 11000,      8: < 12500     9: >12501 -- extremely large...
    supportsparticleTypes = {"NORMAL"}, -- Supports multiple flag options : MULTI-VORTEX, DRILLBIT, NORMAL
    isAnticyclonic = false, -- Is this particle anticyclonic (clockwise spinning or not?) (segments it into anticyclonic sublist)
    supportsphases = {"MAIN", "BIRTH", "DEATH"}, -- Supports multiple flag options : MAIN, BIRTH, DEATH, VORTEX-BREAKDOWN. MAIN is normal tornado activity, birth and death self explanatory, vortex-breakdown has a chance of getting set when tornadoes are multivortex.
    wallcloudColorType = "black", -- wallcloud color Types Available are "white", "black", "brown", only supports one entry.
    behaviorType = "WEAK" -- IS particle "WEAK" COMPATIBLE, "VIOLENT" COMPATIBLE, or "BOTH". Only supports one entry.
})

AddUserParticlesAutospawnXT2({
    name = "PGYT_EF_1o",
    subvortsForParticle = false,
    rangeActivationTiers = {2, 3},-- Tiers are    1 : < 2000,   2: < 3500,   3: < 5000,   4: < 6500,   5: < 8000,   6: < 9500,     7: < 11000,      8: < 12500     9: >12501 -- extremely large...
    supportsparticleTypes = {"NORMAL"}, -- Supports multiple flag options : MULTI-VORTEX, DRILLBIT, NORMAL
    isAnticyclonic = false, -- Is this particle anticyclonic (clockwise spinning or not?) (segments it into anticyclonic sublist)
    supportsphases = {"MAIN"}, -- Supports multiple flag options : MAIN, BIRTH, DEATH, VORTEX-BREAKDOWN. MAIN is normal tornado activity, birth and death self explanatory, vortex-breakdown has a chance of getting set when tornadoes are multivortex.
    wallcloudColorType = "black", -- wallcloud color Types Available are "white", "black", "brown", only supports one entry.
    behaviorType = "BOTH" -- IS particle "WEAK" COMPATIBLE, "VIOLENT" COMPATIBLE, or "BOTH". Only supports one entry.
})

AddUserParticlesAutospawnXT2({
    name = "PGYT_EF_1u",
    subvortsForParticle = false,
    rangeActivationTiers = {2, 3},-- Tiers are    1 : < 2000,   2: < 3500,   3: < 5000,   4: < 6500,   5: < 8000,   6: < 9500,     7: < 11000,      8: < 12500     9: >12501 -- extremely large...
    supportsparticleTypes = {"NORMAL"}, -- Supports multiple flag options : MULTI-VORTEX, DRILLBIT, NORMAL
    isAnticyclonic = false, -- Is this particle anticyclonic (clockwise spinning or not?) (segments it into anticyclonic sublist)
    supportsphases = {"MAIN"}, -- Supports multiple flag options : MAIN, BIRTH, DEATH, VORTEX-BREAKDOWN. MAIN is normal tornado activity, birth and death self explanatory, vortex-breakdown has a chance of getting set when tornadoes are multivortex.
    wallcloudColorType = "black", -- wallcloud color Types Available are "white", "black", "brown", only supports one entry.
    behaviorType = "WEAK" -- IS particle "WEAK" COMPATIBLE, "VIOLENT" COMPATIBLE, or "BOTH". Only supports one entry.
})

AddUserParticlesAutospawnXT2({
    name = "5TonyEF121",
    subvortsForParticle = false,
    rangeActivationTiers = {1, 2, 3},-- Tiers are    1 : < 2000,   2: < 3500,   3: < 5000,   4: < 6500,   5: < 8000,   6: < 9500,     7: < 11000,      8: < 12500     9: >12501 -- extremely large...
    supportsparticleTypes = {"NORMAL", "BIRTH", "DEATH"}, -- Supports multiple flag options : MULTI-VORTEX, DRILLBIT, NORMAL
    isAnticyclonic = false, -- Is this particle anticyclonic (clockwise spinning or not?) (segments it into anticyclonic sublist)
    supportsphases = {"MAIN"}, -- Supports multiple flag options : MAIN, BIRTH, DEATH, VORTEX-BREAKDOWN. MAIN is normal tornado activity, birth and death self explanatory, vortex-breakdown has a chance of getting set when tornadoes are multivortex.
    wallcloudColorType = "black", -- wallcloud color Types Available are "white", "black", "brown", only supports one entry.
    behaviorType = "BOTH" -- IS particle "WEAK" COMPATIBLE, "VIOLENT" COMPATIBLE, or "BOTH". Only supports one entry.
})

AddUserParticlesAutospawnXT2({
    name = "5TonyEF112",
    subvortsForParticle = false,
    rangeActivationTiers = {2, 3},-- Tiers are    1 : < 2000,   2: < 3500,   3: < 5000,   4: < 6500,   5: < 8000,   6: < 9500,     7: < 11000,      8: < 12500     9: >12501 -- extremely large...
    supportsparticleTypes = {"NORMAL"}, -- Supports multiple flag options : MULTI-VORTEX, DRILLBIT, NORMAL
    isAnticyclonic = false, -- Is this particle anticyclonic (clockwise spinning or not?) (segments it into anticyclonic sublist)
    supportsphases = {"MAIN"}, -- Supports multiple flag options : MAIN, BIRTH, DEATH, VORTEX-BREAKDOWN. MAIN is normal tornado activity, birth and death self explanatory, vortex-breakdown has a chance of getting set when tornadoes are multivortex.
    wallcloudColorType = "black", -- wallcloud color Types Available are "white", "black", "brown", only supports one entry.
    behaviorType = "WEAK" -- IS particle "WEAK" COMPATIBLE, "VIOLENT" COMPATIBLE, or "BOTH". Only supports one entry.
})

AddUserParticlesAutospawnXT2({
    name = "5TonyEF114",
    subvortsForParticle = false,
    rangeActivationTiers = {2, 3},-- Tiers are    1 : < 2000,   2: < 3500,   3: < 5000,   4: < 6500,   5: < 8000,   6: < 9500,     7: < 11000,      8: < 12500     9: >12501 -- extremely large...
    supportsparticleTypes = {"NORMAL"}, -- Supports multiple flag options : MULTI-VORTEX, DRILLBIT, NORMAL
    isAnticyclonic = false, -- Is this particle anticyclonic (clockwise spinning or not?) (segments it into anticyclonic sublist)
    supportsphases = {"MAIN"}, -- Supports multiple flag options : MAIN, BIRTH, DEATH, VORTEX-BREAKDOWN. MAIN is normal tornado activity, birth and death self explanatory, vortex-breakdown has a chance of getting set when tornadoes are multivortex.
    wallcloudColorType = "black", -- wallcloud color Types Available are "white", "black", "brown", only supports one entry.
    behaviorType = "WEAK" -- IS particle "WEAK" COMPATIBLE, "VIOLENT" COMPATIBLE, or "BOTH". Only supports one entry.
})

AddUserParticlesAutospawnXT2({
    name = "PGYT_EF_1j",
    subvortsForParticle = false,
    rangeActivationTiers = {2, 3},-- Tiers are    1 : < 2000,   2: < 3500,   3: < 5000,   4: < 6500,   5: < 8000,   6: < 9500,     7: < 11000,      8: < 12500     9: >12501 -- extremely large...
    supportsparticleTypes = {"NORMAL"}, -- Supports multiple flag options : MULTI-VORTEX, DRILLBIT, NORMAL
    isAnticyclonic = false, -- Is this particle anticyclonic (clockwise spinning or not?) (segments it into anticyclonic sublist)
    supportsphases = {"MAIN"}, -- Supports multiple flag options : MAIN, BIRTH, DEATH, VORTEX-BREAKDOWN. MAIN is normal tornado activity, birth and death self explanatory, vortex-breakdown has a chance of getting set when tornadoes are multivortex.
    wallcloudColorType = "black", -- wallcloud color Types Available are "white", "black", "brown", only supports one entry.
    behaviorType = "BOTH" -- IS particle "WEAK" COMPATIBLE, "VIOLENT" COMPATIBLE, or "BOTH". Only supports one entry.
})

AddUserParticlesAutospawnXT2({
    name = "5TonyEF115",
    subvortsForParticle = false,
    rangeActivationTiers = {1, 2, 3},-- Tiers are    1 : < 2000,   2: < 3500,   3: < 5000,   4: < 6500,   5: < 8000,   6: < 9500,     7: < 11000,      8: < 12500     9: >12501 -- extremely large...
    supportsparticleTypes = {"NORMAL"}, -- Supports multiple flag options : MULTI-VORTEX, DRILLBIT, NORMAL
    isAnticyclonic = false, -- Is this particle anticyclonic (clockwise spinning or not?) (segments it into anticyclonic sublist)
    supportsphases = {"MAIN", "BIRTH", "DEATH"}, -- Supports multiple flag options : MAIN, BIRTH, DEATH, VORTEX-BREAKDOWN. MAIN is normal tornado activity, birth and death self explanatory, vortex-breakdown has a chance of getting set when tornadoes are multivortex.
    wallcloudColorType = "black", -- wallcloud color Types Available are "white", "black", "brown", only supports one entry.
    behaviorType = "WEAK" -- IS particle "WEAK" COMPATIBLE, "VIOLENT" COMPATIBLE, or "BOTH". Only supports one entry.
})

AddUserParticlesAutospawnXT2({
    name = "5TonyEF18",
    subvortsForParticle = false,
    rangeActivationTiers = {2, 3},-- Tiers are    1 : < 2000,   2: < 3500,   3: < 5000,   4: < 6500,   5: < 8000,   6: < 9500,     7: < 11000,      8: < 12500     9: >12501 -- extremely large...
    supportsparticleTypes = {"NORMAL"}, -- Supports multiple flag options : MULTI-VORTEX, DRILLBIT, NORMAL
    isAnticyclonic = false, -- Is this particle anticyclonic (clockwise spinning or not?) (segments it into anticyclonic sublist)
    supportsphases = {"MAIN", "BIRTH", "DEATH"}, -- Supports multiple flag options : MAIN, BIRTH, DEATH, VORTEX-BREAKDOWN. MAIN is normal tornado activity, birth and death self explanatory, vortex-breakdown has a chance of getting set when tornadoes are multivortex.
    wallcloudColorType = "black", -- wallcloud color Types Available are "white", "black", "brown", only supports one entry.
    behaviorType = "WEAK" -- IS particle "WEAK" COMPATIBLE, "VIOLENT" COMPATIBLE, or "BOTH". Only supports one entry.
})

AddUserParticlesAutospawnXT2({
    name = "PGYT_EF_1o",
    subvortsForParticle = false,
    rangeActivationTiers = {2, 3},-- Tiers are    1 : < 2000,   2: < 3500,   3: < 5000,   4: < 6500,   5: < 8000,   6: < 9500,     7: < 11000,      8: < 12500     9: >12501 -- extremely large...
    supportsparticleTypes = {"NORMAL"}, -- Supports multiple flag options : MULTI-VORTEX, DRILLBIT, NORMAL
    isAnticyclonic = false, -- Is this particle anticyclonic (clockwise spinning or not?) (segments it into anticyclonic sublist)
    supportsphases = {"MAIN"}, -- Supports multiple flag options : MAIN, BIRTH, DEATH, VORTEX-BREAKDOWN. MAIN is normal tornado activity, birth and death self explanatory, vortex-breakdown has a chance of getting set when tornadoes are multivortex.
    wallcloudColorType = "black", -- wallcloud color Types Available are "white", "black", "brown", only supports one entry.
    behaviorType = "WEAK" -- IS particle "WEAK" COMPATIBLE, "VIOLENT" COMPATIBLE, or "BOTH". Only supports one entry.
})

AddUserParticlesAutospawnXT2({
    name = "5TonyEF211",
    subvortsForParticle = false,
    rangeActivationTiers = {1, 2, 3},-- Tiers are    1 : < 2000,   2: < 3500,   3: < 5000,   4: < 6500,   5: < 8000,   6: < 9500,     7: < 11000,      8: < 12500     9: >12501 -- extremely large...
    supportsparticleTypes = {"NORMAL"}, -- Supports multiple flag options : MULTI-VORTEX, DRILLBIT, NORMAL
    isAnticyclonic = false, -- Is this particle anticyclonic (clockwise spinning or not?) (segments it into anticyclonic sublist)
    supportsphases = {"MAIN"}, -- Supports multiple flag options : MAIN, BIRTH, DEATH, VORTEX-BREAKDOWN. MAIN is normal tornado activity, birth and death self explanatory, vortex-breakdown has a chance of getting set when tornadoes are multivortex.
    wallcloudColorType = "black", -- wallcloud color Types Available are "white", "black", "brown", only supports one entry.
    behaviorType = "BOTH" -- IS particle "WEAK" COMPATIBLE, "VIOLENT" COMPATIBLE, or "BOTH". Only supports one entry.
})

AddUserParticlesAutospawnXT2({
    name = "PGYT_EF_2",
    subvortsForParticle = false,
    rangeActivationTiers = {2, 3},-- Tiers are    1 : < 2000,   2: < 3500,   3: < 5000,   4: < 6500,   5: < 8000,   6: < 9500,     7: < 11000,      8: < 12500     9: >12501 -- extremely large...
    supportsparticleTypes = {"NORMAL"}, -- Supports multiple flag options : MULTI-VORTEX, DRILLBIT, NORMAL
    isAnticyclonic = false, -- Is this particle anticyclonic (clockwise spinning or not?) (segments it into anticyclonic sublist)
    supportsphases = {"MAIN"}, -- Supports multiple flag options : MAIN, BIRTH, DEATH, VORTEX-BREAKDOWN. MAIN is normal tornado activity, birth and death self explanatory, vortex-breakdown has a chance of getting set when tornadoes are multivortex.
    wallcloudColorType = "black", -- wallcloud color Types Available are "white", "black", "brown", only supports one entry.
    behaviorType = "BOTH" -- IS particle "WEAK" COMPATIBLE, "VIOLENT" COMPATIBLE, or "BOTH". Only supports one entry.
})

AddUserParticlesAutospawnXT2({
    name = "PGYT_EF_2n",
    subvortsForParticle = false,
    rangeActivationTiers = {3, 4},-- Tiers are    1 : < 2000,   2: < 3500,   3: < 5000,   4: < 6500,   5: < 8000,   6: < 9500,     7: < 11000,      8: < 12500     9: >12501 -- extremely large...
    supportsparticleTypes = {"NORMAL"}, -- Supports multiple flag options : MULTI-VORTEX, DRILLBIT, NORMAL
    isAnticyclonic = false, -- Is this particle anticyclonic (clockwise spinning or not?) (segments it into anticyclonic sublist)
    supportsphases = {"MAIN"}, -- Supports multiple flag options : MAIN, BIRTH, DEATH, VORTEX-BREAKDOWN. MAIN is normal tornado activity, birth and death self explanatory, vortex-breakdown has a chance of getting set when tornadoes are multivortex.
    wallcloudColorType = "black", -- wallcloud color Types Available are "white", "black", "brown", only supports one entry.
    behaviorType = "BOTH" -- IS particle "WEAK" COMPATIBLE, "VIOLENT" COMPATIBLE, or "BOTH". Only supports one entry.
})

AddUserParticlesAutospawnXT2({
    name = "PGYT_EF_2r",
    subvortsForParticle = false,
    rangeActivationTiers = {2, 3},-- Tiers are    1 : < 2000,   2: < 3500,   3: < 5000,   4: < 6500,   5: < 8000,   6: < 9500,     7: < 11000,      8: < 12500     9: >12501 -- extremely large...
    supportsparticleTypes = {"NORMAL"}, -- Supports multiple flag options : MULTI-VORTEX, DRILLBIT, NORMAL
    isAnticyclonic = false, -- Is this particle anticyclonic (clockwise spinning or not?) (segments it into anticyclonic sublist)
    supportsphases = {"MAIN"}, -- Supports multiple flag options : MAIN, BIRTH, DEATH, VORTEX-BREAKDOWN. MAIN is normal tornado activity, birth and death self explanatory, vortex-breakdown has a chance of getting set when tornadoes are multivortex.
    wallcloudColorType = "black", -- wallcloud color Types Available are "white", "black", "brown", only supports one entry.
    behaviorType = "WEAK" -- IS particle "WEAK" COMPATIBLE, "VIOLENT" COMPATIBLE, or "BOTH". Only supports one entry.
})

AddUserParticlesAutospawnXT2({
    name = "PGYT_EF_2h",
    subvortsForParticle = false,
    rangeActivationTiers = {2, 3},-- Tiers are    1 : < 2000,   2: < 3500,   3: < 5000,   4: < 6500,   5: < 8000,   6: < 9500,     7: < 11000,      8: < 12500     9: >12501 -- extremely large...
    supportsparticleTypes = {"NORMAL"}, -- Supports multiple flag options : MULTI-VORTEX, DRILLBIT, NORMAL
    isAnticyclonic = false, -- Is this particle anticyclonic (clockwise spinning or not?) (segments it into anticyclonic sublist)
    supportsphases = {"MAIN"}, -- Supports multiple flag options : MAIN, BIRTH, DEATH, VORTEX-BREAKDOWN. MAIN is normal tornado activity, birth and death self explanatory, vortex-breakdown has a chance of getting set when tornadoes are multivortex.
    wallcloudColorType = "black", -- wallcloud color Types Available are "white", "black", "brown", only supports one entry.
    behaviorType = "BOTH" -- IS particle "WEAK" COMPATIBLE, "VIOLENT" COMPATIBLE, or "BOTH". Only supports one entry.
})

AddUserParticlesAutospawnXT2({
    name = "PGYT_EF_2i",
    subvortsForParticle = false,
    rangeActivationTiers = {2, 3},-- Tiers are    1 : < 2000,   2: < 3500,   3: < 5000,   4: < 6500,   5: < 8000,   6: < 9500,     7: < 11000,      8: < 12500     9: >12501 -- extremely large...
    supportsparticleTypes = {"NORMAL"}, -- Supports multiple flag options : MULTI-VORTEX, DRILLBIT, NORMAL
    isAnticyclonic = false, -- Is this particle anticyclonic (clockwise spinning or not?) (segments it into anticyclonic sublist)
    supportsphases = {"MAIN", "BIRTH", "DEATH"}, -- Supports multiple flag options : MAIN, BIRTH, DEATH, VORTEX-BREAKDOWN. MAIN is normal tornado activity, birth and death self explanatory, vortex-breakdown has a chance of getting set when tornadoes are multivortex.
    wallcloudColorType = "black", -- wallcloud color Types Available are "white", "black", "brown", only supports one entry.
    behaviorType = "BOTH" -- IS particle "WEAK" COMPATIBLE, "VIOLENT" COMPATIBLE, or "BOTH". Only supports one entry.
})

AddUserParticlesAutospawnXT2({
    name = "PGYT_EF_2c",
    subvortsForParticle = false,
    rangeActivationTiers = {2, 3},-- Tiers are    1 : < 2000,   2: < 3500,   3: < 5000,   4: < 6500,   5: < 8000,   6: < 9500,     7: < 11000,      8: < 12500     9: >12501 -- extremely large...
    supportsparticleTypes = {"NORMAL"}, -- Supports multiple flag options : MULTI-VORTEX, DRILLBIT, NORMAL
    isAnticyclonic = false, -- Is this particle anticyclonic (clockwise spinning or not?) (segments it into anticyclonic sublist)
    supportsphases = {"MAIN"}, -- Supports multiple flag options : MAIN, BIRTH, DEATH, VORTEX-BREAKDOWN. MAIN is normal tornado activity, birth and death self explanatory, vortex-breakdown has a chance of getting set when tornadoes are multivortex.
    wallcloudColorType = "black", -- wallcloud color Types Available are "white", "black", "brown", only supports one entry.
    behaviorType = "WEAK" -- IS particle "WEAK" COMPATIBLE, "VIOLENT" COMPATIBLE, or "BOTH". Only supports one entry.
})

AddUserParticlesAutospawnXT2({
    name = "5TonyEF24",
    subvortsForParticle = false,
    rangeActivationTiers = {2, 3},-- Tiers are    1 : < 2000,   2: < 3500,   3: < 5000,   4: < 6500,   5: < 8000,   6: < 9500,     7: < 11000,      8: < 12500     9: >12501 -- extremely large...
    supportsparticleTypes = {"NORMAL"}, -- Supports multiple flag options : MULTI-VORTEX, DRILLBIT, NORMAL
    isAnticyclonic = false, -- Is this particle anticyclonic (clockwise spinning or not?) (segments it into anticyclonic sublist)
    supportsphases = {"MAIN"}, -- Supports multiple flag options : MAIN, BIRTH, DEATH, VORTEX-BREAKDOWN. MAIN is normal tornado activity, birth and death self explanatory, vortex-breakdown has a chance of getting set when tornadoes are multivortex.
    wallcloudColorType = "black", -- wallcloud color Types Available are "white", "black", "brown", only supports one entry.
    behaviorType = "BOTH" -- IS particle "WEAK" COMPATIBLE, "VIOLENT" COMPATIBLE, or "BOTH". Only supports one entry.
})

AddUserParticlesAutospawnXT2({
    name = "Twister_EF3",
    subvortsForParticle = false,
    rangeActivationTiers = {2, 3, 4},-- Tiers are    1 : < 2000,   2: < 3500,   3: < 5000,   4: < 6500,   5: < 8000,   6: < 9500,     7: < 11000,      8: < 12500     9: >12501 -- extremely large...
    supportsparticleTypes = {"NORMAL"}, -- Supports multiple flag options : MULTI-VORTEX, DRILLBIT, NORMAL
    isAnticyclonic = false, -- Is this particle anticyclonic (clockwise spinning or not?) (segments it into anticyclonic sublist)
    supportsphases = {"MAIN"}, -- Supports multiple flag options : MAIN, BIRTH, DEATH, VORTEX-BREAKDOWN. MAIN is normal tornado activity, birth and death self explanatory, vortex-breakdown has a chance of getting set when tornadoes are multivortex.
    wallcloudColorType = "black", -- wallcloud color Types Available are "white", "black", "brown", only supports one entry.
    behaviorType = "BOTH" -- IS particle "WEAK" COMPATIBLE, "VIOLENT" COMPATIBLE, or "BOTH". Only supports one entry.
})

AddUserParticlesAutospawnXT2({
    name = "5TonyEF3",
    subvortsForParticle = false,
    rangeActivationTiers = {3, 4, 5},-- Tiers are    1 : < 2000,   2: < 3500,   3: < 5000,   4: < 6500,   5: < 8000,   6: < 9500,     7: < 11000,      8: < 12500     9: >12501 -- extremely large...
    supportsparticleTypes = {"NORMAL"}, -- Supports multiple flag options : MULTI-VORTEX, DRILLBIT, NORMAL
    isAnticyclonic = false, -- Is this particle anticyclonic (clockwise spinning or not?) (segments it into anticyclonic sublist)
    supportsphases = {"MAIN"}, -- Supports multiple flag options : MAIN, BIRTH, DEATH, VORTEX-BREAKDOWN. MAIN is normal tornado activity, birth and death self explanatory, vortex-breakdown has a chance of getting set when tornadoes are multivortex.
    wallcloudColorType = "black", -- wallcloud color Types Available are "white", "black", "brown", only supports one entry.
    behaviorType = "BOTH" -- IS particle "WEAK" COMPATIBLE, "VIOLENT" COMPATIBLE, or "BOTH". Only supports one entry.
})

AddUserParticlesAutospawnXT2({
    name = "5TonyEF322",
    subvortsForParticle = false,
    rangeActivationTiers = {2, 3, 4},-- Tiers are    1 : < 2000,   2: < 3500,   3: < 5000,   4: < 6500,   5: < 8000,   6: < 9500,     7: < 11000,      8: < 12500     9: >12501 -- extremely large...
    supportsparticleTypes = {"NORMAL"}, -- Supports multiple flag options : MULTI-VORTEX, DRILLBIT, NORMAL
    isAnticyclonic = false, -- Is this particle anticyclonic (clockwise spinning or not?) (segments it into anticyclonic sublist)
    supportsphases = {"MAIN"}, -- Supports multiple flag options : MAIN, BIRTH, DEATH, VORTEX-BREAKDOWN. MAIN is normal tornado activity, birth and death self explanatory, vortex-breakdown has a chance of getting set when tornadoes are multivortex.
    wallcloudColorType = "black", -- wallcloud color Types Available are "white", "black", "brown", only supports one entry.
    behaviorType = "BOTH" -- IS particle "WEAK" COMPATIBLE, "VIOLENT" COMPATIBLE, or "BOTH". Only supports one entry.
})

AddUserParticlesAutospawnXT2({
    name = "5TonyEF310",
    subvortsForParticle = false,
    rangeActivationTiers = {2, 3},-- Tiers are    1 : < 2000,   2: < 3500,   3: < 5000,   4: < 6500,   5: < 8000,   6: < 9500,     7: < 11000,      8: < 12500     9: >12501 -- extremely large...
    supportsparticleTypes = {"NORMAL"}, -- Supports multiple flag options : MULTI-VORTEX, DRILLBIT, NORMAL
    isAnticyclonic = false, -- Is this particle anticyclonic (clockwise spinning or not?) (segments it into anticyclonic sublist)
    supportsphases = {"MAIN"}, -- Supports multiple flag options : MAIN, BIRTH, DEATH, VORTEX-BREAKDOWN. MAIN is normal tornado activity, birth and death self explanatory, vortex-breakdown has a chance of getting set when tornadoes are multivortex.
    wallcloudColorType = "black", -- wallcloud color Types Available are "white", "black", "brown", only supports one entry.
    behaviorType = "WEAK" -- IS particle "WEAK" COMPATIBLE, "VIOLENT" COMPATIBLE, or "BOTH". Only supports one entry.
})

AddUserParticlesAutospawnXT2({
    name = "Twister_EF4",
    subvortsForParticle = false,
    rangeActivationTiers = {3, 4, 5},-- Tiers are    1 : < 2000,   2: < 3500,   3: < 5000,   4: < 6500,   5: < 8000,   6: < 9500,     7: < 11000,      8: < 12500     9: >12501 -- extremely large...
    supportsparticleTypes = {"NORMAL"}, -- Supports multiple flag options : MULTI-VORTEX, DRILLBIT, NORMAL
    isAnticyclonic = false, -- Is this particle anticyclonic (clockwise spinning or not?) (segments it into anticyclonic sublist)
    supportsphases = {"MAIN"}, -- Supports multiple flag options : MAIN, BIRTH, DEATH, VORTEX-BREAKDOWN. MAIN is normal tornado activity, birth and death self explanatory, vortex-breakdown has a chance of getting set when tornadoes are multivortex.
    wallcloudColorType = "black", -- wallcloud color Types Available are "white", "black", "brown", only supports one entry.
    behaviorType = "BOTH" -- IS particle "WEAK" COMPATIBLE, "VIOLENT" COMPATIBLE, or "BOTH". Only supports one entry.
})

AddUserParticlesAutospawnXT2({
    name = "5TonyEF411",
    subvortsForParticle = false,
    rangeActivationTiers = {4, 5},-- Tiers are    1 : < 2000,   2: < 3500,   3: < 5000,   4: < 6500,   5: < 8000,   6: < 9500,     7: < 11000,      8: < 12500     9: >12501 -- extremely large...
    supportsparticleTypes = {"NORMAL"}, -- Supports multiple flag options : MULTI-VORTEX, DRILLBIT, NORMAL
    isAnticyclonic = false, -- Is this particle anticyclonic (clockwise spinning or not?) (segments it into anticyclonic sublist)
    supportsphases = {"MAIN"}, -- Supports multiple flag options : MAIN, BIRTH, DEATH, VORTEX-BREAKDOWN. MAIN is normal tornado activity, birth and death self explanatory, vortex-breakdown has a chance of getting set when tornadoes are multivortex.
    wallcloudColorType = "black", -- wallcloud color Types Available are "white", "black", "brown", only supports one entry.
    behaviorType = "BOTH" -- IS particle "WEAK" COMPATIBLE, "VIOLENT" COMPATIBLE, or "BOTH". Only supports one entry.
})

AddUserParticlesAutospawnXT2({
    name = "PGYT_EF_4d",
    subvortsForParticle = false,
    rangeActivationTiers = {4, 5, 6},-- Tiers are    1 : < 2000,   2: < 3500,   3: < 5000,   4: < 6500,   5: < 8000,   6: < 9500,     7: < 11000,      8: < 12500     9: >12501 -- extremely large...
    supportsparticleTypes = {"NORMAL"}, -- Supports multiple flag options : MULTI-VORTEX, DRILLBIT, NORMAL
    isAnticyclonic = false, -- Is this particle anticyclonic (clockwise spinning or not?) (segments it into anticyclonic sublist)
    supportsphases = {"MAIN"}, -- Supports multiple flag options : MAIN, BIRTH, DEATH, VORTEX-BREAKDOWN. MAIN is normal tornado activity, birth and death self explanatory, vortex-breakdown has a chance of getting set when tornadoes are multivortex.
    wallcloudColorType = "black", -- wallcloud color Types Available are "white", "black", "brown", only supports one entry.
    behaviorType = "BOTH" -- IS particle "WEAK" COMPATIBLE, "VIOLENT" COMPATIBLE, or "BOTH". Only supports one entry.
})

AddUserParticlesAutospawnXT2({
    name = "5TonyEF421",
    subvortsForParticle = false,
    rangeActivationTiers = {4, 5},-- Tiers are    1 : < 2000,   2: < 3500,   3: < 5000,   4: < 6500,   5: < 8000,   6: < 9500,     7: < 11000,      8: < 12500     9: >12501 -- extremely large...
    supportsparticleTypes = {"NORMAL"}, -- Supports multiple flag options : MULTI-VORTEX, DRILLBIT, NORMAL
    isAnticyclonic = false, -- Is this particle anticyclonic (clockwise spinning or not?) (segments it into anticyclonic sublist)
    supportsphases = {"MAIN"}, -- Supports multiple flag options : MAIN, BIRTH, DEATH, VORTEX-BREAKDOWN. MAIN is normal tornado activity, birth and death self explanatory, vortex-breakdown has a chance of getting set when tornadoes are multivortex.
    wallcloudColorType = "black", -- wallcloud color Types Available are "white", "black", "brown", only supports one entry.
    behaviorType = "VIOLENT" -- IS particle "WEAK" COMPATIBLE, "VIOLENT" COMPATIBLE, or "BOTH". Only supports one entry.
})

AddUserParticlesAutospawnXT2({
    name = "PGYT_EF_4b",
    subvortsForParticle = false,
    rangeActivationTiers = {4, 5, 6},-- Tiers are    1 : < 2000,   2: < 3500,   3: < 5000,   4: < 6500,   5: < 8000,   6: < 9500,     7: < 11000,      8: < 12500     9: >12501 -- extremely large...
    supportsparticleTypes = {"NORMAL"}, -- Supports multiple flag options : MULTI-VORTEX, DRILLBIT, NORMAL
    isAnticyclonic = false, -- Is this particle anticyclonic (clockwise spinning or not?) (segments it into anticyclonic sublist)
    supportsphases = {"MAIN"}, -- Supports multiple flag options : MAIN, BIRTH, DEATH, VORTEX-BREAKDOWN. MAIN is normal tornado activity, birth and death self explanatory, vortex-breakdown has a chance of getting set when tornadoes are multivortex.
    wallcloudColorType = "black", -- wallcloud color Types Available are "white", "black", "brown", only supports one entry.
    behaviorType = "BOTH" -- IS particle "WEAK" COMPATIBLE, "VIOLENT" COMPATIBLE, or "BOTH". Only supports one entry.
})

AddUserParticlesAutospawnXT2({
    name = "5TonyEF516",
    subvortsForParticle = false,
    rangeActivationTiers = {4, 5, 6},-- Tiers are    1 : < 2000,   2: < 3500,   3: < 5000,   4: < 6500,   5: < 8000,   6: < 9500,     7: < 11000,      8: < 12500     9: >12501 -- extremely large...
    supportsparticleTypes = {"NORMAL"}, -- Supports multiple flag options : MULTI-VORTEX, DRILLBIT, NORMAL
    isAnticyclonic = false, -- Is this particle anticyclonic (clockwise spinning or not?) (segments it into anticyclonic sublist)
    supportsphases = {"MAIN"}, -- Supports multiple flag options : MAIN, BIRTH, DEATH, VORTEX-BREAKDOWN. MAIN is normal tornado activity, birth and death self explanatory, vortex-breakdown has a chance of getting set when tornadoes are multivortex.
    wallcloudColorType = "black", -- wallcloud color Types Available are "white", "black", "brown", only supports one entry.
    behaviorType = "BOTH" -- IS particle "WEAK" COMPATIBLE, "VIOLENT" COMPATIBLE, or "BOTH". Only supports one entry.
})

AddUserParticlesAutospawnXT2({
    name = "5TonyEF55",
    subvortsForParticle = false,
    rangeActivationTiers = {3, 4, 5, 6},-- Tiers are    1 : < 2000,   2: < 3500,   3: < 5000,   4: < 6500,   5: < 8000,   6: < 9500,     7: < 11000,      8: < 12500     9: >12501 -- extremely large...
    supportsparticleTypes = {"NORMAL"}, -- Supports multiple flag options : MULTI-VORTEX, DRILLBIT, NORMAL
    isAnticyclonic = false, -- Is this particle anticyclonic (clockwise spinning or not?) (segments it into anticyclonic sublist)
    supportsphases = {"MAIN"}, -- Supports multiple flag options : MAIN, BIRTH, DEATH, VORTEX-BREAKDOWN. MAIN is normal tornado activity, birth and death self explanatory, vortex-breakdown has a chance of getting set when tornadoes are multivortex.
    wallcloudColorType = "black", -- wallcloud color Types Available are "white", "black", "brown", only supports one entry.
    behaviorType = "VIOLENT" -- IS particle "WEAK" COMPATIBLE, "VIOLENT" COMPATIBLE, or "BOTH". Only supports one entry.
})

AddUserParticlesAutospawnXT2({
    name = "5TonyEF56",
    subvortsForParticle = false,
    rangeActivationTiers = {4, 5, 6},-- Tiers are    1 : < 2000,   2: < 3500,   3: < 5000,   4: < 6500,   5: < 8000,   6: < 9500,     7: < 11000,      8: < 12500     9: >12501 -- extremely large...
    supportsparticleTypes = {"NORMAL"}, -- Supports multiple flag options : MULTI-VORTEX, DRILLBIT, NORMAL
    isAnticyclonic = false, -- Is this particle anticyclonic (clockwise spinning or not?) (segments it into anticyclonic sublist)
    supportsphases = {"MAIN", "BIRTH", "DEATH"}, -- Supports multiple flag options : MAIN, BIRTH, DEATH, VORTEX-BREAKDOWN. MAIN is normal tornado activity, birth and death self explanatory, vortex-breakdown has a chance of getting set when tornadoes are multivortex.
    wallcloudColorType = "black", -- wallcloud color Types Available are "white", "black", "brown", only supports one entry.
    behaviorType = "BOTH" -- IS particle "WEAK" COMPATIBLE, "VIOLENT" COMPATIBLE, or "BOTH". Only supports one entry.
})

AddUserParticlesAutospawnXT2({
    name = "5TonyEF59",
    subvortsForParticle = false,
    rangeActivationTiers = {4, 5, 6},-- Tiers are    1 : < 2000,   2: < 3500,   3: < 5000,   4: < 6500,   5: < 8000,   6: < 9500,     7: < 11000,      8: < 12500     9: >12501 -- extremely large...
    supportsparticleTypes = {"NORMAL"}, -- Supports multiple flag options : MULTI-VORTEX, DRILLBIT, NORMAL
    isAnticyclonic = false, -- Is this particle anticyclonic (clockwise spinning or not?) (segments it into anticyclonic sublist)
    supportsphases = {"MAIN"}, -- Supports multiple flag options : MAIN, BIRTH, DEATH, VORTEX-BREAKDOWN. MAIN is normal tornado activity, birth and death self explanatory, vortex-breakdown has a chance of getting set when tornadoes are multivortex.
    wallcloudColorType = "black", -- wallcloud color Types Available are "white", "black", "brown", only supports one entry.
    behaviorType = "VIOLENT" -- IS particle "WEAK" COMPATIBLE, "VIOLENT" COMPATIBLE, or "BOTH". Only supports one entry.
})

AddUserParticlesAutospawnXT2({
    name = "5TonyEF510",
    subvortsForParticle = false,
    rangeActivationTiers = {5, 6},-- Tiers are    1 : < 2000,   2: < 3500,   3: < 5000,   4: < 6500,   5: < 8000,   6: < 9500,     7: < 11000,      8: < 12500     9: >12501 -- extremely large...
    supportsparticleTypes = {"NORMAL"}, -- Supports multiple flag options : MULTI-VORTEX, DRILLBIT, NORMAL
    isAnticyclonic = false, -- Is this particle anticyclonic (clockwise spinning or not?) (segments it into anticyclonic sublist)
    supportsphases = {"MAIN"}, -- Supports multiple flag options : MAIN, BIRTH, DEATH, VORTEX-BREAKDOWN. MAIN is normal tornado activity, birth and death self explanatory, vortex-breakdown has a chance of getting set when tornadoes are multivortex.
    wallcloudColorType = "black", -- wallcloud color Types Available are "white", "black", "brown", only supports one entry.
    behaviorType = "BOTH" -- IS particle "WEAK" COMPATIBLE, "VIOLENT" COMPATIBLE, or "BOTH". Only supports one entry.
})

-- LARGE

AddUserParticlesAutospawnXT2({
    name = "PGYT_EF_0l",
    subvortsForParticle = false,
    rangeActivationTiers = {2, 3, 4},-- Tiers are    1 : < 2000,   2: < 3500,   3: < 5000,   4: < 6500,   5: < 8000,   6: < 9500,     7: < 11000,      8: < 12500     9: >12501 -- extremely large...
    supportsparticleTypes = {"NORMAL"}, -- Supports multiple flag options : MULTI-VORTEX, DRILLBIT, NORMAL
    isAnticyclonic = false, -- Is this particle anticyclonic (clockwise spinning or not?) (segments it into anticyclonic sublist)
    supportsphases = {"MAIN"}, -- Supports multiple flag options : MAIN, BIRTH, DEATH, VORTEX-BREAKDOWN. MAIN is normal tornado activity, birth and death self explanatory, vortex-breakdown has a chance of getting set when tornadoes are multivortex.
    wallcloudColorType = "black", -- wallcloud color Types Available are "white", "black", "brown", only supports one entry.
    behaviorType = "BOTH" -- IS particle "WEAK" COMPATIBLE, "VIOLENT" COMPATIBLE, or "BOTH". Only supports one entry.
})

AddUserParticlesAutospawnXT2({
    name = "5TonyEF018",
    subvortsForParticle = false,
    rangeActivationTiers = {3, 4},-- Tiers are    1 : < 2000,   2: < 3500,   3: < 5000,   4: < 6500,   5: < 8000,   6: < 9500,     7: < 11000,      8: < 12500     9: >12501 -- extremely large...
    supportsparticleTypes = {"NORMAL"}, -- Supports multiple flag options : MULTI-VORTEX, DRILLBIT, NORMAL
    isAnticyclonic = false, -- Is this particle anticyclonic (clockwise spinning or not?) (segments it into anticyclonic sublist)
    supportsphases = {"MAIN"}, -- Supports multiple flag options : MAIN, BIRTH, DEATH, VORTEX-BREAKDOWN. MAIN is normal tornado activity, birth and death self explanatory, vortex-breakdown has a chance of getting set when tornadoes are multivortex.
    wallcloudColorType = "black", -- wallcloud color Types Available are "white", "black", "brown", only supports one entry.
    behaviorType = "WEAK" -- IS particle "WEAK" COMPATIBLE, "VIOLENT" COMPATIBLE, or "BOTH". Only supports one entry.
})

AddUserParticlesAutospawnXT2({
    name = "PGYT_EF_0h",
    subvortsForParticle = false,
    rangeActivationTiers = {3, 4},-- Tiers are    1 : < 2000,   2: < 3500,   3: < 5000,   4: < 6500,   5: < 8000,   6: < 9500,     7: < 11000,      8: < 12500     9: >12501 -- extremely large...
    supportsparticleTypes = {"NORMAL"}, -- Supports multiple flag options : MULTI-VORTEX, DRILLBIT, NORMAL
    isAnticyclonic = false, -- Is this particle anticyclonic (clockwise spinning or not?) (segments it into anticyclonic sublist)
    supportsphases = {"MAIN"}, -- Supports multiple flag options : MAIN, BIRTH, DEATH, VORTEX-BREAKDOWN. MAIN is normal tornado activity, birth and death self explanatory, vortex-breakdown has a chance of getting set when tornadoes are multivortex.
    wallcloudColorType = "black", -- wallcloud color Types Available are "white", "black", "brown", only supports one entry.
    behaviorType = "BOTH" -- IS particle "WEAK" COMPATIBLE, "VIOLENT" COMPATIBLE, or "BOTH". Only supports one entry.
})

AddUserParticlesAutospawnXT2({
    name = "5TonyEF08",
    subvortsForParticle = false,
    rangeActivationTiers = {3, 4},-- Tiers are    1 : < 2000,   2: < 3500,   3: < 5000,   4: < 6500,   5: < 8000,   6: < 9500,     7: < 11000,      8: < 12500     9: >12501 -- extremely large...
    supportsparticleTypes = {"NORMAL"}, -- Supports multiple flag options : MULTI-VORTEX, DRILLBIT, NORMAL
    isAnticyclonic = false, -- Is this particle anticyclonic (clockwise spinning or not?) (segments it into anticyclonic sublist)
    supportsphases = {"MAIN", "BIRTH", "DEATH"}, -- Supports multiple flag options : MAIN, BIRTH, DEATH, VORTEX-BREAKDOWN. MAIN is normal tornado activity, birth and death self explanatory, vortex-breakdown has a chance of getting set when tornadoes are multivortex.
    wallcloudColorType = "black", -- wallcloud color Types Available are "white", "black", "brown", only supports one entry.
    behaviorType = "WEAK" -- IS particle "WEAK" COMPATIBLE, "VIOLENT" COMPATIBLE, or "BOTH". Only supports one entry.
})

AddUserParticlesAutospawnXT2({
    name = "PGYT_EF_1d",
    subvortsForParticle = false,
    rangeActivationTiers = {4, 5},-- Tiers are    1 : < 2000,   2: < 3500,   3: < 5000,   4: < 6500,   5: < 8000,   6: < 9500,     7: < 11000,      8: < 12500     9: >12501 -- extremely large...
    supportsparticleTypes = {"NORMAL"}, -- Supports multiple flag options : MULTI-VORTEX, DRILLBIT, NORMAL
    isAnticyclonic = false, -- Is this particle anticyclonic (clockwise spinning or not?) (segments it into anticyclonic sublist)
    supportsphases = {"MAIN"}, -- Supports multiple flag options : MAIN, BIRTH, DEATH, VORTEX-BREAKDOWN. MAIN is normal tornado activity, birth and death self explanatory, vortex-breakdown has a chance of getting set when tornadoes are multivortex.
    wallcloudColorType = "black", -- wallcloud color Types Available are "white", "black", "brown", only supports one entry.
    behaviorType = "BOTH" -- IS particle "WEAK" COMPATIBLE, "VIOLENT" COMPATIBLE, or "BOTH". Only supports one entry.
})

AddUserParticlesAutospawnXT2({
    name = "PGYT_EF_1e",
    subvortsForParticle = false,
    rangeActivationTiers = {3, 4},-- Tiers are    1 : < 2000,   2: < 3500,   3: < 5000,   4: < 6500,   5: < 8000,   6: < 9500,     7: < 11000,      8: < 12500     9: >12501 -- extremely large...
    supportsparticleTypes = {"NORMAL"}, -- Supports multiple flag options : MULTI-VORTEX, DRILLBIT, NORMAL
    isAnticyclonic = false, -- Is this particle anticyclonic (clockwise spinning or not?) (segments it into anticyclonic sublist)
    supportsphases = {"MAIN"}, -- Supports multiple flag options : MAIN, BIRTH, DEATH, VORTEX-BREAKDOWN. MAIN is normal tornado activity, birth and death self explanatory, vortex-breakdown has a chance of getting set when tornadoes are multivortex.
    wallcloudColorType = "black", -- wallcloud color Types Available are "white", "black", "brown", only supports one entry.
    behaviorType = "BOTH" -- IS particle "WEAK" COMPATIBLE, "VIOLENT" COMPATIBLE, or "BOTH". Only supports one entry.
})

AddUserParticlesAutospawnXT2({
    name = "5TonyEF214",
    subvortsForParticle = false,
    rangeActivationTiers = {3, 4},-- Tiers are    1 : < 2000,   2: < 3500,   3: < 5000,   4: < 6500,   5: < 8000,   6: < 9500,     7: < 11000,      8: < 12500     9: >12501 -- extremely large...
    supportsparticleTypes = {"NORMAL"}, -- Supports multiple flag options : MULTI-VORTEX, DRILLBIT, NORMAL
    isAnticyclonic = false, -- Is this particle anticyclonic (clockwise spinning or not?) (segments it into anticyclonic sublist)
    supportsphases = {"MAIN"}, -- Supports multiple flag options : MAIN, BIRTH, DEATH, VORTEX-BREAKDOWN. MAIN is normal tornado activity, birth and death self explanatory, vortex-breakdown has a chance of getting set when tornadoes are multivortex.
    wallcloudColorType = "black", -- wallcloud color Types Available are "white", "black", "brown", only supports one entry.
    behaviorType = "BOTH" -- IS particle "WEAK" COMPATIBLE, "VIOLENT" COMPATIBLE, or "BOTH". Only supports one entry.
})

AddUserParticlesAutospawnXT2({
    name = "5TonyEF27",
    subvortsForParticle = false,
    rangeActivationTiers = {4, 5},-- Tiers are    1 : < 2000,   2: < 3500,   3: < 5000,   4: < 6500,   5: < 8000,   6: < 9500,     7: < 11000,      8: < 12500     9: >12501 -- extremely large...
    supportsparticleTypes = {"NORMAL"}, -- Supports multiple flag options : MULTI-VORTEX, DRILLBIT, NORMAL
    isAnticyclonic = false, -- Is this particle anticyclonic (clockwise spinning or not?) (segments it into anticyclonic sublist)
    supportsphases = {"MAIN"}, -- Supports multiple flag options : MAIN, BIRTH, DEATH, VORTEX-BREAKDOWN. MAIN is normal tornado activity, birth and death self explanatory, vortex-breakdown has a chance of getting set when tornadoes are multivortex.
    wallcloudColorType = "black", -- wallcloud color Types Available are "white", "black", "brown", only supports one entry.
    behaviorType = "BOTH" -- IS particle "WEAK" COMPATIBLE, "VIOLENT" COMPATIBLE, or "BOTH". Only supports one entry.
})

AddUserParticlesAutospawnXT2({
    name = "5TonyEF210",
    subvortsForParticle = false,
    rangeActivationTiers = {3, 4},-- Tiers are    1 : < 2000,   2: < 3500,   3: < 5000,   4: < 6500,   5: < 8000,   6: < 9500,     7: < 11000,      8: < 12500     9: >12501 -- extremely large...
    supportsparticleTypes = {"NORMAL"}, -- Supports multiple flag options : MULTI-VORTEX, DRILLBIT, NORMAL
    isAnticyclonic = false, -- Is this particle anticyclonic (clockwise spinning or not?) (segments it into anticyclonic sublist)
    supportsphases = {"MAIN"}, -- Supports multiple flag options : MAIN, BIRTH, DEATH, VORTEX-BREAKDOWN. MAIN is normal tornado activity, birth and death self explanatory, vortex-breakdown has a chance of getting set when tornadoes are multivortex.
    wallcloudColorType = "black", -- wallcloud color Types Available are "white", "black", "brown", only supports one entry.
    behaviorType = "BOTH" -- IS particle "WEAK" COMPATIBLE, "VIOLENT" COMPATIBLE, or "BOTH". Only supports one entry.
})

AddUserParticlesAutospawnXT2({
    name = "PGYT_EF_2b",
    subvortsForParticle = false,
    rangeActivationTiers = {4, 5},-- Tiers are    1 : < 2000,   2: < 3500,   3: < 5000,   4: < 6500,   5: < 8000,   6: < 9500,     7: < 11000,      8: < 12500     9: >12501 -- extremely large...
    supportsparticleTypes = {"NORMAL"}, -- Supports multiple flag options : MULTI-VORTEX, DRILLBIT, NORMAL
    isAnticyclonic = false, -- Is this particle anticyclonic (clockwise spinning or not?) (segments it into anticyclonic sublist)
    supportsphases = {"MAIN"}, -- Supports multiple flag options : MAIN, BIRTH, DEATH, VORTEX-BREAKDOWN. MAIN is normal tornado activity, birth and death self explanatory, vortex-breakdown has a chance of getting set when tornadoes are multivortex.
    wallcloudColorType = "black", -- wallcloud color Types Available are "white", "black", "brown", only supports one entry.
    behaviorType = "WEAK" -- IS particle "WEAK" COMPATIBLE, "VIOLENT" COMPATIBLE, or "BOTH". Only supports one entry.
})

AddUserParticlesAutospawnXT2({
    name = "5TonyEF321",
    subvortsForParticle = false,
    rangeActivationTiers = {3, 4},-- Tiers are    1 : < 2000,   2: < 3500,   3: < 5000,   4: < 6500,   5: < 8000,   6: < 9500,     7: < 11000,      8: < 12500     9: >12501 -- extremely large...
    supportsparticleTypes = {"NORMAL"}, -- Supports multiple flag options : MULTI-VORTEX, DRILLBIT, NORMAL
    isAnticyclonic = false, -- Is this particle anticyclonic (clockwise spinning or not?) (segments it into anticyclonic sublist)
    supportsphases = {"MAIN"}, -- Supports multiple flag options : MAIN, BIRTH, DEATH, VORTEX-BREAKDOWN. MAIN is normal tornado activity, birth and death self explanatory, vortex-breakdown has a chance of getting set when tornadoes are multivortex.
    wallcloudColorType = "black", -- wallcloud color Types Available are "white", "black", "brown", only supports one entry.
    behaviorType = "BOTH" -- IS particle "WEAK" COMPATIBLE, "VIOLENT" COMPATIBLE, or "BOTH". Only supports one entry.
})

AddUserParticlesAutospawnXT2({
    name = "PGYT_EF_3d",
    subvortsForParticle = false,
    rangeActivationTiers = {4, 5},-- Tiers are    1 : < 2000,   2: < 3500,   3: < 5000,   4: < 6500,   5: < 8000,   6: < 9500,     7: < 11000,      8: < 12500     9: >12501 -- extremely large...
    supportsparticleTypes = {"NORMAL"}, -- Supports multiple flag options : MULTI-VORTEX, DRILLBIT, NORMAL
    isAnticyclonic = false, -- Is this particle anticyclonic (clockwise spinning or not?) (segments it into anticyclonic sublist)
    supportsphases = {"MAIN"}, -- Supports multiple flag options : MAIN, BIRTH, DEATH, VORTEX-BREAKDOWN. MAIN is normal tornado activity, birth and death self explanatory, vortex-breakdown has a chance of getting set when tornadoes are multivortex.
    wallcloudColorType = "black", -- wallcloud color Types Available are "white", "black", "brown", only supports one entry.
    behaviorType = "VIOLENT" -- IS particle "WEAK" COMPATIBLE, "VIOLENT" COMPATIBLE, or "BOTH". Only supports one entry.
})

AddUserParticlesAutospawnXT2({
    name = "5TonyEF416",
    subvortsForParticle = false,
    rangeActivationTiers = {5, 6},-- Tiers are    1 : < 2000,   2: < 3500,   3: < 5000,   4: < 6500,   5: < 8000,   6: < 9500,     7: < 11000,      8: < 12500     9: >12501 -- extremely large...
    supportsparticleTypes = {"NORMAL"}, -- Supports multiple flag options : MULTI-VORTEX, DRILLBIT, NORMAL
    isAnticyclonic = false, -- Is this particle anticyclonic (clockwise spinning or not?) (segments it into anticyclonic sublist)
    supportsphases = {"MAIN"}, -- Supports multiple flag options : MAIN, BIRTH, DEATH, VORTEX-BREAKDOWN. MAIN is normal tornado activity, birth and death self explanatory, vortex-breakdown has a chance of getting set when tornadoes are multivortex.
    wallcloudColorType = "black", -- wallcloud color Types Available are "white", "black", "brown", only supports one entry.
    behaviorType = "VIOLENT" -- IS particle "WEAK" COMPATIBLE, "VIOLENT" COMPATIBLE, or "BOTH". Only supports one entry.
})

AddUserParticlesAutospawnXT2({
    name = "PGYT_EF_4",
    subvortsForParticle = false,
    rangeActivationTiers = {5, 6},-- Tiers are    1 : < 2000,   2: < 3500,   3: < 5000,   4: < 6500,   5: < 8000,   6: < 9500,     7: < 11000,      8: < 12500     9: >12501 -- extremely large...
    supportsparticleTypes = {"NORMAL"}, -- Supports multiple flag options : MULTI-VORTEX, DRILLBIT, NORMAL
    isAnticyclonic = false, -- Is this particle anticyclonic (clockwise spinning or not?) (segments it into anticyclonic sublist)
    supportsphases = {"MAIN"}, -- Supports multiple flag options : MAIN, BIRTH, DEATH, VORTEX-BREAKDOWN. MAIN is normal tornado activity, birth and death self explanatory, vortex-breakdown has a chance of getting set when tornadoes are multivortex.
    wallcloudColorType = "black", -- wallcloud color Types Available are "white", "black", "brown", only supports one entry.
    behaviorType = "VIOLENT" -- IS particle "WEAK" COMPATIBLE, "VIOLENT" COMPATIBLE, or "BOTH". Only supports one entry.
})

AddUserParticlesAutospawnXT2({
    name = "5TonyEF45",
    subvortsForParticle = false,
    rangeActivationTiers = {4, 5, 6},-- Tiers are    1 : < 2000,   2: < 3500,   3: < 5000,   4: < 6500,   5: < 8000,   6: < 9500,     7: < 11000,      8: < 12500     9: >12501 -- extremely large...
    supportsparticleTypes = {"NORMAL"}, -- Supports multiple flag options : MULTI-VORTEX, DRILLBIT, NORMAL
    isAnticyclonic = false, -- Is this particle anticyclonic (clockwise spinning or not?) (segments it into anticyclonic sublist)
    supportsphases = {"MAIN"}, -- Supports multiple flag options : MAIN, BIRTH, DEATH, VORTEX-BREAKDOWN. MAIN is normal tornado activity, birth and death self explanatory, vortex-breakdown has a chance of getting set when tornadoes are multivortex.
    wallcloudColorType = "black", -- wallcloud color Types Available are "white", "black", "brown", only supports one entry.
    behaviorType = "VIOLENT" -- IS particle "WEAK" COMPATIBLE, "VIOLENT" COMPATIBLE, or "BOTH". Only supports one entry.
})

AddUserParticlesAutospawnXT2({
    name = "5TonyEF47",
    subvortsForParticle = false,
    rangeActivationTiers = {5, 6},-- Tiers are    1 : < 2000,   2: < 3500,   3: < 5000,   4: < 6500,   5: < 8000,   6: < 9500,     7: < 11000,      8: < 12500     9: >12501 -- extremely large...
    supportsparticleTypes = {"NORMAL"}, -- Supports multiple flag options : MULTI-VORTEX, DRILLBIT, NORMAL
    isAnticyclonic = false, -- Is this particle anticyclonic (clockwise spinning or not?) (segments it into anticyclonic sublist)
    supportsphases = {"MAIN"}, -- Supports multiple flag options : MAIN, BIRTH, DEATH, VORTEX-BREAKDOWN. MAIN is normal tornado activity, birth and death self explanatory, vortex-breakdown has a chance of getting set when tornadoes are multivortex.
    wallcloudColorType = "black", -- wallcloud color Types Available are "white", "black", "brown", only supports one entry.
    behaviorType = "VIOLENT" -- IS particle "WEAK" COMPATIBLE, "VIOLENT" COMPATIBLE, or "BOTH". Only supports one entry.
})

AddUserParticlesAutospawnXT2({
    name = "5TonyEF46",
    subvortsForParticle = false,
    rangeActivationTiers = {5, 6, 7},-- Tiers are    1 : < 2000,   2: < 3500,   3: < 5000,   4: < 6500,   5: < 8000,   6: < 9500,     7: < 11000,      8: < 12500     9: >12501 -- extremely large...
    supportsparticleTypes = {"NORMAL"}, -- Supports multiple flag options : MULTI-VORTEX, DRILLBIT, NORMAL
    isAnticyclonic = false, -- Is this particle anticyclonic (clockwise spinning or not?) (segments it into anticyclonic sublist)
    supportsphases = {"MAIN"}, -- Supports multiple flag options : MAIN, BIRTH, DEATH, VORTEX-BREAKDOWN. MAIN is normal tornado activity, birth and death self explanatory, vortex-breakdown has a chance of getting set when tornadoes are multivortex.
    wallcloudColorType = "black", -- wallcloud color Types Available are "white", "black", "brown", only supports one entry.
    behaviorType = "VIOLENT" -- IS particle "WEAK" COMPATIBLE, "VIOLENT" COMPATIBLE, or "BOTH". Only supports one entry.
})

AddUserParticlesAutospawnXT2({
    name = "PGYT_EF_5b",
    subvortsForParticle = false,
    rangeActivationTiers = {7, 8},-- Tiers are    1 : < 2000,   2: < 3500,   3: < 5000,   4: < 6500,   5: < 8000,   6: < 9500,     7: < 11000,      8: < 12500     9: >12501 -- extremely large...
    supportsparticleTypes = {"NORMAL"}, -- Supports multiple flag options : MULTI-VORTEX, DRILLBIT, NORMAL
    isAnticyclonic = false, -- Is this particle anticyclonic (clockwise spinning or not?) (segments it into anticyclonic sublist)
    supportsphases = {"MAIN"}, -- Supports multiple flag options : MAIN, BIRTH, DEATH, VORTEX-BREAKDOWN. MAIN is normal tornado activity, birth and death self explanatory, vortex-breakdown has a chance of getting set when tornadoes are multivortex.
    wallcloudColorType = "black", -- wallcloud color Types Available are "white", "black", "brown", only supports one entry.
    behaviorType = "BOTH" -- IS particle "WEAK" COMPATIBLE, "VIOLENT" COMPATIBLE, or "BOTH". Only supports one entry.
})

AddUserParticlesAutospawnXT2({
    name = "5TonyEF519",
    subvortsForParticle = false,
    rangeActivationTiers = {5, 6},-- Tiers are    1 : < 2000,   2: < 3500,   3: < 5000,   4: < 6500,   5: < 8000,   6: < 9500,     7: < 11000,      8: < 12500     9: >12501 -- extremely large...
    supportsparticleTypes = {"NORMAL"}, -- Supports multiple flag options : MULTI-VORTEX, DRILLBIT, NORMAL
    isAnticyclonic = false, -- Is this particle anticyclonic (clockwise spinning or not?) (segments it into anticyclonic sublist)
    supportsphases = {"MAIN"}, -- Supports multiple flag options : MAIN, BIRTH, DEATH, VORTEX-BREAKDOWN. MAIN is normal tornado activity, birth and death self explanatory, vortex-breakdown has a chance of getting set when tornadoes are multivortex.
    wallcloudColorType = "black", -- wallcloud color Types Available are "white", "black", "brown", only supports one entry.
    behaviorType = "VIOLENT" -- IS particle "WEAK" COMPATIBLE, "VIOLENT" COMPATIBLE, or "BOTH". Only supports one entry.
})

-- SMALL MULTIVORTEX

AddUserParticlesAutospawnXT2({
    name = "5TonyEF02",
    subvortsForParticle = true,
    rangeActivationTiers = {2, 3},
    supportsparticleTypes = {"NORMAL"},
    isAnticyclonic = false,
    supportsphases = {"MAIN", "BIRTH", "DEATH"},
    wallcloudColorType = "black",
    behaviorType = "WEAK"
})

AddUserParticlesAutospawnXT2({
    name = "PGYT_EF_0w",
    subvortsForParticle = true,
    rangeActivationTiers = {2, 3},
    supportsparticleTypes = {"NORMAL"},
    isAnticyclonic = false,
    supportsphases = {"MAIN"},
    wallcloudColorType = "black",
    behaviorType = "WEAK"
})

AddUserParticlesAutospawnXT2({
    name = "5TonyEF022",
    subvortsForParticle = true,
    rangeActivationTiers = {2, 3},
    supportsparticleTypes = {"NORMAL"},
    isAnticyclonic = false,
    supportsphases = {"MAIN", "BIRTH", "DEATH"},
    wallcloudColorType = "black",
    behaviorType = "WEAK"
})

AddUserParticlesAutospawnXT2({
    name = "5TonyEF016",
    subvortsForParticle = true,
    rangeActivationTiers = {2},
    supportsparticleTypes = {"NORMAL"},
    isAnticyclonic = false,
    supportsphases = {"MAIN", "BIRTH", "DEATH"},
    wallcloudColorType = "black",
    behaviorType = "WEAK"
})

AddUserParticlesAutospawnXT2({
    name = "5TonyEF012",
    subvortsForParticle = true,
    rangeActivationTiers = {1, 2},
    supportsparticleTypes = {"NORMAL"},
    isAnticyclonic = false,
    supportsphases = {"MAIN", "BIRTH", "DEATH"},
    wallcloudColorType = "black",
    behaviorType = "WEAK"
})

AddUserParticlesAutospawnXT2({
    name = "5TonyEF110",
    subvortsForParticle = true,
    rangeActivationTiers = {2},
    supportsparticleTypes = {"NORMAL"},
    isAnticyclonic = false,
    supportsphases = {"MAIN"},
    wallcloudColorType = "black",
    behaviorType = "WEAK"
})

AddUserParticlesAutospawnXT2({
    name = "PGYT_EF_2k",
    subvortsForParticle = true,
    rangeActivationTiers = {2, 3},
    supportsparticleTypes = {"NORMAL"},
    isAnticyclonic = false,
    supportsphases = {"MAIN", "BIRTH", "DEATH"},
    wallcloudColorType = "black",
    behaviorType = "WEAK"
})

AddUserParticlesAutospawnXT2({
    name = "PGYT_EF_2e",
    subvortsForParticle = true,
    rangeActivationTiers = {2, 3},
    supportsparticleTypes = {"MULTI-VORTEX"},
    isAnticyclonic = false,
    supportsphases = {"MAIN", "VORTEX-BREAKDOWN"},
    wallcloudColorType = "black",
    behaviorType = "BOTH"
})

AddUserParticlesAutospawnXT2({
    name = "5TonyEF314",
    subvortsForParticle = true,
    rangeActivationTiers = {2, 3},
    supportsparticleTypes = {"NORMAL"},
    isAnticyclonic = false,
    supportsphases = {"MAIN"},
    wallcloudColorType = "black",
    behaviorType = "BOTH"
})

AddUserParticlesAutospawnXT2({
    name = "5TonyEF515",
    subvortsForParticle = true,
    rangeActivationTiers = {3, 4},
    supportsparticleTypes = {"NORMAL"},
    isAnticyclonic = false,
    supportsphases = {"MAIN"},
    wallcloudColorType = "black",
    behaviorType = "VIOLENT"
})

AddUserParticlesAutospawnXT2({
    name = "PGYT_EF_4c",
    subvortsForParticle = true,
    rangeActivationTiers = {4, 5},
    supportsparticleTypes = {"NORMAL"},
    isAnticyclonic = false,
    supportsphases = {"MAIN", "BIRTH"},
    wallcloudColorType = "black",
    behaviorType = "BOTH"
})

AddUserParticlesAutospawnXT2({
    name = "5TonyEF5",
    subvortsForParticle = true,
    rangeActivationTiers = {4, 5, 6},
    supportsparticleTypes = {"MULTI-VORTEX"},
    isAnticyclonic = false,
    supportsphases = {"MAIN", "VORTEX-BREAKDOWN"},
    wallcloudColorType = "black",
    behaviorType = "VIOLENT"
})

AddUserParticlesAutospawnXT2({
    name = "5TonyEF52",
    subvortsForParticle = true,
    rangeActivationTiers = {4, 5},
    supportsparticleTypes = {"MULTI-VORTEX"},
    isAnticyclonic = false,
    supportsphases = {"MAIN", "VORTEX-BREAKDOWN"},
    wallcloudColorType = "black",
    behaviorType = "VIOLENT"
})

AddUserParticlesAutospawnXT2({
    name = "5TonyEF522",
    subvortsForParticle = true,
    rangeActivationTiers = {4, 5},
    supportsparticleTypes = {"NORMAL", "MULTI-VORTEX"},
    isAnticyclonic = false,
    supportsphases = {"MAIN", "VORTEX-BREAKDOWN"},
    wallcloudColorType = "black",
    behaviorType = "VIOLENT"
})

AddUserParticlesAutospawnXT2({
    name = "5TonyEF53",
    subvortsForParticle = true,
    rangeActivationTiers = {4, 5, 6},
    supportsparticleTypes = {"MULTI-VORTEX"},
    isAnticyclonic = false,
    supportsphases = {"MAIN", "BIRTH", "DEATH", "VORTEX-BREAKDOWN"},
    wallcloudColorType = "black",
    behaviorType = "BOTH"
})

-- LARGE MULTIVORTEX

AddUserParticlesAutospawnXT2({
    name = "5TonyEF021",
    subvortsForParticle = true,
    rangeActivationTiers = {2, 3},
    supportsparticleTypes = {"NORMAL"},
    isAnticyclonic = false,
    supportsphases = {"MAIN", "BIRTH", "DEATH"},
    wallcloudColorType = "black",
    behaviorType = "WEAK"
})

AddUserParticlesAutospawnXT2({
    name = "5TonyEF12",
    subvortsForParticle = true,
    rangeActivationTiers = {3, 4},
    supportsparticleTypes = {"MULTI-VORTEX"},
    isAnticyclonic = false,
    supportsphases = {"MAIN", "BIRTH", "DEATH", "VORTEX-BREAKDOWN"},
    wallcloudColorType = "black",
    behaviorType = "WEAK"
})

AddUserParticlesAutospawnXT2({
    name = "5TonyEF216",
    subvortsForParticle = true,
    rangeActivationTiers = {2, 3},
    supportsparticleTypes = {"NORMAL"},
    isAnticyclonic = false,
    supportsphases = {"MAIN", "BIRTH", "DEATH"},
    wallcloudColorType = "black",
    behaviorType = "WEAK"
})

AddUserParticlesAutospawnXT2({
    name = "5TonyEF37",
    subvortsForParticle = true,
    rangeActivationTiers = {2, 3},
    supportsparticleTypes = {"MULTI-VORTEX"},
    isAnticyclonic = false,
    supportsphases = {"MAIN", "BIRTH", "DEATH", "VORTEX-BREAKDOWN"},
    wallcloudColorType = "black",
    behaviorType = "BOTH"
})

AddUserParticlesAutospawnXT2({
    name = "5TonyEF5",
    subvortsForParticle = true,
    rangeActivationTiers = {5, 6},  
    supportsparticleTypes = {"MULTI-VORTEX"},
    isAnticyclonic = false,
    supportsphases = {"MAIN", "VORTEX-BREAKDOWN", "VORTEX-BREAKDOWN"},
    wallcloudColorType = "black",
    behaviorType = "VIOLENT"
})

---------------------------------- BROWN TORNADOES ------------------------------------------

-- SMALL

AddUserParticlesAutospawnXT2({
    name = "PGYT_EF_0k",
    subvortsForParticle = false,
    rangeActivationTiers = {1, 2},
    supportsparticleTypes = {"NORMAL"},
    isAnticyclonic = false,
    supportsphases = {"MAIN"},
    wallcloudColorType = "brown",
    behaviorType = "BOTH"
})

AddUserParticlesAutospawnXT2({
    name = "5TonyEF017",
    subvortsForParticle = false,
    rangeActivationTiers = {1, 2},
    supportsparticleTypes = {"NORMAL"},
    isAnticyclonic = false,
    supportsphases = {"MAIN", "BIRTH", "DEATH"},
    wallcloudColorType = "brown",
    behaviorType = "WEAK"
})

AddUserParticlesAutospawnXT2({
    name = "PGYT_EF_0",
    subvortsForParticle = false,
    rangeActivationTiers = {2, 3},
    supportsparticleTypes = {"NORMAL"},
    isAnticyclonic = false,
    supportsphases = {"MAIN"},
    wallcloudColorType = "brown",
    behaviorType = "BOTH"
})

AddUserParticlesAutospawnXT2({
    name = "PGYT_EF_0u",
    subvortsForParticle = false,
    rangeActivationTiers = {2, 3},
    supportsparticleTypes = {"NORMAL"},
    isAnticyclonic = false,
    supportsphases = {"MAIN"},
    wallcloudColorType = "brown",
    behaviorType = "BOTH"
})

AddUserParticlesAutospawnXT2({
    name = "PGYT_EF_1b",
    subvortsForParticle = false,
    rangeActivationTiers = {2, 3},
    supportsparticleTypes = {"NORMAL"},
    isAnticyclonic = false,
    supportsphases = {"MAIN"},
    wallcloudColorType = "brown",
    behaviorType = "WEAK"
})

AddUserParticlesAutospawnXT2({
    name = "5TonyEF211",
    subvortsForParticle = false,
    rangeActivationTiers = {2, 3},
    supportsparticleTypes = {"NORMAL"},
    isAnticyclonic = false,
    supportsphases = {"MAIN"},
    wallcloudColorType = "brown",
    behaviorType = "BOTH"
})

AddUserParticlesAutospawnXT2({
    name = "PGYT_EF_2",
    subvortsForParticle = false,
    rangeActivationTiers = {2, 3},
    supportsparticleTypes = {"NORMAL"},
    isAnticyclonic = false,
    supportsphases = {"MAIN"},
    wallcloudColorType = "brown",
    behaviorType = "BOTH"
})

AddUserParticlesAutospawnXT2({
    name = "PGYT_EF_2n",
    subvortsForParticle = false,
    rangeActivationTiers = {3, 4},
    supportsparticleTypes = {"NORMAL"},
    isAnticyclonic = false,
    supportsphases = {"MAIN"},
    wallcloudColorType = "brown",
    behaviorType = "BOTH"
})

AddUserParticlesAutospawnXT2({
    name = "PGYT_EF_2r",
    subvortsForParticle = false,
    rangeActivationTiers = {2, 3},
    supportsparticleTypes = {"NORMAL"},
    isAnticyclonic = false,
    supportsphases = {"MAIN"},
    wallcloudColorType = "brown",
    behaviorType = "WEAK"
})

AddUserParticlesAutospawnXT2({
    name = "PGYT_EF_2h",
    subvortsForParticle = false,
    rangeActivationTiers = {2, 3},
    supportsparticleTypes = {"NORMAL"},
    isAnticyclonic = false,
    supportsphases = {"MAIN"},
    wallcloudColorType = "brown",
    behaviorType = "WEAK"
})

AddUserParticlesAutospawnXT2({
    name = "PGYT_EF_2i",
    subvortsForParticle = false,
    rangeActivationTiers = {2, 3},
    supportsparticleTypes = {"NORMAL"},
    isAnticyclonic = false,
    supportsphases = {"MAIN", "BIRTH", "DEATH"},
    wallcloudColorType = "brown",
    behaviorType = "WEAK"
})

AddUserParticlesAutospawnXT2({
    name = "PGYT_EF_2c",
    subvortsForParticle = false,
    rangeActivationTiers = {2, 3},
    supportsparticleTypes = {"NORMAL"},
    isAnticyclonic = false,
    supportsphases = {"MAIN"},
    wallcloudColorType = "brown",
    behaviorType = "BOTH"
})

AddUserParticlesAutospawnXT2({
    name = "5TonyEF24",
    subvortsForParticle = false,
    rangeActivationTiers = {3},
    supportsparticleTypes = {"NORMAL"},
    isAnticyclonic = false,
    supportsphases = {"MAIN"},
    wallcloudColorType = "brown",
    behaviorType = "BOTH"
})

AddUserParticlesAutospawnXT2({
    name = "5TonyEF320",
    subvortsForParticle = false,
    rangeActivationTiers = {2, 3, 4},
    supportsparticleTypes = {"NORMAL"},
    isAnticyclonic = false,
    supportsphases = {"MAIN"},
    wallcloudColorType = "brown",
    behaviorType = "BOTH"
})

AddUserParticlesAutospawnXT2({
    name = "5TonyEF412",
    subvortsForParticle = false,
    rangeActivationTiers = {2, 3},
    supportsparticleTypes = {"NORMAL"},
    isAnticyclonic = false,
    supportsphases = {"MAIN"},
    wallcloudColorType = "brown",
    behaviorType = "BOTH"
})

AddUserParticlesAutospawnXT2({
    name = "5TonyEF420",
    subvortsForParticle = false,
    rangeActivationTiers = {3, 4},
    supportsparticleTypes = {"NORMAL"},
    isAnticyclonic = false,
    supportsphases = {"MAIN"},
    wallcloudColorType = "brown",
    behaviorType = "VIOLENT"
})

AddUserParticlesAutospawnXT2({
    name = "5TonyEF413",
    subvortsForParticle = false,
    rangeActivationTiers = {2, 3},
    supportsparticleTypes = {"NORMAL"},
    isAnticyclonic = false,
    supportsphases = {"MAIN"},
    wallcloudColorType = "brown",
    behaviorType = "BOTH"
})

AddUserParticlesAutospawnXT2({
    name = "Twister_EF5",
    subvortsForParticle = false,
    rangeActivationTiers = {5, 6},
    supportsparticleTypes = {"NORMAL"},
    isAnticyclonic = false,
    supportsphases = {"MAIN"},
    wallcloudColorType = "brown",
    behaviorType = "VIOLENT"
})

AddUserParticlesAutospawnXT2({
    name = "5TonyEF518",
    subvortsForParticle = false,
    rangeActivationTiers = {5, 6},
    supportsparticleTypes = {"NORMAL"},
    isAnticyclonic = false,
    supportsphases = {"MAIN"},
    wallcloudColorType = "brown",
    behaviorType = "VIOLENT"
})

-- LARGE

AddUserParticlesAutospawnXT2({
    name = "PGYT_EF_0l",
    subvortsForParticle = false,
    rangeActivationTiers = {2},
    supportsparticleTypes = {"NORMAL"},
    isAnticyclonic = false,
    supportsphases = {"MAIN"},
    wallcloudColorType = "brown",
    behaviorType = "WEAK"
})

AddUserParticlesAutospawnXT2({
    name = "5TonyEF018",
    subvortsForParticle = false,
    rangeActivationTiers = {2, 3},
    supportsparticleTypes = {"NORMAL"},
    isAnticyclonic = false,
    supportsphases = {"MAIN"},
    wallcloudColorType = "brown",
    behaviorType = "WEAK"
})

AddUserParticlesAutospawnXT2({
    name = "PGYT_EF_0h",
    subvortsForParticle = false,
    rangeActivationTiers = {2, 3},
    supportsparticleTypes = {"NORMAL"},
    isAnticyclonic = false,
    supportsphases = {"MAIN"},
    wallcloudColorType = "brown",
    behaviorType = "BOTH"
})

AddUserParticlesAutospawnXT2({
    name = "5TonyEF08",
    subvortsForParticle = false,
    rangeActivationTiers = {2, 3, 4},
    supportsparticleTypes = {"NORMAL"},
    isAnticyclonic = false,
    supportsphases = {"MAIN", "BIRTH", "DEATH"},
    wallcloudColorType = "brown",
    behaviorType = "WEAK"
})

AddUserParticlesAutospawnXT2({
    name = "5TonyEF111",
    subvortsForParticle = true,
    rangeActivationTiers = {3},
    supportsparticleTypes = {"NORMAL"},
    isAnticyclonic = false,
    supportsphases = {"MAIN"},
    wallcloudColorType = "brown",
    behaviorType = "WEAK"
})

AddUserParticlesAutospawnXT2({
    name = "5TonyEF212",
    subvortsForParticle = false,
    rangeActivationTiers = {3, 4},
    supportsparticleTypes = {"NORMAL"},
    isAnticyclonic = false,
    supportsphases = {"MAIN"},
    wallcloudColorType = "brown",
    behaviorType = "BOTH"
})

AddUserParticlesAutospawnXT2({
    name = "5TonyEF25",
    subvortsForParticle = false,
    rangeActivationTiers = {3, 4},
    supportsparticleTypes = {"NORMAL"},
    isAnticyclonic = false,
    supportsphases = {"MAIN", "BIRTH", "DEATH"},
    wallcloudColorType = "brown",
    behaviorType = "BOTH"
})

AddUserParticlesAutospawnXT2({
    name = "Tornadotest2_base",
    subvortsForParticle = false,
    rangeActivationTiers = {2, 3},
    supportsparticleTypes = {"NORMAL"},
    isAnticyclonic = false,
    supportsphases = {"MAIN"},
    wallcloudColorType = "brown",
    behaviorType = "WEAK"
})

AddUserParticlesAutospawnXT2({
    name = "5TonyEF317",
    subvortsForParticle = false,
    rangeActivationTiers = {3, 4},
    supportsparticleTypes = {"NORMAL"},
    isAnticyclonic = false,
    supportsphases = {"MAIN"},
    wallcloudColorType = "brown",
    behaviorType = "BOTH"
})

AddUserParticlesAutospawnXT2({
    name = "5TonyEF34",
    subvortsForParticle = false,
    rangeActivationTiers = {4, 5},
    supportsparticleTypes = {"NORMAL"},
    isAnticyclonic = false,
    supportsphases = {"MAIN"},
    wallcloudColorType = "brown",
    behaviorType = "BOTH"
})

AddUserParticlesAutospawnXT2({
    name = "5TonyEF315",
    subvortsForParticle = false,
    rangeActivationTiers = {4, 5},
    supportsparticleTypes = {"NORMAL"},
    isAnticyclonic = false,
    supportsphases = {"MAIN"},
    wallcloudColorType = "brown",
    behaviorType = "VIOLENT"
})

AddUserParticlesAutospawnXT2({
    name = "5TonyEF49",
    subvortsForParticle = false,
    rangeActivationTiers = {4, 5, 6},
    supportsparticleTypes = {"NORMAL"},
    isAnticyclonic = false,
    supportsphases = {"MAIN"},
    wallcloudColorType = "brown",
    behaviorType = "VIOLENT"
})

AddUserParticlesAutospawnXT2({
    name = "5TonyEF511",
    subvortsForParticle = false,
    rangeActivationTiers = {4, 5, 6},
    supportsparticleTypes = {"NORMAL"},
    isAnticyclonic = false,
    supportsphases = {"MAIN"},
    wallcloudColorType = "brown",
    behaviorType = "VIOLENT"
})

-- SMALL MULTIVORTEX

AddUserParticlesAutospawnXT2({
    name = "5TonyEF02",
    subvortsForParticle = true,
    rangeActivationTiers = {2, 3},
    supportsparticleTypes = {"NORMAL"},
    isAnticyclonic = false,
    supportsphases = {"MAIN", "BIRTH", "DEATH"},
    wallcloudColorType = "brown",
    behaviorType = "WEAK"
})

AddUserParticlesAutospawnXT2({
    name = "PGYT_EF_0w",
    subvortsForParticle = true,
    rangeActivationTiers = {2, 3},
    supportsparticleTypes = {"NORMAL"},
    isAnticyclonic = false,
    supportsphases = {"MAIN"},
    wallcloudColorType = "brown",
    behaviorType = "BOTH"
})

AddUserParticlesAutospawnXT2({
    name = "5TonyEF022",
    subvortsForParticle = true,
    rangeActivationTiers = {2, 3},
    supportsparticleTypes = {"NORMAL"},
    isAnticyclonic = false,
    supportsphases = {"MAIN", "BIRTH", "DEATH"},
    wallcloudColorType = "brown",
    behaviorType = "WEAK"
})

AddUserParticlesAutospawnXT2({
    name = "5TonyEF016",
    subvortsForParticle = true,
    rangeActivationTiers = {2, 3},
    supportsparticleTypes = {"NORMAL"},
    isAnticyclonic = false,
    supportsphases = {"MAIN", "BIRTH", "DEATH"},
    wallcloudColorType = "brown",
    behaviorType = "WEAK"
})

AddUserParticlesAutospawnXT2({
    name = "5TonyEF012",
    subvortsForParticle = true,
    rangeActivationTiers = {1, 2},
    supportsparticleTypes = {"NORMAL"},
    isAnticyclonic = false,
    supportsphases = {"MAIN", "BIRTH", "DEATH"},
    wallcloudColorType = "brown",
    behaviorType = "WEAK"
})

AddUserParticlesAutospawnXT2({
    name = "5TonyEF110",
    subvortsForParticle = true,
    rangeActivationTiers = {1, 2},
    supportsparticleTypes = {"NORMAL"},
    isAnticyclonic = false,
    supportsphases = {"MAIN", "BIRTH", "DEATH"},
    wallcloudColorType = "brown",
    behaviorType = "WEAK"
})

AddUserParticlesAutospawnXT2({
    name = "PGYT_EF_2k",
    subvortsForParticle = true,
    rangeActivationTiers = {2, 3, 4},
    supportsparticleTypes = {"NORMAL"},
    isAnticyclonic = false,
    supportsphases = {"MAIN", "BIRTH", "DEATH"},
    wallcloudColorType = "brown",
    behaviorType = "WEAK"
})

AddUserParticlesAutospawnXT2({
    name = "PGYT_EF_2e",
    subvortsForParticle = true,
    rangeActivationTiers = {2, 3},
    supportsparticleTypes = {"MULTI-VORTEX"},
    isAnticyclonic = false,
    supportsphases = {"MAIN", "VORTEX-BREAKDOWN"},
    wallcloudColorType = "brown",
    behaviorType = "BOTH"
})

AddUserParticlesAutospawnXT2({
    name = "5TonyEF314",
    subvortsForParticle = true,
    rangeActivationTiers = {2, 3},
    supportsparticleTypes = {"NORMAL"},
    isAnticyclonic = false,
    supportsphases = {"MAIN"},
    wallcloudColorType = "brown",
    behaviorType = "BOTH"
})

AddUserParticlesAutospawnXT2({
    name = "PGYT_EF_4c",
    subvortsForParticle = true,
    rangeActivationTiers = {4, 5},
    supportsparticleTypes = {"NORMAL"},
    isAnticyclonic = false,
    supportsphases = {"MAIN", "BIRTH"},
    wallcloudColorType = "brown",
    behaviorType = "BOTH"
})

AddUserParticlesAutospawnXT2({
    name = "5TonyEF54",
    subvortsForParticle = true,
    rangeActivationTiers = {5, 6, 7},
    supportsparticleTypes = {"MULTI-VORTEX"},
    isAnticyclonic = false,
    supportsphases = {"MAIN", "BIRTH", "DEATH", "VORTEX-BREAKDOWN"},
    wallcloudColorType = "brown",
    behaviorType = "BOTH"
})

-- LARGE MULTIVORTEX

AddUserParticlesAutospawnXT2({
    name = "5TonyEF021",
    subvortsForParticle = true,
    rangeActivationTiers = {2, 3, 4},
    supportsparticleTypes = {"NORMAL"},
    isAnticyclonic = false,
    supportsphases = {"MAIN", "BIRTH", "DEATH"},
    wallcloudColorType = "brown",
    behaviorType = "WEAK"
})

AddUserParticlesAutospawnXT2({
    name = "5TonyEF12",
    subvortsForParticle = true,
    rangeActivationTiers = {3, 4, 5},
    supportsparticleTypes = {"NORMAL"},
    isAnticyclonic = false,
    supportsphases = {"MAIN", "BIRTH", "DEATH"},
    wallcloudColorType = "brown",
    behaviorType = "WEAK"
})

AddUserParticlesAutospawnXT2({
    name = "5TonyEF220",
    subvortsForParticle = true,
    rangeActivationTiers = {5, 6},
    supportsparticleTypes = {"MULTI-VORTEX"},
    isAnticyclonic = false,
    supportsphases = {"MAIN", "BIRTH", "DEATH", "VORTEX-BREAKDOWN"},
    wallcloudColorType = "brown",
    behaviorType = "BOTH"
})

AddUserParticlesAutospawnXT2({
    name = "5TonyEF311",
    subvortsForParticle = true,
    rangeActivationTiers = {3, 4, 5},
    supportsparticleTypes = {"NORMAL"},
    isAnticyclonic = false,
    supportsphases = {"MAIN"},
    wallcloudColorType = "brown",
    behaviorType = "BOTH"
})

AddUserParticlesAutospawnXT2({
    name = "5TonyEF4",
    subvortsForParticle = true,
    rangeActivationTiers = {5, 6},
    supportsparticleTypes = {"MULTI-VORTEX"},
    isAnticyclonic = false,
    supportsphases = {"MAIN", "BIRTH", "DEATH", "VORTEX-BREAKDOWN"},
    wallcloudColorType = "brown",
    behaviorType = "BOTH"
})

AddUserParticlesAutospawnXT2({
    name = "5TonyEF54",
    subvortsForParticle = true,
    rangeActivationTiers = {5, 6},
    supportsparticleTypes = {"MULTI-VORTEX"},
    isAnticyclonic = false,
    supportsphases = {"MAIN", "BIRTH", "DEATH", "VORTEX-BREAKDOWN"},
    wallcloudColorType = "brown",
    behaviorType = "BOTH"
})

AddUserParticlesAutospawnXT2({
    name = "El_Grande",
    subvortsForParticle = true,
    rangeActivationTiers = {7, 8, 9},
    supportsparticleTypes = {"MULTI-VORTEX"},
    isAnticyclonic = false,
    supportsphases = {"MAIN", "BIRTH", "DEATH", "VORTEX-BREAKDOWN"},
    wallcloudColorType = "brown",
    behaviorType = "BOTH"
})

if SERVER then
    timer.Simple(3, function()
        PrintAllParticleGroups()
    end)
end



-- MR WEDGE PARTICLE UPDATE

AddUserParticlesAutospawnXT2({
    name = "v1_f0",
    subvortsForParticle = false,
    rangeActivationTiers = {1, 2},
    supportsparticleTypes = {"NORMAL"},
    isAnticyclonic = false,
    supportsphases = {"MAIN", "BIRTH", "DEATH"},
    wallcloudColorType = "black",
    behaviorType = "WEAK"
})

AddUserParticlesAutospawnXT2({
    name = "v1_f1",
    subvortsForParticle = false,
    rangeActivationTiers = {2},
    supportsparticleTypes = {"NORMAL"},
    isAnticyclonic = false,
    supportsphases = {"MAIN"},
    wallcloudColorType = "black",
    behaviorType = "WEAK"
})

AddUserParticlesAutospawnXT2({
    name = "v1_f2",
    subvortsForParticle = false,
    rangeActivationTiers = {3, 4},
    supportsparticleTypes = {"NORMAL"},
    isAnticyclonic = false,
    supportsphases = {"MAIN"},
    wallcloudColorType = "black",
    behaviorType = "BOTH"
})

AddUserParticlesAutospawnXT2({
    name = "v1_f3",
    subvortsForParticle = false,
    rangeActivationTiers = {2, 3},
    supportsparticleTypes = {"NORMAL"},
    isAnticyclonic = false,
    supportsphases = {"MAIN"},
    wallcloudColorType = "black",
    behaviorType = "VIOLENT"
})

AddUserParticlesAutospawnXT2({
    name = "v1_f4",
    subvortsForParticle = false,
    rangeActivationTiers = {4, 5},
    supportsparticleTypes = {"NORMAL"},
    isAnticyclonic = false,
    supportsphases = {"MAIN"},
    wallcloudColorType = "black",
    behaviorType = "BOTH"
})

AddUserParticlesAutospawnXT2({
    name = "v1_f5",
    subvortsForParticle = false,
    rangeActivationTiers = {2, 3},
    supportsparticleTypes = {"NORMAL"},
    isAnticyclonic = false,
    supportsphases = {"MAIN"},
    wallcloudColorType = "brown",
    behaviorType = "BOTH"
})

AddUserParticlesAutospawnXT2({
    name = "v2_f0",
    subvortsForParticle = false,
    rangeActivationTiers = {2, 3},
    supportsparticleTypes = {"NORMAL"},
    isAnticyclonic = false,
    supportsphases = {"MAIN", "BIRTH", "DEATH"},
    wallcloudColorType = "white",
    behaviorType = "WEAK"
})

AddUserParticlesAutospawnXT2({
    name = "v2_f1",
    subvortsForParticle = false,
    rangeActivationTiers = {2, 3},
    supportsparticleTypes = {"NORMAL"},
    isAnticyclonic = false,
    supportsphases = {"MAIN"},
    wallcloudColorType = "white",
    behaviorType = "BOTH"
})

AddUserParticlesAutospawnXT2({
    name = "v2_f2",
    subvortsForParticle = false,
    rangeActivationTiers = {3, 4},
    supportsparticleTypes = {"NORMAL"},
    isAnticyclonic = false,
    supportsphases = {"MAIN"},
    wallcloudColorType = "white",
    behaviorType = "WEAK"
})

AddUserParticlesAutospawnXT2({
    name = "v2_f3",
    subvortsForParticle = true,
    rangeActivationTiers = {2, 3},
    supportsparticleTypes = {"NORMAL"},
    isAnticyclonic = false,
    supportsphases = {"MAIN"},
    wallcloudColorType = "black",
    behaviorType = "VIOLENT"
})

AddUserParticlesAutospawnXT2({
    name = "v2_f4",
    subvortsForParticle = false,
    rangeActivationTiers = {5},
    supportsparticleTypes = {"NORMAL"},
    isAnticyclonic = false,
    supportsphases = {"MAIN"},
    wallcloudColorType = "black",
    behaviorType = "VIOLENT"
})

AddUserParticlesAutospawnXT2({
    name = "v2_f5",
    subvortsForParticle = false,
    rangeActivationTiers = {4, 5},
    supportsparticleTypes = {"NORMAL"},
    isAnticyclonic = false,
    supportsphases = {"MAIN"},
    wallcloudColorType = "white",
    behaviorType = "VIOLENT"
})

AddUserParticlesAutospawnXT2({
    name = "v3_f0",
    subvortsForParticle = true,
    rangeActivationTiers = {1, 2},
    supportsparticleTypes = {"MULTI-VORTEX"},
    isAnticyclonic = false,
    supportsphases = {"MAIN", "BIRTH", "DEATH", "VORTEX-BREAKDOWN"},
    wallcloudColorType = "white",
    behaviorType = "WEAK"
})

AddUserParticlesAutospawnXT2({
    name = "v3_f1",
    subvortsForParticle = false,
    rangeActivationTiers = {2, 3},
    supportsparticleTypes = {"NORMAL"},
    isAnticyclonic = false,
    supportsphases = {"MAIN", "BIRTH", "DEATH"},
    wallcloudColorType = "black",
    behaviorType = "WEAK"
})

AddUserParticlesAutospawnXT2({
    name = "v3_f2",
    subvortsForParticle = true,
    rangeActivationTiers = {2, 3},
    supportsparticleTypes = {"NORMAL"},
    isAnticyclonic = false,
    supportsphases = {"MAIN", "BIRTH", "DEATH", "VORTEX-BREAKDOWN"},
    wallcloudColorType = "white",
    behaviorType = "WEAK"
})

AddUserParticlesAutospawnXT2({
    name = "v3_f3",
    subvortsForParticle = true,
    rangeActivationTiers = {3, 4},
    supportsparticleTypes = {"NORMAL"},
    isAnticyclonic = false,
    supportsphases = {"MAIN"},
    wallcloudColorType = "black",
    behaviorType = "VIOLENT"
})

AddUserParticlesAutospawnXT2({
    name = "v3_f4",
    subvortsForParticle = false,
    rangeActivationTiers = {4, 5},
    supportsparticleTypes = {"NORMAL"},
    isAnticyclonic = false,
    supportsphases = {"MAIN"},
    wallcloudColorType = "white",
    behaviorType = "BOTH"
})

AddUserParticlesAutospawnXT2({
    name = "v3_f5",
    subvortsForParticle = true,
    rangeActivationTiers = {4, 5},
    supportsparticleTypes = {"MULTI-VORTEX"},
    isAnticyclonic = false,
    supportsphases = {"MAIN", "VORTEX-BREAKDOWN"},
    wallcloudColorType = "black",
    behaviorType = "VIOLENT"
})

AddUserParticlesAutospawnXT2({
    name = "v4_f0",
    subvortsForParticle = false,
    rangeActivationTiers = {3, 4},
    supportsparticleTypes = {"NORMAL"},
    isAnticyclonic = false,
    supportsphases = {"MAIN", "BIRTH", "DEATH", "VORTEX-BREAKDOWN"},
    wallcloudColorType = "white",
    behaviorType = "BOTH"
})

AddUserParticlesAutospawnXT2({
    name = "v4_f1",
    subvortsForParticle = true,
    rangeActivationTiers = {3},
    supportsparticleTypes = {"NORMAL"},
    isAnticyclonic = false,
    supportsphases = {"MAIN", "BIRTH", "DEATH"},
    wallcloudColorType = "white",
    behaviorType = "BOTH"
})

AddUserParticlesAutospawnXT2({
    name = "v4_f2",
    subvortsForParticle = true,
    rangeActivationTiers = {3, 4},
    supportsparticleTypes = {"NORMAL"},
    isAnticyclonic = false,
    supportsphases = {"MAIN", "BIRTH", "DEATH"},
    wallcloudColorType = "black",
    behaviorType = "WEAK"
})

AddUserParticlesAutospawnXT2({
    name = "v4_f3",
    subvortsForParticle = false,
    rangeActivationTiers = {3},
    supportsparticleTypes = {"NORMAL"},
    isAnticyclonic = false,
    supportsphases = {"MAIN"},
    wallcloudColorType = "black",
    behaviorType = "VIOLENT"
})

AddUserParticlesAutospawnXT2({
    name = "v4_f4",
    subvortsForParticle = false,
    rangeActivationTiers = {4, 5},
    supportsparticleTypes = {"NORMAL"},
    isAnticyclonic = false,
    supportsphases = {"MAIN"},
    wallcloudColorType = "black",
    behaviorType = "VIOLENT"
})

AddUserParticlesAutospawnXT2({
    name = "v4_f5",
    subvortsForParticle = false,
    rangeActivationTiers = {5, 6},
    supportsparticleTypes = {"NORMAL"},
    isAnticyclonic = false,
    supportsphases = {"MAIN"},
    wallcloudColorType = "white",
    behaviorType = "VIOLENT"
})

AddUserParticlesAutospawnXT2({
    name = "v5_f2",
    subvortsForParticle = false,
    rangeActivationTiers = {3, 4},
    supportsparticleTypes = {"NORMAL"},
    isAnticyclonic = false,
    supportsphases = {"MAIN"},
    wallcloudColorType = "white",
    behaviorType = "BOTH"
})

AddUserParticlesAutospawnXT2({
    name = "v5_f3",
    subvortsForParticle = false,
    rangeActivationTiers = {3, 4},
    supportsparticleTypes = {"NORMAL"},
    isAnticyclonic = false,
    supportsphases = {"MAIN"},
    wallcloudColorType = "white",
    behaviorType = "VIOLENT"
})

AddUserParticlesAutospawnXT2({
    name = "v5_f4",
    subvortsForParticle = false,
    rangeActivationTiers = {4, 5},
    supportsparticleTypes = {"NORMAL"},
    isAnticyclonic = false,
    supportsphases = {"MAIN"},
    wallcloudColorType = "white",
    behaviorType = "BOTH"
})

AddUserParticlesAutospawnXT2({
    name = "v5_f5",
    subvortsForParticle = false,
    rangeActivationTiers = {4, 5},
    supportsparticleTypes = {"NORMAL"},
    isAnticyclonic = false,
    supportsphases = {"MAIN"},
    wallcloudColorType = "black",
    behaviorType = "BOTH"
})

AddUserParticlesAutospawnXT2({
    name = "v6_f0",
    subvortsForParticle = false,
    rangeActivationTiers = {2, 3},
    supportsparticleTypes = {"NORMAL"},
    isAnticyclonic = false,
    supportsphases = {"MAIN", "DEATH"},
    wallcloudColorType = "white",
    behaviorType = "WEAK"
})

AddUserParticlesAutospawnXT2({
    name = "v6_f1",
    subvortsForParticle = false,
    rangeActivationTiers = {2, 3},
    supportsparticleTypes = {"NORMAL"},
    isAnticyclonic = false,
    supportsphases = {"MAIN"},
    wallcloudColorType = "black",
    behaviorType = "WEAK"
})

AddUserParticlesAutospawnXT2({
    name = "v6_f2",
    subvortsForParticle = false,
    rangeActivationTiers = {2, 3},
    supportsparticleTypes = {"NORMAL"},
    isAnticyclonic = false,
    supportsphases = {"MAIN"},
    wallcloudColorType = "white",
    behaviorType = "BOTH"
})

AddUserParticlesAutospawnXT2({
    name = "v6_f3",
    subvortsForParticle = false,
    rangeActivationTiers = {4, 5},
    supportsparticleTypes = {"NORMAL"},
    isAnticyclonic = false,
    supportsphases = {"MAIN"},
    wallcloudColorType = "black",
    behaviorType = "VIOLENT"
})

AddUserParticlesAutospawnXT2({
    name = "v6_f4",
    subvortsForParticle = false,
    rangeActivationTiers = {4, 5},
    supportsparticleTypes = {"NORMAL"},
    isAnticyclonic = false,
    supportsphases = {"MAIN"},
    wallcloudColorType = "black",
    behaviorType = "VIOLENT"
})

AddUserParticlesAutospawnXT2({
    name = "v6_f5",
    subvortsForParticle = false,
    rangeActivationTiers = {6, 7},
    supportsparticleTypes = {"NORMAL"},
    isAnticyclonic = false,
    supportsphases = {"MAIN"},
    wallcloudColorType = "black",
    behaviorType = "VIOLENT"
})

AddUserParticlesAutospawnXT2({
    name = "v7_f0",
    subvortsForParticle = true,
    rangeActivationTiers = {4, 5},
    supportsparticleTypes = {"NORMAL"},
    isAnticyclonic = false,
    supportsphases = {"MAIN", "BIRTH", "DEATH"},
    wallcloudColorType = "black",
    behaviorType = "BOTH"
})

AddUserParticlesAutospawnXT2({
    name = "v7_f1",
    subvortsForParticle = false,
    rangeActivationTiers = {2, 3},
    supportsparticleTypes = {"NORMAL"},
    isAnticyclonic = false,
    supportsphases = {"MAIN"},
    wallcloudColorType = "white",
    behaviorType = "WEAK"
})

AddUserParticlesAutospawnXT2({
    name = "v7_f2",
    subvortsForParticle = true,
    rangeActivationTiers = {3, 4},
    supportsparticleTypes = {"NORMAL"},
    isAnticyclonic = false,
    supportsphases = {"MAIN"},
    wallcloudColorType = "brown",
    behaviorType = "WEAK"
})

AddUserParticlesAutospawnXT2({
    name = "v7_f3",
    subvortsForParticle = false,
    rangeActivationTiers = {3, 4},
    supportsparticleTypes = {"NORMAL"},
    isAnticyclonic = false,
    supportsphases = {"MAIN"},
    wallcloudColorType = "black",
    behaviorType = "VIOLENT"
})

AddUserParticlesAutospawnXT2({
    name = "v7_f4",
    subvortsForParticle = false,
    rangeActivationTiers = {4, 5},
    supportsparticleTypes = {"NORMAL"},
    isAnticyclonic = false,
    supportsphases = {"MAIN"},
    wallcloudColorType = "white",
    behaviorType = "BOTH"
})

AddUserParticlesAutospawnXT2({
    name = "v8_f0",
    subvortsForParticle = false,
    rangeActivationTiers = {2, 3},
    supportsparticleTypes = {"NORMAL"},
    isAnticyclonic = false,
    supportsphases = {"MAIN", "BIRTH", "DEATH"},
    wallcloudColorType = "black",
    behaviorType = "WEAK"
})

AddUserParticlesAutospawnXT2({
    name = "v8_f1",
    subvortsForParticle = false,
    rangeActivationTiers = {2, 3},
    supportsparticleTypes = {"NORMAL"},
    isAnticyclonic = false,
    supportsphases = {"MAIN"},
    wallcloudColorType = "black",
    behaviorType = "WEAK"
})

AddUserParticlesAutospawnXT2({
    name = "v8_f3",
    subvortsForParticle = false,
    rangeActivationTiers = {5, 6},
    supportsparticleTypes = {"NORMAL"},
    isAnticyclonic = false,
    supportsphases = {"MAIN"},
    wallcloudColorType = "black",
    behaviorType = "BOTH"
})

AddUserParticlesAutospawnXT2({
    name = "v8_f4",
    subvortsForParticle = false,
    rangeActivationTiers = {5, 6},
    supportsparticleTypes = {"NORMAL"},
    isAnticyclonic = false,
    supportsphases = {"MAIN"},
    wallcloudColorType = "black",
    behaviorType = "VIOLENT"
})

AddUserParticlesAutospawnXT2({
    name = "v8_f5",
    subvortsForParticle = true,
    rangeActivationTiers = {4, 5},
    supportsparticleTypes = {"NORMAL"},
    isAnticyclonic = false,
    supportsphases = {"MAIN"},
    wallcloudColorType = "brown",
    behaviorType = "VIOLENT"
})

AddUserParticlesAutospawnXT2({
    name = "v9_f0",
    subvortsForParticle = false,
    rangeActivationTiers = {2, 3},
    supportsparticleTypes = {"NORMAL"},
    isAnticyclonic = false,
    supportsphases = {"MAIN", "BIRTH", "DEATH"},
    wallcloudColorType = "brown",
    behaviorType = "WEAK"
})

AddUserParticlesAutospawnXT2({
    name = "v9_f1",
    subvortsForParticle = true,
    rangeActivationTiers = {2, 3},
    supportsparticleTypes = {"NORMAL"},
    isAnticyclonic = false,
    supportsphases = {"MAIN", "BIRTH", "DEATH"},
    wallcloudColorType = "brown",
    behaviorType = "WEAK"
})

AddUserParticlesAutospawnXT2({
    name = "v9_f2",
    subvortsForParticle = true,
    rangeActivationTiers = {3, 4},
    supportsparticleTypes = {"NORMAL"},
    isAnticyclonic = false,
    supportsphases = {"MAIN", "BIRTH", "DEATH"},
    wallcloudColorType = "white",
    behaviorType = "BOTH"
})

AddUserParticlesAutospawnXT2({
    name = "v9_f3",
    subvortsForParticle = false,
    rangeActivationTiers = {4, 5},
    supportsparticleTypes = {"NORMAL"},
    isAnticyclonic = false,
    supportsphases = {"MAIN"},
    wallcloudColorType = "white",
    behaviorType = "BOTH"
})

AddUserParticlesAutospawnXT2({
    name = "v9_f4",
    subvortsForParticle = false,
    rangeActivationTiers = {5, 6},
    supportsparticleTypes = {"NORMAL"},
    isAnticyclonic = false,
    supportsphases = {"MAIN"},
    wallcloudColorType = "brown",
    behaviorType = "BOTH"
})

AddUserParticlesAutospawnXT2({
    name = "v9_f5",
    subvortsForParticle = true,
    rangeActivationTiers = {4, 5},
    supportsparticleTypes = {"NORMAL"},
    isAnticyclonic = false,
    supportsphases = {"MAIN"},
    wallcloudColorType = "black",
    behaviorType = "VIOLENT"
})

AddUserParticlesAutospawnXT2({
    name = "v10_f0",
    subvortsForParticle = false,
    rangeActivationTiers = {1, 2},
    supportsparticleTypes = {"NORMAL"},
    isAnticyclonic = false,
    supportsphases = {"MAIN", "BIRTH", "DEATH"},
    wallcloudColorType = "white",
    behaviorType = "WEAK"
})

AddUserParticlesAutospawnXT2({
    name = "v10_f1",
    subvortsForParticle = true,
    rangeActivationTiers = {2, 3},
    supportsparticleTypes = {"NORMAL"},
    isAnticyclonic = false,
    supportsphases = {"MAIN", "BIRTH", "DEATH"},
    wallcloudColorType = "black",
    behaviorType = "WEAK"
})

AddUserParticlesAutospawnXT2({
    name = "v10_f2",
    subvortsForParticle = false,
    rangeActivationTiers = {3, 4},
    supportsparticleTypes = {"NORMAL"},
    isAnticyclonic = false,
    supportsphases = {"MAIN"},
    wallcloudColorType = "black",
    behaviorType = "WEAK"
})

AddUserParticlesAutospawnXT2({
    name = "v10_f3",
    subvortsForParticle = false,
    rangeActivationTiers = {4, 5},
    supportsparticleTypes = {"NORMAL"},
    isAnticyclonic = false,
    supportsphases = {"MAIN"},
    wallcloudColorType = "white",
    behaviorType = "BOTH"
})

AddUserParticlesAutospawnXT2({
    name = "v10_f4",
    subvortsForParticle = false,
    rangeActivationTiers = {5, 6},
    supportsparticleTypes = {"NORMAL"},
    isAnticyclonic = false,
    supportsphases = {"MAIN"},
    wallcloudColorType = "brown",
    behaviorType = "BOTH"
})

AddUserParticlesAutospawnXT2({
    name = "v10_f5",
    subvortsForParticle = true,
    rangeActivationTiers = {4, 5},
    supportsparticleTypes = {"NORMAL"},
    isAnticyclonic = false,
    supportsphases = {"MAIN"},
    wallcloudColorType = "black",
    behaviorType = "VIOLENT"
})

AddUserParticlesAutospawnXT2({
    name = "v11_f0",
    subvortsForParticle = false,
    rangeActivationTiers = {1, 2},
    supportsparticleTypes = {"NORMAL"},
    isAnticyclonic = false,
    supportsphases = {"MAIN", "BIRTH", "DEATH"},
    wallcloudColorType = "white",
    behaviorType = "BOTH"
})

AddUserParticlesAutospawnXT2({
    name = "v11_f1",
    subvortsForParticle = false,
    rangeActivationTiers = {2, 3},
    supportsparticleTypes = {"NORMAL"},
    isAnticyclonic = false,
    supportsphases = {"MAIN"},
    wallcloudColorType = "black",
    behaviorType = "WEAK"
})

AddUserParticlesAutospawnXT2({
    name = "v11_f2",
    subvortsForParticle = false,
    rangeActivationTiers = {4, 5},
    supportsparticleTypes = {"NORMAL"},
    isAnticyclonic = false,
    supportsphases = {"MAIN"},
    wallcloudColorType = "white",
    behaviorType = "BOTH"
})

AddUserParticlesAutospawnXT2({
    name = "v11_f3",
    subvortsForParticle = false,
    rangeActivationTiers = {4, 5},
    supportsparticleTypes = {"NORMAL"},
    isAnticyclonic = false,
    supportsphases = {"MAIN"},
    wallcloudColorType = "white",
    behaviorType = "BOTH"
})

AddUserParticlesAutospawnXT2({
    name = "v11_f4",
    subvortsForParticle = false,
    rangeActivationTiers = {5, 6},
    supportsparticleTypes = {"NORMAL"},
    isAnticyclonic = false,
    supportsphases = {"MAIN"},
    wallcloudColorType = "black",
    behaviorType = "VIOLENT"
})

AddUserParticlesAutospawnXT2({
    name = "v11_f5",
    subvortsForParticle = true,
    rangeActivationTiers = {4, 5},
    supportsparticleTypes = {"NORMAL"},
    isAnticyclonic = false,
    supportsphases = {"MAIN"},
    wallcloudColorType = "black",
    behaviorType = "VIOLENT"
})

AddUserParticlesAutospawnXT2({
    name = "v12_f0",
    subvortsForParticle = false,
    rangeActivationTiers = {2, 3},
    supportsparticleTypes = {"NORMAL"},
    isAnticyclonic = false,
    supportsphases = {"MAIN"},
    wallcloudColorType = "black",
    behaviorType = "WEAK"
})

AddUserParticlesAutospawnXT2({
    name = "v12_f1",
    subvortsForParticle = false,
    rangeActivationTiers = {3, 4},
    supportsparticleTypes = {"NORMAL"},
    isAnticyclonic = false,
    supportsphases = {"MAIN"},
    wallcloudColorType = "brown",
    behaviorType = "WEAK"
})

AddUserParticlesAutospawnXT2({
    name = "v12_f2",
    subvortsForParticle = false,
    rangeActivationTiers = {4, 5},
    supportsparticleTypes = {"NORMAL"},
    isAnticyclonic = false,
    supportsphases = {"MAIN"},
    wallcloudColorType = "brown",
    behaviorType = "WEAK"
})

AddUserParticlesAutospawnXT2({
    name = "v12_f3",
    subvortsForParticle = false,
    rangeActivationTiers = {4, 5},
    supportsparticleTypes = {"NORMAL"},
    isAnticyclonic = false,
    supportsphases = {"MAIN"},
    wallcloudColorType = "white",
    behaviorType = "BOTH"
})

AddUserParticlesAutospawnXT2({
    name = "v12_f4",
    subvortsForParticle = true,
    rangeActivationTiers = {5, 6},
    supportsparticleTypes = {"MULTI-VORTEX"},
    isAnticyclonic = false,
    supportsphases = {"MAIN", "BIRTH", "DEATH", "VORTEX-BREAKDOWN"},
    wallcloudColorType = "white",
    behaviorType = "BOTH"
})

AddUserParticlesAutospawnXT2({
    name = "v12_f5",
    subvortsForParticle = false,
    rangeActivationTiers = {5, 6},
    supportsparticleTypes = {"NORMAL"},
    isAnticyclonic = false,
    supportsphases = {"MAIN"},
    wallcloudColorType = "brown",
    behaviorType = "VIOLENT"
})

AddUserParticlesAutospawnXT2({
    name = "v13_f1",
    subvortsForParticle = true,
    rangeActivationTiers = {2, 3},
    supportsparticleTypes = {"NORMAL"},
    isAnticyclonic = false,
    supportsphases = {"MAIN", "BIRTH", "DEATH", "VORTEX-BREAKDOWN"},
    wallcloudColorType = "white",
    behaviorType = "WEAK"
})

AddUserParticlesAutospawnXT2({
    name = "v13_f2",
    subvortsForParticle = false,
    rangeActivationTiers = {4, 5},
    supportsparticleTypes = {"NORMAL"},
    isAnticyclonic = false,
    supportsphases = {"MAIN"},
    wallcloudColorType = "black",
    behaviorType = "BOTH"
})

AddUserParticlesAutospawnXT2({
    name = "v13_f3",
    subvortsForParticle = false,
    rangeActivationTiers = {4, 5},
    supportsparticleTypes = {"NORMAL"},
    isAnticyclonic = false,
    supportsphases = {"MAIN"},
    wallcloudColorType = "brown",
    behaviorType = "BOTH"
})

AddUserParticlesAutospawnXT2({
    name = "v13_f4",
    subvortsForParticle = true,
    rangeActivationTiers = {4, 5},
    supportsparticleTypes = {"NORMAL"},
    isAnticyclonic = false,
    supportsphases = {"MAIN", "BIRTH", "DEATH"},
    wallcloudColorType = "black",
    behaviorType = "BOTH"
})

AddUserParticlesAutospawnXT2({
    name = "v13_f5",
    subvortsForParticle = true,
    rangeActivationTiers = {5, 6},
    supportsparticleTypes = {"MULTI-VORTEX"},
    isAnticyclonic = false,
    supportsphases = {"MAIN", "BIRTH", "DEATH", "VORTEX-BREAKDOWN"},
    wallcloudColorType = "black",
    behaviorType = "BOTH"
})

AddUserParticlesAutospawnXT2({
    name = "v14_f1",
    subvortsForParticle = true,
    rangeActivationTiers = {5, 6},
    supportsparticleTypes = {"MULTI-VORTEX"},
    isAnticyclonic = false,
    supportsphases = {"MAIN", "BIRTH", "DEATH", "VORTEX-BREAKDOWN"},
    wallcloudColorType = "black",
    behaviorType = "WEAK"
})

AddUserParticlesAutospawnXT2({
    name = "v14_f2",
    subvortsForParticle = false,
    rangeActivationTiers = {5, 6},
    supportsparticleTypes = {"NORMAL"},
    isAnticyclonic = false,
    supportsphases = {"MAIN"},
    wallcloudColorType = "brown",
    behaviorType = "BOTH"
})

AddUserParticlesAutospawnXT2({
    name = "v14_f3", -- EL RENO
    subvortsForParticle = true,
    rangeActivationTiers = {7, 8, 9},
    supportsparticleTypes = {"MULTI-VORTEX"},
    isAnticyclonic = false,
    supportsphases = {"MAIN", "VORTEX-BREAKDOWN"},
    wallcloudColorType = "white",
    behaviorType = "BOTH"
})

AddUserParticlesAutospawnXT2({
    name = "v15_f1",
    subvortsForParticle = true,
    rangeActivationTiers = {2, 3},
    supportsparticleTypes = {"MULTI-VORTEX"},
    isAnticyclonic = false,
    supportsphases = {"MAIN", "VORTEX-BREAKDOWN"},
    wallcloudColorType = "white",
    behaviorType = "WEAK"
})

AddUserParticlesAutospawnXT2({
    name = "v15_f2",
    subvortsForParticle = false,
    rangeActivationTiers = {2, 3},
    supportsparticleTypes = {"NORMAL"},
    isAnticyclonic = false,
    supportsphases = {"MAIN"},
    wallcloudColorType = "white",
    behaviorType = "WEAK"
})

AddUserParticlesAutospawnXT2({
    name = "v15_f3",
    subvortsForParticle = false,
    rangeActivationTiers = {5, 6},
    supportsparticleTypes = {"NORMAL"},
    isAnticyclonic = false,
    supportsphases = {"MAIN"},
    wallcloudColorType = "white",
    behaviorType = "BOTH"
})

AddUserParticlesAutospawnXT2({
    name = "v15_f4",
    subvortsForParticle = true,
    rangeActivationTiers = {5, 6},
    supportsparticleTypes = {"MULTI-VORTEX"},
    isAnticyclonic = false,
    supportsphases = {"MAIN", "BIRTH", "DEATH", "VORTEX-BREAKDOWN"},
    wallcloudColorType = "black",
    behaviorType = "BOTH"
})

AddUserParticlesAutospawnXT2({
    name = "v15_f5",
    subvortsForParticle = true,
    rangeActivationTiers = {5, 6},
    supportsparticleTypes = {"NORMAL"},
    isAnticyclonic = false,
    supportsphases = {"MAIN"},
    wallcloudColorType = "white",
    behaviorType = "VIOLENT"
})

AddUserParticlesAutospawnXT2({
    name = "v16_f1",
    subvortsForParticle = false,
    rangeActivationTiers = {2, 3},
    supportsparticleTypes = {"NORMAL"},
    isAnticyclonic = false,
    supportsphases = {"MAIN"},
    wallcloudColorType = "black",
    behaviorType = "WEAK"
})

AddUserParticlesAutospawnXT2({
    name = "v16_f2",
    subvortsForParticle = false,
    rangeActivationTiers = {2, 3},
    supportsparticleTypes = {"NORMAL"},
    isAnticyclonic = false,
    supportsphases = {"MAIN"},
    wallcloudColorType = "white",
    behaviorType = "BOTH"
})

AddUserParticlesAutospawnXT2({
    name = "v16_f3",
    subvortsForParticle = false,
    rangeActivationTiers = {5, 6},
    supportsparticleTypes = {"NORMAL"},
    isAnticyclonic = false,
    supportsphases = {"MAIN"},
    wallcloudColorType = "black",
    behaviorType = "BOTH"
})

AddUserParticlesAutospawnXT2({
    name = "v16_f5",
    subvortsForParticle = false,
    rangeActivationTiers = {6, 7},
    supportsparticleTypes = {"NORMAL"},
    isAnticyclonic = false,
    supportsphases = {"MAIN"},
    wallcloudColorType = "black",
    behaviorType = "VIOLENT"
})

AddUserParticlesAutospawnXT2({
    name = "v17_f2",
    subvortsForParticle = false,
    rangeActivationTiers = {2, 3},
    supportsparticleTypes = {"NORMAL"},
    isAnticyclonic = false,
    supportsphases = {"MAIN"},
    wallcloudColorType = "white",
    behaviorType = "BOTH"
})

AddUserParticlesAutospawnXT2({
    name = "v17_f3",
    subvortsForParticle = false,
    rangeActivationTiers = {4, 5},
    supportsparticleTypes = {"NORMAL"},
    isAnticyclonic = false,
    supportsphases = {"MAIN"},
    wallcloudColorType = "black",
    behaviorType = "VIOLENT"
})

AddUserParticlesAutospawnXT2({
    name = "v17_f4",
    subvortsForParticle = false,
    rangeActivationTiers = {1, 2},
    supportsparticleTypes = {"NORMAL"},
    isAnticyclonic = false,
    supportsphases = {"MAIN"},
    wallcloudColorType = "black",
    behaviorType = "VIOLENT"
})

AddUserParticlesAutospawnXT2({
    name = "v17_f5",
    subvortsForParticle = false,
    rangeActivationTiers = {4, 5},
    supportsparticleTypes = {"NORMAL"},
    isAnticyclonic = false,
    supportsphases = {"MAIN"},
    wallcloudColorType = "white",
    behaviorType = "VIOLENT"
})

AddUserParticlesAutospawnXT2({
    name = "v18_f1",
    subvortsForParticle = true,
    rangeActivationTiers = {1, 2},
    supportsparticleTypes = {"MULTI-VORTEX"},
    isAnticyclonic = false,
    supportsphases = {"MAIN", "BIRTH", "DEATH", "VORTEX-BREAKDOWN"},
    wallcloudColorType = "black",
    behaviorType = "WEAK"
})

AddUserParticlesAutospawnXT2({
    name = "v18_f2",
    subvortsForParticle = true,
    rangeActivationTiers = {4, 5},
    supportsparticleTypes = {"NORMAL"},
    isAnticyclonic = false,
    supportsphases = {"MAIN", "BIRTH", "DEATH", "VORTEX-BREAKDOWN"},
    wallcloudColorType = "black",
    behaviorType = "BOTH"
})

AddUserParticlesAutospawnXT2({
    name = "v18_f4",
    subvortsForParticle = false,
    rangeActivationTiers = {6, 7},
    supportsparticleTypes = {"NORMAL"},
    isAnticyclonic = false,
    supportsphases = {"MAIN"},
    wallcloudColorType = "brown",
    behaviorType = "VIOLENT"
})

AddUserParticlesAutospawnXT2({
    name = "v18_f5",
    subvortsForParticle = false,
    rangeActivationTiers = {6, 7},
    supportsparticleTypes = {"NORMAL"},
    isAnticyclonic = false,
    supportsphases = {"MAIN"},
    wallcloudColorType = "white",
    behaviorType = "VIOLENT"
})

AddUserParticlesAutospawnXT2({
    name = "v19_f1",
    subvortsForParticle = true,
    rangeActivationTiers = {1, 2},
    supportsparticleTypes = {"MULTI-VORTEX"},
    isAnticyclonic = false,
    supportsphases = {"MAIN", "BIRTH", "DEATH", "VORTEX-BREAKDOWN"},
    wallcloudColorType = "white",
    behaviorType = "BOTH"
})

AddUserParticlesAutospawnXT2({
    name = "v19_f4",
    subvortsForParticle = true,
    rangeActivationTiers = {5, 6},
    supportsparticleTypes = {"MULTI-VORTEX"},
    isAnticyclonic = false,
    supportsphases = {"MAIN", "BIRTH", "DEATH", "VORTEX-BREAKDOWN"},
    wallcloudColorType = "white",
    behaviorType = "BOTH"
})

AddUserParticlesAutospawnXT2({
    name = "v19_f5",
    subvortsForParticle = false,
    rangeActivationTiers = {5, 6},
    supportsparticleTypes = {"NORMAL"},
    isAnticyclonic = false,
    supportsphases = {"MAIN"},
    wallcloudColorType = "black",
    behaviorType = "VIOLENT"
})

AddUserParticlesAutospawnXT2({
    name = "v20_f1",
    subvortsForParticle = true,
    rangeActivationTiers = {3, 4},
    supportsparticleTypes = {"NORMAL"},
    isAnticyclonic = false,
    supportsphases = {"MAIN", "BIRTH", "DEATH"},
    wallcloudColorType = "white",
    behaviorType = "WEAK"
})

AddUserParticlesAutospawnXT2({
    name = "v20_f2",
    subvortsForParticle = false,
    rangeActivationTiers = {3, 4},
    supportsparticleTypes = {"NORMAL"},
    isAnticyclonic = false,
    supportsphases = {"MAIN"},
    wallcloudColorType = "black",
    behaviorType = "BOTH"
})

AddUserParticlesAutospawnXT2({
    name = "v20_f3",
    subvortsForParticle = true,
    rangeActivationTiers = {3, 4},
    supportsparticleTypes = {"NORMAL"},
    isAnticyclonic = false,
    supportsphases = {"MAIN", "DEATH"},
    wallcloudColorType = "white",
    behaviorType = "VIOLENT"
})

AddUserParticlesAutospawnXT2({
    name = "v20_f4",
    subvortsForParticle = false,
    rangeActivationTiers = {4, 5},
    supportsparticleTypes = {"NORMAL"},
    isAnticyclonic = false,
    supportsphases = {"MAIN"},
    wallcloudColorType = "white",
    behaviorType = "VIOLENT"
})

AddUserParticlesAutospawnXT2({
    name = "v20_f5",
    subvortsForParticle = false,
    rangeActivationTiers = {4, 5},
    supportsparticleTypes = {"NORMAL"},
    isAnticyclonic = false,
    supportsphases = {"MAIN"},
    wallcloudColorType = "black",
    behaviorType = "VIOLENT"
})

AddUserParticlesAutospawnXT2({
    name = "v21_f1",
    subvortsForParticle = false,
    rangeActivationTiers = {2, 3},
    supportsparticleTypes = {"NORMAL"},
    isAnticyclonic = false,
    supportsphases = {"MAIN", "BIRTH", "DEATH"},
    wallcloudColorType = "black",
    behaviorType = "WEAK"
})

AddUserParticlesAutospawnXT2({
    name = "v21_f2",
    subvortsForParticle = true,
    rangeActivationTiers = {3, 4},
    supportsparticleTypes = {"NORMAL"},
    isAnticyclonic = false,
    supportsphases = {"MAIN"},
    wallcloudColorType = "black",
    behaviorType = "BOTH"
})

AddUserParticlesAutospawnXT2({
    name = "v21_f3",
    subvortsForParticle = false,
    rangeActivationTiers = {3, 4},
    supportsparticleTypes = {"NORMAL"},
    isAnticyclonic = false,
    supportsphases = {"MAIN"},
    wallcloudColorType = "white",
    behaviorType = "VIOLENT"
})

AddUserParticlesAutospawnXT2({
    name = "v21_f4",
    subvortsForParticle = false,
    rangeActivationTiers = {5, 6},
    supportsparticleTypes = {"NORMAL"},
    isAnticyclonic = false,
    supportsphases = {"MAIN"},
    wallcloudColorType = "white",
    behaviorType = "VIOLENT"
})

AddUserParticlesAutospawnXT2({
    name = "v21_f5",
    subvortsForParticle = false,
    rangeActivationTiers = {5, 6},
    supportsparticleTypes = {"NORMAL"},
    isAnticyclonic = false,
    supportsphases = {"MAIN"},
    wallcloudColorType = "black",
    behaviorType = "VIOLENT"
})

AddUserParticlesAutospawnXT2({
    name = "v22_f1",
    subvortsForParticle = true,
    rangeActivationTiers = {2, 3},
    supportsparticleTypes = {"MULTI-VORTEX"},
    isAnticyclonic = false,
    supportsphases = {"MAIN", "VORTEX-BREAKDOWN"},
    wallcloudColorType = "white",
    behaviorType = "WEAK"
})

AddUserParticlesAutospawnXT2({
    name = "v22_f2",
    subvortsForParticle = false,
    rangeActivationTiers = {3, 4},
    supportsparticleTypes = {"NORMAL"},
    isAnticyclonic = false,
    supportsphases = {"MAIN"},
    wallcloudColorType = "black",
    behaviorType = "WEAK"
})

AddUserParticlesAutospawnXT2({
    name = "v22_f4",
    subvortsForParticle = true,
    rangeActivationTiers = {4, 5},
    supportsparticleTypes = {"MULTI-VORTEX"},
    isAnticyclonic = false,
    supportsphases = {"MAIN", "VORTEX-BREAKDOWN"},
    wallcloudColorType = "white",
    behaviorType = "VIOLENT"
})

AddUserParticlesAutospawnXT2({
    name = "v23_f5",
    subvortsForParticle = true,
    rangeActivationTiers = {4, 5},
    supportsparticleTypes = {"MULTI-VORTEX"},
    isAnticyclonic = false,
    supportsphases = {"MAIN", "VORTEX-BREAKDOWN"},
    wallcloudColorType = "black",
    behaviorType = "BOTH"
})

AddUserParticlesAutospawnXT2({
    name = "v24_f3",
    subvortsForParticle = true,
    rangeActivationTiers = {3, 4},
    supportsparticleTypes = {"NORMAL"},
    isAnticyclonic = false,
    supportsphases = {"MAIN", "BIRTH", "DEATH"},
    wallcloudColorType = "brown",
    behaviorType = "BOTH"
})

AddUserParticlesAutospawnXT2({
    name = "v24_f4",
    subvortsForParticle = false,
    rangeActivationTiers = {5, 6},
    supportsparticleTypes = {"NORMAL"},
    isAnticyclonic = false,
    supportsphases = {"MAIN"},
    wallcloudColorType = "white",
    behaviorType = "VIOLENT"
})

AddUserParticlesAutospawnXT2({
    name = "v24_f5",
    subvortsForParticle = true,
    rangeActivationTiers = {3, 4},
    supportsparticleTypes = {"NORMAL"},
    isAnticyclonic = false,
    supportsphases = {"MAIN"},
    wallcloudColorType = "white",
    behaviorType = "VIOLENT"
})

AddUserParticlesAutospawnXT2({
    name = "v25_f4",
    subvortsForParticle = false,
    rangeActivationTiers = {4, 5},
    supportsparticleTypes = {"NORMAL"},
    isAnticyclonic = false,
    supportsphases = {"MAIN"},
    wallcloudColorType = "black",
    behaviorType = "VIOLENT"
})

AddUserParticlesAutospawnXT2({
    name = "v25_f5",
    subvortsForParticle = true,
    rangeActivationTiers = {3, 4},
    supportsparticleTypes = {"MULTI-VORTEX"},
    isAnticyclonic = false,
    supportsphases = {"MAIN", "BIRTH", "DEATH", "VORTEX-BREAKDOWN"},
    wallcloudColorType = "brown",
    behaviorType = "BOTH"
})

AddUserParticlesAutospawnXT2({
    name = "v26_f4",
    subvortsForParticle = false,
    rangeActivationTiers = {6, 7},
    supportsparticleTypes = {"NORMAL"},
    isAnticyclonic = false,
    supportsphases = {"MAIN"},
    wallcloudColorType = "black",
    behaviorType = "VIOLENT"
})

AddUserParticlesAutospawnXT2({
    name = "v26_f5",
    subvortsForParticle = false,
    rangeActivationTiers = {4, 5},
    supportsparticleTypes = {"NORMAL"},
    isAnticyclonic = false,
    supportsphases = {"MAIN"},
    wallcloudColorType = "black",
    behaviorType = "BOTH"
})

AddUserParticlesAutospawnXT2({
    name = "v27_f4",
    subvortsForParticle = false,
    rangeActivationTiers = {5, 6},
    supportsparticleTypes = {"NORMAL"},
    isAnticyclonic = false,
    supportsphases = {"MAIN"},
    wallcloudColorType = "white",
    behaviorType = "VIOLENT"
})

AddUserParticlesAutospawnXT2({
    name = "v27_f5",
    subvortsForParticle = false,
    rangeActivationTiers = {4, 5},
    supportsparticleTypes = {"NORMAL"},
    isAnticyclonic = false,
    supportsphases = {"MAIN"},
    wallcloudColorType = "brown",
    behaviorType = "BOTH"
})

AddUserParticlesAutospawnXT2({
    name = "v28_f4",
    subvortsForParticle = true,
    rangeActivationTiers = {5, 6},
    supportsparticleTypes = {"NORMAL"},
    isAnticyclonic = false,
    supportsphases = {"MAIN"},
    wallcloudColorType = "black",
    behaviorType = "VIOLENT"
})

AddUserParticlesAutospawnXT2({
    name = "v28_f5",
    subvortsForParticle = false,
    rangeActivationTiers = {5, 6},
    supportsparticleTypes = {"NORMAL"},
    isAnticyclonic = false,
    supportsphases = {"MAIN"},
    wallcloudColorType = "white",
    behaviorType = "VIOLENT"
})

AddUserParticlesAutospawnXT2({
    name = "v29_f4",
    subvortsForParticle = true,
    rangeActivationTiers = {5, 6},
    supportsparticleTypes = {"MULTI-VORTEX"},
    isAnticyclonic = false,
    supportsphases = {"MAIN", "VORTEX-BREAKDOWN"},
    wallcloudColorType = "black",
    behaviorType = "VIOLENT"
})

AddUserParticlesAutospawnXT2({
    name = "v29_f5",
    subvortsForParticle = true,
    rangeActivationTiers = {4, 5},
    supportsparticleTypes = {"MULTI-VORTEX"},
    isAnticyclonic = false,
    supportsphases = {"MAIN", "BIRTH", "DEATH", "VORTEX-BREAKDOWN"},
    wallcloudColorType = "black",
    behaviorType = "BOTH"
})

AddUserParticlesAutospawnXT2({
    name = "v30_f4",
    subvortsForParticle = true,
    rangeActivationTiers = {7, 8},
    supportsparticleTypes = {"NORMAL"},
    isAnticyclonic = false,
    supportsphases = {"MAIN"},
    wallcloudColorType = "black",
    behaviorType = "VIOLENT"
})

AddUserParticlesAutospawnXT2({
    name = "v30_f5",
    subvortsForParticle = true,
    rangeActivationTiers = {6, 7},
    supportsparticleTypes = {"MULTI-VORTEX"},
    isAnticyclonic = false,
    supportsphases = {"MAIN", "BIRTH", "DEATH", "VORTEX-BREAKDOWN"},
    wallcloudColorType = "black",
    behaviorType = "BOTH"
})






