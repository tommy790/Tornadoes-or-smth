ENT.Type = "anim"
ENT.Base = "base_gmodentity"
ENT.PrintName = "Wind Vector Handler"
ENT.Spawnable = false

ENT.WindVectors = {}

function ENT:Initialize()
    self:SetNoDraw(true)
    self:SetSolid(SOLID_NONE)
    self:SetMoveType(MOVETYPE_NONE)
end

function ENT:Setup(vortexSize, numWindVectors)
    self.VortexSize = vortexSize
    self.NumWindVectors = numWindVectors
    self:SpawnWindVectors()
end

local heightVector = Vector(0, 0, 15)

function ENT:SpawnWindVectors()

    local vSize = self.VortexSize
    local nWindVec = self.NumWindVectors

    if !vSize or !nWindVec then return end

    local spacing = math.sqrt((math.pi * vSize * vSize) / nWindVec)
    local numPerRow = math.ceil((vSize * 2) / spacing)

    for x = -vSize, vSize, spacing do

        for y = -vSize, vSize, spacing do

            local pos2D = Vector(x, y, 0)

            if pos2D:Length2D() <= vSize then

                local vecEnt = ents.Create("gstorms_windvector")

                if !vecEnt:IsValid() then continue end

                vecEnt:SetPos(self:LocalToWorld(pos2D))
                vecEnt:SetParent(self)
                vecEnt:Spawn()

                table.insert(self.WindVectors, {ent = vecEnt, localPos = pos2D + heightVector})

            end

        end

    end

end
