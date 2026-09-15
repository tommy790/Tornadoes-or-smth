E2Lib.RegisterExtension("tiv", false, "Allows Expression 2 to interact with Tornado Intercept Vehicles.")

__e2setcost(5)

--- Returns 1 if <this> is a supported Tornado Intercept Vehicle, 0 otherwise
e2function number entity:isTIV()
    if not IsValid(this) then return 0 end
    return (TIV and TIV.IsSupportedVehicle and TIV.IsSupportedVehicle(this)) and 1 or 0
end

--- Returns the current deployment state of <this> TIV (idle, lowering, deploying_spikes, anchored, retracting, raising, lofted)
e2function string entity:tivState()
    if not IsValid(this) or not TIV or not TIV.IsSupportedVehicle or not TIV.IsSupportedVehicle(this) then return "" end
    local data = TIV.Deploy and TIV.Deploy.GetState and TIV.Deploy.GetState(this)
    return (data and data.state) or "idle"
end

--- Returns 1 if <this> TIV is fully deployed and anchored, 0 otherwise
e2function number entity:tivIsDeployed()
    if not IsValid(this) or not TIV or not TIV.IsSupportedVehicle or not TIV.IsSupportedVehicle(this) then return 0 end
    local data = TIV.Deploy and TIV.Deploy.GetState and TIV.Deploy.GetState(this)
    return (data and data.state == "anchored") and 1 or 0
end

--- Returns 1 if <this> TIV is anchored, 0 otherwise
e2function number entity:tivIsAnchored()
    if not IsValid(this) or not TIV or not TIV.IsSupportedVehicle or not TIV.IsSupportedVehicle(this) then return 0 end
    local data = TIV.Deploy and TIV.Deploy.GetState and TIV.Deploy.GetState(this)
    return (data and data.anchored) and 1 or 0
end

--- Returns 1 if <this> TIV is currently in deploy or retract animation, 0 otherwise
e2function number entity:tivIsTransitioning()
    if not IsValid(this) or not TIV or not TIV.IsSupportedVehicle or not TIV.IsSupportedVehicle(this) then return 0 end
    local data = TIV.Deploy and TIV.Deploy.GetState and TIV.Deploy.GetState(this)
    local state = data and data.state or "idle"
    return (state ~= "idle" and state ~= "anchored") and 1 or 0
end

--- Returns the wind speed at <this> TIV in MPH
e2function number entity:tivWindSpeed()
    if not IsValid(this) or not TIV or not TIV.Wind or not TIV.Wind.GetSpeed then return 0 end
    return TIV.Wind.GetSpeed(this) or 0
end

--- Returns the wind direction vector at <this> TIV
e2function vector entity:tivWindDirection()
    if not IsValid(this) or not TIV or not TIV.Wind or not TIV.Wind.GetDirection then return Vector(1, 0, 0) end
    return TIV.Wind.GetDirection(this) or Vector(1, 0, 0)
end

--- Returns the current wind stress on <this> TIV's anchors (0.0 to 1.0)
e2function number entity:tivStress()
    if not IsValid(this) or not TIV or not TIV.Loft or not TIV.Loft.CalculateStress then return 0 end
    local data = TIV.Deploy and TIV.Deploy.GetState and TIV.Deploy.GetState(this)
    if not data or data.state ~= "anchored" then return 0 end
    local spd = TIV.Wind and TIV.Wind.GetSpeed and TIV.Wind.GetSpeed(this) or 0
    return TIV.Loft.CalculateStress(spd, this)
end

--- Returns the total number of installed spikes on <this> TIV
e2function number entity:tivSpikeCount()
    if not IsValid(this) or not TIV or not TIV.Spikes or not TIV.Spikes.GetCount then return 0 end
    local data = TIV.Deploy and TIV.Deploy.GetState and TIV.Deploy.GetState(this)
    return (data and TIV.Spikes.GetCount(data)) or 0
end

--- Returns the overall spike state (idle, deploying, deployed, retracting, none)
e2function string entity:tivSpikeState()
    if not IsValid(this) or not TIV or not TIV.Spikes or not TIV.Spikes.GetState then return "none" end
    local data = TIV.Deploy and TIV.Deploy.GetState and TIV.Deploy.GetState(this)
    return (data and TIV.Spikes.GetState(data)) or "none"
end

--- Returns 1 if <this> TIV's anchor integrity is intact, 0 if compromised
e2function number entity:tivAnchorIntegrity()
    if not IsValid(this) or not TIV or not TIV.Anchor or not TIV.Anchor.CheckIntegrity then return 1 end
    local data = TIV.Deploy and TIV.Deploy.GetState and TIV.Deploy.GetState(this)
    if not data or data.state ~= "anchored" then return 1 end
    return TIV.Anchor.CheckIntegrity(this, data) and 1 or 0
end

--- Returns 1 if <this> TIV is currently lofted in a tornado, 0 otherwise
e2function number entity:tivIsLofted()
    if not IsValid(this) or not TIV then return 0 end
    local data = TIV.Deploy and TIV.Deploy.GetState and TIV.Deploy.GetState(this)
    return (data and data.state == "lofted") and 1 or 0
end

--- Returns the Wire controller entity associated with <this> TIV (or NULL)
e2function entity entity:tivController()
    if not IsValid(this) then return NULL end
    if IsValid(this.TIVWireController) then return this.TIVWireController end
    if TIV and TIV.Wire and TIV.Wire.Controllers then
        local ctrl = TIV.Wire.Controllers[this:EntIndex()]
        if IsValid(ctrl) then return ctrl end
    end
    return NULL
end

__e2setcost(15)

--- Starts deployment of <this> TIV. Returns 1 if deploy sequence initiated, 0 otherwise
e2function number entity:tivDeploy()
    if not IsValid(this) or not TIV or not TIV.IsSupportedVehicle or not TIV.IsSupportedVehicle(this) then return 0 end
    if not isOwner(self, this) then return self:throw("You do not own this TIV!", 0) end
    local data = TIV.Deploy and TIV.Deploy.GetState and TIV.Deploy.GetState(this)
    if not data or data.state ~= "idle" then return 0 end
    TIV.Deploy.EnsureSpikes(this, data)
    TIV.Deploy.StartDeploy(self.player, this)
    return 1
end

--- Starts retraction of <this> TIV. Returns 1 if retraction initiated, 0 otherwise
e2function number entity:tivRetract()
    if not IsValid(this) or not TIV or not TIV.IsSupportedVehicle or not TIV.IsSupportedVehicle(this) then return 0 end
    if not isOwner(self, this) then return self:throw("You do not own this TIV!", 0) end
    local data = TIV.Deploy and TIV.Deploy.GetState and TIV.Deploy.GetState(this)
    if not data or data.state ~= "anchored" then return 0 end
    TIV.Deploy.StartRetract(self.player, this)
    return 1
end

--- Toggles deployment of <this> TIV. Returns 1 on success, 0 otherwise
e2function number entity:tivToggle()
    if not IsValid(this) or not TIV or not TIV.IsSupportedVehicle or not TIV.IsSupportedVehicle(this) then return 0 end
    if not isOwner(self, this) then return self:throw("You do not own this TIV!", 0) end
    local data = TIV.Deploy and TIV.Deploy.GetState and TIV.Deploy.GetState(this)
    if not data then return 0 end
    if data.state == "idle" then
        TIV.Deploy.EnsureSpikes(this, data)
        TIV.Deploy.StartDeploy(self.player, this)
        return 1
    elseif data.state == "anchored" then
        TIV.Deploy.StartRetract(self.player, this)
        return 1
    end
    return 0
end

--- Emergency stop/abort of <this> TIV deployment or anchoring
e2function number entity:tivEmergencyStop()
    if not IsValid(this) or not TIV or not TIV.IsSupportedVehicle or not TIV.IsSupportedVehicle(this) then return 0 end
    if not isOwner(self, this) then return self:throw("You do not own this TIV!", 0) end
    if TIV.Wire and TIV.Wire.EmergencyStop then
        TIV.Wire.EmergencyStop(this)
        return 1
    end
    return 0
end

--- Emergency reset of <this> TIV systems and spikes
e2function number entity:tivReset()
    if not IsValid(this) or not TIV or not TIV.IsSupportedVehicle or not TIV.IsSupportedVehicle(this) then return 0 end
    if not isOwner(self, this) then return self:throw("You do not own this TIV!", 0) end
    if TIV.Wire and TIV.Wire.Reset then
        TIV.Wire.Reset(this)
        return 1
    end
    return 0
end

__e2setcost(5)

--- Returns the current spendable Intercept points of the driver/owner of <this> TIV
e2function number entity:tivCurrentIntercepts()
    if not IsValid(this) or not TIV then return 0 end
    local driver = this.GetDriver and this:GetDriver() or nil
    if not IsValid(driver) and this.CPPIGetOwner then driver = this:CPPIGetOwner() end
    if not IsValid(driver) then return 0 end
    local prof = TIV.Progression and TIV.Progression.GetPlayerProfile and TIV.Progression.GetPlayerProfile(driver)
    return prof and prof.current_intercepts or 0
end

--- Returns the lifetime total Intercepts earned by the driver/owner of <this> TIV
e2function number entity:tivTotalIntercepts()
    if not IsValid(this) or not TIV then return 0 end
    local driver = this.GetDriver and this:GetDriver() or nil
    if not IsValid(driver) and this.CPPIGetOwner then driver = this:CPPIGetOwner() end
    if not IsValid(driver) then return 0 end
    local prof = TIV.Progression and TIV.Progression.GetPlayerProfile and TIV.Progression.GetPlayerProfile(driver)
    return prof and prof.total_intercepts or 0
end

--- Returns the number of unlocked upgrades for the driver/owner of <this> TIV
e2function number entity:tivUpgradeCount()
    if not IsValid(this) or not TIV then return 0 end
    local driver = this.GetDriver and this:GetDriver() or nil
    if not IsValid(driver) and this.CPPIGetOwner then driver = this:CPPIGetOwner() end
    if not IsValid(driver) then return 0 end
    local prof = TIV.Progression and TIV.Progression.GetPlayerProfile and TIV.Progression.GetPlayerProfile(driver)
    if not prof or not prof.unlocked_upgrades then return 0 end
    local count = 0
    for _, state in pairs(prof.unlocked_upgrades) do
        if state then count = count + 1 end
    end
    return count
end

--- Returns 1 if the driver/owner of <this> TIV has unlocked the specified upgrade <upgradeID>, 0 otherwise
e2function number entity:tivHasUpgrade(string upgradeID)
    if not IsValid(this) or not TIV or not upgradeID then return 0 end
    local driver = this.GetDriver and this:GetDriver() or nil
    if not IsValid(driver) and this.CPPIGetOwner then driver = this:CPPIGetOwner() end
    if not IsValid(driver) then return 0 end
    local prof = TIV.Progression and TIV.Progression.GetPlayerProfile and TIV.Progression.GetPlayerProfile(driver)
    return (prof and prof.unlocked_upgrades and prof.unlocked_upgrades[upgradeID]) and 1 or 0
end

--- Returns the number of armor panels installed on <this> TIV
e2function number entity:tivArmorCount()
    if not IsValid(this) or not TIV then return 0 end
    local stats = this._TIVEffectiveStats
    if stats and stats.total_armor_count then return stats.total_armor_count end
    return (this._TIVArmorProps and #this._TIVArmorProps) or 0
end

--- Returns the kinetic/impact debris protection percentage of <this> TIV (0 to 100)
e2function number entity:tivArmorProtection()
    if not IsValid(this) or not TIV then return 0 end
    local stats = this._TIVEffectiveStats
    return (stats and stats.impact_reduction) and math.Round(stats.impact_reduction * 100) or 0
end

--- Returns the effective loft wind threshold in MPH of <this> TIV (including armor and upgrades)
e2function number entity:tivLoftThreshold()
    if not IsValid(this) or not TIV then return 180 end
    local stats = this._TIVEffectiveStats
    return (stats and stats.effective_loft_mph) or (TIV.Config and TIV.Config.LoftWindThreshold) or 180
end

--- Returns the aerodynamic wind drag resistance scale of <this> TIV (lower = more aerodynamic)
e2function number entity:tivWindResistanceScale()
    if not IsValid(this) or not TIV then return 1 end
    local stats = this._TIVEffectiveStats
    return (stats and stats.wind_force_mult) and math.Round(stats.wind_force_mult, 2) or 1
end
