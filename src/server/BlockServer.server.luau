local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

local Shared = ReplicatedStorage:WaitForChild("shared")
local Remotes = Shared:WaitForChild("remotes")
local BlockEvent = Remotes:WaitForChild("BlockEvent")

local BlockReplication = Remotes:FindFirstChild("BlockReplication")
local StylesData = require(Shared.modules.StylesData)


BlockEvent.OnServerEvent:Connect(function(player, isBlockingState)
	local character = player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	if not humanoid or humanoid.Health <= 0 then return end
	
	if character:GetAttribute("IsStunned") == true or character:GetAttribute("IsDizzy") == true then
		character:SetAttribute("IsBlocking", false)
		BlockReplication:FireAllClients(character, false)
		return
	end
	
	character:SetAttribute("IsBlocking", isBlockingState)
	
	local currentStyle = character:GetAttribute("currentStyle") or "Boxing"
	local styleConfig = StylesData[currentStyle]
	
	if isBlockingState then
		humanoid.WalkSpeed = styleConfig and styleConfig.BlockWalkSpeed or 5
	else
		humanoid.WalkSpeed = styleConfig and styleConfig.WalkSpeed or 10
	end

	BlockReplication:FireAllClientssssssss(character, isBlockingState)
end)