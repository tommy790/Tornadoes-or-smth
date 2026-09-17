-- Returns a list of failure strings; empty means the stub matches Source.
local function same(v, ex, ey, ez)
    return math.abs(v.x - ex) < 1e-6
       and math.abs(v.y - ey) < 1e-6
       and math.abs(v.z - ez) < 1e-6
end
local function show(v) return string.format("(%.2f,%.2f,%.2f)", v.x, v.y, v.z) end

local checks = {
    { "Angle(0,0,0):Forward()",  __newangle(0,0,0):Forward(),   1,  0,  0 },
    { "Angle(0,0,0):Right()",    __newangle(0,0,0):Right(),     0, -1,  0 },
    { "Angle(0,0,0):Up()",       __newangle(0,0,0):Up(),        0,  0,  1 },
    { "Angle(0,90,0):Forward()", __newangle(0,90,0):Forward(),  0,  1,  0 },
    { "Angle(0,90,0):Right()",   __newangle(0,90,0):Right(),    1,  0,  0 },
    { "Angle(0,0,90):Right()",   __newangle(0,0,90):Right(),    0,  0, -1 },
    { "Angle(90,0,0):Up()",      __newangle(90,0,0):Up(),       1,  0,  0 },
    { "Angle(90,0,0):Forward()", __newangle(90,0,0):Forward(),  0,  0,  1 },
}
local bad = {}
for _, c in ipairs(checks) do
    if not same(c[2], c[3], c[4], c[5]) then
        bad[#bad+1] = string.format("%s -> %s expected (%d,%d,%d)",
            c[1], show(c[2]), c[3], c[4], c[5])
    end
end
return bad
