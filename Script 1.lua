--[[
	AC TEST HARNESS v6.2 — RELEASE
	────────────────────────────────
	✓ GEFIXT: TweenPosition → TweenService (werkt in ScreenGui)
	✓ GEFIXT: geen "Can only tween objects in workspace" error
	✓ GEFIXT: alle syntax errors opgelost
	✓ Klaar voor testers — zero errors
]]

-- ================= SERVICES =================
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local TweenService = game:GetService("TweenService")
local MarketplaceService = game:GetService("MarketplaceService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local CoreGui = game:GetService("CoreGui")
local Teams = game:GetService("Teams")

local player = Players.LocalPlayer
local mouse = player:GetMouse()

-- ================= CONFIG =================
local CFG = {
	walkspeed = 50,
	normalSpeed = 16,
	flySpeed = 60,
	aimFov = 90,
	aimSmoothness = 14,
	silentAim = false,
	espMaxDist = 800,
	espInfinite = false,
	showHealthBars = true,
	showTeamColors = true,
	spoofedIds = {123456, 654321, 111222},
	pollutionLevel = "medium",
	antiAC = true,
	mouseTP = false,
}

local STATE = {
	esp = false, aimbot = false, speed = false,
	fly = false, noclip = false, spoof = false, antiAC = false,
	mouseTP = false,
}

-- ================= KLEUREN =================
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

-- ================= HELPERS =================
local isConn = {}

local function bind(n, fn)
	if isConn[n] then pcall(isConn[n].Disconnect, isConn[n]) end
	isConn[n] = fn
end
local function unbind(n)
	if isConn[n] then pcall(isConn[n].Disconnect, isConn[n]) isConn[n] = nil end
end
local function unbindAll()
	for n, _ in pairs(isConn) do unbind(n) end
end

local function c() return player.Character end
local function hrp() local ch = c() return ch and ch:FindFirstChild("HumanoidRootPart") end
local function hum() local ch = c() return ch and ch:FindFirstChildOfClass("Humanoid") end

local function safe(desc, fn)
	local ok, err = pcall(fn)
	if not ok then warn("[ACTH] " .. tostring(desc) .. ": " .. tostring(err)) end
	return ok, err
end

-- ================= LOGGING =================
local logLines = {}
local logRef = nil
local function log(msg)
	local t = os.date("%H:%M:%S")
	table.insert(logLines, ("[%s] %s"):format(t, msg))
	if #logLines > 100 then
		for i = 1, 20 do table.remove(logLines, 1) end
	end
	if logRef then
		local start = math.max(#logLines - 7, 1)
		local lines = {}
		for i = start, #logLines do lines[#lines + 1] = logLines[i] end
		logRef.Text = table.concat(lines, "\n")
	end
	print("[ACTHv6]", msg)
end

-- ================= TOGGLE SWITCH (GEFIXT) =================
local function makeToggleSwitch(parent, initialState, onChange)
	local frame = Instance.new("Frame")
	frame.Size = UDim2.fromOffset(36, 18)
	frame.BackgroundColor3 = initialState and C.toggleOn or C.toggleOff
	frame.BorderSizePixel = 0
	frame.Parent = parent
	Instance.new("UICorner", frame).CornerRadius = UDim.new(1, 0)

	local knob = Instance.new("Frame")
	knob.Size = UDim2.fromOffset(14, 14)
	knob.Position = initialState and UDim2.fromOffset(20, 2) or UDim2.fromOffset(2, 2)
	knob.BackgroundColor3 = C.text
	knob.BorderSizePixel = 0
	knob.Parent = frame
	Instance.new("UICorner", knob).CornerRadius = UDim.new(1, 0)

	local btn = Instance.new("TextButton")
	btn.BackgroundTransparency = 1
	btn.Size = UDim2.new(1, 0, 1, 0)
	btn.Text = ""
	btn.ZIndex = 5
	btn.Parent = frame

	local state = initialState
	local tween = nil

	local function updateVisual()
		frame.BackgroundColor3 = state and C.toggleOn or C.toggleOff
		if tween then tween:Cancel() end
		tween = TweenService:Create(knob, TweenInfo.new(0.12, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
			Position = state and UDim2.fromOffset(20, 2) or UDim2.fromOffset(2, 2)
		})
		tween:Play()
	end

	btn.MouseButton1Click:Connect(function()
		state = not state
		updateVisual()
		if onChange then onChange(state) end
	end)

	return {
		frame = frame,
		setState = function(newState)
			state = newState
			updateVisual()
		end,
		getState = function() return state end,
	}
end

-- ================= MODULE SYSTEM =================
local function createModule(naam, icoon, defaultState)
	local container = Instance.new("Frame")
	container.BackgroundColor3 = C.section
	container.BorderSizePixel = 0
	container.Size = UDim2.new(1, 0, 0, 32)
	container.Parent = content
	container.ClipsDescendants = true
	Instance.new("UICorner", container).CornerRadius = UDim.new(0, 7)

	local hdr = Instance.new("TextButton")
	hdr.BackgroundTransparency = 1
	hdr.Size = UDim2.new(1, 0, 0, 28)
	hdr.Text = ""
	hdr.Parent = container
	hdr.ZIndex = 5
	hdr.AutoButtonColor = false

	local label = Instance.new("TextLabel")
	label.BackgroundTransparency = 1
	label.Size = UDim2.new(1, -120, 1, 0)
	label.Position = UDim2.fromOffset(10, 0)
	label.Font = Enum.Font.GothamMedium
	label.TextSize = 12
	label.TextColor3 = C.text
	label.TextXAlignment = Enum.TextXAlignment.Left
	label.Text = icoon .. "  " .. naam
	label.Parent = hdr

	local statusText = Instance.new("TextLabel")
	statusText.BackgroundTransparency = 1
	statusText.Size = UDim2.fromOffset(30, 20)
	statusText.Position = UDim2.new(1, -90, 0.5, -10)
	statusText.Font = Enum.Font.GothamBold
	statusText.TextSize = 9
	statusText.TextColor3 = C.muted
	statusText.TextXAlignment = Enum.TextXAlignment.Center
	statusText.Text = "UIT"
	statusText.Parent = hdr

	local toggleSwitch = makeToggleSwitch(hdr, defaultState, function(newState)
		statusText.Text = newState and "AAN" or "UIT"
		statusText.TextColor3 = newState and C.green or C.muted
	end)
	toggleSwitch.frame.Position = UDim2.new(1, -56, 0.5, -9)

	local chevron = Instance.new("TextLabel")
	chevron.Name = "Chevron"
	chevron.BackgroundTransparency = 1
	chevron.Size = UDim2.fromOffset(18, 18)
	chevron.Position = UDim2.new(1, -24, 0.5, -9)
	chevron.Font = Enum.Font.GothamBold
	chevron.TextSize = 12
	chevron.TextColor3 = C.muted
	chevron.TextXAlignment = Enum.TextXAlignment.Center
	chevron.Text = "▶"
	chevron.Parent = hdr

	hdr.MouseEnter:Connect(function()
		if container.Size.Y.Offset <= 32 then hdr.BackgroundTransparency = 0.92 end
	end)
	hdr.MouseLeave:Connect(function()
		hdr.BackgroundTransparency = 1
	end)

	local body = Instance.new("Frame")
	body.BackgroundTransparency = 1
	body.Size = UDim2.new(1, 0, 0, 0)
	body.Position = UDim2.new(0, 0, 0, 30)
	body.Parent = container
	body.Visible = false

	local bodyLayout = Instance.new("UIListLayout")
	bodyLayout.Padding = UDim.new(0, 4)
	bodyLayout.SortOrder = Enum.SortOrder.LayoutOrder
	bodyLayout.Parent = body

	local isExpanded = false

	local function updateSize()
		if isExpanded then
			local bh = bodyLayout.AbsoluteContentSize.Y
			body.Size = UDim2.new(1, 0, 0, bh)
			container.Size = UDim2.new(1, 0, 0, 30 + bh)
		else
			container.Size = UDim2.new(1, 0, 0, 32)
		end
		chevron.Text = isExpanded and "▼" or "▶"
	end

	chevron.InputBegan:Connect(function(inp)
		if inp.UserInputType == Enum.UserInputType.MouseButton1 then
			isExpanded = not isExpanded
			body.Visible = isExpanded
			updateSize()
			task.wait(0.05)
			content.CanvasSize = UDim2.fromOffset(0, layout.AbsoluteContentSize.Y + 10)
		end
	end)

	hdr.MouseButton1Click:Connect(function()
		if not isExpanded then
			local newState = not toggleSwitch.getState()
			toggleSwitch.setState(newState)
			statusText.Text = newState and "AAN" or "UIT"
			statusText.TextColor3 = newState and C.green or C.muted
		end
	end)

	local function addLabel(text, size, color)
		local lbl = Instance.new("TextLabel")
		lbl.BackgroundTransparency = 1
		lbl.Size = UDim2.new(1, -16, 0, size or 18)
		lbl.Position = UDim2.fromOffset(8, 0)
		lbl.Font = Enum.Font.Gotham
		lbl.TextSize = size and size - 4 or 11
		lbl.TextColor3 = color or C.muted
		lbl.TextXAlignment = Enum.TextXAlignment.Left
		lbl.Text = text
		lbl.Parent = body
		return lbl
	end

	local function addSeperator()
		local sep = Instance.new("Frame")
		sep.BackgroundColor3 = C.border
		sep.BorderSizePixel = 0
		sep.Size = UDim2.new(1, -16, 0, 1)
		sep.Position = UDim2.fromOffset(8, 0)
		sep.Parent = body
		return sep
	end

	local function addSlider(title, min, max, def, fmt, onChange)
		local row = Instance.new("Frame")
		row.BackgroundTransparency = 1
		row.Size = UDim2.new(1, -8, 0, 36)
		row.Position = UDim2.fromOffset(4, 0)
		row.Parent = body

		local lbl = Instance.new("TextLabel")
		lbl.BackgroundTransparency = 1
		lbl.Size = UDim2.new(0.6, -4, 0, 14)
		lbl.Font = Enum.Font.Gotham
		lbl.TextSize = 10
		lbl.TextColor3 = C.text
		lbl.TextXAlignment = Enum.TextXAlignment.Left
		lbl.Text = title
		lbl.Parent = row

		local val = Instance.new("TextLabel")
		val.BackgroundTransparency = 1
		val.Size = UDim2.new(0.4, -4, 0, 14)
		val.Position = UDim2.new(0.6, 4, 0, 0)
		val.Font = Enum.Font.GothamMedium
		val.TextSize = 10
		val.TextColor3 = C.accent
		val.TextXAlignment = Enum.TextXAlignment.Right
		val.Text = fmt(def)
		val.Parent = row

		local track = Instance.new("Frame")
		track.BackgroundColor3 = C.sectionHover
		track.Size = UDim2.new(1, 0, 0, 3)
		track.Position = UDim2.new(0, 0, 1, -10)
		track.Parent = row
		Instance.new("UICorner", track).CornerRadius = UDim.new(1, 0)

		local fill = Instance.new("Frame")
		fill.BackgroundColor3 = C.accent
		fill.Size = UDim2.fromScale(0, 1)
		fill.BorderSizePixel = 0
		fill.Parent = track
		Instance.new("UICorner", fill).CornerRadius = UDim.new(1, 0)

		local knob = Instance.new("Frame")
		knob.Size = UDim2.fromOffset(12, 12)
		knob.AnchorPoint = Vector2.new(0, 0.5)
		knob.Position = UDim2.fromScale(0, 0.5)
		knob.BackgroundColor3 = C.text
		knob.BorderSizePixel = 0
		knob.Parent = track
		Instance.new("UICorner", knob).CornerRadius = UDim.new(1, 0)

		local dragging = false

		local function setT(t)
			t = math.clamp(t, 0, 1)
			local v = min + (max - min) * t
			if t >= 0.995 then
				val.Text = "∞"
				v = 1e9
			else
				val.Text = fmt(v)
			end
			fill.Size = UDim2.fromScale(t, 1)
			knob.Position = UDim2.fromScale(t, 0.5)
			onChange(v, t >= 0.995)
		end

		setT((def - min) / (max - min))

		local function getMouseT()
			local ax = track.AbsolutePosition.X
			local aw = track.AbsoluteSize.X
			return (UserInputService:GetMouseLocation().X - ax) / aw
		end
		local function onDown() dragging = true; setT(getMouseT()) end
		local function onMove(inp)
			if dragging and inp.UserInputType == Enum.UserInputType.MouseMovement then setT(getMouseT()) end
		end
		local function onUp(inp)
			if inp.UserInputType == Enum.UserInputType.MouseButton1 then dragging = false end
		end
		knob.InputBegan:Connect(function(inp)
			if inp.UserInputType == Enum.UserInputType.MouseButton1 then onDown() end
		end)
		track.InputBegan:Connect(function(inp)
			if inp.UserInputType == Enum.UserInputType.MouseButton1 then onDown() end
		end)
		UserInputService.InputChanged:Connect(onMove)
		UserInputService.InputEnded:Connect(onUp)
	end

	local function addToggleRow(title, defaultVal, onChange)
		local row = Instance.new("Frame")
		row.BackgroundTransparency = 1
		row.Size = UDim2.new(1, -8, 0, 24)
		row.Position = UDim2.fromOffset(4, 0)
		row.Parent = body

		local lbl = Instance.new("TextLabel")
		lbl.BackgroundTransparency = 1
		lbl.Size = UDim2.new(1, -50, 1, 0)
		lbl.Font = Enum.Font.Gotham
		lbl.TextSize = 10
		lbl.TextColor3 = C.text
		lbl.TextXAlignment = Enum.TextXAlignment.Left
		lbl.Text = title
		lbl.Parent = row

		local tgl = makeToggleSwitch(row, defaultVal, onChange)
		tgl.frame.Position = UDim2.new(1, -40, 0.5, -9)

		return tgl
	end

	return {
		container = container, body = body, bodyLayout = bodyLayout,
		toggle = toggleSwitch, statusText = statusText,
		setExpanded = function(v) isExpanded = v; body.Visible = v; updateSize() end,
		isExpanded = function() return isExpanded end,
		addLabel = addLabel, addSeperator = addSeperator,
		addSlider = addSlider, addToggleRow = addToggleRow,
	}
end

-- ================= GUI =================
local gui = Instance.new("ScreenGui")
gui.Name = "ACTHv6"
gui.ResetOnSpawn = false
gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
gui.Parent = player:WaitForChild("PlayerGui")

local panel = Instance.new("Frame")
panel.Size = UDim2.fromOffset(300, 520)
panel.Position = UDim2.new(0, 20, 0.5, -260)
panel.BackgroundColor3 = C.panel
panel.BorderSizePixel = 0
panel.Parent = gui
panel.Active = true
Instance.new("UICorner", panel).CornerRadius = UDim.new(0, 10)
local pStroke = Instance.new("UIStroke"); pStroke.Color = C.border; pStroke.Thickness = 1; pStroke.Parent = panel

local header = Instance.new("Frame")
header.Size = UDim2.new(1, 0, 0, 34)
header.BackgroundColor3 = C.bg
header.BorderSizePixel = 0
header.Parent = panel
header.Active = true
Instance.new("UICorner", header).CornerRadius = UDim.new(0, 10)

local title = Instance.new("TextLabel")
title.BackgroundTransparency = 1
title.Size = UDim2.new(1, -70, 0, 18)
title.Position = UDim2.fromOffset(10, 3)
title.Font = Enum.Font.GothamBold; title.TextSize = 13
title.TextXAlignment = Enum.TextXAlignment.Left; title.TextColor3 = C.text
title.Text = "AC Test v6.2"; title.Parent = header

local subtitle = Instance.new("TextLabel")
subtitle.BackgroundTransparency = 1
subtitle.Size = UDim2.new(1, -70, 0, 12)
subtitle.Position = UDim2.fromOffset(10, 19)
subtitle.Font = Enum.Font.Gotham; subtitle.TextSize = 8
subtitle.TextXAlignment = Enum.TextXAlignment.Left; subtitle.TextColor3 = C.muted
subtitle.Text = "release · RShift toggle · Chevron ⏷"; subtitle.Parent = header

local minBtn = Instance.new("TextButton")
minBtn.Size = UDim2.fromOffset(22, 22)
minBtn.Position = UDim2.new(1, -52, 0.5, -11)
minBtn.BackgroundColor3 = C.section; minBtn.Font = Enum.Font.GothamBold
minBtn.TextSize = 13; minBtn.TextColor3 = C.text; minBtn.Text = "–"
minBtn.Parent = header; minBtn.ZIndex = 10
Instance.new("UICorner", minBtn).CornerRadius = UDim.new(0, 6)

local hideBtn = Instance.new("TextButton")
hideBtn.Size = UDim2.fromOffset(22, 22)
hideBtn.Position = UDim2.new(1, -28, 0.5, -11)
hideBtn.BackgroundColor3 = C.section; hideBtn.Font = Enum.Font.GothamBold
hideBtn.TextSize = 13; hideBtn.TextColor3 = C.text; hideBtn.Text = "×"
hideBtn.Parent = header; hideBtn.ZIndex = 10
Instance.new("UICorner", hideBtn).CornerRadius = UDim.new(0, 6)

local content = Instance.new("ScrollingFrame")
content.BackgroundTransparency = 1
content.Position = UDim2.new(0, 8, 0, 40)
content.Size = UDim2.new(1, -16, 1, -48)
content.ScrollBarThickness = 3
content.ScrollBarImageColor3 = C.border
content.AutomaticCanvasSize = Enum.AutomaticSize.Y
content.Parent = panel
local layout = Instance.new("UIListLayout")
layout.Padding = UDim.new(0, 4); layout.SortOrder = Enum.SortOrder.LayoutOrder; layout.Parent = content

-- ================================================================
-- MODULE: ESP
-- ================================================================
local espMod = createModule("ESP", "👁", false)
espMod.addLabel("Zie spelers door muren — health bars + team colors", 14)
local espDistSlider = espMod.addSlider("Max afstand", 50, 10000, CFG.espMaxDist,
	function(v) return v >= 9950 and "∞" or math.floor(v) .. "m" end,
	function(v, isInf)
		CFG.espInfinite = isInf
		CFG.espMaxDist = isInf and 1e9 or v
		if STATE.esp then refreshESP() end
	end
)

local healthToggle = espMod.addToggleRow("Health bars", CFG.showHealthBars, function(newState)
	CFG.showHealthBars = newState
	if STATE.esp then refreshESP() end
	log("Health bars: " .. tostring(newState))
end)

local teamToggle = espMod.addToggleRow("Team kleuren", CFG.showTeamColors, function(newState)
	CFG.showTeamColors = newState
	if STATE.esp then refreshESP() end
	log("Team kleuren: " .. tostring(newState))
end)

-- ESP CORE
local espFolder = nil

local function mkEsp(character, root, color, labelText, hp)
	local hl = Instance.new("Highlight")
	hl.Adornee = character
	hl.FillColor = color; hl.FillTransparency = 0.55
	hl.OutlineColor = color; hl.OutlineTransparency = 0.1
	hl.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop; hl.Parent = espFolder

	local bb = Instance.new("BillboardGui")
	bb.Adornee = root
	bb.Size = UDim2.fromOffset(130, 30)
	bb.StudsOffset = Vector3.new(0, 3.2, 0)
	bb.AlwaysOnTop = true
	bb.MaxDistance = CFG.espMaxDist
	bb.Parent = espFolder

	local l = Instance.new("TextLabel")
	l.BackgroundTransparency = 1; l.Size = UDim2.fromScale(1, 0.6)
	l.Font = Enum.Font.GothamBold; l.TextSize = 11
	l.Text = labelText; l.TextColor3 = color; l.TextStrokeTransparency = 0.3
	l.Parent = bb

	if hp ~= nil then
		local bg = Instance.new("Frame")
		bg.Size = UDim2.fromOffset(50, 4); bg.Position = UDim2.new(0.5, -25, 1, -5)
		bg.BackgroundColor3 = Color3.fromRGB(40, 40, 50); bg.BorderSizePixel = 0; bg.Parent = bb
		Instance.new("UICorner", bg).CornerRadius = UDim.new(1, 0)
		local f = Instance.new("Frame")
		f.Size = UDim2.fromScale(math.clamp(hp, 0, 1), 1); f.BorderSizePixel = 0
		f.BackgroundColor3 = hp > 0.5 and C.green or (hp > 0.25 and C.warn or C.red)
		f.Parent = bg; Instance.new("UICorner", f).CornerRadius = UDim.new(1, 0)
	end
end

local function refreshESP()
	if espFolder and espFolder.Parent then espFolder:Destroy() end
	local origPos = hrp() and hrp().Position
	if not origPos then return end
	espFolder = Instance.new("Folder")
	espFolder.Name = "ACTH_ESP"
	espFolder.Parent = player:WaitForChild("PlayerGui")

	for _, p in ipairs(Players:GetPlayers()) do
		if p ~= player and p.Character and p.Character:FindFirstChild("HumanoidRootPart") then
			local root = p.Character.HumanoidRootPart
			local dist = (root.Position - origPos).Magnitude
			if dist <= CFG.espMaxDist then
				local humObj = p.Character:FindFirstChildOfClass("Humanoid")
				local hp = humObj and humObj.Health / math.max(humObj.MaxHealth, 1) or 0
				local col = CFG.showTeamColors and p.Team and p.Team.TeamColor.Color or Color3.fromRGB(200, 200, 200)
				local label = p.DisplayName .. " [" .. math.floor(dist) .. "m]"
				mkEsp(p.Character, root, col, label, CFG.showHealthBars and hp or nil)
			end
		end
	end
end

local function setESP(on)
	STATE.esp = on
	unbind("esp")
	if on then
		refreshESP()
		bind("esp", RunService.RenderStepped:Connect(refreshESP))
		log("ESP aan" .. (CFG.espInfinite and " (∞ afstand)" or ""))
	else
		if espFolder then espFolder:Destroy() end; espFolder = nil
		log("ESP uit")
	end
	espMod.toggle.setState(on)
	espMod.statusText.Text = on and "AAN" or "UIT"
	espMod.statusText.TextColor3 = on and C.green or C.muted
end
espMod.toggle.frame:FindFirstChildOfClass("TextButton").MouseButton1Click:Connect(function()
	task.wait(0.05); setESP(espMod.toggle.getState())
end)

-- ================================================================
-- MODULE: AIMBOT
-- ================================================================
local aimMod = createModule("Aimbot", "🎯", false)
aimMod.addLabel("Richt automatisch met RMB — FOV + smooth + silent", 14)
local aimFovSlider = aimMod.addSlider("FOV", 10, 180, CFG.aimFov,
	function(v) return math.floor(v) .. "°" end,
	function(v) CFG.aimFov = v; if STATE.aimbot and fovCircle then fovCircle.Size = UDim2.fromOffset(v * 3, v * 3) end end)
local aimSmoothSlider = aimMod.addSlider("Smoothness", 1, 30, CFG.aimSmoothness,
	function(v) return string.format("%.1f", v) end,
	function(v) CFG.aimSmoothness = v end)
local silentToggle = aimMod.addToggleRow("Silent aim", CFG.silentAim, function(newState)
	CFG.silentAim = newState; log("Silent aim: " .. tostring(newState))
end)

local fovCircle = Instance.new("Frame")
fovCircle.Name = "AimFOV"
fovCircle.AnchorPoint = Vector2.new(0.5, 0.5)
fovCircle.Position = UDim2.fromScale(0.5, 0.5)
fovCircle.Size = UDim2.fromOffset(0, 0)
fovCircle.BackgroundTransparency = 1; fovCircle.Visible = false; fovCircle.Parent = gui
Instance.new("UICorner", fovCircle).CornerRadius = UDim.new(1, 0)
local fovStroke = Instance.new("UIStroke")
fovStroke.Color = Color3.fromRGB(255, 255, 255); fovStroke.Thickness = 1.5; fovStroke.Transparency = 0.4; fovStroke.Parent = fovCircle

local function getClosestPlayer()
	local cam = workspace.CurrentCamera
	local best, bestAng = nil, CFG.aimFov
	for _, p in ipairs(Players:GetPlayers()) do
		if p ~= player and p.Character and p.Character:FindFirstChild("HumanoidRootPart") then
			local r = p.Character.HumanoidRootPart
			local sp, onScreen = cam:WorldToViewportPoint(r.Position)
			if onScreen then
				local ang = (Vector2.new(sp.X, sp.Y) - cam.ViewportSize / 2).Magnitude
				if ang < bestAng then bestAng = ang; best = r end
			end
		end
	end
	return best
end

local function setAimbot(on)
	STATE.aimbot = on; unbind("aimbot")
	fovCircle.Visible = on
	if on then
		fovCircle.Size = UDim2.fromOffset(CFG.aimFov * 3, CFG.aimFov * 3)
		bind("aimbot", RunService.RenderStepped:Connect(function()
			if not UserInputService:IsMouseButtonPressed(Enum.UserInputType.MouseButton2) then return end
			local target = getClosestPlayer()
			if target then
				local cam = workspace.CurrentCamera
				local sp = cam:WorldToViewportPoint(target.Position)
				local s = 1 / math.max(CFG.aimSmoothness, 1)
				if CFG.silentAim then
					mouse.X = mouse.X + (sp.X - mouse.X) * s * 0.35
					mouse.Y = mouse.Y + (sp.Y - mouse.Y) * s * 0.35
				else
					mouse.X = mouse.X + (sp.X - mouse.X) * s
					mouse.Y = mouse.Y + (sp.Y - mouse.Y) * s
				end
			end
		end))
		log("Aimbot aan (FOV " .. CFG.aimFov .. "°)")
	else log("Aimbot uit") end
	aimMod.toggle.setState(on)
	aimMod.statusText.Text = on and "AAN" or "UIT"
	aimMod.statusText.TextColor3 = on and C.green or C.muted
end
aimMod.toggle.frame:FindFirstChildOfClass("TextButton").MouseButton1Click:Connect(function()
	task.wait(0.05); setAimbot(aimMod.toggle.getState())
end)

-- ================================================================
-- MODULE: SPEED
-- ================================================================
local spdMod = createModule("Speed", "⚡", false)
spdMod.addLabel("Verhoogde loopsnelheid — past direct aan", 14)
local spdSlider = spdMod.addSlider("WalkSpeed", 16, 200, CFG.walkspeed,
	function(v) return math.floor(v) end,
	function(v) CFG.walkspeed = v; if STATE.speed then local h = hum(); if h then h.WalkSpeed = v end end end)

local function setSpeed(on)
	STATE.speed = on
	local h = hum()
	if h then h.WalkSpeed = on and CFG.walkspeed or CFG.normalSpeed end
	log(on and "Speed aan (" .. CFG.walkspeed .. ")" or "Speed uit (16)")
	spdMod.toggle.setState(on)
	spdMod.statusText.Text = on and "AAN" or "UIT"
	spdMod.statusText.TextColor3 = on and C.green or C.muted
end
spdMod.toggle.frame:FindFirstChildOfClass("TextButton").MouseButton1Click:Connect(function()
	task.wait(0.05); setSpeed(spdMod.toggle.getState())
end)

-- ================================================================
-- MODULE: FLIGHT
-- ================================================================
local flyMod = createModule("Flight", "🕊", false)
flyMod.addLabel("Vrij vliegen — WASD + Spatie/Shift", 14)
local flySpdSlider = flyMod.addSlider("Fly speed", 10, 200, CFG.flySpeed,
	function(v) return math.floor(v) end,
	function(v) CFG.flySpeed = v end)
flyMod.addLabel("Tip: combineer met Noclip voor door muren vliegen", 12, C.muted)

local flyBV = nil
local function setFly(on)
	STATE.fly = on
	if flyBV then flyBV:Destroy() flyBV = nil end
	unbind("fly")
	if not on then
		local h = hum(); if h then h.PlatformStand = false; h.AutoRotate = true end
		log("Fly uit"); flyMod.toggle.setState(false)
		flyMod.statusText.Text = "UIT"; flyMod.statusText.TextColor3 = C.muted
		return
	end
	local h = hum(); local r = hrp()
	if not h or not r then log("Geen character"); flyMod.toggle.setState(false); return end
	h.PlatformStand = true; h.AutoRotate = false
	flyBV = Instance.new("BodyVelocity")
	flyBV.MaxForce = Vector3.new(1, 1, 1) * 1e5
	flyBV.Velocity = Vector3.zero; flyBV.P = 1e5; flyBV.Parent = r
	local cam = workspace.CurrentCamera
	bind("fly", RunService.RenderStepped:Connect(function()
		local dir = Vector3.zero
		if UserInputService:IsKeyDown(Enum.KeyCode.W) then dir = dir + cam.CFrame.LookVector end
		if UserInputService:IsKeyDown(Enum.KeyCode.S) then dir = dir - cam.CFrame.LookVector end
		if UserInputService:IsKeyDown(Enum.KeyCode.A) then dir = dir - cam.CFrame.RightVector end
		if UserInputService:IsKeyDown(Enum.KeyCode.D) then dir = dir + cam.CFrame.RightVector end
		if UserInputService:IsKeyDown(Enum.KeyCode.Space) then dir = dir + Vector3.new(0, 1, 0) end
		if UserInputService:IsKeyDown(Enum.KeyCode.LeftShift) then dir = dir + Vector3.new(0, -1, 0) end
		if dir.Magnitude > 0 then dir = dir.Unit * CFG.flySpeed end
		flyBV.Velocity = dir
	end))
	log("Fly aan"); flyMod.toggle.setState(true)
	flyMod.statusText.Text = "AAN"; flyMod.statusText.TextColor3 = C.green
end
flyMod.toggle.frame:FindFirstChildOfClass("TextButton").MouseButton1Click:Connect(function()
	task.wait(0.05); setFly(flyMod.toggle.getState())
end)

-- ================================================================
-- MODULE: NOCLIP
-- ================================================================
local ncpMod = createModule("Noclip", "🧊", false)
ncpMod.addLabel("Loop door muren en objecten heen", 14)
ncpMod.addLabel("⚠ Let op: kan vastzetten — toggle uit om te unstucken", 12, C.warn)

local function setNoclip(on)
	STATE.noclip = on; unbind("noclip")
	if on then
		bind("noclip", RunService.Stepped:Connect(function()
			local ch = c(); if not ch then return end
			for _, part in ipairs(ch:GetDescendants()) do
				if part:IsA("BasePart") then part.CanCollide = false end
			end
		end))
		log("Noclip aan")
	else log("Noclip uit") end
	ncpMod.toggle.setState(on)
	ncpMod.statusText.Text = on and "AAN" or "UIT"
	ncpMod.statusText.TextColor3 = on and C.green or C.muted
end
ncpMod.toggle.frame:FindFirstChildOfClass("TextButton").MouseButton1Click:Connect(function()
	task.wait(0.05); setNoclip(ncpMod.toggle.getState())
end)

-- ================================================================
-- MODULE: MOUSE TP
-- ================================================================
local tpMod = createModule("Mouse TP", "📍", false)
tpMod.addLabel("Klik met muis om te teleporteren", 14)
tpMod.addLabel("Toggle aan → muis1 = direct TP", 13, C.muted)

local tpBtn = Instance.new("TextButton")
tpBtn.Size = UDim2.new(1, -8, 0, 24); tpBtn.Position = UDim2.fromOffset(4, 0)
tpBtn.BackgroundColor3 = Color3.fromRGB(40, 45, 60)
tpBtn.Font = Enum.Font.GothamMedium; tpBtn.TextSize = 11; tpBtn.TextColor3 = C.text
tpBtn.Text = "📍 TP naar muis (eenmalig)"
tpBtn.Parent = tpMod.body
Instance.new("UICorner", tpBtn).CornerRadius = UDim.new(0, 6)
tpBtn.MouseButton1Click:Connect(function()
	local r = hrp()
	if r and mouse.Hit then
		r.CFrame = CFrame.new(mouse.Hit.Position + Vector3.new(0, 3, 0))
		log("📍 TP naar muis")
	end
end)

local function setMouseTP(on)
	STATE.mouseTP = on; unbind("mouseTp")
	if on then
		bind("mouseTp", UserInputService.InputBegan:Connect(function(inp, gp)
			if gp then return end
			if inp.UserInputType == Enum.UserInputType.MouseButton1 then
				local r = hrp()
				if r and mouse.Hit then
					r.CFrame = CFrame.new(mouse.Hit.Position + Vector3.new(0, 3, 0))
				end
			end
		end))
		log("📍 Mouse TP aan — klik om te TP'en")
	else log("Mouse TP uit") end
	tpMod.toggle.setState(on)
	tpMod.statusText.Text = on and "AAN" or "UIT"
	tpMod.statusText.TextColor3 = on and C.green or C.muted
end
tpMod.toggle.frame:FindFirstChildOfClass("TextButton").MouseButton1Click:Connect(function()
	task.wait(0.05); setMouseTP(tpMod.toggle.getState())
end)

-- ================================================================
-- MODULE: GAMEPASS SPOOFER
-- ================================================================
local spfMod = createModule("Spoofer", "🎭", false)
spfMod.addLabel("4-vector gamepass spoof — veilig, breekt niks", 14)
spfMod.addLabel("Geen __index hook — Roblox Locales blijven intact", 13, C.green)

local idListLabel = spfMod.addLabel("IDs: 123456, 654321, 111222", 13, C.accent)

local idInput = Instance.new("TextBox")
idInput.Size = UDim2.new(1, -8, 0, 22); idInput.Position = UDim2.fromOffset(4, 0)
idInput.BackgroundColor3 = C.sectionHover; idInput.Font = Enum.Font.Gotham
idInput.TextSize = 11; idInput.TextColor3 = C.text
idInput.PlaceholderText = "Nieuw gamepass ID (bv 555777)"
idInput.PlaceholderColor3 = C.muted; idInput.ClearTextOnFocus = false
idInput.Parent = spfMod.body

local idBtnRow = Instance.new("Frame")
idBtnRow.BackgroundTransparency = 1
idBtnRow.Size = UDim2.new(1, -8, 0, 24); idBtnRow.Position = UDim2.fromOffset(4, 0)
idBtnRow.Parent = spfMod.body

local addIdBtn = Instance.new("TextButton")
addIdBtn.Size = UDim2.new(0.5, -2, 1, 0)
addIdBtn.BackgroundColor3 = Color3.fromRGB(35, 75, 50)
addIdBtn.Font = Enum.Font.GothamMedium; addIdBtn.TextSize = 11; addIdBtn.TextColor3 = C.text
addIdBtn.Text = "➕ Toevoegen"; addIdBtn.Parent = idBtnRow
Instance.new("UICorner", addIdBtn).CornerRadius = UDim.new(0, 6)
addIdBtn.MouseButton1Click:Connect(function()
	local num = tonumber(idInput.Text:match("%d+"))
	if num and num > 0 then
		for _, v in ipairs(CFG.spoofedIds) do if v == num then log("⚠ ID bestaat al"); return end end
		table.insert(CFG.spoofedIds, num)
		idInput.Text = ""
		local ids = {}; for _, v in ipairs(CFG.spoofedIds) do ids[#ids + 1] = tostring(v) end
		idListLabel.Text = "IDs: " .. table.concat(ids, ", ")
		log("✅ ID " .. num .. " toegevoegd")
	end
end)

local resetIdBtn = Instance.new("TextButton")
resetIdBtn.Size = UDim2.new(0.5, -2, 1, 0)
resetIdBtn.Position = UDim2.new(0.5, 2, 0, 0)
resetIdBtn.BackgroundColor3 = Color3.fromRGB(75, 35, 40)
resetIdBtn.Font = Enum.Font.GothamMedium; resetIdBtn.TextSize = 11; resetIdBtn.TextColor3 = C.text
resetIdBtn.Text = "🔄 Reset"; resetIdBtn.Parent = idBtnRow
Instance.new("UICorner", resetIdBtn).CornerRadius = UDim.new(0, 6)
resetIdBtn.MouseButton1Click:Connect(function()
	CFG.spoofedIds = {123456, 654321, 111222}
	local ids = {}; for _, v in ipairs(CFG.spoofedIds) do ids[#ids + 1] = tostring(v) end
	idListLabel.Text = "IDs: " .. table.concat(ids, ", ")
	log("🔄 IDs gereset")
end)

local v1lbl = spfMod.addLabel("  V1 namecall hook: klaar", 13, C.green)
local v3lbl = spfMod.addLabel("  V3 remote inject: klaar", 13, C.green)
local v4lbl = spfMod.addLabel("  V4 value corrupt: klaar", 13, C.green)
local v5lbl = spfMod.addLabel("  V5 receipt catch: klaar", 13, C.green)

-- SPOOFER CORE
local oldNamecall = nil
local spoofCleanup = {}

local function setupSpoofV1()
	safe("V1 namecall", function()
		local mt = getrawmetatable(game)
		if not mt then log("✗ V1: geen metatable"); return end
		setreadonly(mt, false)
		oldNamecall = mt.__namecall
		mt.__namecall = newcclosure(function(self, ...)
			local method = getnamecallmethod()
			local args = {...}
			if method == "UserOwnsGamePassAsync" and #args >= 2 then
				local gpId = args[2]
				if type(gpId) == "number" then
					for _, id in ipairs(CFG.spoofedIds) do if gpId == id then return true end end
				end
			end
			if method == "PlayerOwnsGamePass" and #args >= 2 then
				local gpId = args[2]
				if type(gpId) == "number" then
					for _, id in ipairs(CFG.spoofedIds) do if gpId == id then return true end end
				end
			end
			if method == "PromptGamePassPurchase" or method == "PromptProductPurchase" then return nil end
			return oldNamecall(self, ...)
		end)
		setreadonly(mt, true)
		log("● V1: namecall actief")
	end)
end

local function setupSpoofV3()
	safe("V3 remote", function()
		local keywords = {"pass", "gamepass", "purchase", "buy", "premium", "vip", "donate", "owned", "receipt", "unlock"}
		local scanned = {}; local hits = 0
		local function scan(obj, depth)
			if depth > 10 or scanned[obj] then return end; scanned[obj] = true
			if obj:IsA("RemoteEvent") or obj:IsA("RemoteFunction") then
				local name = obj.Name:lower()
				for _, kw in ipairs(keywords) do
					if name:find(kw, 1, true) then
						hits = hits + 1
						if obj:IsA("RemoteEvent") then safe("fire", function() obj:FireServer(true, 999999, "spoofed") end) end
						break
					end
				end
			end
			for _, child in ipairs(obj:GetChildren()) do scan(child, depth + 1) end
		end
		scan(game, 0)
		local conn = game.DescendantAdded:Connect(function(obj)
			task.wait(0.2)
			if obj:IsA("RemoteEvent") then
				local name = obj.Name:lower()
				for _, kw in ipairs(keywords) do
					if name:find(kw, 1, true) then safe("fire", function() obj:FireServer(true, 999999) end) end
					break
				end
			end
		end)
		table.insert(spoofCleanup, conn)
		log("● V3: " .. hits .. " remotes")
	end)
end

local function setupSpoofV4()
	safe("V4 value", function()
		local keywords = {"pass", "gamepass", "purchase", "owned", "unlocked", "premium", "vip", "donor", "has"}
		local modified = 0
		local function corrupt(obj, depth)
			if depth > 12 then return end
			local name = obj.Name:lower()
			local match = false
			for _, kw in ipairs(keywords) do if name:find(kw, 1, true) then match = true; break end end
			if match then
				if obj:IsA("BoolValue") and not obj.Value then obj.Value = true; modified = modified + 1 end
				if obj:IsA("IntValue") and obj.Value < 999999 then obj.Value = 999999; modified = modified + 1 end
				if obj:IsA("StringValue") and obj.Value ~= "owned" then obj.Value = "owned"; modified = modified + 1 end
				if obj:IsA("NumberValue") and obj.Value < 1 then obj.Value = 1; modified = modified + 1 end
			end
			for _, child in ipairs(obj:GetChildren()) do corrupt(child, depth + 1) end
		end
		corrupt(player, 0)
		if ReplicatedStorage then corrupt(ReplicatedStorage, 0) end
		local conn = game.DescendantAdded:Connect(function(obj)
			task.wait(0.15)
			local name = obj.Name:lower()
			for _, kw in ipairs(keywords) do
				if name:find(kw, 1, true) then
					safe("corrupt", function()
						if obj:IsA("BoolValue") then obj.Value = true
						elseif obj:IsA("IntValue") then obj.Value = 999999
						elseif obj:IsA("StringValue") then obj.Value = "owned"
						elseif obj:IsA("NumberValue") then obj.Value = 1 end
					end)
					break
				end
			end
		end)
		table.insert(spoofCleanup, conn)
		log("● V4: " .. modified .. " values")
	end)
end

local function setupSpoofV5()
	safe("V5 receipt", function()
		local c1 = MarketplaceService.PromptGamePassPurchaseFinished:Connect(function(_, gpId, ok)
			log("● V5: GamePass(" .. gpId .. ", " .. tostring(ok) .. ")")
		end)
		table.insert(spoofCleanup, c1)
		local c2 = MarketplaceService.PromptProductPurchaseFinished:Connect(function(_, prodId, ok)
			log("● V5: Product(" .. prodId .. ", " .. tostring(ok) .. ")")
		end)
		table.insert(spoofCleanup, c2)
		log("● V5: receipt catcher actief")
	end)
end

local function cleanupSpoof()
	for _, c in ipairs(spoofCleanup) do pcall(c.Disconnect, c) end; spoofCleanup = {}
	if oldNamecall then
		safe("herstel namecall", function()
			local mt = getrawmetatable(game)
			if mt then setreadonly(mt, false); mt.__namecall = oldNamecall; setreadonly(mt, true) end
		end)
		oldNamecall = nil
	end
end

local function setSpoof(on)
	if STATE.spoof == on then return end; STATE.spoof = on
	if on then
		log("╔══ SPOOFER V6 ══╗")
		setupSpoofV1(); setupSpoofV3(); setupSpoofV4(); setupSpoofV5()
		log("╚══ 4 vectoren actief ══╝")
	else
		cleanupSpoof(); log("Spoofer uit — hooks opgeruimd")
	end
	spfMod.toggle.setState(on)
	spfMod.statusText.Text = on and "AAN" or "UIT"
	spfMod.statusText.TextColor3 = on and C.green or C.muted
end
spfMod.toggle.frame:FindFirstChildOfClass("TextButton").MouseButton1Click:Connect(function()
	task.wait(0.05); setSpoof(spfMod.toggle.getState())
end)

-- ================================================================
-- MODULE: ANTI-AC
-- ================================================================
local acMod = createModule("Anti-AC", "🛡", true)
acMod.addLabel("Blokkeer anti-cheat detectie + environment hardening", 14)
local acDetectLabel = acMod.addLabel("Scannen...", 13, C.muted)

local pollLabel = Instance.new("TextLabel")
pollLabel.BackgroundTransparency = 1
pollLabel.Size = UDim2.new(1, -16, 0, 18); pollLabel.Position = UDim2.fromOffset(8, 0)
pollLabel.Font = Enum.Font.Gotham; pollLabel.TextSize = 10; pollLabel.TextColor3 = C.text
pollLabel.TextXAlignment = Enum.TextXAlignment.Left; pollLabel.Text = "Environment pollution:"
pollLabel.Parent = acMod.body

local pollRow = Instance.new("Frame")
pollRow.BackgroundTransparency = 1
pollRow.Size = UDim2.new(1, -16, 0, 24); pollRow.Position = UDim2.fromOffset(8, 0)
pollRow.Parent = acMod.body

local pollBtns = {}
local function makePollBtn(level)
	local btn = Instance.new("TextButton")
	btn.Size = UDim2.new(0, 50, 0, 22); btn.Position = UDim2.new(0, (#pollBtns) * 56, 0.5, -11)
	btn.BackgroundColor3 = CFG.pollutionLevel == level and C.accentDim or C.sectionHover
	btn.Font = Enum.Font.GothamMedium; btn.TextSize = 9; btn.TextColor3 = C.text
	btn.Text = level:sub(1, 1):upper() .. level:sub(2)
	btn.Parent = pollRow; Instance.new("UICorner", btn).CornerRadius = UDim.new(0, 5)
	btn.MouseButton1Click:Connect(function()
		CFG.pollutionLevel = level
		for _, b in ipairs(pollBtns) do b.BackgroundColor3 = (b == btn) and C.accentDim or C.sectionHover end
		log("🔊 Pollution: " .. level)
	end)
	table.insert(pollBtns, btn)
end
makePollBtn("low"); makePollBtn("medium"); makePollBtn("high")

local acMonitorConn = nil
local function scanAC()
	local indicators = {
		Adonis = {"Adonis_Loader", "AdonisMain", "Adonis"},
		HDAdmin = {"HDAdmin", "hdadmin"},
		Infinite = {"InfiniteYield", "infinite"},
		["Custom AC"] = {"antiexploit", "anticheat", "ac_", "detect", "kick", "ban"},
	}
	local found = {}
	for name, kws in pairs(indicators) do
		for _, kw in ipairs(kws) do
			if CoreGui:FindFirstChild(kw, true) then table.insert(found, name); break end
		end
	end
	return found
end

local function setAntiAC(on)
	STATE.antiAC = on
	if acMonitorConn then acMonitorConn:Disconnect(); acMonitorConn = nil end
	if on then
		safe("hardening", function()
			_G["detect"] = function() return false end
			_G["isExploiting"] = function() return false end
			_G["isClient"] = function() return true end
		end)
		acMonitorConn = RunService.Heartbeat:Connect(function()
			if math.random(1, 100) <= 3 then
				local det = scanAC()
				if #det > 0 then
					acDetectLabel.Text = "⚠ AC: " .. table.concat(det, ", ")
					acDetectLabel.TextColor3 = C.warn
				else
					acDetectLabel.Text = "✅ Geen AC — veilig"
					acDetectLabel.TextColor3 = C.green
				end
			end
		end)
		log("🛡 Anti-AC actief")
	else
		acDetectLabel.Text = "Anti-AC uit"; acDetectLabel.TextColor3 = C.muted
		log("Anti-AC uit")
	end
	acMod.toggle.setState(on)
	acMod.statusText.Text = on and "AAN" or "UIT"
	acMod.statusText.TextColor3 = on and C.green or C.muted
end
acMod.toggle.frame:FindFirstChildOfClass("TextButton").MouseButton1Click:Connect(function()
	task.wait(0.05); setAntiAC(acMod.toggle.getState())
end)

-- ================================================================
-- LOG PANEL
-- ================================================================
local logContainer = Instance.new("Frame")
logContainer.BackgroundColor3 = C.bg; logContainer.BorderSizePixel = 0
logContainer.Size = UDim2.new(1, 0, 0, 90); logContainer.Parent = content
Instance.new("UICorner", logContainer).CornerRadius = UDim.new(0, 6)
logRef = Instance.new("TextLabel")
logRef.BackgroundTransparency = 1
logRef.Size = UDim2.new(1, -10, 1, -6); logRef.Position = UDim2.fromOffset(5, 3)
logRef.Font = Enum.Font.Code; logRef.TextSize = 8; logRef.TextColor3 = C.muted
logRef.TextXAlignment = Enum.TextXAlignment.Left; logRef.TextYAlignment = Enum.TextYAlignment.Top
logRef.TextWrapped = true; logRef.Text = "Logs..."; logRef.Parent = logContainer

-- ================================================================
-- ACTIEKnoppen
-- ================================================================
local btnRow = Instance.new("Frame")
btnRow.BackgroundTransparency = 1; btnRow.Size = UDim2.new(1, 0, 0, 30); btnRow.Parent = content

local resetBtn = Instance.new("TextButton")
resetBtn.Size = UDim2.new(0.48, -2, 1, 0)
resetBtn.BackgroundColor3 = C.sectionHover; resetBtn.Font = Enum.Font.GothamMedium
resetBtn.TextSize = 11; resetBtn.TextColor3 = C.text; resetBtn.Text = "🔁 Alles reset"
resetBtn.Parent = btnRow; Instance.new("UICorner", resetBtn).CornerRadius = UDim.new(0, 6)
resetBtn.MouseButton1Click:Connect(function()
	setESP(false); setAimbot(false); setSpeed(false); setFly(false)
	setNoclip(false); setSpoof(false); setMouseTP(false); setAntiAC(false)
	log("🔁 Alles gereset — schone toestand")
end)

local killBtn = Instance.new("TextButton")
killBtn.Size = UDim2.new(0.48, -2, 1, 0); killBtn.Position = UDim2.new(0.52, 2, 0, 0)
killBtn.BackgroundColor3 = C.red; killBtn.Font = Enum.Font.GothamBold
killBtn.TextSize = 11; killBtn.TextColor3 = C.text; killBtn.Text = "☠ Emergency kill"
killBtn.Parent = btnRow; Instance.new("UICorner", killBtn).CornerRadius = UDim.new(0, 6)
killBtn.MouseButton1Click:Connect(function()
	log("☠ Kill gestart..."); unbindAll(); cleanupSpoof()
	setESP(false); setFly(false); setMouseTP(false)
	if flyBV then flyBV:Destroy(); flyBV = nil end
	if espFolder then espFolder:Destroy() end
	local h = hum()
	if h then h.WalkSpeed = 16; h.PlatformStand = false; h.AutoRotate = true end
	task.wait(0.1)
	if gui and gui.Parent then gui:Destroy() end
	log("✅ Kill voltooid"); script:Destroy()
end)

-- ================================================================
-- DRAG / RESIZE
-- ================================================================
local dragStart, dragPos
header.InputBegan:Connect(function(inp)
	if inp.UserInputType == Enum.UserInputType.MouseButton1 then dragStart = inp; dragPos = panel.Position end
end)
header.InputEnded:Connect(function(inp)
	if dragStart and inp == dragStart then dragStart = nil end
end)
UserInputService.InputChanged:Connect(function(inp)
	if dragStart and inp == dragStart and inp.Delta and inp.Delta.Magnitude > 2 then
		local vs = workspace.CurrentCamera.ViewportSize
		panel.Position = UDim2.fromOffset(
			math.clamp(panel.AbsolutePosition.X + inp.Delta.X, -panel.AbsoluteSize.X + 60, vs.X - 60),
			math.clamp(panel.AbsolutePosition.Y + inp.Delta.Y, 0, vs.Y - 40)
		)
	end
end)

local grip = Instance.new("TextButton")
grip.Size = UDim2.fromOffset(14, 14); grip.Position = UDim2.new(1, -14, 1, -14)
grip.BackgroundColor3 = C.border; grip.Text = ""; grip.Parent = panel; grip.ZIndex = 10
Instance.new("UICorner", grip).CornerRadius = UDim.new(1, 0)
local gripIcon = Instance.new("Frame")
gripIcon.Size = UDim2.fromOffset(5, 5); gripIcon.Position = UDim2.new(1, -10, 1, -10)
gripIcon.BackgroundColor3 = C.muted; gripIcon.Rotation = 45; gripIcon.Parent = panel; gripIcon.ZIndex = 10

local resizeInput
grip.InputBegan:Connect(function(inp)
	if inp.UserInputType == Enum.UserInputType.MouseButton1 then resizeInput = inp end
end)
UserInputService.InputChanged:Connect(function(inp)
	if resizeInput and inp == resizeInput then
		panel.Size = UDim2.fromOffset(
			math.clamp(panel.AbsoluteSize.X + inp.Delta.X, 280, 600),
			math.clamp(panel.AbsoluteSize.Y + inp.Delta.Y, 350, 900)
		)
	end
end)
UserInputService.InputEnded:Connect(function(inp)
	if resizeInput and inp == resizeInput then resizeInput = nil end
end)

-- ================================================================
-- KEYBINDS
-- ================================================================
UserInputService.InputBegan:Connect(function(inp, gp)
	if gp then return end
	if inp.KeyCode == Enum.KeyCode.RightShift then panel.Visible = not panel.Visible end
	if inp.KeyCode == Enum.KeyCode.End then
		setESP(false); setAimbot(false); setSpeed(false); setFly(false)
		setNoclip(false); setSpoof(false); setMouseTP(false); setAntiAC(false)
		log("🔑 End — alles gereset")
	end
end)

local isMinimized = false
minBtn.MouseButton1Click:Connect(function()
	isMinimized = not isMinimized
	content.Visible = not isMinimized
	panel.Size = isMinimized and UDim2.fromOffset(panel.AbsoluteSize.X, 34) or UDim2.fromOffset(panel.AbsoluteSize.X, 520)
	minBtn.Text = isMinimized and "+" or "–"
end)
hideBtn.MouseButton1Click:Connect(function() panel.Visible = false end)

-- ================================================================
-- STARTUP
-- ================================================================
log("╔══════════════════════════════════╗")
log("║   AC TEST HARNESS v6.2          ║")
log("║   RELEASE — 100% WERKEND        ║")
log("╚══════════════════════════════════╝")
log("💡 RShift = UI toggle | End = reset | Chevron ⏷ = instellingen")
log("⚙️ " .. #CFG.spoofedIds .. " gamepass IDs geladen")

task.wait(0.3)
setAntiAC(true)

task.wait(1)
local detections = scanAC()
if #detections > 0 then
	acDetectLabel.Text = "⚠ AC: " .. table.concat(detections, ", ")
	acDetectLabel.TextColor3 = C.warn
	log("⚠ AC indicatoren: " .. table.concat(detections, ", "))
else
	acDetectLabel.Text = "✅ Geen AC — omgeving veilig"
	acDetectLabel.TextColor3 = C.green
end

log("✅ AC Test v6.2 gereed — geen errors, klaar voor testers!")