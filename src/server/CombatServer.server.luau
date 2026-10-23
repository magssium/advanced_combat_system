local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")
local ServerScriptService = game:GetService("ServerScriptService")

local Shared = ReplicatedStorage:WaitForChild("shared")
local Remotes = Shared:WaitForChild("remotes")

local CombatEvent = Remotes:WaitForChild("CombatEvent")
local ToggleStyleEvent = Remotes:WaitForChild("ToggleStyleEvent")
local Replicator = Remotes:WaitForChild("Replicator")
local CameraShakeEvent = Remotes:WaitForChild("CameraShakeEvent")
local BlockReplication = Remotes:WaitForChild("BlockReplication")
local NPCAttackEvent = Remotes:WaitForChild("NPCAttackEvent")

local FightingStyle = require(Shared.modules.FightingStyle)
local StylesData = require(Shared.modules.StylesData)

local PlayerDataHandler = require(ServerScriptService.server.PlayerDataHandler)
local BanManager = require(ServerScriptService.server.BanManager)

local activeSessionStyles = {}
PlayerDataHandler:Init()


local npcStyleHelpers = {}
local function GetNpcStyleHelper(styleName)
	if not npcStyleHelpers[styleName] then
		local data = StylesData[styleName]
		npcStyleHelpers[styleName] = FightingStyle.new(
			nil,
			styleName,
			data.WalkSpeed,
			data.AnimId,
			data.IdleAnimId,
			data.MaxCombo,
			data.AttackCooldown,
			data.EndComboCooldown,
			data.M1Anims
		)
	end
	return npcStyleHelpers[styleName]
end


Players.PlayerRemoving:Connect(function(player)
	activeSessionStyles[player] = nil
end)


local function SetupPlayerStyles(player: Player)
	task.wait(0.2)
	if not player:IsDescendantOf(Players) then return end

	local savedStyle = PlayerDataHandler:Get(player, "currentStyle")
	local playerProfile = { CurrentStyleName = nil }

	for styleName, data in pairs(StylesData) do
		playerProfile[styleName] = FightingStyle.new(
			player,
			styleName,
			data.WalkSpeed,
			data.AnimId,
			data.IdleAnimId,
			data.MaxCombo,
			data.AttackCooldown,
			data.EndComboCooldown,
			data.M1Anims
		)
	end

	activeSessionStyles[player] = playerProfile
	if savedStyle and savedStyle ~= "None" and playerProfile[savedStyle] then
		playerProfile[savedStyle]:Equip()
		playerProfile.CurrentStyleName = savedStyle
		ToggleStyleEvent:FireClient(player, savedStyle)
	end
end

Players.PlayerAdded:Connect(SetupPlayerStyles)


local function RunHit(attackerCharacter, attackerPlayer, styleConfig, currentCombo, templateStyleObject)
	local liveCharacter = attackerPlayer and attackerPlayer.Character or attackerCharacter
	local liveHumanoid = liveCharacter and liveCharacter:FindFirstChildOfClass("Humanoid")
	local liveRoot = liveCharacter and liveCharacter:FindFirstChild("HumanoidRootPart")

	if not liveHumanoid or liveHumanoid.Health <= 0 or not liveRoot then return end
	if liveCharacter:GetAttribute("IsRagdolled") == true then return end

	local damageList = styleConfig.ComboDamage or {}
	local activeDamage = damageList[currentCombo] or 5 

	local knockbackList = styleConfig.ComboKnockback or {}
	local activeKnockbackSpeed = knockbackList[currentCombo] or 15

	local hitboxSize = styleConfig.HitboxSettings.Size
	local hitboxOffset = styleConfig.HitboxSettings.Offset
	local hitboxCFrame = liveRoot.CFrame * CFrame.new(hitboxOffset)

	local visualBox = Instance.new("Part")
	visualBox.Size = hitboxSize
	visualBox.CFrame = hitboxCFrame
	visualBox.Anchored = true
	visualBox.CanCollide = false
	visualBox.CanQuery = false
	visualBox.Material = Enum.Material.Neon
	visualBox.Color = Color3.fromRGB(255, 50, 50)
	visualBox.Transparency = 0.6
	visualBox.Parent = workspace
	game:GetService("Debris"):AddItem(visualBox, 0.15)

	local overlapParams = OverlapParams.new()
	overlapParams.FilterType = Enum.RaycastFilterType.Exclude
	overlapParams.FilterDescendantsInstances = {liveCharacter}

	local partsFound = workspace:GetPartBoundsInBox(hitboxCFrame, hitboxSize, overlapParams)

	table.sort(partsFound, function(a, b)
		local distA = (a.Position - hitboxCFrame.Position).Magnitude
		local distB = (b.Position - hitboxCFrame.Position).Magnitude
		return distA < distB
	end)

	local hitHumanoids = {}

	for _, part in ipairs(partsFound) do
		local victimModel = part.Parent
		local targetHumanoid = victimModel:FindFirstChildOfClass("Humanoid")
		local targetRoot = victimModel:FindFirstChild("HumanoidRootPart")
		local targetPlayer = Players:GetPlayerFromCharacter(victimModel)

		if targetHumanoid and targetHumanoid.Health > 0 and targetRoot and not hitHumanoids[targetHumanoid]
			and victimModel:GetAttribute("IsRagdolled") ~= true then
			hitHumanoids[targetHumanoid] = true

			local isTargetBlocking = victimModel:GetAttribute("IsBlocking") == true
			local isGuardBroken = false

			if isTargetBlocking then
				local attackerToVictim = (targetRoot.Position - liveRoot.Position).Unit
				local victimLook = targetRoot.CFrame.LookVector
				local dotProduct = victimLook:Dot(-attackerToVictim)

				if dotProduct < 0.25 then
					isTargetBlocking = false

					victimModel:SetAttribute("IsBlocking", false)
					victimModel:SetAttribute("WasBackstabbed", true)

					victimModel:SetAttribute("NetworkBlockLock", true)
					task.delay(0.5, function()
						if victimModel and victimModel.Parent then
							victimModel:SetAttribute("NetworkBlockLock", nil)
							victimModel:SetAttribute("WasBackstabbed", nil)
						end
					end)
				else
					victimModel:SetAttribute("WasBackstabbed", false)

					local targetMaxBlockHp = styleConfig.MaxBlockHealth
					local currentBlockHP = victimModel:GetAttribute("BlockHealth") or targetMaxBlockHp
					local blockDamage = styleConfig.BlockDamage
					local newBlockHP = math.max(0, currentBlockHP - blockDamage)

					victimModel:SetAttribute("BlockHealth", newBlockHP)

					if newBlockHP <= 0 then
						isGuardBroken = true
						isTargetBlocking = false

						victimModel:SetAttribute("IsBlocking", false)
						victimModel:SetAttribute("BlockHealth", targetMaxBlockHp)
						victimModel:SetAttribute("GuardBrokenAt", workspace:GetServerTimeNow())

						BlockReplication:FireAllClients(victimModel, "GuardBreak")
					end
				end
			end

			local finalDamage = activeDamage
			if isTargetBlocking then
				finalDamage = activeDamage * styleConfig.BlockDamageMultiplier
			end

			targetHumanoid:TakeDamage(finalDamage) 

			local isFinisher = (currentCombo == styleConfig.MaxCombo) or isGuardBroken

			if isFinisher and not isTargetBlocking then
				local ragdollToken
				if targetPlayer then
					local targetSession = activeSessionStyles[targetPlayer]
					if targetSession and targetSession.CurrentStyleName then
						local activeTargetStyleObject = targetSession[targetSession.CurrentStyleName]
						if activeTargetStyleObject and activeTargetStyleObject.RagdollCharacter then
							ragdollToken = activeTargetStyleObject:RagdollCharacter(victimModel)
						end
					end
				else
					local styleObjectTemplate = templateStyleObject
					if styleObjectTemplate and styleObjectTemplate.RagdollCharacter then
						ragdollToken = styleObjectTemplate:RagdollCharacter(victimModel)
					end
				end

				local recoveryTime = 2.0
				if isGuardBroken then
					recoveryTime = styleConfig.BlockBreakRecoveryTime
					if targetPlayer then
						local targetSession = activeSessionStyles[targetPlayer]
						if targetSession and targetSession.CurrentStyleName then
							local targetStyleConfig = StylesData[targetSession.CurrentStyleName]
							recoveryTime = targetStyleConfig.BlockBreakRecoveryTime or recoveryTime
						end
					end
				end

				task.delay(recoveryTime, function()
					if victimModel and targetHumanoid and targetHumanoid.Health > 0 then
						local recoveryStyleObject
						if targetPlayer then
							local targetSession = activeSessionStyles[targetPlayer]
							if targetSession and targetSession.CurrentStyleName then
								recoveryStyleObject = targetSession[targetSession.CurrentStyleName]
							end
						else
							recoveryStyleObject = templateStyleObject
						end

						if recoveryStyleObject and recoveryStyleObject.UnragdollCharacter then
							recoveryStyleObject:UnragdollCharacter(victimModel, ragdollToken)
						else
							targetHumanoid:ChangeState(Enum.HumanoidStateType.GettingUp)
						end

						if targetPlayer then
							local targetSession = activeSessionStyles[targetPlayer]
							if targetSession and targetSession.CurrentStyleName then
								local targetStyleConfig = StylesData[targetSession.CurrentStyleName]
								targetHumanoid.WalkSpeed = targetStyleConfig.WalkSpeed or 16
							else
								targetHumanoid.WalkSpeed = 16
							end
						else
							targetHumanoid.WalkSpeed = 10
						end
					end
				end)
			end

			if CameraShakeEvent then
				local intensity = isFinisher and 3.5 or 1.2
				local speed = isFinisher and 35 or 25
				local duration = isFinisher and 0.35 or 0.15

				if isTargetBlocking then intensity = intensity * 0.4 end

				if attackerPlayer then
					CameraShakeEvent:FireClient(attackerPlayer, intensity, speed, duration)
				end
				if targetPlayer then
					CameraShakeEvent:FireClient(targetPlayer, intensity * 1.5, speed * 1.2, duration)
				end
			end

			if Replicator then
				local activeHitSoundId = styleConfig.HitSoundId or "rbxassetid://0"
				local activeHitAnimId = styleConfig.HitAnimId or "rbxassetid://0"

				if isTargetBlocking then
					activeHitAnimId = styleConfig.BlockHitAnimId or "rbxassetid://0"
				end

				Replicator:FireAllClients(victimModel, activeHitSoundId, activeHitAnimId, isTargetBlocking)
			end



			local stunList = styleConfig.ComboStun or {}
			local activeStunDuration = stunList[currentCombo] or 0.4
			if isTargetBlocking then activeStunDuration = activeStunDuration * 0.5 end

			if isGuardBroken then
				activeStunDuration = styleConfig.BlockBreakStunTime
				if targetPlayer then
					local targetSession = activeSessionStyles[targetPlayer]
					if targetSession and targetSession.CurrentStyleName then
						local targetStyleConfig = StylesData[targetSession.CurrentStyleName]
						activeStunDuration = targetStyleConfig.BlockBreakStunTime or activeStunDuration
					end
				end
			end

			targetHumanoid.WalkSpeed = 0
			if targetPlayer then
				targetPlayer:SetAttribute("IsStunned", true)
			else
				victimModel:SetAttribute("IsStunned", true)
			end

			task.delay(activeStunDuration, function()
				if targetHumanoid and targetHumanoid.Parent then
					if targetPlayer then
						targetPlayer:SetAttribute("IsStunned", false)
						if targetPlayer.Character and targetPlayer.Character:GetAttribute("IsBlocking") == true then
							targetHumanoid.WalkSpeed = styleConfig.BlockWalkSpeed or 5
							return
						end
						local targetSession = activeSessionStyles[targetPlayer]
						if targetSession and targetSession.CurrentStyleName then
							local targetStyleConfig = StylesData[targetSession.CurrentStyleName]
							targetHumanoid.WalkSpeed = targetStyleConfig.WalkSpeed or 16
						else
							targetHumanoid.WalkSpeed = 16
						end
					else
						victimModel:SetAttribute("IsStunned", false)
						targetHumanoid.WalkSpeed = 10
					end
				end
			end)

			targetRoot.AssemblyLinearVelocity = Vector3.zero
			local targetAttachment = Instance.new("Attachment")
			targetAttachment.Parent = targetRoot

			local linearVelocity = Instance.new("LinearVelocity")
			linearVelocity.Attachment0 = targetAttachment
			linearVelocity.MaxForce = 2500000
			linearVelocity.RelativeTo = Enum.ActuatorRelativeTo.World
			linearVelocity.VelocityConstraintMode = Enum.VelocityConstraintMode.Plane
			linearVelocity.PrimaryTangentAxis = Vector3.new(1, 0, 0)
			linearVelocity.SecondaryTangentAxis = Vector3.new(0, 0, 1)

			local pushDirection = (targetRoot.Position - liveRoot.Position).Unit
			local finalKnockbackSpeed = activeKnockbackSpeed
			if isTargetBlocking and not isFinisher then 
				finalKnockbackSpeed = finalKnockbackSpeed * 0.3 
			end

			linearVelocity.PlaneVelocity = Vector2.new(pushDirection.X * finalKnockbackSpeed, pushDirection.Z * finalKnockbackSpeed)
			linearVelocity.Parent = targetRoot

			game:GetService("Debris"):AddItem(linearVelocity, 0.15)
			game:GetService("Debris"):AddItem(targetAttachment, 0.15)
		end
	end
end

CombatEvent.OnServerEvent:Connect(function(player)
	if player:GetAttribute("IsStunned") == true or player:GetAttribute("IsDizzy") == true then 
		return 
	end

	local session = activeSessionStyles[player]
	if not session or not session.CurrentStyleName then return end

	local character = player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	local rootPart = character and character:FindFirstChild("HumanoidRootPart")

	if not humanoid or humanoid.Health <= 0 or not rootPart then return end
	if character:GetAttribute("IsRagdolled") == true then return end

	local activeStyleName = session.CurrentStyleName
	local activeStyleObject = session[activeStyleName]

	local styleConfig = StylesData[activeStyleName]
	if not styleConfig or not styleConfig.HitboxSettings then return end

	if not activeStyleObject.ServerLastPunchTime then
		activeStyleObject.ServerLastPunchTime = 0
	end

	local currentTime = os.clock()
	local timeSinceLastAttack = currentTime - activeStyleObject.ServerLastPunchTime

	if timeSinceLastAttack < (styleConfig.AttackCooldown - 0.05) then
		return 
	end
	activeStyleObject.ServerLastPunchTime = currentTime

	local currentCombo = activeStyleObject.CurrentCombo or 1
	local delayList = styleConfig.ComboHitboxDelay or {}
	local activeDelayTime = delayList[currentCombo] or 0.1

	task.delay(activeDelayTime, function()
		RunHit(character, player, styleConfig, currentCombo, activeStyleObject)
	end)

	if currentCombo >= styleConfig.MaxCombo then
		activeStyleObject.CurrentCombo = 1
	else
		activeStyleObject.CurrentCombo = currentCombo + 1
	end
end)


NPCAttackEvent.Event:Connect(function(npcCharacter, styleName, comboIndex)
	local styleConfig = StylesData[styleName]
	if not styleConfig or not styleConfig.HitboxSettings then return end
	if not npcCharacter or not npcCharacter.Parent then return end

	local delayList = styleConfig.ComboHitboxDelay or {}
	local activeDelayTime = delayList[comboIndex] or 0.1
	local helper = GetNpcStyleHelper(styleName)

	task.delay(activeDelayTime, function()
		RunHit(npcCharacter, nil, styleConfig, comboIndex, helper)
	end)
end)


ToggleStyleEvent.OnServerEvent:Connect(function(player, requestedStyleName)
	local session = activeSessionStyles[player]
	if not session then return end

	if requestedStyleName ~= nil and not StylesData[requestedStyleName] then
		return
	end

	if requestedStyleName ~= nil then
		local unlockedStyles = PlayerDataHandler:Get(player, "unlockedStyles")
		if not table.find(unlockedStyles, requestedStyleName) then
			BanManager.BanPlayer(player.UserId, -1, "Exploit Style")
			return
		end
	end

	if requestedStyleName == nil or session.CurrentStyleName == requestedStyleName then
		if session.CurrentStyleName then
			session[session.CurrentStyleName]:Unequip()
			session.CurrentStyleName = nil
			PlayerDataHandler:Set(player, "currentStyle", "None")
		end
	else
		if session.CurrentStyleName then
			session[session.CurrentStyleName]:Unequip()
		end
		session[requestedStyleName]:Equip()
		session.CurrentStyleName = requestedStyleName
		PlayerDataHandler:Set(player, "currentStyle", requestedStyleName)
	end
	ToggleStyleEvent:FireClient(player, session.CurrentStyleName)
end)