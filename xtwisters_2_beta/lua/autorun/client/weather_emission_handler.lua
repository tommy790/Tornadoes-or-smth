-- Global variable to check particle emissions, if you want this as a condition for paused game states
-- Do something along the lines of attach particle if GetIsPausedState() ~= true (then no particle emissions lol.), (Makes Sense? Cool!)
-- Example statement if GetIsPausedState ~= true then (attach particle to player for rendering weather)

if CLIENT then
    function GetIsPausedState()
        local IsPaused = gui.IsGameUIVisible()
        if IsPaused == false then
            return false
        elseif IsPaused == true then
            return true
        end
    end

    -- Create a hook to check the paused state continuously
    hook.Add("Think", "CheckPausedState", function()
        GetIsPausedState()
    end)

    -- Call GetIsPausedState initially to set the state
    GetIsPausedState()
end
