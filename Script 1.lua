--[[
    AC TEST HARNESS v7.2
    Client-harness voor je EIGEN Roblox testgame.

    Nieuw in v7.2:
    - Server-authorized test mode: draai ACTestHarness_Server.lua in
      ServerScriptService en de controls werken altijd voor jouw testers,
      ook buiten Studio. Geen bypass, geen hooks.
    - Gamepass auto-detect: de harness zoekt zelf de pass IDs die in het game
      geconfigureerd staan en laat de server de echte ownership bevestigen.
    - Grotere health bars in de ESP, altijd rood.
    - Fix: passLabel en acLabel waren globals in plaats van upvalues.

    Wat er bewust NIET in zit: gamepass spoofing, silent aim of anti-cheat
    bypass. Dat maakt van een testharness een exploit.
]]

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local TweenService = game:GetService("TweenService")
local MarketplaceService = game:GetService("MarketplaceService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local CoreGui = game:GetService("CoreGui")

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")
local mouse = player:GetMouse()
local GUI_NAME = "ACTH_v72"

local C = {
    bg = Color3.fromRGB(16, 16, 20), panel = Color3.fromRGB(20, 20, 26),
    section = Color3.fromRGB(26, 26, 34), hover = Color3.fromRGB(33, 33, 43),
    border = Color3.fromRGB(50, 50, 62), accent = Color3.fromRGB(94, 130, 255),
    accentDim = Color3.fromRGB(64, 90, 190), text = Color3.fromRGB(232, 232, 240),
    muted = Color3.fromRGB(140, 140, 158), red = Color3.fromRGB(200, 60, 65),
    healthRed = Color3.fromRGB(235, 45, 55),
    green = Color3.fromRGB(55, 160, 80), warn = Color3.fromRGB(220, 180, 60),
    off = Color3.fromRGB(50, 50, 62), on = Color3.fromRGB(60, 110, 220),
}

local CFG = {
    walkSpeed = 50, flySpeed = 60, aimFov = 90, aimSmoothness = 14,
    espMaxDistance = 800, espInfinite = false, showHealthBars = true,
    showTeamColors = true, healthBarWidth = 104, healthBarHeight = 12,
    pollutionLevel = "medium", gamePassIds = {},
}

local STATE = {esp=false, target=false, speed=false, fly=false, noclip=false, mouseTP=false, pass=false, ac=false}
local SESSION = {authorized=false, passes={}, source="niet gecontroleerd"}

local old = playerGui:FindFirstChild(GUI_NAME)
if old then old:Destroy() end

local conns, logs = {}, {}
local gui, panel, content, layout, logLabel
local espFolder, flyVelocity, flyAttachment, aimTarget
local originalWalkSpeed
local stopped = false
local passLabel, passListLabel, passStateLabel, acLabel

local function disconnect(name)
    if conns[name] then pcall(function() conns[name]:Disconnect() end); conns[name] = nil end
end
local function connect(name, signal, callback)
    disconnect(name); conns[name] = signal:Connect(callback); return conns[name]
end
local function disconnectAll()
    for name in pairs(conns) do disconnect(name) end
end
local function log(message)
    local line = ("[%s] %s"):format(os.date("%H:%M:%S"), tostring(message))
    table.insert(logs, line)
    if #logs > 80 then table.remove(logs, 1) end
    if logLabel and logLabel.Parent then
        local visible = {}
        for i = math.max(1, #logs - 8), #logs do table.insert(visible, logs[i]) end
        logLabel.Text = table.concat(visible, "\n")
    end
    print("[ACTH]", message)
end
local function character() return player.Character end
local function root()
    local ch = character(); return ch and ch:FindFirstChild("HumanoidRootPart")
end
local function humanoid()
    local ch = character(); return ch and ch:FindFirstChildOfClass("Humanoid")
end
local function rounded(obj, radius)
    local c = Instance.new("UICorner"); c.CornerRadius = UDim.new(0, radius or 6); c.Parent = obj
end
local function status(label, value)
    label.Text = value and "AAN" or "UIT"; label.TextColor3 = value and C.green or C.muted
end

-- ================= AUTORISATIE (server bepaalt) =================
local function localTestMode()
    return RunService:IsStudio() or game:GetAttribute("AC_TEST_MODE") == true
end

-- Zoekt de gamepass IDs die in het game zelf geconfigureerd staan.
local function discoverPassIds()
    local ids, seen = {}, {}
    local function add(value)
        local id = tonumber(value)
        if id and id > 100 and id % 1 == 0 and not seen[id] then
            seen[id] = true; table.insert(ids, id)
        end
    end
    local roots = {ReplicatedStorage, workspace, player}
    for _, source in ipairs(roots) do
        local ok, items = pcall(function() return source:GetDescendants() end)
        if ok then
            for _, item in ipairs(items) do
                local name = item.Name:lower()
                if name:find("pass", 1, true) then
                    if item:IsA("IntValue") or item:IsA("NumberValue") then add(item.Value)
                    elseif item:IsA("StringValue") then add(item.Value:match("%d%d%d%d+")) end
                    add(item.Name:match("%d%d%d%d+"))
                end
                local attr = item:GetAttribute("GamePassId") or item:GetAttribute("GamepassId")
                if attr then add(attr) end
                if #ids >= 25 then return ids end
            end
        end
    end
    return ids
end

local function fetchSession()
    local discovered = discoverPassIds()
    CFG.gamePassIds = discovered
    local bridge = ReplicatedStorage:FindFirstChild("ACTH_Bridge")
    if bridge and bridge:IsA("RemoteFunction") then
        local ok, result = pcall(function() return bridge:InvokeServer("GetSession", discovered) end)
        if ok and type(result) == "table" then
            SESSION.authorized = result.authorized == true
            SESSION.passes = type(result.passes) == "table" and result.passes or {}
            SESSION.source = SESSION.authorized and "server: tester geautoriseerd" or "server: niet geautoriseerd"
            return true
        end
        SESSION.source = "server bridge gaf geen antwoord"
    else
        SESSION.source = localTestMode() and "lokale testmode (Studio/AC_TEST_MODE)" or "geen server bridge gevonden"
    end
    SESSION.authorized = localTestMode()
    return false
end

local function allowMovement()
    if SESSION.authorized or localTestMode() then return true end
    log("Controls uit: draai ACTestHarness_Server.lua in je eigen game en zet je UserId erin")
    return false
end

-- ================= GUI =================
gui = Instance.new("ScreenGui")
gui.Name = GUI_NAME; gui.ResetOnSpawn = false; gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling; gui.Parent = playerGui
panel = Instance.new("Frame")
panel.Size = UDim2.fromOffset(320, 560); panel.Position = UDim2.new(0, 20, 0.5, -280)
panel.BackgroundColor3 = C.panel; panel.BorderSizePixel = 0; panel.Active = true; panel.Parent = gui; rounded(panel, 10)
local stroke = Instance.new("UIStroke"); stroke.Color = C.border; stroke.Parent = panel
local header = Instance.new("Frame")
header.Size = UDim2.new(1, 0, 0, 36); header.BackgroundColor3 = C.bg; header.BorderSizePixel = 0; header.Active = true; header.Parent = panel; rounded(header, 10)
local title = Instance.new("TextLabel")
title.BackgroundTransparency = 1; title.Size = UDim2.new(1, -75, 0, 19); title.Position = UDim2.fromOffset(10, 3)
title.Font = Enum.Font.GothamBold; title.TextSize = 13; title.TextColor3 = C.text; title.TextXAlignment = Enum.TextXAlignment.Left
title.Text = "AC Test v7.2"; title.Parent = header
local subtitle = Instance.new("TextLabel")
subtitle.BackgroundTransparency = 1; subtitle.Size = UDim2.new(1, -75, 0, 12); subtitle.Position = UDim2.fromOffset(10, 21)
subtitle.Font = Enum.Font.Gotham; subtitle.TextSize = 8; subtitle.TextColor3 = C.muted; subtitle.TextXAlignment = Enum.TextXAlignment.Left
subtitle.Text = "RShift toggle \u00b7 End reset \u00b7 Chevron instellingen"; subtitle.Parent = header
local minButton = Instance.new("TextButton")
minButton.Size = UDim2.fromOffset(22, 22); minButton.Position = UDim2.new(1, -52, 0.5, -11); minButton.BackgroundColor3 = C.section
minButton.Font = Enum.Font.GothamBold; minButton.TextSize = 13; minButton.TextColor3 = C.text; minButton.Text = "\u2212"; minButton.AutoButtonColor = false; minButton.Parent = header; rounded(minButton, 6)
local hideButton = Instance.new("TextButton")
hideButton.Size = UDim2.fromOffset(22, 22); hideButton.Position = UDim2.new(1, -28, 0.5, -11); hideButton.BackgroundColor3 = C.section
hideButton.Font = Enum.Font.GothamBold; hideButton.TextSize = 13; hideButton.TextColor3 = C.text; hideButton.Text = "\u00d7"; hideButton.AutoButtonColor = false; hideButton.Parent = header; rounded(hideButton, 6)
content = Instance.new("ScrollingFrame")
content.Position = UDim2.new(0, 8, 0, 42); content.Size = UDim2.new(1, -16, 1, -50); content.BackgroundTransparency = 1
content.ScrollBarThickness = 3; content.ScrollBarImageColor3 = C.border; content.AutomaticCanvasSize = Enum.AutomaticSize.None; content.Parent = panel
layout = Instance.new("UIListLayout"); layout.Padding = UDim.new(0, 4); layout.SortOrder = Enum.SortOrder.LayoutOrder; layout.Parent = content
connect("canvas", layout:GetPropertyChangedSignal("AbsoluteContentSize"), function() content.CanvasSize = UDim2.fromOffset(0, layout.AbsoluteContentSize.Y + 10) end)

local function toggle(parent, initial, callback)
    local frame = Instance.new("Frame"); frame.Size = UDim2.fromOffset(36, 18); frame.BackgroundColor3 = initial and C.on or C.off; frame.BorderSizePixel = 0; frame.Parent = parent; rounded(frame, 9)
    local knob = Instance.new("Frame"); knob.Size = UDim2.fromOffset(14, 14); knob.Position = initial and UDim2.fromOffset(20, 2) or UDim2.fromOffset(2, 2); knob.BackgroundColor3 = C.text; knob.BorderSizePixel = 0; knob.Parent = frame; rounded(knob, 7)
    local button = Instance.new("TextButton"); button.Size = UDim2.fromScale(1, 1); button.BackgroundTransparency = 1; button.Text = ""; button.ZIndex = 5; button.Parent = frame
    local value, tween = initial, nil
    local function render()
        frame.BackgroundColor3 = value and C.on or C.off
        if tween then tween:Cancel() end
        tween = TweenService:Create(knob, TweenInfo.new(0.12), {Position = value and UDim2.fromOffset(20, 2) or UDim2.fromOffset(2, 2)})
        tween:Play()
    end
    local function set(newValue, fire)
        value = newValue == true; render(); if fire and callback then callback(value) end
    end
    button.MouseButton1Click:Connect(function() set(not value, true) end)
    return {frame=frame, get=function() return value end, set=set}
end

local function module(name, icon, initial, callback)
    local box = Instance.new("Frame"); box.Size = UDim2.new(1, 0, 0, 32); box.BackgroundColor3 = C.section; box.BorderSizePixel = 0; box.ClipsDescendants = true; box.Parent = content; rounded(box, 7)
    local head = Instance.new("Frame"); head.Size = UDim2.new(1, 0, 0, 30); head.BackgroundTransparency = 1; head.Parent = box
    local label = Instance.new("TextLabel"); label.BackgroundTransparency = 1; label.Size = UDim2.new(1, -120, 1, 0); label.Position = UDim2.fromOffset(10, 0); label.Font = Enum.Font.GothamMedium; label.TextSize = 12; label.TextColor3 = C.text; label.TextXAlignment = Enum.TextXAlignment.Left; label.Text = icon .. "  " .. name; label.Parent = head
    local stateLabel = Instance.new("TextLabel"); stateLabel.BackgroundTransparency = 1; stateLabel.Size = UDim2.fromOffset(32, 20); stateLabel.Position = UDim2.new(1, -92, 0.5, -10); stateLabel.Font = Enum.Font.GothamBold; stateLabel.TextSize = 9; stateLabel.TextXAlignment = Enum.TextXAlignment.Center; stateLabel.Parent = head; status(stateLabel, initial)
    local switch = toggle(head, initial, function(value) status(stateLabel, value); if callback then callback(value) end end); switch.frame.Position = UDim2.new(1, -56, 0.5, -9)
    local chevron = Instance.new("TextButton"); chevron.Size = UDim2.fromOffset(24, 24); chevron.Position = UDim2.new(1, -27, 0.5, -12); chevron.BackgroundTransparency = 1; chevron.TextColor3 = C.muted; chevron.Font = Enum.Font.GothamBold; chevron.TextSize = 12; chevron.Text = "\u25b6"; chevron.AutoButtonColor = false; chevron.Parent = head
    local body = Instance.new("Frame"); body.Position = UDim2.fromOffset(0, 30); body.Size = UDim2.new(1, 0, 0, 0); body.BackgroundTransparency = 1; body.Visible = false; body.Parent = box
    local bodyLayout = Instance.new("UIListLayout"); bodyLayout.Padding = UDim.new(0, 4); bodyLayout.SortOrder = Enum.SortOrder.LayoutOrder; bodyLayout.Parent = body
    local expanded = false
    local function resize()
        local height = expanded and bodyLayout.AbsoluteContentSize.Y or 0
        body.Size = UDim2.new(1, 0, 0, height); box.Size = UDim2.new(1, 0, 0, expanded and 30 + height or 32)
        body.Visible = expanded; chevron.Text = expanded and "\u25bc" or "\u25b6"
        task.defer(function() content.CanvasSize = UDim2.fromOffset(0, layout.AbsoluteContentSize.Y + 10) end)
    end
    connect("module_layout_" .. name, bodyLayout:GetPropertyChangedSignal("AbsoluteContentSize"), resize)
    chevron.MouseButton1Click:Connect(function() expanded = not expanded; resize() end)
    local function addLabel(text, height, color)
        local item = Instance.new("TextLabel"); item.BackgroundTransparency = 1; item.Size = UDim2.new(1, -16, 0, height or 18); item.Position = UDim2.fromOffset(8, 0); item.Font = Enum.Font.Gotham; item.TextSize = math.max(9, math.min(12, (height or 18) - 6)); item.TextColor3 = color or C.muted; item.TextXAlignment = Enum.TextXAlignment.Left; item.TextYAlignment = Enum.TextYAlignment.Top; item.TextWrapped = true; item.Text = text; item.Parent = body; return item
    end
    local function addButton(text, color, callback2)
        local button = Instance.new("TextButton"); button.Size = UDim2.new(1, -8, 0, 26); button.BackgroundColor3 = color or C.hover; button.Font = Enum.Font.GothamMedium; button.TextSize = 11; button.TextColor3 = C.text; button.Text = text; button.AutoButtonColor = false; button.Parent = body; rounded(button, 6)
        button.MouseButton1Click:Connect(callback2); return button
    end
    local function addToggleRow(text, initialValue, callback2)
        local row = Instance.new("Frame"); row.BackgroundTransparency = 1; row.Size = UDim2.new(1, -8, 0, 24); row.Position = UDim2.fromOffset(4, 0); row.Parent = body
        local rowLabel = Instance.new("TextLabel"); rowLabel.BackgroundTransparency = 1; rowLabel.Size = UDim2.new(1, -50, 1, 0); rowLabel.Font = Enum.Font.Gotham; rowLabel.TextSize = 10; rowLabel.TextColor3 = C.text; rowLabel.TextXAlignment = Enum.TextXAlignment.Left; rowLabel.Text = text; rowLabel.Parent = row
        local rowToggle = toggle(row, initialValue, callback2); rowToggle.frame.Position = UDim2.new(1, -40, 0.5, -9); return rowToggle
    end
    local function addSlider(text, minValue, maxValue, defaultValue, formatter, callback2)
        local row = Instance.new("Frame"); row.BackgroundTransparency = 1; row.Size = UDim2.new(1, -8, 0, 38); row.Position = UDim2.fromOffset(4, 0); row.Parent = body
        local rowLabel = Instance.new("TextLabel"); rowLabel.BackgroundTransparency = 1; rowLabel.Size = UDim2.new(0.6, -4, 0, 15); rowLabel.Font = Enum.Font.Gotham; rowLabel.TextSize = 10; rowLabel.TextColor3 = C.text; rowLabel.TextXAlignment = Enum.TextXAlignment.Left; rowLabel.Text = text; rowLabel.Parent = row
        local valueLabel = Instance.new("TextLabel"); valueLabel.BackgroundTransparency = 1; valueLabel.Size = UDim2.new(0.4, -4, 0, 15); valueLabel.Position = UDim2.new(0.6, 4, 0, 0); valueLabel.Font = Enum.Font.GothamMedium; valueLabel.TextSize = 10; valueLabel.TextColor3 = C.accent; valueLabel.TextXAlignment = Enum.TextXAlignment.Right; valueLabel.Parent = row
        local track = Instance.new("Frame"); track.Size = UDim2.new(1, 0, 0, 4); track.Position = UDim2.new(0, 0, 1, -11); track.BackgroundColor3 = C.hover; track.BorderSizePixel = 0; track.Parent = row; rounded(track, 2)
        local fill = Instance.new("Frame"); fill.Size = UDim2.fromScale(0, 1); fill.BackgroundColor3 = C.accent; fill.BorderSizePixel = 0; fill.Parent = track; rounded(fill, 2)
        local knob = Instance.new("Frame"); knob.AnchorPoint = Vector2.new(0.5, 0.5); knob.Size = UDim2.fromOffset(12, 12); knob.BackgroundColor3 = C.text; knob.BorderSizePixel = 0; knob.Parent = track; rounded(knob, 6)
        local dragging = false
        local function setAlpha(alpha)
            alpha = math.clamp(alpha, 0, 1); local value = minValue + (maxValue - minValue) * alpha
            valueLabel.Text = formatter(value, alpha >= 0.995); fill.Size = UDim2.fromScale(alpha, 1); knob.Position = UDim2.fromScale(alpha, 0.5)
            if callback2 then callback2(value, alpha >= 0.995) end
        end
        local function alphaAtMouse() return (UserInputService:GetMouseLocation().X - track.AbsolutePosition.X) / math.max(track.AbsoluteSize.X, 1) end
        local function begin(input) if input.UserInputType == Enum.UserInputType.MouseButton1 then dragging = true; setAlpha(alphaAtMouse()) end end
        track.InputBegan:Connect(begin); knob.InputBegan:Connect(begin)
        connect("slider_move_" .. name .. text, UserInputService.InputChanged, function(input) if dragging and input.UserInputType == Enum.UserInputType.MouseMovement then setAlpha(alphaAtMouse()) end end)
        connect("slider_end_" .. name .. text, UserInputService.InputEnded, function(input) if input.UserInputType == Enum.UserInputType.MouseButton1 then dragging = false end end)
        setAlpha((defaultValue - minValue) / (maxValue - minValue)); return row
    end
    return {
        body = body, addLabel = addLabel, addButton = addButton, addToggleRow = addToggleRow, addSlider = addSlider, toggle = switch,
        set = function(value, fire) switch.set(value, false); status(stateLabel, value); if fire ~= false and callback then callback(value) end end,
    }
end

-- ================= ESP =================
local function clearESP() if espFolder then espFolder:Destroy(); espFolder = nil end end
local function refreshESP()
    if not STATE.esp then return end
    clearESP(); local originPart = root(); if not originPart then return end
    espFolder = Instance.new("Folder"); espFolder.Name = "ACTH_ESP"; espFolder.Parent = playerGui
    local barW, barH = CFG.healthBarWidth, CFG.healthBarHeight
    for _, target in ipairs(Players:GetPlayers()) do
        local ch = target.Character
        local targetRoot = ch and ch:FindFirstChild("HumanoidRootPart")
        if target ~= player and targetRoot and (targetRoot.Position - originPart.Position).Magnitude <= CFG.espMaxDistance then
            local distance = (targetRoot.Position - originPart.Position).Magnitude
            local color = (CFG.showTeamColors and target.Team) and target.Team.TeamColor.Color or Color3.fromRGB(200, 200, 200)
            local highlight = Instance.new("Highlight"); highlight.Adornee = ch; highlight.FillColor = color; highlight.FillTransparency = 0.58; highlight.OutlineColor = color; highlight.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop; highlight.Parent = espFolder
            local bill = Instance.new("BillboardGui"); bill.Adornee = targetRoot; bill.Size = UDim2.fromOffset(math.max(160, barW + 40), 26 + barH + 8); bill.StudsOffset = Vector3.new(0, 3.4, 0); bill.AlwaysOnTop = true; bill.MaxDistance = CFG.espMaxDistance; bill.Parent = espFolder
            local label = Instance.new("TextLabel"); label.BackgroundTransparency = 1; label.Size = UDim2.new(1, 0, 0, 22); label.Font = Enum.Font.GothamBold; label.TextSize = 12; label.TextColor3 = color; label.TextStrokeTransparency = 0.3; label.Text = target.DisplayName .. " [" .. math.floor(distance) .. "m]"; label.Parent = bill
            if CFG.showHealthBars then
                local h = ch:FindFirstChildOfClass("Humanoid")
                local ratio = h and math.clamp(h.Health / math.max(h.MaxHealth, 1), 0, 1) or 0
                local bar = Instance.new("Frame"); bar.Size = UDim2.fromOffset(barW, barH); bar.Position = UDim2.new(0.5, -barW / 2, 1, -(barH + 2)); bar.BackgroundColor3 = Color3.fromRGB(28, 28, 34); bar.BackgroundTransparency = 0.15; bar.BorderSizePixel = 0; bar.Parent = bill; rounded(bar, math.floor(barH / 2))
                local barStroke = Instance.new("UIStroke"); barStroke.Color = Color3.fromRGB(10, 10, 12); barStroke.Thickness = 1; barStroke.Transparency = 0.4; barStroke.Parent = bar
                local fill = Instance.new("Frame"); fill.Size = UDim2.fromScale(ratio, 1); fill.BackgroundColor3 = C.healthRed; fill.BorderSizePixel = 0; fill.Parent = bar; rounded(fill, math.floor(barH / 2))
                local hpText = Instance.new("TextLabel"); hpText.BackgroundTransparency = 1; hpText.Size = UDim2.fromScale(1, 1); hpText.Font = Enum.Font.GothamBold; hpText.TextSize = math.max(9, barH - 3); hpText.TextColor3 = C.text; hpText.TextStrokeTransparency = 0.4; hpText.Text = h and (math.floor(h.Health) .. " / " .. math.floor(h.MaxHealth)) or "?"; hpText.ZIndex = 2; hpText.Parent = bar
            end
        end
    end
end

local espModule
espModule = module("ESP", "\ud83d\udc41", false, function(on)
    STATE.esp = on; disconnect("esp_refresh")
    if on then
        local elapsed = 0; refreshESP()
        connect("esp_refresh", RunService.Heartbeat, function(dt) elapsed += dt; if elapsed >= 0.25 then elapsed = 0; refreshESP() end end)
        log("ESP aan")
    else clearESP(); log("ESP uit") end
end)
espModule.addLabel("Spelers, afstand, teamkleur en grote rode health bars.", 24)
espModule.addSlider("Max afstand", 50, 10000, CFG.espMaxDistance, function(v, infinite) return infinite and "\u221e" or math.floor(v) .. "m" end, function(v, infinite) CFG.espInfinite = infinite; CFG.espMaxDistance = infinite and 1e9 or v end)
espModule.addSlider("Health bar breedte", 60, 200, CFG.healthBarWidth, function(v) return math.floor(v) .. "px" end, function(v) CFG.healthBarWidth = math.floor(v); if STATE.esp then refreshESP() end end)
espModule.addSlider("Health bar hoogte", 6, 24, CFG.healthBarHeight, function(v) return math.floor(v) .. "px" end, function(v) CFG.healthBarHeight = math.floor(v); if STATE.esp then refreshESP() end end)
espModule.addToggleRow("Health bars", CFG.showHealthBars, function(v) CFG.showHealthBars = v; if STATE.esp then refreshESP() end end)
espModule.addToggleRow("Team kleuren", CFG.showTeamColors, function(v) CFG.showTeamColors = v; if STATE.esp then refreshESP() end end)

-- ================= TARGET DIAGNOSTIC =================
local fov = Instance.new("Frame"); fov.AnchorPoint = Vector2.new(0.5, 0.5); fov.Position = UDim2.fromScale(0.5, 0.5); fov.BackgroundTransparency = 1; fov.Visible = false; fov.Parent = gui; rounded(fov, 200)
local fovStroke = Instance.new("UIStroke"); fovStroke.Color = Color3.new(1, 1, 1); fovStroke.Transparency = 0.4; fovStroke.Parent = fov
local function findTarget()
    local camera = workspace.CurrentCamera; if not camera then return nil end
    local best, bestDistance, radius = nil, nil, CFG.aimFov * 3
    for _, target in ipairs(Players:GetPlayers()) do
        local ch = target.Character
        local r = ch and ch:FindFirstChild("HumanoidRootPart")
        local h = ch and ch:FindFirstChildOfClass("Humanoid")
        if target ~= player and r and h and h.Health > 0 then
            local point, visible = camera:WorldToViewportPoint(r.Position)
            local distance = (Vector2.new(point.X, point.Y) - camera.ViewportSize / 2).Magnitude
            if visible and distance <= radius and (not bestDistance or distance < bestDistance) then best, bestDistance = target, distance end
        end
    end
    return best
end
local targetModule
targetModule = module("Target diagnostic", "\ud83c\udfaf", false, function(on)
    STATE.target = on; fov.Visible = on; disconnect("target_scan")
    if on then
        fov.Size = UDim2.fromOffset(CFG.aimFov * 3, CFG.aimFov * 3)
        connect("target_scan", RunService.RenderStepped, function() aimTarget = findTarget() end)
        log("Target diagnostic aan")
    else aimTarget = nil; log("Target diagnostic uit") end
end)
targetModule.addLabel("Toont welke target je crosshair zou pakken. Stuurt je camera niet.", 30)
targetModule.addSlider("FOV", 10, 180, CFG.aimFov, function(v) return math.floor(v) .. "\u00b0" end, function(v) CFG.aimFov = v; if STATE.target then fov.Size = UDim2.fromOffset(v * 3, v * 3) end end)
local targetLabel = targetModule.addLabel("Target: geen", 18, C.accent)
connect("target_label", RunService.Heartbeat, function()
    if targetLabel.Parent then targetLabel.Text = "Target: " .. (aimTarget and aimTarget.DisplayName or "geen") end
end)

-- ================= MOVEMENT =================
local speedModule
speedModule = module("Speed", "\u26a1", false, function(on)
    if on and not allowMovement() then speedModule.set(false, false); return end
    STATE.speed = on; local h = humanoid()
    if h then
        if on then originalWalkSpeed = originalWalkSpeed or h.WalkSpeed; h.WalkSpeed = CFG.walkSpeed
        else h.WalkSpeed = originalWalkSpeed or 16 end
    end
    log(on and ("Speed aan (" .. math.floor(CFG.walkSpeed) .. ")") or "Speed uit")
end)
speedModule.addSlider("WalkSpeed", 16, 200, CFG.walkSpeed, function(v) return math.floor(v) end, function(v) CFG.walkSpeed = v; if STATE.speed then local h = humanoid(); if h then h.WalkSpeed = v end end end)

local flyModule
flyModule = module("Flight", "\ud83d\udd4a", false, function(on)
    if on and not allowMovement() then flyModule.set(false, false); return end
    STATE.fly = on; disconnect("fly")
    if flyVelocity then flyVelocity:Destroy(); flyVelocity = nil end
    if flyAttachment then flyAttachment:Destroy(); flyAttachment = nil end
    local h, r = humanoid(), root()
    if not on then
        if h then h.PlatformStand = false; h.AutoRotate = true end
        log("Flight uit"); return
    end
    if not h or not r then flyModule.set(false, false); log("Flight: character niet klaar"); return end
    h.PlatformStand = true; h.AutoRotate = false
    flyAttachment = Instance.new("Attachment"); flyAttachment.Parent = r
    flyVelocity = Instance.new("LinearVelocity"); flyVelocity.Attachment0 = flyAttachment; flyVelocity.RelativeTo = Enum.ActuatorRelativeTo.World; flyVelocity.MaxForce = math.huge; flyVelocity.Parent = r
    connect("fly", RunService.RenderStepped, function()
        if not flyVelocity or not flyVelocity.Parent then return end
        local camera = workspace.CurrentCamera; if not camera then return end
        local d = Vector3.zero
        if UserInputService:IsKeyDown(Enum.KeyCode.W) then d += camera.CFrame.LookVector end
        if UserInputService:IsKeyDown(Enum.KeyCode.S) then d -= camera.CFrame.LookVector end
        if UserInputService:IsKeyDown(Enum.KeyCode.A) then d -= camera.CFrame.RightVector end
        if UserInputService:IsKeyDown(Enum.KeyCode.D) then d += camera.CFrame.RightVector end
        if UserInputService:IsKeyDown(Enum.KeyCode.Space) then d += Vector3.yAxis end
        if UserInputService:IsKeyDown(Enum.KeyCode.LeftShift) then d -= Vector3.yAxis end
        flyVelocity.VectorVelocity = d.Magnitude > 0 and d.Unit * CFG.flySpeed or Vector3.zero
    end)
    log("Flight aan")
end)
flyModule.addLabel("WASD + Space/Shift.", 18)
flyModule.addSlider("Fly speed", 10, 200, CFG.flySpeed, function(v) return math.floor(v) end, function(v) CFG.flySpeed = v end)

local noclipModule
noclipModule = module("Noclip", "\ud83e\uddca", false, function(on)
    if on and not allowMovement() then noclipModule.set(false, false); return end
    STATE.noclip = on; disconnect("noclip")
    if not on then
        local ch = character()
        if ch then for _, item in ipairs(ch:GetDescendants()) do if item:IsA("BasePart") then item.CanCollide = true end end end
        log("Noclip uit"); return
    end
    connect("noclip", RunService.Stepped, function()
        local ch = character()
        if ch then for _, item in ipairs(ch:GetDescendants()) do if item:IsA("BasePart") then item.CanCollide = false end end end
    end)
    log("Noclip aan")
end)
noclipModule.addLabel("Herstelt collision bij uitschakelen.", 18)

local tpModule
tpModule = module("Mouse TP", "\ud83d\udccd", false, function(on)
    if on and not allowMovement() then tpModule.set(false, false); return end
    STATE.mouseTP = on; disconnect("mouse_tp")
    if on then
        connect("mouse_tp", UserInputService.InputBegan, function(input, processed)
            if not processed and input.UserInputType == Enum.UserInputType.MouseButton1 then
                local r = root(); if r and mouse.Hit then r.CFrame = CFrame.new(mouse.Hit.Position + Vector3.new(0, 3, 0)) end
            end
        end)
        log("Mouse TP aan")
    else log("Mouse TP uit") end
end)
tpModule.addLabel("Klik in de wereld om te verplaatsen.", 18)
tpModule.addButton("\ud83d\udccd Eenmalig naar muis", C.hover, function()
    if not allowMovement() then return end
    local r = root()
    if r and mouse.Hit then r.CFrame = CFrame.new(mouse.Hit.Position + Vector3.new(0, 3, 0)); log("Eenmalige TP uitgevoerd") end
end)

-- ================= GAMEPASS DETECTIE =================
local function renderPasses()
    if not passLabel then return end
    if #SESSION.passes > 0 then
        local lines = {}
        for _, entry in ipairs(SESSION.passes) do
            table.insert(lines, (entry.owned and "\u2705 " or "\u2b1c ") .. (entry.name or entry.id) .. " (" .. tostring(entry.id) .. ")")
        end
        passLabel.Text = table.concat(lines, "\n")
        passLabel.Size = UDim2.new(1, -16, 0, 14 * #lines + 6)
        return
    end
    if #CFG.gamePassIds == 0 then
        passLabel.Text = "Geen gamepass IDs gevonden in dit game"
        return
    end
    local lines = {}
    for _, id in ipairs(CFG.gamePassIds) do
        local okOwns, owns = pcall(function() return MarketplaceService:UserOwnsGamePassAsync(player.UserId, id) end)
        table.insert(lines, (okOwns and (owns and "\u2705 " or "\u2b1c ") or "\u26a0 ") .. tostring(id))
    end
    passLabel.Text = table.concat(lines, "\n")
    passLabel.Size = UDim2.new(1, -16, 0, 14 * #lines + 6)
end

local passModule
passModule = module("Gamepass detectie", "\ud83c\udfab", false, function(on)
    STATE.pass = on
    if not on then
        if passLabel then passLabel.Text = "Detectie uit" end
        return
    end
    task.spawn(function()
        fetchSession()
        if passStateLabel then passStateLabel.Text = "Bron: " .. SESSION.source end
        if passListLabel then passListLabel.Text = "Gevonden IDs: " .. (#CFG.gamePassIds > 0 and table.concat(CFG.gamePassIds, ", ") or "geen") end
        renderPasses()
        log("Gamepass detectie: " .. #CFG.gamePassIds .. " IDs, " .. #SESSION.passes .. " server-bevestigd")
    end)
end)
passModule.addLabel("Detecteert de pass IDs die in het game staan en laat de server de echte ownership bevestigen. Geen spoofing.", 42, C.warn)
passStateLabel = passModule.addLabel("Bron: " .. SESSION.source, 18, C.muted)
passLabel = passModule.addLabel("Detectie uit", 20, C.accent)
passListLabel = passModule.addLabel("Gevonden IDs: nog niet gescand", 30, C.muted)
passModule.addButton("\ud83d\udd04 Opnieuw scannen", C.hover, function()
    task.spawn(function()
        fetchSession()
        passStateLabel.Text = "Bron: " .. SESSION.source
        passListLabel.Text = "Gevonden IDs: " .. (#CFG.gamePassIds > 0 and table.concat(CFG.gamePassIds, ", ") or "geen")
        renderPasses()
        log("Gamepass scan opnieuw uitgevoerd")
    end)
end)

-- ================= AC MONITOR =================
local acModule
acModule = module("AC monitor", "\ud83d\udee1", false, function(on)
    STATE.ac = on; disconnect("ac_scan")
    if not on then
        if acLabel then acLabel.Text = "Monitor uit"; acLabel.TextColor3 = C.muted end
        log("AC monitor uit"); return
    end
    local function scan()
        local names = {"Adonis", "HDAdmin", "InfiniteYield", "AntiCheat", "AntiExploit"}
        local found = {}
        for _, name in ipairs(names) do
            if CoreGui:FindFirstChild(name, true) then table.insert(found, name) end
        end
        if acLabel then
            acLabel.Text = #found > 0 and ("Indicatoren: " .. table.concat(found, ", ")) or "Geen bekende client-indicatoren"
            acLabel.TextColor3 = #found > 0 and C.warn or C.green
        end
    end
    scan()
    local elapsed = 0
    connect("ac_scan", RunService.Heartbeat, function(dt) elapsed += dt; if elapsed >= 2 then elapsed = 0; scan() end end)
    log("AC monitor actief, alleen observatie")
end)
acModule.addLabel("Observeert lokaal welke admin/AC systemen aanwezig zijn. Blokkeert niets.", 34, C.warn)
acLabel = acModule.addLabel("Monitor uit", 20, C.muted)
local pollLabel = acModule.addLabel("Log-profiel: " .. CFG.pollutionLevel, 20, C.accent)
local pollRow = Instance.new("Frame"); pollRow.Size = UDim2.new(1, -8, 0, 26); pollRow.BackgroundTransparency = 1; pollRow.Parent = acModule.body
for index, level in ipairs({"low", "medium", "high"}) do
    local b = Instance.new("TextButton")
    b.Size = UDim2.fromOffset(70, 24); b.Position = UDim2.fromOffset((index - 1) * 76, 0)
    b.BackgroundColor3 = level == CFG.pollutionLevel and C.accentDim or C.hover
    b.Font = Enum.Font.GothamMedium; b.TextSize = 10; b.TextColor3 = C.text
    b.Text = level:sub(1, 1):upper() .. level:sub(2); b.AutoButtonColor = false; b.Parent = pollRow; rounded(b, 5)
    b.MouseButton1Click:Connect(function()
        CFG.pollutionLevel = level; pollLabel.Text = "Log-profiel: " .. level
        for _, sibling in ipairs(pollRow:GetChildren()) do
            if sibling:IsA("TextButton") then sibling.BackgroundColor3 = sibling == b and C.accentDim or C.hover end
        end
        log("Log-profiel: " .. level)
    end)
end

-- ================= LOG + ACTIES =================
local logBox = Instance.new("Frame"); logBox.Size = UDim2.new(1, 0, 0, 96); logBox.BackgroundColor3 = C.bg; logBox.BorderSizePixel = 0; logBox.Parent = content; rounded(logBox, 6)
logLabel = Instance.new("TextLabel"); logLabel.Size = UDim2.new(1, -10, 1, -6); logLabel.Position = UDim2.fromOffset(5, 3); logLabel.BackgroundTransparency = 1; logLabel.Font = Enum.Font.Code; logLabel.TextSize = 8; logLabel.TextColor3 = C.muted; logLabel.TextXAlignment = Enum.TextXAlignment.Left; logLabel.TextYAlignment = Enum.TextYAlignment.Top; logLabel.TextWrapped = true; logLabel.Parent = logBox

local actions = Instance.new("Frame"); actions.Size = UDim2.new(1, 0, 0, 30); actions.BackgroundTransparency = 1; actions.Parent = content
local reset = Instance.new("TextButton"); reset.Size = UDim2.new(0.48, -2, 1, 0); reset.BackgroundColor3 = C.hover; reset.Font = Enum.Font.GothamMedium; reset.TextSize = 11; reset.TextColor3 = C.text; reset.Text = "\ud83d\udd01 Alles reset"; reset.AutoButtonColor = false; reset.Parent = actions; rounded(reset, 6)
local kill = Instance.new("TextButton"); kill.Size = UDim2.new(0.48, -2, 1, 0); kill.Position = UDim2.new(0.52, 2, 0, 0); kill.BackgroundColor3 = C.red; kill.Font = Enum.Font.GothamBold; kill.TextSize = 11; kill.TextColor3 = C.text; kill.Text = "\u2620 Sluit harness"; kill.AutoButtonColor = false; kill.Parent = actions; rounded(kill, 6)

local function resetAll()
    espModule.set(false); targetModule.set(false); speedModule.set(false); flyModule.set(false)
    noclipModule.set(false); tpModule.set(false); passModule.set(false); acModule.set(false)
    local h = humanoid()
    if h then h.WalkSpeed = originalWalkSpeed or 16; h.PlatformStand = false; h.AutoRotate = true end
    log("Alles gereset")
end
reset.MouseButton1Click:Connect(resetAll)
kill.MouseButton1Click:Connect(function()
    if stopped then return end
    stopped = true; resetAll(); disconnectAll(); clearESP()
    if gui then gui:Destroy() end
    logLabel = nil
end)

-- ================= DRAG / KEYBINDS =================
local dragging, dragStart, panelStart = false, nil, nil
header.InputBegan:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.MouseButton1 then dragging = true; dragStart = input.Position; panelStart = panel.Position end
end)
UserInputService.InputChanged:Connect(function(input)
    if dragging and input.UserInputType == Enum.UserInputType.MouseMovement then
        local d = input.Position - dragStart
        local cam = workspace.CurrentCamera
        local v = cam and cam.ViewportSize or Vector2.new(1280, 720)
        panel.Position = UDim2.fromOffset(
            math.clamp(panelStart.X.Offset + d.X, -panel.AbsoluteSize.X + 60, v.X - 60),
            math.clamp(panelStart.Y.Offset + d.Y, 0, v.Y - 40)
        )
    end
end)
UserInputService.InputEnded:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.MouseButton1 then dragging = false end
end)

local minimized = false
minButton.MouseButton1Click:Connect(function()
    minimized = not minimized; content.Visible = not minimized
    panel.Size = UDim2.fromOffset(panel.AbsoluteSize.X, minimized and 36 or 560)
    minButton.Text = minimized and "+" or "\u2212"
end)
hideButton.MouseButton1Click:Connect(function() panel.Visible = false end)
connect("keys", UserInputService.InputBegan, function(input, processed)
    if processed then return end
    if input.KeyCode == Enum.KeyCode.RightShift then panel.Visible = not panel.Visible
    elseif input.KeyCode == Enum.KeyCode.End then resetAll(); log("End: alles gereset") end
end)
connect("character", player.CharacterAdded, function(ch)
    originalWalkSpeed = nil
    if STATE.speed then
        local h = ch:WaitForChild("Humanoid", 5)
        if h then originalWalkSpeed = h.WalkSpeed; h.WalkSpeed = CFG.walkSpeed end
    end
    if STATE.fly then flyModule.set(false) end
    if STATE.noclip then noclipModule.set(false) end
end)

-- ================= START =================
log("AC Test Harness v7.2 gestart")
log("RShift = UI toggle | End = reset | Chevron = instellingen")
task.spawn(function()
    fetchSession()
    if passStateLabel then passStateLabel.Text = "Bron: " .. SESSION.source end
    if passListLabel then passListLabel.Text = "Gevonden IDs: " .. (#CFG.gamePassIds > 0 and table.concat(CFG.gamePassIds, ", ") or "geen") end
    log(SESSION.authorized and ("Controls vrijgegeven \u2014 " .. SESSION.source) or ("Controls beperkt \u2014 " .. SESSION.source))
    log(#CFG.gamePassIds .. " gamepass IDs gedetecteerd")
end)
