/*
                     ░  ░ ░               
             ▒  ░░░   ░░     ░            
         ▒░░░ ░░                   ░      
         ░                           ░▒   
     ▒░                             ░░░   
     ░                                 ░░ 
   ░                                   ░░ 
                          ░░▒▒░░          
                  ░░░░▒▓▓████████▓▒░    ░ 
                  ▒██████████████████▒  ░ 
                 ░▒███████████████████▓   
                 ░░▓███████████████████▓  
                  ░▒▓███████████████████▒ 
                  ▒▓▓█████▒░░▒▒▒▒▓█████░  
                 ░▓███████████████████▓▓▓▒
                ░▓███████████▓▓▓▒▓▓█▓▓▓███
     ▒▒▒▓░      ▓████████▓▓███░░▓███▓▓▓▓ ░
    ░▓▒█▒▒▒░   ░▒████████████▓▓▓█████▓▓▓▒ 
     ▓██▒░▒▓▓░ ░░▓██████████▓▓████████▓▒▒ 
     ░██▒▓▓██▒ ░▒▓███████████████████████ 
      ▒███▓██▒░░░▓█▓██████████████████████
    ▒  ░████▓▒░ ░░▓▓▓▓▓███████████████▓███
         ▒▒▓▓▒▒░░▒▒▓▓▓▓▓▓▓███████▒░░░▒▓▓█ 
         ▒░▒▓▓▒▒▓▓▓▓▒▒▒▓▓▓▒▓▓████████▓▓▓  
        ▒▒▒▓▓▓▒▓▓▒▒▓▓▒▒▒▓▓▓▓████████████  
        ▒▒▓▓▓▓▒▒▒▒▒▓▓▓▓▓▓██▓▓▓██▓░░░░▒▒   
          ▓▓▓▓▒▒▒▒▒▒▓▓█▓▓██▓▒▒░░    ░     
            ▓▓▒▒▒▒▒▓▓▓▓▓▓▓███▒▓▓░░░░▒     
              ▓▓▓▓▓▓▓▓▓▓▓███▓▒▒▒▒▒▒▒▓     
                ▓▓▓▓▓▓▓▓▓▓█▓▒▒▒▒▒▓▓▓      
                 ▓▓▓▒▒▓▓▓▓▓▓▓▒░░░▒▒       
                   ▓▒▒▒▒▒▒▒▓▓▓▓▒▒▒        
                       █▒░▒▒▒▒▓▒▒         
*/
-- ################################################### GENERAL CONSTANTS & HELPERS ###################################################

-- [General] --

local mathMin = math.min
local mathMax = math.max
local mathClamp = math.Clamp
local mathExp = math.exp
local mathSqrt = math.sqrt
local mathFloor = math.floor
local mathAbs = math.abs

local GSGetVortexShapeMod = GSGetVortexShapeMod

local kinematicViscosityAir = 1.5 * 10^-5 -- m^2/s
local kinematicViscosityAir2 = 2 * kinematicViscosityAir
local kinematicViscosityAir6 = 6 * kinematicViscosityAir
local tiny = 1e-8

-- [Burgers-Rott] --

local burgersRottXStar = 1.2564312086 -- Constant computed from iteration (for peak scaling)
local mathPi = math.pi
local twoMathPi = 2 * mathPi

-- [Sullivan] --

local sullivanHCache1 = {} -- inner integral cache
local sullivanHCache2 = {} -- outer integral cache

local sullivanHRes = 32 -- Iteration Control 64 originally, Higher = More Accurate Sim / Resolution
local sullivanHResHalf = sullivanHRes / 2

local sullivanPrecomputedHInf = 37.9043503584 -- H(inf) precomputed by iterating -- H(high value) = this value
local sullivanXStar = 6.2577 -- eta* where tangential peaks -- This is used for solving for H(n) and not physically used since H(sullivanXStar) is precomputed, gonna keep it here just in case I need to find something else using it.
local sullivanAEffNumerator = kinematicViscosityAir2 * sullivanXStar
local invSullivanHInf = 1 / sullivanPrecomputedHInf
local sullivanTangentialScale = 1.1311995735 * invSullivanHInf

-- [Two Celled Transition]

local transitionSpan = 0.1

-- [Additional precomputations]

local invTwoMathPi = 1 / twoMathPi

-- [Sources] --

-- https://profchrisbaker.com/wp-content/uploads/2020/06/tornado-models.pdf
-- https://arc.aiaa.org/doi/abs/10.2514/3.7723?journalCode=aiaaj#:~:text=The%20inner%20cell%20consists%20of,(5)

-- [Helpers] --

local function GSGetUnitRadialAndTangentialXY(dx, dy, distance2D, isAnticyclonic)
    local invLen = 1 / mathMax(distance2D, tiny)
    local radialX, radialY = dx * invLen, dy * invLen

    if isAnticyclonic then
      return radialX, radialY, radialY, -radialX
    end

    return radialX, radialY, -radialY, radialX
end

-- ################################################### BURGERS-ROTT (SINGLE CELL & NON-DIMENSIONAL) ###################################################

local function GSBurgersRottComputeGamma(expArg) return (twoMathPi) / (1 - mathExp(expArg)) end
local function GSBurgersRottTangential(r, r2, gamma, expArg) return (gamma / r) * (1 - mathExp(expArg * r2)) end
local function GSBurgersRottRadial(r, a) return - a * r end
local function GSBurgersRottUpdraft(z, a) return 2 * a * z end

-- ################################################### SULLIVAN VORTEX (TWO CELL & DIMENSIONAL) ####################################################

local function GSQuantKey(x) return mathFloor(x * 100000 + 0.5) end
local function GSSullivanTangential(gamma, eta, ratio) return gamma * eta / ratio end
local function GSSullivanRadial(r, a, expar22v) return -a * r + (kinematicViscosityAir6 / r) * (1 - expar22v) end
local function GSSullivanUpdraft(z, a, expar22v) return 2 * a * z * (1 - 3 * expar22v) end

local function GSSullivanH(x)

    if x >= 6 then return sullivanPrecomputedHInf end

    local kx = GSQuantKey(x)
    local cache = sullivanHCache2[kx]

    if cache then return cache end

    local nOuterRaw = mathFloor(sullivanHResHalf * x)
    local nOuter = mathMax(sullivanHRes, nOuterRaw)

    if (nOuter % 2 == 1) then nOuter = nOuter + 1 end

    local hOuter, sumOuter = x / nOuter, 0

    for i = 0, nOuter do

        local t = i * hOuter
        local kt = GSQuantKey(t)
        local Jt = sullivanHCache1[kt]

        if !Jt then

            local nInnerRaw = mathFloor(sullivanHResHalf * t)
            local nInner = mathMax(sullivanHRes, nInnerRaw)

            if (nInner % 2 == 1) then nInner = nInner + 1 end

            local innerEnd = (t > 0) and nInner or 0
            local hInner, sumInner = (t > 0) and (t / nInner) or 1, 0
            
            for j = 0, innerEnd do
                local tau = j * hInner
                local val = (tau < tiny) and (1 - tau * 0.5 + (tau * tau) / 6 - (tau * tau * tau) / 24) or ((1 - mathExp(-tau)) / tau)
                local w = (j == 0 or j == innerEnd) and 1 or ((j % 2 == 1) and 4 or 2)
            
                sumInner = sumInner + w * val
            end

            Jt = (t > 0) and (sumInner * hInner / 3) or 0

            sullivanHCache1[kt] = Jt

        end

        local integrand = mathExp(-t + 3 * Jt)
        local wOuter = (i == 0 or i == nOuter) and 1 or ((i % 2 == 1) and 4 or 2)

        sumOuter = sumOuter + wOuter * integrand

    end

    local Hx = sumOuter * hOuter / 3

    sullivanHCache2[kx] = Hx

    return Hx

end

-- ################################################### MAIN VORTEX MODEL HANDLING - BURGERS-ROTT & SULLIVAN ####################################################

local transitionHalfSpan = transitionSpan * 0.5
local invTransitionSpan = 1 / transitionSpan
local sullivanDowndraftCutoff = 1.0986122886681098
local burgersRottExpArg = -burgersRottXStar
local burgersRottGammaBase = GSBurgersRottComputeGamma(burgersRottExpArg)
local burgersRottGammaBaseInvTwoPi = burgersRottGammaBase * invTwoMathPi

local function GSBurgersRottComponents(r, r2, z, a, falloffExponent, vortexShapeMod, gamma)
    local vt = mathMin(GSBurgersRottTangential(r, r2, gamma, burgersRottExpArg), 1) ^ falloffExponent
    local ur = mathClamp(GSBurgersRottRadial(r, a) * vortexShapeMod, -1, 1)
    local uz = mathMin(GSBurgersRottUpdraft(z, a), 1) ^ falloffExponent

    return vt, ur, uz
end

local function GSSullivanComponents(r, ratio, ar22v, z, a, falloffExponent, vortexShapeMod, gammaScale)
    local expar22v = mathExp(-ar22v)
    local eta = GSSullivanH(ar22v)

    local vt = mathMin(GSSullivanTangential(sullivanTangentialScale * gammaScale, eta, ratio), 1) ^ falloffExponent
    local ur = mathClamp(GSSullivanRadial(r, a * 20, expar22v) * vortexShapeMod, -1, 1)
    local uzZ = ar22v < sullivanDowndraftCutoff and 1 or z
    local uzRaw = mathClamp(GSSullivanUpdraft(uzZ, a, expar22v), -1, 1)
    local uz = (uzRaw >= 0) and (uzRaw ^ falloffExponent) or -((-uzRaw) ^ falloffExponent)

    return vt, ur, uz
end

function GSVortexModel(dx, dy, distance2D, distanceZ, vortexRMW, zScale, a, twoCelledH, falloffExponent, isAnticyclonic, wt, funnelMaxHeight)
    a = mathMin(a * 0.5, 0.5)

    local vt, ur, uz, t
    local radialX, radialY, tangentialX, tangentialY = GSGetUnitRadialAndTangentialXY(dx, dy, distance2D, isAnticyclonic)
    local vortexShapeMod = GSGetVortexShapeMod(distanceZ, zScale, wt)
    local z = mathMax(1 - (distanceZ / zScale), tiny)
    local gammaScale = (distance2D > vortexRMW and falloffExponent < 1) and (1 / falloffExponent) or 1
    local ratio = mathMax(distance2D / vortexRMW, tiny)
    local ratioSqr = ratio * ratio

    if twoCelledH >= 1 then
        t = 0
    elseif twoCelledH <= 0 then
        t = 1
    else
        local heightFrac = mathClamp(distanceZ / funnelMaxHeight, 0, 1)
        local delta = heightFrac - twoCelledH

        if delta <= -transitionHalfSpan then
            t = 0
        elseif delta >= transitionHalfSpan then
            t = 1
        else
            t = (delta + transitionHalfSpan) * invTransitionSpan
            t = t * t * (3 - 2 * t)
        end
    end

    if t == 0 then
        local burgersGamma = burgersRottGammaBaseInvTwoPi * gammaScale
        vt, ur, uz = GSBurgersRottComponents(ratio, ratioSqr, z, a, falloffExponent, vortexShapeMod, burgersGamma)
    elseif t == 1 then
        local sullivanSqrtTerm = mathSqrt(sullivanAEffNumerator / a)
        local sullivanR = mathMax(ratio * sullivanSqrtTerm, tiny)
        local sullivanAr22v = sullivanXStar * ratioSqr

        vt, ur, uz = GSSullivanComponents(sullivanR, ratio, sullivanAr22v, z, a, falloffExponent, vortexShapeMod, gammaScale)
    else
        local burgersGamma = burgersRottGammaBaseInvTwoPi * gammaScale
        local sullivanSqrtTerm = mathSqrt(sullivanAEffNumerator / a)
        local sullivanR = mathMax(ratio * sullivanSqrtTerm, tiny)
        local sullivanAr22v = sullivanXStar * ratioSqr

        local vt1, ur1, uz1 = GSBurgersRottComponents(ratio, ratioSqr, z, a, falloffExponent, vortexShapeMod, burgersGamma)
        local vt2, ur2, uz2 = GSSullivanComponents(sullivanR, ratio, sullivanAr22v, z, a, falloffExponent, vortexShapeMod, gammaScale)

        vt = vt1 + (vt2 - vt1) * t
        ur = ur1 + (ur2 - ur1) * t
        uz = uz1 + (uz2 - uz1) * t
    end

    local len = mathSqrt((ur * ur) + (vt * vt) + (uz * uz))
    local invLen = 1 / mathMax(len, tiny)
    local vecX = (radialX * ur + tangentialX * vt) * invLen
    local vecY = (radialY * ur + tangentialY * vt) * invLen

    return vt, mathAbs(uz), vecX, vecY, uz * invLen
end