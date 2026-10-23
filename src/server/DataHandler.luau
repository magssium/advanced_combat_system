local ServerScriptService = game:GetService("ServerScriptService")
local PlayerDataHandler = {}

-- example data table
local dataTemplate = {
    currentStyle = "Boxing",
    unlockedStyles = {
        "Boxing"
    }
}

local Players = game:GetService("Players")

local ServerPackages = ServerScriptService.ServerPackages
local ProfileService = require(ServerPackages.ProfileService)

local ProfileStore = ProfileService.GetProfileStore(
    "PlayerProfile",
    dataTemplate
)

local profiles = {}


local function PlayerAdded(player: Player)
    local profile = ProfileStore:LoadProfileAsync("Player_".. player.UserId)
    if profile then 
        profile:AddUserId(player.UserId)
        profile:Reconcile()

        profile:ListenToRelease(function()
            profiles[player] = nil
            player:Kick()
        end)

        if not player:IsDescendantOf(Players) then
            profile:Release()
        else
            profiles[player] = profile
        end
    else
        player:Kick()
    end
end


local function GetProfile(player: Player)
    local startTime = os.clock()
    while not profiles[player] and (os.clock() - startTime) < 5 do
        task.wait()
    end

    assert(profiles[player], string.format("Profile does not exist for %s", player.UserId))
    return profiles[player]
end


function PlayerDataHandler:Init()
    for _, player in Players:GetPlayers() do
        task.spawn(PlayerAdded, player)
    end

    Players.PlayerAdded:Connect(PlayerAdded)
    Players.PlayerRemoving:Connect(function(player)
        if profiles[player] then
            profiles[player]:Release()
        end
    end)
end


function PlayerDataHandler:Get(player: Player, key)
    local profile = GetProfile(player)
    assert(profile.Data[key] ~= nil, string.format("Data does not exist for key: %s", key))

    return profile.Data[key]
end


function PlayerDataHandler:Set(player: Player, key, value)
    local profile = GetProfile(player)
    assert(profile.Data[key] ~= nil, string.format("Data does not exist for key: %s", key))
    assert(type(profile.Data[key]) == type(value))
    
    profile.Data[key] = value
end


function PlayerDataHandler:Update(player: Player, key, callback)
    local profile = GetProfile(player)
    local oldData = self:Get(player, key)
    local newData = callback(oldData)

    self:Set(player, key, newData)
end

return PlayerDataHandler
