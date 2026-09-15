if SERVER then return end

local snekGridSize = 64
local snekStartMoveDelay = 0.085
local snekMinMoveDelay = 0.04
local snekInputDelay = 0.055

surface.CreateFont("GSSnekFontLarge", {font = "Tahoma", size = ScreenScale(10), weight = 900, antialias = true})
surface.CreateFont("GSSnekFontSmall", {font = "Tahoma", size = ScreenScale(6), weight = 700, antialias = true})

local GSSnekBg = Color(10, 11, 14, 245)
local GSSnekPanel = Color(18, 20, 24, 245)
local GSSnekGrid = Color(255, 255, 255, 10)
local GSSnekSnake = Color(84, 220, 98, 255)
local GSSnekSnakeHead = Color(142, 255, 150, 255)
local GSSnekFood = Color(255, 72, 72, 255)
local GSSnekText = Color(235, 238, 245, 255)
local GSSnekTextDim = Color(165, 170, 180, 255)

local snekGoalSound = "computer/snek_goal_collection.wav"
local snekDeathSound = "computer/snek_death.wav"
local snekNewBestSound = "computer/snek_new_best.wav"
local snekMusicSound = "computer/snek_music.wav"
local snekSavePath = "gstorms/gstorms_computer/gstorms_snek.json"
local snekMusicLoopTime = 23.5
local snekMusicVolume = 0.6
local GSSnekActivePanel = nil

local function GSCellIndex(x, y)
    return x + (y * snekGridSize)
end

local function GSIsSnekCellFilled(panel, x, y)
    return panel.SnakeMap[GSCellIndex(x, y)] == true
end

local function GSPlaceSnekFood(panel)

    if panel.SnakeCount >= snekGridSize * snekGridSize then
        panel.GameOver = true
        panel.Won = true
        return
    end

    for i = 1, 4096 do

        local x = math.random(snekGridSize)
        local y = math.random(snekGridSize)

        if !GSIsSnekCellFilled(panel, x, y) then
            panel.FoodX = x
            panel.FoodY = y
            return
        end

    end

    for y = 1, snekGridSize do
        for x = 1, snekGridSize do
            if !GSIsSnekCellFilled(panel, x, y) then
                panel.FoodX = x
                panel.FoodY = y
                return
            end
        end
    end

end

local function GSLoadSnekBestScore()

    local data = file.Read(snekSavePath, "DATA")
    if !data then return 0, false end

    local tbl = util.JSONToTable(data)
    if !istable(tbl) then return 0, false end

    return tonumber(tbl.bestScore) or 0, true

end

local function GSSaveSnekBestScore(score)

    file.CreateDir("gstorms")
    file.CreateDir("gstorms/gstorms_computer")
    file.Write(snekSavePath, util.TableToJSON({bestScore = score}, true))

end

local function GSCheckSnekBestScore(panel)

    if panel.Score <= (panel.BestScore or 0) then return end

    local oldBest = panel.BestScore or 0

    panel.BestScore = panel.Score

    GSSaveSnekBestScore(panel.BestScore)

    if panel.HadBestScoreAtRunStart and !panel.NewBestPlayed and panel.Score > oldBest then
        panel.NewBestPlayed = true
        surface.PlaySound(snekNewBestSound)
    end

end

local function GSResetSnek(panel)

    panel.Snake = panel.Snake or {}
    panel.SnakeMap = panel.SnakeMap or {}

    table.Empty(panel.Snake)
    table.Empty(panel.SnakeMap)

    local cx = math.floor(snekGridSize * 0.5)
    local cy = math.floor(snekGridSize * 0.5)

    panel.SnakeCount = 4

    for i = 1, panel.SnakeCount do

        local cell = panel.Snake[i] or {}

        cell.x = cx - i + 1
        cell.y = cy

        panel.Snake[i] = cell
        panel.SnakeMap[GSCellIndex(cell.x, cell.y)] = true

    end

    panel.DirX = 1
    panel.DirY = 0
    panel.NextDirX = 1
    panel.NextDirY = 0

    local bestScore, hasBestScore = GSLoadSnekBestScore()

    panel.Score = 0
    panel.BestScore = bestScore
    panel.HadBestScoreAtRunStart = hasBestScore
    panel.NewBestPlayed = false
    panel.GameOver = false
    panel.Won = false
    panel.NextMove = RealTime() + snekStartMoveDelay
    panel.NextInput = 0

    GSPlaceSnekFood(panel)

end

local function GSQueueSnekDirection(panel, dx, dy)

    if dx == -panel.DirX and dy == -panel.DirY then return end

    panel.NextDirX = dx
    panel.NextDirY = dy

end

local function GSHandleSnekInput(panel)

    local time = RealTime()

    if time < panel.NextInput then return end

    if panel.GameOver then

        if input.IsKeyDown(KEY_R) then
            panel.NextInput = time + 0.18
            GSResetSnek(panel)
        end

        return

    end

    if input.IsKeyDown(KEY_UP) or input.IsKeyDown(KEY_W) then
        GSQueueSnekDirection(panel, 0, -1)
        panel.NextInput = time + snekInputDelay
        return
    end

    if input.IsKeyDown(KEY_DOWN) or input.IsKeyDown(KEY_S) then
        GSQueueSnekDirection(panel, 0, 1)
        panel.NextInput = time + snekInputDelay
        return
    end

    if input.IsKeyDown(KEY_LEFT) or input.IsKeyDown(KEY_A) then
        GSQueueSnekDirection(panel, -1, 0)
        panel.NextInput = time + snekInputDelay
        return
    end

    if input.IsKeyDown(KEY_RIGHT) or input.IsKeyDown(KEY_D) then
        GSQueueSnekDirection(panel, 1, 0)
        panel.NextInput = time + snekInputDelay
        return
    end

end

local function GSMoveSnek(panel)

    panel.DirX = panel.NextDirX
    panel.DirY = panel.NextDirY

    local head = panel.Snake[1]
    local newX = head.x + panel.DirX
    local newY = head.y + panel.DirY

    if newX < 1 or newX > snekGridSize or newY < 1 or newY > snekGridSize then
        surface.PlaySound(snekDeathSound)
        panel.GameOver = true
        return
    end

    local ateFood = newX == panel.FoodX and newY == panel.FoodY
    local tail = panel.Snake[panel.SnakeCount]
    local newIndex = GSCellIndex(newX, newY)

    if panel.SnakeMap[newIndex] and (ateFood or tail.x ~= newX or tail.y ~= newY) then
        surface.PlaySound(snekDeathSound)
        panel.GameOver = true
        return
    end

    if ateFood then
        panel.SnakeCount = panel.SnakeCount + 1
        panel.Snake[panel.SnakeCount] = panel.Snake[panel.SnakeCount] or {}
    else
        panel.SnakeMap[GSCellIndex(tail.x, tail.y)] = nil
    end

    for i = panel.SnakeCount, 2, -1 do

        local dst = panel.Snake[i]
        local src = panel.Snake[i - 1]

        dst.x = src.x
        dst.y = src.y

    end

    head.x = newX
    head.y = newY

    panel.SnakeMap[newIndex] = true

    if ateFood then
        panel.Score = panel.Score + 1
        surface.PlaySound(snekGoalSound)
        GSCheckSnekBestScore(panel)
        GSPlaceSnekFood(panel)
    end

end

local function GSStopSnekMusic(panel)

    if panel.SnekMusic then
        panel.SnekMusic:Stop()
        panel.SnekMusic = nil
    end

    panel.NextMusicLoop = nil

end

function GSStopSnekAppMusic()
    if IsValid(GSSnekActivePanel) then GSStopSnekMusic(GSSnekActivePanel) end
end

local function GSPlaySnekMusic(panel)

    local ply = LocalPlayer()
    if !IsValid(ply) then return end

    panel.SnekMusic = panel.SnekMusic or CreateSound(ply, snekMusicSound)
    panel.SnekMusic:Stop()
    panel.SnekMusic:PlayEx(snekMusicVolume, 100)
    panel.NextMusicLoop = RealTime() + snekMusicLoopTime

end

local function GSUpdateSnekMusic(panel)

    local time = RealTime()

    if !panel.SnekMusic or !panel.NextMusicLoop or time >= panel.NextMusicLoop then
        GSPlaySnekMusic(panel)
    end

end

local function GSThinkSnek(panel)

    if !panel.Snake then GSResetSnek(panel) end

    GSUpdateSnekMusic(panel)
    GSHandleSnekInput(panel)

    if panel.GameOver then return end

    local time = RealTime()

    if time < panel.NextMove then return end

    local moveDelay = math.max(snekMinMoveDelay, snekStartMoveDelay - (panel.Score * 0.0015))

    panel.NextMove = time + moveDelay

    GSMoveSnek(panel)

end

local function GSPaintSnek(panel, w, h)

    surface.SetDrawColor(GSSnekBg)
    surface.DrawRect(0, 0, w, h)

    local topH = 42

    surface.SetDrawColor(GSSnekPanel)
    surface.DrawRect(0, 0, w, topH)

    draw.SimpleText("Snek", "GSSnekFontLarge", 12, topH * 0.5, GSSnekText, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
    draw.SimpleText("Score: " .. tostring(panel.Score or 0) .. "  Best: " .. tostring(panel.BestScore or 0), "GSSnekFontSmall", w - 12, topH * 0.5, GSSnekText, TEXT_ALIGN_RIGHT, TEXT_ALIGN_CENTER)

    local boardAreaH = h - topH
    local cellSize = math.floor(math.min(w * 0.94, boardAreaH * 0.94) / snekGridSize)
    local boardSize = cellSize * snekGridSize
    local boardX = math.floor((w - boardSize) * 0.5)
    local boardY = topH + math.floor((boardAreaH - boardSize) * 0.5)

    surface.SetDrawColor(4, 5, 7, 255)
    surface.DrawRect(boardX, boardY, boardSize, boardSize)

    surface.SetDrawColor(GSSnekGrid)

    for i = 0, snekGridSize do
        local p = boardX + (i * cellSize)
        surface.DrawRect(p, boardY, 1, boardSize)
    end

    for i = 0, snekGridSize do
        local p = boardY + (i * cellSize)
        surface.DrawRect(boardX, p, boardSize, 1)
    end

    if panel.FoodX and panel.FoodY then

        surface.SetDrawColor(GSSnekFood)

        local fx = boardX + ((panel.FoodX - 1) * cellSize)
        local fy = boardY + ((panel.FoodY - 1) * cellSize)

        surface.DrawRect(fx + 1, fy + 1, cellSize - 2, cellSize - 2)

    end

    if panel.Snake then

        for i = panel.SnakeCount, 1, -1 do

            local cell = panel.Snake[i]
            if !cell then continue end

            surface.SetDrawColor(i == 1 and GSSnekSnakeHead or GSSnekSnake)

            local sx = boardX + ((cell.x - 1) * cellSize)
            local sy = boardY + ((cell.y - 1) * cellSize)

            surface.DrawRect(sx + 1, sy + 1, cellSize - 2, cellSize - 2)

        end

    end

    surface.SetDrawColor(255, 255, 255, 70)
    surface.DrawOutlinedRect(boardX, boardY, boardSize, boardSize)

    if panel.GameOver then

        surface.SetDrawColor(0, 0, 0, 190)
        surface.DrawRect(boardX, boardY, boardSize, boardSize)

        local title = panel.Won and "YOU WIN" or "GAME OVER"

        draw.SimpleText(title, "GSSnekFontLarge", w * 0.5, boardY + boardSize * 0.45, GSSnekText, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
        draw.SimpleText("Press R to restart", "GSSnekFontSmall", w * 0.5, boardY + boardSize * 0.53, GSSnekTextDim, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)

    else

        draw.SimpleText("WASD / Arrow Keys", "GSSnekFontSmall", boardX, boardY + boardSize + 8, GSSnekTextDim, TEXT_ALIGN_LEFT, TEXT_ALIGN_TOP)

    end

end

function GSCreateSnekApp()

    local dFrame = vgui.Create("DFrame", GSGetComputerDesktop())
    dFrame:SetTitle("Snek")
    dFrame:SetSizable(false)
    dFrame:SetDeleteOnClose(false)
    dFrame:SetSize(math.max(520, ScrH() * 0.72), math.max(560, ScrH() * 0.78))
    dFrame:SetPos(ScrW() * 0.36, ScrH() * 0.14)

    local dPnl = vgui.Create("DPanel", dFrame)
    dPnl:Dock(FILL)
    dPnl:SetMouseInputEnabled(true)
    dPnl.Paint = GSPaintSnek
    dPnl.Think = GSThinkSnek

    GSSnekActivePanel = dPnl

    GSResetSnek(dPnl)
    GSSetupAppWindowControls(dFrame, 460, 500)

    dFrame.OnDesktopResized = function()
        if dFrame.GSFullscreen and dFrame.GSApplyFullscreen then dFrame:GSApplyFullscreen() end
    end
    
    dFrame.OnClose = function()
        GSStopSnekAppMusic()
        GSCloseApp("Snek")
    end
    
    dFrame:MakePopup()
    dFrame:SetKeyboardInputEnabled(false)
    dFrame:SetMouseInputEnabled(true)
    
    return dFrame

end