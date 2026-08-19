--[[
    AC TEST HARNESS - SERVER BRIDGE v1.0

    Plaats dit als gewoon Script in ServerScriptService van je EIGEN game.

    Waarom dit bestaat:
    De client-harness hoeft niets te spoofen. De server bepaalt wie tester is
    en welke gamepasses de speler echt heeft. Staat jouw UserId hieronder, dan
    werken alle controls in de harness altijd, zonder Studio en zonder bypass.
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local MarketplaceService = game:GetService("MarketplaceService")

local CONFIG = {
    -- Zet hier de UserIds van je testers, bijvoorbeeld: 123456789, 987654321
    testers = {},

    -- true = alle spelers in dit game mogen de testcontrols gebruiken.
    -- Alleen aanzetten in een prive testgame.
    allowEveryone = true,

    -- Gamepass IDs van jouw game. Laat leeg om alleen auto-detect te gebruiken.
    gamePassIds = {},

    cooldown = 2,
}

-- Client leest dit attribuut als snelle check.
game:SetAttribute("AC_TEST_MODE", true)

local bridge = ReplicatedStorage:FindFirstChild("ACTH_Bridge")
if not bridge then
    bridge = Instance.new("RemoteFunction")
    bridge.Name = "ACTH_Bridge"
    bridge.Parent = ReplicatedStorage
end

local lastCall = {}

local function isTester(player)
    if CONFIG.allowEveryone then return true end
    for _, id in ipairs(CONFIG.testers) do
        if player.UserId == id then return true end
    end
    return false
end

local function collectPassIds(extra)
    local ids, seen = {}, {}
    local function add(value)
        local id = tonumber(value)
        if id and id > 0 and id % 1 == 0 and not seen[id] then
            seen[id] = true
            table.insert(ids, id)
        end
    end
    for _, id in ipairs(CONFIG.gamePassIds) do add(id) end
    if type(extra) == "table" then
        for _, id in ipairs(extra) do add(id) end
    end
    return ids
end

local function passInfo(player, extra)
    local list = {}
    for _, id in ipairs(collectPassIds(extra)) do
        local name = "GamePass " .. id
        local okInfo, info = pcall(function()
            return MarketplaceService:GetProductInfo(id, Enum.InfoType.GamePass)
        end)
        if okInfo and type(info) == "table" and info.Name then name = info.Name end
        local okOwns, owns = pcall(function()
            return MarketplaceService:UserOwnsGamePassAsync(player.UserId, id)
        end)
        table.insert(list, {
            id = id,
            name = name,
            owned = okOwns and owns == true,
            valid = okInfo,
        })
        if #list >= 40 then break end
    end
    return list
end

bridge.OnServerInvoke = function(player, action, payload)
    local now = os.clock()
    if lastCall[player] and now - lastCall[player] < CONFIG.cooldown then
        return {authorized = false, throttled = true, passes = {}}
    end
    lastCall[player] = now

    if action ~= "GetSession" then
        return {authorized = false, passes = {}}
    end

    local authorized = isTester(player)
    return {
        authorized = authorized,
        passes = authorized and passInfo(player, payload) or {},
        serverTime = os.time(),
    }
end

Players.PlayerRemoving:Connect(function(player)
    lastCall[player] = nil
end)

print("[ACTH] Server bridge actief. Toegang:", CONFIG.allowEveryone and "iedereen in dit game" or (#CONFIG.testers .. " testers"))
