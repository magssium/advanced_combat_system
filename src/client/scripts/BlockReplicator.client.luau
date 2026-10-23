local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")
local Players = game:GetService("Players")

local shared = ReplicatedStorage:WaitForChild("shared")
local remotes = shared:WaitForChild("remotes")
local vfx = shared:WaitForChild("vfx")

local BlockReplication = remotes:WaitForChild("BlockReplication")
local blockShieldTemplate = vfx:WaitForChild("block")
local shieldBreakTemplate = vfx:FindFirstChild("blockBreak")

local activeShields = {}
local GUARD_BREAK_VFX_DURATION = 0.5
local localPlayer = Players.LocalPlayer


local function Toggle3DShieldVFX(character: Model, isBlocking: boolean)
    if not character or not character:IsA("Model") then return end

    if isBlocking then
        if activeShields[character] then return end

        local rootPart = character:FindFirstChild("HumanoidRootPart")

        if rootPart and blockShieldTemplate then
            local shieldVFX = blockShieldTemplate:Clone()
            shieldVFX.Name = "BlockShield"

            if shieldVFX:IsA("BasePart") then
                shieldVFX.Anchored = false
                shieldVFX.CanCollide = false
                shieldVFX.CanTouch = false
                shieldVFX.CanQuery = false
                shieldVFX.Massless = true
                shieldVFX.Transparency = 1
            end

            for _, desc in ipairs(shieldVFX:GetDescendants()) do
                if desc:IsA("BillboardGui") or desc:IsA("SurfaceGui") or desc:IsA("GuiObject") then
                    desc:Destroy()
                elseif desc:IsA("BasePart") then
                    desc.Anchored = false
                    desc.CanCollide = false
                    desc.CanTouch = false
                    desc.CanQuery = false
                    desc.Massless = true
                    desc.Transparency = 1
                end
            end

            if shieldVFX:IsA("BasePart") or shieldVFX:IsA("Model") then
                local mainPart = shieldVFX:IsA("BasePart") and shieldVFX 
                    or shieldVFX.PrimaryPart 
                    or shieldVFX:FindFirstChildWhichIsA("BasePart")

                if mainPart then
                    local targetCFrame = rootPart.CFrame * CFrame.new(0, 0, -1.5)

                    if shieldVFX:IsA("Model") then
                        shieldVFX:PivotTo(targetCFrame)
                    else
                        shieldVFX.CFrame = targetCFrame
                    end

                    local weld = Instance.new("WeldConstraint")
                    weld.Part0 = rootPart
                    weld.Part1 = mainPart
                    weld.Parent = mainPart
                end
                shieldVFX.Parent = character
            end

            for _, desc in ipairs(shieldVFX:GetDescendants()) do
                if desc:IsA("ParticleEmitter") then
                    desc.Enabled = true
                    desc:Emit(desc.Rate > 0 and math.clamp(math.floor(desc.Rate * 0.2), 5, 25) or 10)
                end
            end

            activeShields[character] = shieldVFX
        end
    else
        if activeShields[character] then
            local shield = activeShields[character]
            activeShields[character] = nil

            for _, desc in ipairs(shield:GetDescendants()) do
                if desc:IsA("ParticleEmitter") then
                    desc.Enabled = false
                end
            end

            task.delay(0.2, function()
                if shield then shield:Destroy() end
            end)
        end
    end
end


local function TriggerGuardBreakVFX(character: Model)
    if not character or not character:IsA("Model") then return end
    local rootPart = character:FindFirstChild("HumanoidRootPart")
    if not rootPart then return end

    if activeShields[character] then
        local oldShield = activeShields[character]
        activeShields[character] = nil
        oldShield:Destroy()
    end

    if shieldBreakTemplate then
        local breakEffect = shieldBreakTemplate:Clone()
        local targetCFrame = rootPart.CFrame * CFrame.new(0, 0, -1.5)

        if breakEffect:IsA("Model") then
            breakEffect:PivotTo(targetCFrame)
        elseif breakEffect:IsA("BasePart") then
            breakEffect.CFrame = targetCFrame
        end

        breakEffect.Parent = workspace

        for _, desc in ipairs(breakEffect:GetDescendants()) do
            if desc:IsA("ParticleEmitter") then
                desc:Emit(desc.Rate > 0 and desc.Rate or 30)
            elseif desc:IsA("Sound") then
                desc:Play()
            end
        end

        task.delay(GUARD_BREAK_VFX_DURATION, function()
            if not breakEffect then return end
            for _, desc in ipairs(breakEffect:GetDescendants()) do
                if desc:IsA("ParticleEmitter") then
                    desc.Enabled = false
                elseif desc:IsA("Sound") then
                    desc:Stop()
                end
            end
            breakEffect:Destroy()
        end)
    end
end


local function TrackCharacter(character)
    local targetPlayer = Players:GetPlayerFromCharacter(character)
    
    -- FIXED CHECK: Allow tracking if it's YOU, but keep skipping other real players 
    -- to prevent network backstab clipping glitches.
    if targetPlayer and targetPlayer ~= localPlayer then return end

    if character:GetAttribute("IsBlocking") == true then
        Toggle3DShieldVFX(character, true)
    end

	character:GetAttributeChangedSignal("IsBlocking"):Connect(function()
		local state = character:GetAttribute("IsBlocking") or false
		Toggle3DShieldVFX(character, state)
	end)
end

for _, child in ipairs(Workspace:GetChildren()) do
	if child:IsA("Model") and child:FindFirstChildOfClass("Humanoid") then
		TrackCharacter(child)
	end
end


Workspace.ChildAdded:Connect(function(child)
	if child:IsA("Model") then
		task.spawn(function()
			if child:WaitForChild("Humanoid", 3) then
				TrackCharacter(child)
			end
		end)
	end
end)


BlockReplication.OnClientEvent:Connect(function(character: Model, actionType: any)
    if actionType == "GuardBreak" then
        TriggerGuardBreakVFX(character)
    elseif typeof(actionType) == "boolean" then
        Toggle3DShieldVFX(character, actionType)
    end
end)
