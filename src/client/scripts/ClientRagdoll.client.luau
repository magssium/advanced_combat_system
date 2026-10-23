local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RagdollEvent = ReplicatedStorage:WaitForChild("shared"):WaitForChild("remotes"):WaitForChild("RagdollEvent")

local JOINT_TO_LIMB = {
	["Neck"] = "Head",
	["Right Shoulder"] = "Right Arm",
	["Left Shoulder"] = "Left Arm",
	["Right Hip"] = "Right Leg",
	["Left Hip"] = "Left Leg",
}

local activeRagdollSounds = {}

RagdollEvent.OnClientEvent:Connect(function(action, character, soundId)
	if not character then return end

	if action == "StartSound" then
		if activeRagdollSounds[character] then
			activeRagdollSounds[character]:Stop()
			activeRagdollSounds[character]:Destroy()
		end

		local soundParent = character:FindFirstChild("HumanoidRootPart") or character:FindFirstChild("Head")
		if not soundParent then return end

		local sound = Instance.new("Sound")
		sound.Name = "RagdollSound"
		sound.SoundId = soundId
		sound.Looped = true
		sound.Volume = 1
		sound.Parent = soundParent
		sound:Play()

		activeRagdollSounds[character] = sound
		return
	end

	if action == "StopSound" then
		local sound = activeRagdollSounds[character]
		if sound then
			sound:Stop()
			sound:Destroy()
			activeRagdollSounds[character] = nil
		end
		return
	end

	local humanoid = character:FindFirstChildOfClass("Humanoid")
	local torso = character:FindFirstChild("Torso")
	if not humanoid or not torso then return end

	if action == "StartRagdoll" then
		local animator = humanoid:FindFirstChildOfClass("Animator")
		if animator then
			for _, track in ipairs(animator:GetPlayingAnimationTracks()) do
				track:Stop(0)
			end
		end

		humanoid.AutoRotate = false
		humanoid.PlatformStand = true
		humanoid:ChangeState(Enum.HumanoidStateType.Physics)

		for jointName, limbName in pairs(JOINT_TO_LIMB) do
			local limb = character:FindFirstChild(limbName)
			if limb then
				local motor = torso:FindFirstChild(jointName) or (character:FindFirstChild("Head") and character.Head:FindFirstChild(jointName))
				if motor and motor:IsA("Motor6D") then
					motor.Enabled = false 
				end

				if not limb:FindFirstChild("LocalRagdollConstraint") then
					local att0 = Instance.new("Attachment")
					att0.Name = "LocalRagdollAttachment"
					att0.Parent = torso
					
					local att1 = Instance.new("Attachment")
					att1.Name = "LocalRagdollAttachment"
					att1.Parent = limb
					
					local socket = Instance.new("BallSocketConstraint")
					socket.Name = "LocalRagdollConstraint"
					socket.Attachment0 = att0
					socket.Attachment1 = att1
					socket.Parent = limb
				end
			end
		end

	elseif action == "StopRagdoll" then
		for _, desc in ipairs(character:GetDescendants()) do
			if desc.Name == "LocalRagdollConstraint" or desc.Name == "LocalRagdollAttachment" then
				desc:Destroy()
			end
			if desc:IsA("Motor6D") then
				desc.Enabled = true
			end
		end

		humanoid.PlatformStand = false
		humanoid.AutoRotate = true
		humanoid:ChangeState(Enum.HumanoidStateType.GettingUp)
	end
end)