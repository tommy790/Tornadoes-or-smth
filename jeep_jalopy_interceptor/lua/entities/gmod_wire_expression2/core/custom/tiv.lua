E2Lib.RegisterExtension("tiv", false, "Allows Expression 2 to interact with Tornado Intercept Vehicles.")

__e2setcost(5)

--- Returns 1 if <this> is a supported Tornado Intercept Vehicle, 0 otherwise
e2function number entity:isTIV()
    if not IsValid(this) then return 0 end
    return (TIV and TIV.IsSupportedVehicle and TIV.IsSupportedVehicle(this)) and 1 or 0
end

--- Returns the current deployment state of <this> TIV (idle, stabilizing, lowering, deploying_spikes, anchored, retracting, raising, lofted)
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
    return TIV.Loft.CalculateStress(spd)
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
