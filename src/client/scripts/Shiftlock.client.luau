local UserInputService = game:GetService("UserInputService")
local TweenService = game:GetService("TweenService")
local RunService = game:GetService("RunService")
local SoundService = game:GetService("SoundService")
local Players = game:GetService("Players")

local player = Players.LocalPlayer
local camera = workspace.CurrentCamera

local character = player.Character or player.CharacterAdded:Wait()
local humanoid = character:WaitForChild("Humanoid")
local hrp = character:WaitForChild("HumanoidRootPart")

local tweenInfo = TweenInfo.new(0.3, Enum.EasingStyle.Cubic, Enum.EasingDirection.InOut)
local renderConnection = nil    
local shiftLockEnabled = false

local shiftLockSFX = Instance.new("Sound")
shiftLockSFX.Name = "ShiftlockClick"
shiftLockSFX.SoundId = "rbxassetid://120082466915917" 
shiftLockSFX.Volume = 0.15
shiftLockSFX.Parent = SoundService

UserInputService.MouseIcon = "rbxassetid://129875024"


local function RotateCharacterToCamera()
	if not hrp or not camera then return end

	if character and character:GetAttribute("IsRagdolled") == true then return end

	local lookVector = camera.CFrame.LookVector
	local flatLookVector = Vector3.new(lookVector.X, 0, lookVector.Z).Unit

	hrp.CFrame = CFrame.lookAt(hrp.Position, hrp.Position + flatLookVector)
end


local function ToggleShiftLock(enable)
	local clickSound = SoundService:FindFirstChild("ShiftlockClick")
	if clickSound then clickSound:Play() end

	if enable then
		humanoid.AutoRotate = false 
		UserInputService.MouseBehavior = Enum.MouseBehavior.LockCenter
		UserInputService.MouseIcon = "rbxassetid://16481167971" 

		local tweenGoal = {CameraOffset = Vector3.new(2, 0, 0)}
		local tween = TweenService:Create(humanoid, tweenInfo, tweenGoal)
		tween:Play()

		if renderConnection then renderConnection:Disconnect() end
		renderConnection = RunService.RenderStepped:Connect(RotateCharacterToCamera)
	else
		humanoid.AutoRotate = true 
		UserInputService.MouseBehavior = Enum.MouseBehavior.Default
		UserInputService.MouseIcon = "rbxassetid://129875024"

		local tweenGoal = {CameraOffset = Vector3.new(0, 0, 0)}
		local tween = TweenService:Create(humanoid, tweenInfo, tweenGoal)
		tween:Play()

		if renderConnection then 
			renderConnection:Disconnect() 
			renderConnection = nil
		end
	end
end


player.CharacterAdded:Connect(function(newCharacter)
	character = newCharacter
	humanoid = newCharacter:WaitForChild("Humanoid")
	hrp = newCharacter:WaitForChild("HumanoidRootPart")

	if shiftLockEnabled then
		humanoid.AutoRotate = false
	else
		humanoid.AutoRotate = true
	end
end)


UserInputService.InputBegan:Connect(function(input, gameProcessedEvent)
	if gameProcessedEvent then return end

	if input.KeyCode == Enum.KeyCode.LeftShift then
		shiftLockEnabled = not shiftLockEnabled
		ToggleShiftLock(shiftLockEnabled)
	end
end)
