local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")
local Debris = game:GetService("Debris")

local shared = ReplicatedStorage:WaitForChild("shared")
local remotes = shared:WaitForChild("remotes")
local vfx = shared:WaitForChild("vfx")
local modules = shared:WaitForChild("modules")

local StylesData = require(modules:WaitForChild("StylesData"))

local ReplicatorEvent = remotes:WaitForChild("Replicator")
local hitVFX = vfx:FindFirstChild("hit")

local lastBlockState = {}


ReplicatorEvent.OnClientEvent:Connect(function(victimModel: Model, soundId: string?, animationId: string?, serverConfirmedBlock: boolean?)
	if not victimModel or not victimModel:IsA("Model") then return end

	local humanoid: Humanoid = victimModel:FindFirstChildOfClass("Humanoid")
	local rootPart = victimModel:FindFirstChild("HumanoidRootPart")
	if not rootPart then return end

	local isCurrentlyBlocking = if serverConfirmedBlock ~= nil then serverConfirmedBlock else (victimModel:GetAttribute("IsBlocking") == true)
	local isCurrentlyRagdolled = victimModel:GetAttribute("IsRagdolled") == true
	local wasBlockingLastHit = lastBlockState[victimModel] == true
	
	local isBlockBreakState = (wasBlockingLastHit == true) and (isCurrentlyBlocking == false) and (isCurrentlyRagdolled == true)
	local isBackstab = (victimModel:GetAttribute("WasBackstabbed") == true)
	
	lastBlockState[victimModel] = isCurrentlyBlocking

	if isBlockBreakState or isBackstab then
		if humanoid then
			local animator = humanoid:FindFirstChildOfClass("Animator")
			if animator then
				for _, track in ipairs(animator:GetPlayingAnimationTracks()) do
					if string.find(string.lower(track.Animation.AnimationId), "block") or track.Looped == true then
						track:Stop(0)
					end
				end
			end
		end
	end

	if hitVFX and not isCurrentlyBlocking then
		local clonedVFX = hitVFX:Clone()
		if clonedVFX:IsA("BasePart") then
			clonedVFX.Transparency = 1
			clonedVFX.Anchored = true
			clonedVFX.CFrame = rootPart.CFrame
		elseif clonedVFX:IsA("Model") then
			clonedVFX:PivotTo(rootPart.CFrame)
		end

		for _, desc in ipairs(clonedVFX:GetDescendants()) do
			if desc:IsA("ParticleEmitter") then
				desc:Emit(math.random(15, 25))
			end
		end
		clonedVFX.Parent = Workspace
		Debris:AddItem(clonedVFX, 1.0)
	end

	for _, child in ipairs(victimModel:GetChildren()) do
		if child:IsA("Highlight") and (child.Name == "HitFlashHighlight" or child.Name == "BlockBreakHighlight") then
			child:Destroy()
		end
	end

	local flashColor = nil
	local highlightName = "HitFlashHighlight"

	if isBlockBreakState then
		flashColor = Color3.fromRGB(50, 150, 255)
		highlightName = "BlockBreakHighlight"
	elseif not isCurrentlyBlocking then
		flashColor = Color3.fromRGB(255, 0, 0)
	end

	if flashColor then
		local hitHighlight = Instance.new("Highlight")
		hitHighlight.Name = highlightName
		hitHighlight.FillColor = flashColor
		hitHighlight.FillTransparency = 0.05
		hitHighlight.OutlineColor = Color3.fromRGB(255, 255, 255)
		hitHighlight.OutlineTransparency = 0.05
		hitHighlight.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop
		hitHighlight.Adornee = victimModel
		hitHighlight.Parent = victimModel

		local startTime = os.clock()
		local duration = 0.18
		
		local connection
		connection = RunService.RenderStepped:Connect(function()
			if not hitHighlight or not hitHighlight.Parent then
				if connection then connection:Disconnect() end
				return
			end
			
			local elapsed = os.clock() - startTime
			if elapsed >= duration then
				hitHighlight:Destroy()
				if connection then connection:Disconnect() end
				return
			end
			
			local progress = elapsed / duration
			hitHighlight.FillTransparency = 0.05 + (0.95 * progress)
			hitHighlight.OutlineTransparency = 0.05 + (0.95 * progress)
		end)
	end

	if not isCurrentlyBlocking then
		local finalSoundId = soundId

		if not finalSoundId or finalSoundId == "" then
			local styleName = victimModel:GetAttribute("currentStyle") or "Boxing"
			local styleConfig = StylesData[styleName]
			if styleConfig and styleConfig.HitSound then
				finalSoundId = styleConfig.HitSound
			end
		end

		if finalSoundId and finalSoundId ~= "" then
			local formattedSoundId = tostring(finalSoundId)
			if not string.find(formattedSoundId, "rbxassetid://") then
				formattedSoundId = "rbxassetid://" .. formattedSoundId
			end

			local hitSound = Instance.new("Sound")
			hitSound.SoundId = formattedSoundId
			hitSound.Volume = 0.8
			hitSound.RollOffMaxDistance = 100
			hitSound.Parent = rootPart
			hitSound:Play()
			Debris:AddItem(hitSound, 2.0)
		end
	end

	if animationId and animationId ~= "" and humanoid and humanoid.Health > 0 then
		local animator = humanoid:FindFirstChildOfClass("Animator")
		if animator then
			local hitAnim = Instance.new("Animation")
			hitAnim.AnimationId = animationId
			local hitTrack = animator:LoadAnimation(hitAnim)
			
			hitTrack.Priority = Enum.AnimationPriority.Action4
			hitTrack:Play(0.01)
			Debris:AddItem(hitAnim, 1.5)
		end
	end
end)
