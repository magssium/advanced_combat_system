local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local Packages = ReplicatedStorage:WaitForChild("Packages")
local React = require(Packages.React)
local ReactRoblox = require(Packages.ReactRoblox)

local shared = ReplicatedStorage:WaitForChild("shared")
local remotes = shared:WaitForChild("remotes")
local ReplicatorEvent = remotes:WaitForChild("Replicator")

local comboTracker = {}

-- example for the ranks
local RANKS = {
	{ text = "OKAY!", color = Color3.fromRGB(255, 220, 50) },
	{ text = "GOOD!", color = Color3.fromRGB(80, 220, 100) },
	{ text = "GREAT!", color = Color3.fromRGB(50, 180, 255) },
	{ text = "PERFECT!", color = Color3.fromRGB(255, 140, 0) },
	{ text = "CRITICAL!", color = Color3.fromRGB(255, 40, 70) },
	{ text = "INSANE!", color = Color3.fromRGB(180, 50, 255) },
}


local function ComboPopup(props)
	local positionOffset, setPositionOffset = React.useState(Vector3.new(math.random(-15, 15) / 10, 2, 0))
	local transparency, setTransparency = React.useState(0)

	React.useEffect(function()
		local startTime = os.clock()
		local duration = 0.65

		local connection = RunService.RenderStepped:Connect(function()
			local elapsed = os.clock() - startTime
			local progress = math.clamp(elapsed / duration, 0, 1)

			setPositionOffset(Vector3.new(positionOffset.X, 2 + (progress * 3), 0))

			if progress > 0.5 then
				setTransparency((progress - 0.5) * 2)
			end

			if progress >= 1 then
				if props.onComplete then props.onComplete() end
			end
		end)

		return function() connection:Disconnect() end
	end, {})

	if not props.targetPart then return nil end

	local topText = "+" .. tostring(props.comboCount) .. " COMBO"
	if props.isBlockBreak then
		topText = "BLOCK BROKEN!"
	elseif props.isBlocked then
		topText = "BLOCKED"
	end

	local bottomText = if (props.isBlocked or props.isBlockBreak) then "+" .. tostring(props.comboCount) else props.rankData.text

	return React.createElement("BillboardGui", {
		Adornee = props.targetPart,
		Size = UDim2.fromOffset(220, 80),
		StudsOffset = positionOffset,
		AlwaysOnTop = true,
		ResetOnSpawn = false,
	}, {
		UIListLayout = React.createElement("UIListLayout", {
			SortOrder = Enum.SortOrder.LayoutOrder,
			HorizontalAlignment = Enum.HorizontalAlignment.Center,
			VerticalAlignment = Enum.VerticalAlignment.Center,
			Padding = UDim.new(0, -5),
		}),
		ComboText = React.createElement("TextLabel", {
			LayoutOrder = 1,
			Size = UDim2.fromScale(1, 0.5),
			BackgroundTransparency = 1,
			Text = topText,
			Font = Enum.Font.Arcade,
			TextSize = 28,
			TextColor3 = props.rankData.color,
			TextStrokeColor3 = Color3.fromRGB(0, 0, 0),
			TextStrokeTransparency = transparency,
			TextTransparency = transparency,
		}),
		SubText = React.createElement("TextLabel", {
			LayoutOrder = 2,
			Size = UDim2.fromScale(1, 0.4),
			BackgroundTransparency = 1,
			Text = bottomText,
			Font = Enum.Font.Arcade,
			TextSize = 22,
			TextColor3 = props.rankData.color,
			TextStrokeColor3 = Color3.fromRGB(0, 0, 0),
			TextStrokeTransparency = transparency,
			TextTransparency = transparency,
		}),
	})
end


ReplicatorEvent.OnClientEvent:Connect(function(victimModel: Model, soundId: string?, animationId: string?, serverConfirmedBlock: boolean?)
	if not victimModel or not victimModel:IsA("Model") then return end

	local rootPart = victimModel:FindFirstChild("HumanoidRootPart")
	if not rootPart then return end

	local currentTime = os.clock()
	local isRagdolled = victimModel:GetAttribute("IsRagdolled") == true
	

	local isBlocked = if serverConfirmedBlock ~= nil then serverConfirmedBlock else (victimModel:GetAttribute("IsBlocking") == true)
	local victimData = comboTracker[victimModel] or { count = 0, lastHitTime = 0, wasLastHitBlocked = false }
	local isBlockBreak = (victimData.wasLastHitBlocked == true) and (isBlocked == false) and (isRagdolled == true)

	if (currentTime - victimData.lastHitTime > 2.0) or isBlockBreak or (victimData.wasLastHitBlocked ~= isBlocked) then
		victimData.count = 1
	else
		victimData.count = victimData.count + 1
	end
	
	victimData.lastHitTime = currentTime
	victimData.wasLastHitBlocked = isBlocked
	comboTracker[victimModel] = victimData

	local rankDataToUse
	if isBlocked or isBlockBreak then
		rankDataToUse = { text = "", color = Color3.fromRGB(50, 150, 255) }
		
		local head = victimModel:FindFirstChild("Head")
		if head then
			local targetSoundId = nil
			local volumeToSet = 0.65

			if isBlockBreak then
				targetSoundId = "rbxassetid://2885026620"
				volumeToSet = 0.85
			elseif isBlocked then
				targetSoundId = "rbxassetid://136811265205147"
				volumeToSet = 0.65
				victimModel:SetAttribute("MuteNormalHitSound", true)
			end

			if targetSoundId then
				local blockSFX = Instance.new("Sound")
				blockSFX.Name = "BlockHandlingSFX"
				blockSFX.SoundId = targetSoundId
				blockSFX.Volume = volumeToSet
				blockSFX.RollOffMaxDistance = 120
				blockSFX.RollOffMinDistance = 10
				blockSFX.Parent = head
				blockSFX:Play()
				
				blockSFX.Ended:Connect(function()
					blockSFX:Destroy()
					if not isBlocked then
						victimModel:SetAttribute("MuteNormalHitSound", nil)
					end
				end)
			end
		end
	else
		rankDataToUse = RANKS[math.random(1, #RANKS)]
	end

	local container = Instance.new("Folder")
	container.Name = "ComboContainer"
	container.Parent = Workspace

	local root = ReactRoblox.createRoot(container)
	root:render(React.createElement(ComboPopup, {
		targetPart = rootPart,
		comboCount = victimData.count,
		rankData = rankDataToUse,
		isBlocked = isBlocked,
		isBlockBreak = isBlockBreak,
		onComplete = function()
			root:unmount()
			container:Destroy()
		end,
	}))
end)
