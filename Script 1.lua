--[[
    AC TEST HARNESS v7.0
    Client-side QA harness for an owned Roblox experience.

    Belangrijk:
    - Geen metatable hooks, remote-injectie, value-corruptie of anti-cheat bypass.
    - Gamepass IDs worden alleen lokaal gecontroleerd met MarketplaceService.
    - Zet game:GetService("RunService"):IsStudio() of het game-attribuut
      "AC_TEST_MODE" aan voor movement test controls in een geautoriseerde test.
]]

-- ================= SERVICES =================
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local TweenService = game:GetService("TweenService")
local MarketplaceService = game:GetService("MarketplaceService")
local CoreGui = game:GetService("CoreGui")

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")
local mouse = player:GetMouse()

-- ================= CONFIG =================
local DEFAULT_IDS = {123456, 654321, 111222}
local CFG = {
    walkSpeed = 50,
    normalSpeed = 16,
    flySpeed = 60,
    aimFov = 90,
    aimSmoothness = 14,
    espMaxDistance = 800,
    espInfinite = false,
    showHealthBars = true,
    showTeamColors = true,
    pollutionLevel = "medium",
    gamePassIds = table.clone(DEFAULT_IDS),
}

local STATE = {
    esp = false,
    aimbot = false,
    speed = false,
    fly = false,
    noclip = false,
    mouseTP = false,
    gamepassCheck = false,
    acMonitor = false,
}

local GUI_NAME = "ACTH_v7"
local oldGui = playerGui:FindFirstChild(GUI_NAME)
if oldGui then oldGui:Destroy() end

local C = {
    bg = Color3.fromRGB(16, 16, 20),
    panel = Color3.fromRGB(20, 20, 26),
    section = Color3.fromRGB(26, 26, 34),
    sectionHover = Color3.fromRGB(33, 33, 43),
    border = Color3.fromRGB(50, 50, 62),
    accent = Color3.fromRGB(94, 130, 255),
    accentDim = Color3.fromRGB(64, 90, 190),
    text = Color3.fromRGB(232, 232, 240),
    muted = Color3.fromRGB(140, 140, 158),
    red = Color3.fromRGB(200, 60, 65),
    green = Color3.fromRGB(55, 160, 80),
    warn = Color3.fromRGB(220, 180, 60),
    toggleOff = Color3.fromRGB(50, 50, 62),
    toggleOn = Color3.fromRGB(60, 110, 220),
}

-- ================= LIFECYCLE / HELPERS =================
local connections = {}
local destroyed = false
local originalWalkSpeed = nil
local flyVelocity = nil
local flyAttachment = nil
local espFolder = nil
local aimTarget = nil
local logLines = {}
local logLabel = nil
local acLabel = nil
local passLabel = nil

local function disconnect(name)
    local connection = connections[name]
    if connection then
        pcall(function() connection:Disconnect() end)
        connections[name] = nil
    end
end

local function connect(name, signal, callback)
    disconnect(name)
    connections[name] = signal:Connect(callback)
    return connections[name]
end

local function disconnectAll()
    for name in pairs(connections) do
        disconnect(name)
    end
end

local function safe(label, callback)
    local ok, result = pcall(callback)
    if not ok then
        warn("[ACTH] " .. tostring(label) .. ": " .. tostring(result))
    end
    return ok, result
end

local function character()
    return player.Character
end

local function rootPart()
    local ch = character()
    return ch and ch:FindFirstChild("HumanoidRootPart")
end

local function humanoid()
    local ch = character()
    return ch and ch:FindFirstChildOfClass("Humanoid")
end

local function isTestEnvironment()
    return RunService:IsStudio() or game:GetAttribute("AC_TEST_MODE") == true
end

local function log(message)
    local line = ("[%s] %s"):format(os.date("%H:%M:%S"), tostring(message))
    table.insert(logLines, line)
    if #logLines > 80 then table.remove(logLines, 1) end
    if logLabel then
        local first = math.max(1, #logLines - 8)
        local visible = {}
        for i = first, #logLines do table.insert(visible, logLines[i]) end
        logLabel.Text = table.concat(visible, "\n")
    end
    print("[ACTH]", message)
end

local function setStatus(status, enabled)
    status.Text = enabled and "AAN" or "UIT"
    status.TextColor3 = enabled and C.green or C.muted
end

local function rounded(instance, radius)
    local corner = Instance.new("UICorner")
    corner.CornerRadius = UDim.new(0, radius or 6)
    corner.Parent = instance
end

local function updateCanvas(content, layout)
    content.CanvasSize = UDim2.fromOffset(0, layout.AbsoluteContentSize.Y + 10)
end

-- ================= GUI FACTORIES =================
local gui = Instance.new("ScreenGui")
gui.Name = GUI_NAME
gui.ResetOnSpawn = false
gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
gui.Parent = playerGui

local panel = Instance.new("Frame")
panel.Name = "Panel"
panel.Size = UDim2.fromOffset(320, 560)
panel.Position = UDim2.new(0, 20, 0.5, -280)
panel.BackgroundColor3 = C.panel
panel.BorderSizePixel = 0
panel.Active = true
panel.Parent = gui
rounded(panel, 10)
local panelStroke = Instance.new("UIStroke")
panelStroke.Color = C.border
panelStroke.Thickness = 1
panelStroke.Parent = panel

local header = Instance.new("Frame")
header.Size = UDim2.new(1, 0, 0, 36)
header.BackgroundColor3 = C.bg
header.BorderSizePixel = 0
header.Active = true
header.Parent = panel
rounded(header, 10)

local title = Instance.new("TextLabel")
title.BackgroundTransparency = 1
title.Size = UDim2.new(1, -75, 0, 19)
title.Position = UDim2.fromOffset(10, 3)
title.Font = Enum.Font.GothamBold
title.TextSize = 13
title.TextXAlignment = Enum.TextXAlignment.Left
title.TextColor3 = C.text
title.Text = "AC Test v7.0"
title.Parent = header

local subtitle = Instance.new("TextLabel")
subtitle.BackgroundTransparency = 1
subtitle.Size = UDim2.new(1, -75, 0, 12)
subtitle.Position = UDim2.fromOffset(10, 21)
subtitle.Font = Enum.Font.Gotham
subtitle.TextSize = 8
subtitle.TextXAlignment = Enum.TextXAlignment.Left
subtitle.TextColor3 = C.muted
subtitle.Text = "RShift toggle · End reset · Chevron instellingen"
subtitle.Parent = header

local minimizeButton = Instance.new("TextButton")
minimizeButton.Size = UDim2.fromOffset(22, 22)
minimizeButton.Position = UDim2.new(1, -52, 0.5, -11)
minimizeButton.BackgroundColor3 = C.section
minimizeButton.Font = Enum.Font.GothamBold
minimizeButton.TextSize = 13
minimizeButton.TextColor3 = C.text
minimizeButton.Text = "−"
minimizeButton.AutoButtonColor = false
minimizeButton.Parent = header
rounded(minimizeButton, 6)

local hideButton = Instance.new("TextButton")
hideButton.Size = UDim2.fromOffset(22, 22)
hideButton.Position = UDim2.new(1, -28, 0.5, -11)
hideButton.BackgroundColor3 = C.section
hideButton.Font = Enum.Font.GothamBold
hideButton.TextSize = 13
hideButton.TextColor3 = C.text
hideButton.Text = "×"
hideButton.AutoButtonColor = false
hideButton.Parent = header
rounded(hideButton, 6)

local content = Instance.new("ScrollingFrame")
content.Name = "Content"
content.BackgroundTransparency = 1
content.Position = UDim2.new(0, 8, 0, 42)
content.Size = UDim2.new(1, -16, 1, -50)
content.ScrollBarThickness = 3
content.ScrollBarImageColor3 = C.border
content.AutomaticCanvasSize = Enum.AutomaticSize.None
content.CanvasSize = UDim2.fromOffset(0, 0)
content.Parent = panel

local layout = Instance.new("UIListLayout")
layout.Padding = UDim.new(0, 4)
layout.SortOrder = Enum.SortOrder.LayoutOrder
layout.Parent = content
connect("canvas", layout:GetPropertyChangedSignal("AbsoluteContentSize"), function()
    updateCanvas(content, layout)
end)

local function makeToggle(parent, initial, callback)
    local frame = Instance.new("Frame")
    frame.Size = UDim2.fromOffset(36, 18)
    frame.BackgroundColor3 = initial and C.toggleOn or C.toggleOff
    frame.BorderSizePixel = 0
    frame.Parent = parent
    rounded(frame, 9)

    local knob = Instance.new("Frame")
    knob.Size = UDim2.fromOffset(14, 14)
    knob.Position = initial and UDim2.fromOffset(20, 2) or UDim2.fromOffset(2, 2)
    knob.BackgroundColor3 = C.text
    knob.BorderSizePixel = 0
    knob.Parent = frame
    rounded(knob, 7)

    local button = Instance.new("TextButton")
    button.Size = UDim2.fromScale(1, 1)
    button.BackgroundTransparency = 1
    button.Text = ""
    button.ZIndex = 5
    button.Parent = frame

    local state = initial
    local tween
    local function render()
        frame.BackgroundColor3 = state and C.toggleOn or C.toggleOff
        if tween then tween:Cancel() end
        tween = TweenService:Create(knob, TweenInfo.new(0.12), {
            Position = state and UDim2.fromOffset(20, 2) or UDim2.fromOffset(2, 2),
        })
        tween:Play()
    end
    local function set(value, fire)
        state = value == true
        render()
        if fire and callback then callback(state) end
    end
    button.MouseButton1Click:Connect(function()
        set(not state, true)
    end)
    return {frame = frame, button = button, get = function() return state end, set = set}
end

local function createModule(name, icon, initial, onChange)
    local box = Instance.new("Frame")
    box.BackgroundColor3 = C.section
    box.BorderSizePixel = 0
    box.Size = UDim2.new(1, 0, 0, 32)
    box.ClipsDescendants = true
    box.Parent = content
    rounded(box, 7)

    local head = Instance.new("Frame")
    head.BackgroundTransparency = 1
    head.Size = UDim2.new(1, 0, 0, 30)
    head.Parent = box

    local label = Instance.new("TextLabel")
    label.BackgroundTransparency = 1
    label.Size = UDim2.new(1, -120, 1, 0)
    label.Position = UDim2.fromOffset(10, 0)
    label.Font = Enum.Font.GothamMedium
    label.TextSize = 12
    label.TextColor3 = C.text
    label.TextXAlignment = Enum.TextXAlignment.Left
    label.Text = icon .. "  " .. name
    label.Parent = head

    local status = Instance.new("TextLabel")
    status.BackgroundTransparency = 1
    status.Size = UDim2.fromOffset(32, 20)
    status.Position = UDim2.new(1, -92, 0.5, -10)
    status.Font = Enum.Font.GothamBold
    status.TextSize = 9
    status.TextXAlignment = Enum.TextXAlignment.Center
    status.Parent = head
    setStatus(status, initial)

    local toggle = makeToggle(head, initial, function(value)
        setStatus(status, value)
        if onChange then onChange(value) end
    end)
    toggle.frame.Position = UDim2.new(1, -56, 0.5, -9)

    local chevron = Instance.new("TextButton")
    chevron.Size = UDim2.fromOffset(24, 24)
    chevron.Position = UDim2.new(1, -27, 0.5, -12)
    chevron.BackgroundTransparency = 1
    chevron.Font = Enum.Font.GothamBold
    chevron.TextSize = 12
    chevron.TextColor3 = C.muted
    chevron.Text = "▶"
    chevron.AutoButtonColor = false
    chevron.Parent = head

    local body = Instance.new("Frame")
    body.BackgroundTransparency = 1
    body.Size = UDim2.new(1, 0, 0, 0)
    body.Position = UDim2.fromOffset(0, 30)
    body.Visible = false
    body.Parent = box

    local bodyLayout = Instance.new("UIListLayout")
    bodyLayout.Padding = UDim.new(0, 4)
    bodyLayout.SortOrder = Enum.SortOrder.LayoutOrder
    bodyLayout.Parent = body

    local expanded = false
    local function resize()
        local height = expanded and bodyLayout.AbsoluteContentSize.Y or 0
        body.Size = UDim2.new(1, 0, 0, height)
        box.Size = UDim2.new(1, 0, 0, expanded and 30 + height or 32)
        body.Visible = expanded
        chevron.Text = expanded and "▼" or "▶"
        task.defer(function() updateCanvas(content, layout) end)
    end
    connect("layout_" .. name, bodyLayout:GetPropertyChangedSignal("AbsoluteContentSize"), resize)
    chevron.MouseButton1Click:Connect(function()
        expanded = not expanded
        resize()
    end)

    local function addLabel(text, height, color)
        local item = Instance.new("TextLabel")
        item.BackgroundTransparency = 1
        item.Size = UDim2.new(1, -16, 0, height or 18)
        item.Position = UDim2.fromOffset(8, 0)
        item.Font = Enum.Font.Gotham
        item.TextSize = math.max(9, (height or 18) - 5)
        item.TextColor3 = color or C.muted
        item.TextXAlignment = Enum.TextXAlignment.Left
        item.TextWrapped = true
        item.Text = text
        item.Parent = body
        return item
    end

    local function addSeparator()
        local separator = Instance.new("Frame")
        separator.BackgroundColor3 = C.border
        separator.BorderSizePixel = 0
        separator.Size = UDim2.new(1, -16, 0, 1)
        separator.Position = UDim2.fromOffset(8, 0)
        separator.Parent = body
        return separator
    end

    local function addToggleRow(text, initialValue, callback)
        local row = Instance.new("Frame")
        row.BackgroundTransparency = 1
        row.Size = UDim2.new(1, -8, 0, 24)
        row.Position = UDim2.fromOffset(4, 0)
        row.Parent = body
        local rowLabel = Instance.new("TextLabel")
        rowLabel.BackgroundTransparency = 1
        rowLabel.Size = UDim2.new(1, -50, 1, 0)
        rowLabel.Font = Enum.Font.Gotham
        rowLabel.TextSize = 10
        rowLabel.TextColor3 = C.text
        rowLabel.TextXAlignment = Enum.TextXAlignment.Left
        rowLabel.Text = text
        rowLabel.Parent = row
        local rowToggle = makeToggle(row, initialValue, callback)
        rowToggle.frame.Position = UDim2.new(1, -40, 0.5, -9)
        return rowToggle
    end

    local function addSlider(text, minValue, maxValue, defaultValue, formatter, callback)
        local row = Instance.new("Frame")
        row.BackgroundTransparency = 1
        row.Size = UDim2.new(1, -8, 0, 38)
        row.Position = UDim2.fromOffset(4, 0)
        row.Parent = body

        local rowLabel = Instance.new("TextLabel")
        rowLabel.BackgroundTransparency = 1
        rowLabel.Size = UDim2.new(0.6, -4, 0, 15)
        rowLabel.Font = Enum.Font.Gotham
        rowLabel.TextSize = 10
        rowLabel.TextColor3 = C.text
        rowLabel.TextXAlignment = Enum.TextXAlignment.Left
        rowLabel.Text = text
        rowLabel.Parent = row

        local valueLabel = Instance.new("TextLabel")
        valueLabel.BackgroundTransparency = 1
        valueLabel.Size = UDim2.new(0.4, -4, 0, 15)
        valueLabel.Position = UDim2.new(0.6, 4, 0, 0)
        valueLabel.Font = Enum.Font.GothamMedium
        valueLabel.TextSize = 10
        valueLabel.TextColor3 = C.accent
        valueLabel.TextXAlignment = Enum.TextXAlignment.Right
        valueLabel.Parent = row

        local track = Instance.new("Frame")
        track.BackgroundColor3 = C.sectionHover
        track.BorderSizePixel = 0
        track.Size = UDim2.new(1, 0, 0, 4)
        track.Position = UDim2.new(0, 0, 1, -11)
        track.Parent = row
        rounded(track, 2)

        local fill = Instance.new("Frame")
        fill.BackgroundColor3 = C.accent
        fill.BorderSizePixel = 0
        fill.Size = UDim2.fromScale(0, 1)
        fill.Parent = track
        rounded(fill, 2)

        local knob = Instance.new("Frame")
        knob.AnchorPoint = Vector2.new(0.5, 0.5)
        knob.Size = UDim2.fromOffset(12, 12)
        knob.BackgroundColor3 = C.text
        knob.BorderSizePixel = 0
        knob.Parent = track
        rounded(knob, 6)

        local dragging = false
        local function setFromAlpha(alpha)
            alpha = math.clamp(alpha, 0, 1)
            local value = minValue + (maxValue - minValue) * alpha
            valueLabel.Text = formatter(value, alpha >= 0.995)
            fill.Size = UDim2.fromScale(alpha, 1)
            knob.Position = UDim2.fromScale(alpha, 0.5)
            if callback then callback(value, alpha >= 0.995) end
        end
        local function readAlpha()
            local width = math.max(track.AbsoluteSize.X, 1)
            return (UserInputService:GetMouseLocation().X - track.AbsolutePosition.X) / width
        end
        local function begin(input)
            if input.UserInputType == Enum.UserInputType.MouseButton1 then
                dragging = true
                setFromAlpha(readAlpha())
            end
        end
        track.InputBegan:Connect(begin)
        knob.InputBegan:Connect(begin)
        connect("slider_move_" .. name .. text, UserInputService.InputChanged, function(input)
            if dragging and input.UserInputType == Enum.UserInputType.MouseMovement then
                setFromAlpha(readAlpha())
            end
        end)
        connect("slider_end_" .. name .. text, UserInputService.InputEnded, function(input)
            if input.UserInputType == Enum.UserInputType.MouseButton1 then dragging = false end
        end)
        local alpha = (defaultValue - minValue) / (maxValue - minValue)
        setFromAlpha(alpha)
        return row
    end

    return {
        body = body,
        toggle = toggle,
        status = status,
        addLabel = addLabel,
        addSeparator = addSeparator,
        addToggleRow = addToggleRow,
        addSlider = addSlider,
        set = function(value)
            toggle.set(value, false)
            setStatus(status, value)
        end,
    }
end

-- ================= ESP =================
local function clearESP()
    if espFolder then espFolder:Destroy(); espFolder = nil end
end

local function makeESPEntry(targetPlayer, origin)
    local ch = targetPlayer.Character
    local root = ch and ch:FindFirstChild("HumanoidRootPart")
    if not root then return end
    local distance = (root.Position - origin).Magnitude
    if distance > CFG.espMaxDistance then return end

    local color = Color3.fromRGB(200, 200, 200)
    if CFG.showTeamColors and targetPlayer.Team then color = targetPlayer.Team.TeamColor.Color end

    local highlight = Instance.new("Highlight")
    highlight.Adornee = ch
    highlight.FillColor = color
    highlight.FillTransparency = 0.58
    highlight.OutlineColor = color
    highlight.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop
    highlight.Parent = espFolder

    local billboard = Instance.new("BillboardGui")
    billboard.Adornee = root
    billboard.Size = UDim2.fromOffset(150, 34)
    billboard.StudsOffset = Vector3.new(0, 3.2, 0)
    billboard.AlwaysOnTop = true
    billboard.MaxDistance = CFG.espMaxDistance
    billboard.Parent = espFolder

    local text = Instance.new("TextLabel")
    text.BackgroundTransparency = 1
    text.Size = UDim2.new(1, 0, 0, 20)
    text.Font = Enum.Font.GothamBold
    text.TextSize = 11
    text.TextColor3 = color
    text.TextStrokeTransparency = 0.3
    text.Text = targetPlayer.DisplayName .. " [" .. math.floor(distance) .. "m]"
    text.Parent = billboard

    if CFG.showHealthBars then
        local targetHumanoid = ch:FindFirstChildOfClass("Humanoid")
        local ratio = targetHumanoid and math.clamp(targetHumanoid.Health / math.max(targetHumanoid.MaxHealth, 1), 0, 1) or 0
        local bar = Instance.new("Frame")
        bar.Size = UDim2.fromOffset(60, 4)
        bar.Position = UDim2.new(0.5, -30, 1, -6)
        bar.BackgroundColor3 = Color3.fromRGB(40, 40, 50)
        bar.BorderSizePixel = 0
        bar.Parent = billboard
        rounded(bar, 2)
        local fill = Instance.new("Frame")
        fill.Size = UDim2.fromScale(ratio, 1)
        fill.BackgroundColor3 = ratio > 0.5 and C.green or (ratio > 0.25 and C.warn or C.red)
        fill.BorderSizePixel = 0
        fill.Parent = bar
        rounded(fill, 2)
    end
end

local function refreshESP()
    if not STATE.esp then return end
    clearESP()
    local originPart = rootPart()
    if not originPart then return end
    espFolder = Instance.new("Folder")
    espFolder.Name = "ACTH_ESP"
    espFolder.Parent = playerGui
    local origin = originPart.Position
    for _, targetPlayer in ipairs(Players:GetPlayers()) do
        if targetPlayer ~= player then makeESPEntry(targetPlayer, origin) end
    end
end

local espModule = createModule("ESP", "👁", false, function(enabled)
    STATE.esp = enabled
    disconnect("esp_refresh")
    if enabled then
        refreshESP()
        local elapsed = 0
        connect("esp_refresh", RunService.Heartbeat, function(dt)
            elapsed += dt
            if elapsed >= 0.25 then elapsed = 0; refreshESP() end
        end)
        log("ESP aan")
    else
        clearESP()
        log("ESP uit")
    end
end)
espModule.addLabel("Spelers, afstand, teamkleur en health bars.", 20)
espModule.addSlider("Max afstand", 50, 10000, CFG.espMaxDistance, function(value, infinite)
    return infinite and "∞" or (math.floor(value) .. "m")
end, function(value, infinite)
    CFG.espInfinite = infinite
    CFG.espMaxDistance = infinite and 1e9 or value
end)
espModule.addToggleRow("Health bars", CFG.showHealthBars, function(value)
    CFG.showHealthBars = value
    if STATE.esp then refreshESP() end
end)
espModule.addToggleRow("Team kleuren", CFG.showTeamColors, function(value)
    CFG.showTeamColors = value
    if STATE.esp then refreshESP() end
end)

-- ================= AIM ASSIST / TARGET DIAGNOSTIC =================
local fovCircle = Instance.new("Frame")
fovCircle.Name = "AimFOV"
fovCircle.AnchorPoint = Vector2.new(0.5, 0.5)
fovCircle.Position = UDim2.fromScale(0.5, 0.5)
fovCircle.BackgroundTransparency = 1
fovCircle.Visible = false
fovCircle.Parent = gui
rounded(fovCircle, 200)
local fovStroke = Instance.new("UIStroke")
fovStroke.Color = Color3.fromRGB(255, 255, 255)
fovStroke.Thickness = 1.5
fovStroke.Transparency = 0.4
fovStroke.Parent = fovCircle

local function closestTarget()
    local camera = workspace.CurrentCamera
    if not camera then return nil end
    local best, bestDistance
    local radius = CFG.aimFov * 3
    for _, targetPlayer in ipairs(Players:GetPlayers()) do
        local targetRoot = targetPlayer ~= player and targetPlayer.Character and targetPlayer.Character:FindFirstChild("HumanoidRootPart")
        local targetHumanoid = targetPlayer.Character and targetPlayer.Character:FindFirstChildOfClass("Humanoid")
        if targetRoot and targetHumanoid and targetHumanoid.Health > 0 then
            local point, onScreen = camera:WorldToViewportPoint(targetRoot.Position)
            local distance = (Vector2.new(point.X, point.Y) - camera.ViewportSize / 2).Magnitude
            if onScreen and distance <= radius and (not bestDistance or distance < bestDistance) then
                best, bestDistance = targetPlayer, distance
            end
        end
    end
    return best
end

local aimModule = createModule("Aimbot", "🎯", false, function(enabled)
    STATE.aimbot = enabled
    fovCircle.Visible = enabled
    if enabled then
        fovCircle.Size = UDim2.fromOffset(CFG.aimFov * 3, CFG.aimFov * 3)
        connect("aim_target", RunService.RenderStepped, function()
            aimTarget = closestTarget()
        end)
        log("Target diagnostic aan")
    else
        disconnect("aim_target")
        aimTarget = nil
        log("Target diagnostic uit")
    end
end)
aimModule.addLabel("Toont de dichtstbijzijnde geldige target binnen de FOV.", 20)
aimModule.addSlider("FOV", 10, 180, CFG.aimFov, function(value)
    return math.floor(value) .. "°"
end, function(value)
    CFG.aimFov = value
    if STATE.aimbot then fovCircle.Size = UDim2.fromOffset(value * 3, value * 3) end
end)
aimModule.addSlider("Smoothness", 1, 30, CFG.aimSmoothness, function(value)
    return string.format("%.1f", value)
end, function(value)
    CFG.aimSmoothness = value
end)
local targetLabel = aimModule.addLabel("Target: geen", 18, C.accent)
connect("target_label", RunService.Heartbeat, function()
    if targetLabel and targetLabel.Parent then
        targetLabel.Text = "Target: " .. (aimTarget and aimTarget.DisplayName or "geen")
    end
end)

-- ================= MOVEMENT TEST CONTROLS =================
local function movementAllowed()
    if isTestEnvironment() then return true end
    log("Movement controls geblokkeerd: zet AC_TEST_MODE aan in je eigen testgame")
    return false
end

local speedModule = createModule("Speed", "⚡", false, function(enabled)
    if enabled and not movementAllowed() then
        speedModule.set(false)
        return
    end
    STATE.speed = enabled
    local h = humanoid()
    if h then
        if enabled then
            originalWalkSpeed = originalWalkSpeed or h.WalkSpeed
            h.WalkSpeed = CFG.walkSpeed
        else
            h.WalkSpeed = originalWalkSpeed or CFG.normalSpeed
        end
    end
    log(enabled and ("Speed aan (" .. CFG.walkSpeed .. ")") or "Speed uit")
end)
speedModule.addLabel("Alleen voor geautoriseerde Studio/testgames.", 20, C.warn)
speedModule.addSlider("WalkSpeed", 16, 200, CFG.walkSpeed, function(value)
    return math.floor(value)
end, function(value)
    CFG.walkSpeed = value
    if STATE.speed then local h = humanoid(); if h then h.WalkSpeed = value end end
end)

local flyModule = createModule("Flight", "🕊", false, function(enabled)
    if enabled and not movementAllowed() then flyModule.set(false); return end
    STATE.fly = enabled
    disconnect("fly")
    if flyVelocity then flyVelocity:Destroy(); flyVelocity = nil end
    if flyAttachment then flyAttachment:Destroy(); flyAttachment = nil end
    local h, r = humanoid(), rootPart()
    if not enabled then
        if h then h.PlatformStand = false; h.AutoRotate = true end
        log("Flight uit")
        return
    end
    if not h or not r then
        flyModule.set(false)
        log("Flight: character niet klaar")
        return
    end
    h.PlatformStand = true
    h.AutoRotate = false
    flyAttachment = Instance.new("Attachment")
    flyAttachment.Name = "ACTH_FlyAttachment"
    flyAttachment.Parent = r
    flyVelocity = Instance.new("LinearVelocity")
    flyVelocity.Name = "ACTH_FlyVelocity"
    flyVelocity.Attachment0 = flyAttachment
    flyVelocity.RelativeTo = Enum.ActuatorRelativeTo.World
    flyVelocity.MaxForce = math.huge
    flyVelocity.VectorVelocity = Vector3.zero
    flyVelocity.Parent = r
    connect("fly", RunService.RenderStepped, function()
        if not flyVelocity or not flyVelocity.Parent then return end
        local camera = workspace.CurrentCamera
        if not camera then return end
        local direction = Vector3.zero
        if UserInputService:IsKeyDown(Enum.KeyCode.W) then direction += camera.CFrame.LookVector end
        if UserInputService:IsKeyDown(Enum.KeyCode.S) then direction -= camera.CFrame.LookVector end
        if UserInputService:IsKeyDown(Enum.KeyCode.A) then direction -= camera.CFrame.RightVector end
        if UserInputService:IsKeyDown(Enum.KeyCode.D) then direction += camera.CFrame.RightVector end
        if UserInputService:IsKeyDown(Enum.KeyCode.Space) then direction += Vector3.yAxis end
        if UserInputService:IsKeyDown(Enum.KeyCode.LeftShift) then direction -= Vector3.yAxis end
        flyVelocity.VectorVelocity = direction.Magnitude > 0 and direction.Unit * CFG.flySpeed or Vector3.zero
    end)
    log("Flight aan")
end)
flyModule.addLabel("WASD + Space/Shift. Studio of AC_TEST_MODE vereist.", 20, C.warn)
flyModule.addSlider("Fly speed", 10, 200, CFG.flySpeed, function(value)
    return math.floor(value)
end, function(value)
    CFG.flySpeed = value
end)

local noclipModule = createModule("Noclip", "🧊", false, function(enabled)
    if enabled and not movementAllowed() then noclipModule.set(false); return end
    STATE.noclip = enabled
    disconnect("noclip")
    if not enabled then
        local ch = character()
        if ch then
            for _, item in ipairs(ch:GetDescendants()) do
                if item:IsA("BasePart") then item.CanCollide = true end
            end
        end
        log("Noclip uit")
        return
    end
    connect("noclip", RunService.Stepped, function()
        local ch = character()
        if not ch then return end
        for _, item in ipairs(ch:GetDescendants()) do
            if item:IsA("BasePart") then item.CanCollide = false end
        end
    end)
    log("Noclip aan")
end)
noclipModule.addLabel("Herstelt collision bij uitschakelen.", 20)

local tpModule = createModule("Mouse TP", "📍", false, function(enabled)
    if enabled and not movementAllowed() then tpModule.set(false); return end
    STATE.mouseTP = enabled
    disconnect("mouse_tp")
    if enabled then
        connect("mouse_tp", UserInputService.InputBegan, function(input, gameProcessed)
            if gameProcessed or input.UserInputType ~= Enum.UserInputType.MouseButton1 then return end
            local r = rootPart()
            if r and mouse.Hit then r.CFrame = CFrame.new(mouse.Hit.Position + Vector3.new(0, 3, 0)) end
        end)
        log("Mouse TP aan")
    else
        log("Mouse TP uit")
    end
end)
tpModule.addLabel("Klik in de wereld om te verplaatsen. Testomgeving vereist.", 20, C.warn)
local oneShotTP = Instance.new("TextButton")
oneShotTP.Size = UDim2.new(1, -8, 0, 26)
oneShotTP.BackgroundColor3 = C.sectionHover
oneShotTP.Font = Enum.Font.GothamMedium
oneShotTP.TextSize = 11
oneShotTP.TextColor3 = C.text
oneShotTP.Text = "📍 Eenmalig naar muis"
oneShotTP.AutoButtonColor = false
oneShotTP.Parent = tpModule.body
rounded(oneShotTP, 6)
oneShotTP.MouseButton1Click:Connect(function()
    if not movementAllowed() then return end
    local r = rootPart()
    if r and mouse.Hit then r.CFrame = CFrame.new(mouse.Hit.Position + Vector3.new(0, 3, 0)); log("Eenmalige TP uitgevoerd") end
end)

-- ================= GAMEPASS CHECKER =================
local passModule = createModule("Gamepass checker", "🎫", false, function(enabled)
    STATE.gamepassCheck = enabled
    if not enabled then
        if passLabel then passLabel.Text = "Controle uit" end
        return
    end
    if #CFG.gamePassIds == 0 then
        if passLabel then passLabel.Text = "Geen geldige IDs" end
        return
    end
    local results = {}
    for _, id in ipairs(CFG.gamePassIds) do
        local ok, owns = pcall(function()
            return MarketplaceService:UserOwnsGamePassAsync(player.UserId, id)
        end)
        table.insert(results, tostring(id) .. ": " .. (ok and (owns and "ja" or "nee") or "error"))
    end
    if passLabel then passLabel.Text = table.concat(results, "\n") end
    log(#CFG.gamePassIds .. " gamepass IDs gecontroleerd")
end)
passModule.addLabel("Legitieme ownership-check, zonder spoofing of remote hooks.", 28, C.warn)
passLabel = passModule.addLabel("Controle uit", 18, C.accent)
local idsLabel = passModule.addLabel("IDs: " .. table.concat(CFG.gamePassIds, ", "), 28, C.muted)
local idInput = Instance.new("TextBox")
idInput.Size = UDim2.new(1, -8, 0, 24)
idInput.BackgroundColor3 = C.sectionHover
idInput.Font = Enum.Font.Gotham
idInput.TextSize = 11
idInput.TextColor3 = C.text
idInput.PlaceholderColor3 = C.muted
idInput.PlaceholderText = "Gamepass ID"
idInput.ClearTextOnFocus = false
idInput.Parent = passModule.body
rounded(idInput, 6)
local addID = Instance.new("TextButton")
addID.Size = UDim2.new(1, -8, 0, 24)
addID.BackgroundColor3 = Color3.fromRGB(35, 75, 50)
addID.Font = Enum.Font.GothamMedium
addID.TextSize = 11
addID.TextColor3 = C.text
addID.Text = "➕ ID toevoegen"
addID.AutoButtonColor = false
addID.Parent = passModule.body
rounded(addID, 6)
addID.MouseButton1Click:Connect(function()
    local id = tonumber(idInput.Text:match("%d+"))
    if not id or id <= 0 or id % 1 ~= 0 then log("Ongeldige gamepass ID"); return end
    for _, existing in ipairs(CFG.gamePassIds) do
        if existing == id then log("ID bestaat al"); return end
    end
    table.insert(CFG.gamePassIds, id)
    idsLabel.Text = "IDs: " .. table.concat(CFG.gamePassIds, ", ")
    idInput.Text = ""
    log("Gamepass ID toegevoegd")
end)

-- ================= AC MONITOR =================
local acModule = createModule("Anti-AC monitor", "🛡", false, function(enabled)
    STATE.acMonitor = enabled
    disconnect("ac_scan")
    if not enabled then
        if acLabel then acLabel.Text = "Monitor uit"; acLabel.TextColor3 = C.muted end
        log("AC monitor uit")
        return
    end
    local function scan()
        local indicators = {"Adonis", "HDAdmin", "InfiniteYield", "AntiCheat", "AntiExploit"}
        local found = {}
        for _, keyword in ipairs(indicators) do
            local inCore = CoreGui:FindFirstChild(keyword, true)
            if inCore then table.insert(found, keyword) end
        end
        if acLabel then
            acLabel.Text = #found > 0 and ("Indicatoren: " .. table.concat(found, ", ")) or "Geen bekende client-indicatoren"
            acLabel.TextColor3 = #found > 0 and C.warn or C.green
        end
    end
    scan()
    local elapsed = 0
    connect("ac_scan", RunService.Heartbeat, function(dt)
        elapsed += dt
        if elapsed >= 2 then elapsed = 0; scan() end
    end)
    log("AC monitor actief, alleen observatie")
end)
acModule.addLabel("Detecteert alleen lokale indicatoren. Het blokkeert geen anti-cheat.", 28, C.warn)
acLabel = acModule.addLabel("Monitor uit", 20, C.muted)
local pollLabel = acModule.addLabel("Pollution-profiel: " .. CFG.pollutionLevel, 20, C.accent)
local pollRow = Instance.new("Frame")
pollRow.BackgroundTransparency = 1
pollRow.Size = UDim2.new(1, -8, 0, 26)
pollRow.Parent = acModule.body
for index, level in ipairs({"low", "medium", "high"}) do
    local button = Instance.new("TextButton")
    button.Size = UDim2.fromOffset(70, 24)
    button.Position = UDim2.fromOffset((index - 1) * 76, 0)
    button.BackgroundColor3 = level == CFG.pollutionLevel and C.accentDim or C.sectionHover
    button.Font = Enum.Font.GothamMedium
    button.TextSize = 10
    button.TextColor3 = C.text
    button.Text = level:sub(1, 1):upper() .. level:sub(2)
    button.AutoButtonColor = false
    button.Parent = pollRow
    rounded(button, 5)
    button.MouseButton1Click:Connect(function()
        CFG.pollutionLevel = level
        pollLabel.Text = "Pollution-profiel: " .. level
        for _, sibling in ipairs(pollRow:GetChildren()) do
            if sibling:IsA("TextButton") then sibling.BackgroundColor3 = sibling == button and C.accentDim or C.sectionHover end
        end
        log("Pollution-profiel: " .. level)
    end)
end

-- ================= LOG + ACTIONS =================
local logContainer = Instance.new("Frame")
logContainer.BackgroundColor3 = C.bg
logContainer.BorderSizePixel = 0
logContainer.Size = UDim2.new(1, 0, 0, 96)
logContainer.Parent = content
rounded(logContainer, 6)
logLabel = Instance.new("TextLabel")
logLabel.BackgroundTransparency = 1
logLabel.Size = UDim2.new(1, -10, 1, -6)
logLabel.Position = UDim2.fromOffset(5, 3)
logLabel.Font = Enum.Font.Code
logLabel.TextSize = 8
logLabel.TextColor3 = C.muted
logLabel.TextXAlignment = Enum.TextXAlignment.Left
logLabel.TextYAlignment = Enum.TextYAlignment.Top
logLabel.TextWrapped = true
logLabel.Parent = logContainer

local actionRow = Instance.new("Frame")
actionRow.BackgroundTransparency = 1
actionRow.Size = UDim2.new(1, 0, 0, 30)
actionRow.Parent = content

local resetButton = Instance.new("TextButton")
resetButton.Size = UDim2.new(0.48, -2, 1, 0)
resetButton.BackgroundColor3 = C.sectionHover
resetButton.Font = Enum.Font.GothamMedium
resetButton.TextSize = 11
resetButton.TextColor3 = C.text
resetButton.Text = "🔁 Alles reset"
resetButton.AutoButtonColor = false
resetButton.Parent = actionRow
rounded(resetButton, 6)

local killButton = Instance.new("TextButton")
killButton.Size = UDim2.new(0.48, -2, 1, 0)
killButton.Position = UDim2.new(0.52, 2, 0, 0)
killButton.BackgroundColor3 = C.red
killButton.Font = Enum.Font.GothamBold
killButton.TextSize = 11
killButton.TextColor3 = C.text
killButton.Text = "☠ Sluit harness"
killButton.AutoButtonColor = false
killButton.Parent = actionRow
rounded(killButton, 6)

local function resetAll()
    espModule.set(false)
    aimModule.set(false)
    speedModule.set(false)
    flyModule.set(false)
    noclipModule.set(false)
    tpModule.set(false)
    passModule.set(false)
    acModule.set(false)
    local h = humanoid()
    if h then
        h.WalkSpeed = originalWalkSpeed or CFG.normalSpeed
        h.PlatformStand = false
        h.AutoRotate = true
    end
    log("Alles gereset")
end

resetButton.MouseButton1Click:Connect(resetAll)
killButton.MouseButton1Click:Connect(function()
    if destroyed then return end
    destroyed = true
    resetAll()
    disconnectAll()
    clearESP()
    if gui then gui:Destroy() end
    logLabel = nil
end)

-- ================= DRAG / RESIZE =================
local dragging = false
local dragStart
local startPosition
header.InputBegan:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.MouseButton1 then
        dragging = true
        dragStart = input.Position
        startPosition = panel.Position
    end
end)
UserInputService.InputChanged:Connect(function(input)
    if not dragging or input.UserInputType ~= Enum.UserInputType.MouseMovement then return end
    local delta = input.Position - dragStart
    local camera = workspace.CurrentCamera
    local viewport = camera and camera.ViewportSize or Vector2.new(1280, 720)
    panel.Position = UDim2.fromOffset(
        math.clamp(startPosition.X.Offset + delta.X, -panel.AbsoluteSize.X + 60, viewport.X - 60),
        math.clamp(startPosition.Y.Offset + delta.Y, 0, viewport.Y - 40)
    )
end)
UserInputService.InputEnded:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.MouseButton1 then dragging = false end
end)

local resize = Instance.new("TextButton")
resize.Size = UDim2.fromOffset(16, 16)
resize.Position = UDim2.new(1, -16, 1, -16)
resize.BackgroundColor3 = C.border
resize.Text = ""
resize.AutoButtonColor = false
resize.Parent = panel
resize.ZIndex = 10
rounded(resize, 8)
local resizing = false
local resizeStart
local startSize
resize.InputBegan:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.MouseButton1 then
        resizing = true
        resizeStart = input.Position
        startSize = panel.AbsoluteSize
    end
end)
UserInputService.InputChanged:Connect(function(input)
    if not resizing or input.UserInputType ~= Enum.UserInputType.MouseMovement then return end
    local delta = input.Position - resizeStart
    panel.Size = UDim2.fromOffset(
        math.clamp(startSize.X + delta.X, 280, 620),
        math.clamp(startSize.Y + delta.Y, 360, 900)
    )
end)
UserInputService.InputEnded:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.MouseButton1 then resizing = false end
end)

-- ================= BUTTONS / KEYBINDS =================
local minimized = false
minimizeButton.MouseButton1Click:Connect(function()
    minimized = not minimized
    content.Visible = not minimized
    panel.Size = UDim2.fromOffset(panel.AbsoluteSize.X, minimized and 36 or 560)
    minimizeButton.Text = minimized and "+" or "−"
end)
hideButton.MouseButton1Click:Connect(function() panel.Visible = false end)

connect("keybinds", UserInputService.InputBegan, function(input, gameProcessed)
    if gameProcessed then return end
    if input.KeyCode == Enum.KeyCode.RightShift then
        panel.Visible = not panel.Visible
    elseif input.KeyCode == Enum.KeyCode.End then
        resetAll()
        log("End: alles gereset")
    end
end)

connect("character_added", player.CharacterAdded, function(newCharacter)
    originalWalkSpeed = nil
    if STATE.speed then
        local h = newCharacter:WaitForChild("Humanoid", 5)
        if h then originalWalkSpeed = h.WalkSpeed; h.WalkSpeed = CFG.walkSpeed end
    end
    if STATE.fly then flyModule.set(false) end
    if STATE.noclip then noclipModule.set(false) end
end)

-- ================= STARTUP =================
log("AC Test Harness v7.0 gestart")
log("RShift = UI toggle | End = reset | Chevron = instellingen")
log(#CFG.gamePassIds .. " gamepass IDs geladen")
if not isTestEnvironment() then
    log("Movement controls staan uit: geen Studio/AC_TEST_MODE")
end
log("Klaar voor geautoriseerde testers")
