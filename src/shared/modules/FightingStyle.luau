local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local VFXFolder = ReplicatedStorage:WaitForChild("shared"):WaitForChild("vfx")
local DizzyVFXTemplate = VFXFolder:WaitForChild("dizzy")

local FightingStyle = {}
FightingStyle.__index = FightingStyle

local globalLastFireTime = 0
local GLOBAL_FIRE_GUARD = 0.05

local JOINT_TO_LIMB = {
    ["Neck"] = "Head",
    ["Right Shoulder"] = "Right Arm",
    ["Left Shoulder"] = "Left Arm",
    ["Right Hip"] = "Right Leg",
    ["Left Hip"] = "Left Leg",
}


local function getCharacter(self)
    local p = self.Player
    if p == nil then return nil end
    if typeof(p) == "Instance" and p:IsA("Model") then
        return p
    end
    return p.Character
end


function FightingStyle.new(player, styleName, walkSpeed, animId, idleAnimId, maxCombo, attackCooldown, endComboCooldown, m1Anims)
    local self = setmetatable({}, FightingStyle)
    
    self.Player = player
    self.StyleName = styleName
    self.NormalSpeed = 16
    self.CombatSpeed = walkSpeed
    self.AnimationId = animId
    self.IdleAnimationId = idleAnimId
    self.M1AnimsData = m1Anims or {}
    self.IsActive = false
    
    self.CombatEvent = ReplicatedStorage.shared.remotes.CombatEvent 
    self.BlockEvent = ReplicatedStorage.shared.remotes.BlockEvent
    self.LocalShakeEvent = ReplicatedStorage.shared.remotes.LocalShakeEvent
    self.RagdollEvent = ReplicatedStorage.shared.remotes.RagdollEvent

    self.MaxCombo = maxCombo 
    self.AttackCooldown = attackCooldown 
    self.EndComboCooldown = endComboCooldown 
    
    self.CurrentCombo = 1
    self.LastPunchTime = 0
    self.IsFinisherCooldown = false 

    self.OnNpcAttack = nil
    
    if RunService:IsClient() then
        self.CurrentTrack = nil
        self.IdleTrack = nil
        self.RunningConnection = nil
    end
    
    return self
end


function FightingStyle:RagdollCharacter(character: Model)
    if not RunService:IsServer() or not character then return end
    
    local humanoid = character:FindFirstChildOfClass("Humanoid")
    local torso = character:FindFirstChild("Torso")
    if not humanoid or not torso then return end

    local token = (character:GetAttribute("RagdollToken") or 0) + 1
    character:SetAttribute("RagdollToken", token)
    character:SetAttribute("IsRagdolled", true)

    local animator = humanoid:FindFirstChildOfClass("Animator")
    if animator then
        for _, track in ipairs(animator:GetPlayingAnimationTracks()) do
            track:Stop(0)
        end
    end

    if self.IsActive and getCharacter(self) == character then
        self:Unequip()
        self.ReequipAfterRagdoll = true
    end

    local root = character:FindFirstChild("HumanoidRootPart")
    if root then
        root.AssemblyLinearVelocity = Vector3.zero
        root.AssemblyAngularVelocity = Vector3.zero
        root.CanCollide = false
    end

    humanoid.AutoRotate = false
    humanoid:UnequipTools() 
    humanoid.PlatformStand = true
    humanoid:ChangeState(Enum.HumanoidStateType.Physics)

    if character:GetAttribute("IsBlocking") then character:SetAttribute("IsBlocking", false) end
    
    local StylesData = require(ReplicatedStorage.shared.modules.StylesData)
    local styleConfig = StylesData[self.StyleName]
    local jointLimits = (styleConfig and styleConfig.RagdollLimits) or {}
    
    for jointName, offsetData in pairs(jointLimits) do
        local targetLimbName = JOINT_TO_LIMB[jointName]
        local limb = character:FindFirstChild(targetLimbName)
        
        if limb and limb:IsA("BasePart") then
            local existingMotor = torso:FindFirstChild(jointName) or character.Head:FindFirstChild(jointName)
            if existingMotor and existingMotor:IsA("Motor6D") then
                existingMotor.Enabled = false
            end
            
            local att0 = Instance.new("Attachment")
            att0.Name = "RagdollAttachment"
            att0.CFrame = CFrame.new(offsetData.Attachment)
            att0.Parent = torso
            
            local att1 = Instance.new("Attachment")
            att1.Name = "RagdollAttachment"
            att1.CFrame = CFrame.new(offsetData.Joint)
            att1.Parent = limb
            
            local socket = Instance.new("BallSocketConstraint")
            socket.Name = "RagdollConstraint"
            socket.Attachment0 = att0
            socket.Attachment1 = att1
            socket.LimitsEnabled = true
            socket.UpperAngle = 45
            socket.TwistLimitsEnabled = true
            socket.TwistLowerAngle = -45
            socket.TwistUpperAngle = 45
            socket.Parent = limb
            
            local noCollide = Instance.new("NoCollisionConstraint")
            noCollide.Name = "RagdollNoCollide"
            noCollide.Part0 = torso
            noCollide.Part1 = limb
            noCollide.Parent = limb
        end
    end
    
    for _, part in ipairs(character:GetChildren()) do
        if part:IsA("BasePart") then
            part.CanCollide = false
        end
    end

    if torso then torso.CanCollide = true end
    local head = character:FindFirstChild("Head")
    if head then head.CanCollide = true end

    for jointName in pairs(jointLimits) do
        local limbName = JOINT_TO_LIMB[jointName]
        local limb = limbName and character:FindFirstChild(limbName)
        if limb and limb:IsA("BasePart") then
            limb.CanCollide = true
        end
    end

    if head then 
        local existingVFX = head:FindFirstChild("DizzyVFX")
        if existingVFX then existingVFX:Destroy() end
        
        local particle = DizzyVFXTemplate.dizzyEffect
        local vfx = particle:Clone()
        vfx.Name = "DizzyVFX"
        vfx.Parent = head

        if vfx:IsA("ParticleEmitter") then
            vfx.Enabled = true
        end

        self.RagdollEvent:FireAllClients("StartSound", character, "rbxassetid://8227660256")
    end

    return token
end


function FightingStyle:UnragdollCharacter(character: Model, expectedToken)
    if not RunService:IsServer() or not character then return end

    local humanoid = character:FindFirstChildOfClass("Humanoid")
    if not humanoid then return end

    if expectedToken ~= nil and character:GetAttribute("RagdollToken") ~= expectedToken then
        return
    end

    character:SetAttribute("IsRagdolled", false)

    local head = character:FindFirstChild("Head")
    local vfx = head and head:FindFirstChild("DizzyVFX")
    if vfx then vfx:Destroy() end

    for _, desc in ipairs(character:GetDescendants()) do
        if (desc:IsA("BallSocketConstraint") and desc.Name == "RagdollConstraint") 
            or (desc:IsA("Attachment") and desc.Name == "RagdollAttachment")
            or (desc:IsA("NoCollisionConstraint") and desc.Name == "RagdollNoCollide") then
            desc:Destroy()
        end
    end

    for _, desc in ipairs(character:GetDescendants()) do
        if desc:IsA("Motor6D") then
            desc.Enabled = true
        end
    end

    local root = character:FindFirstChild("HumanoidRootPart")
    if root then
        local lookVector = root.CFrame.LookVector
        local flatLook = Vector3.new(lookVector.X, 0, lookVector.Z)
        if flatLook.Magnitude < 0.05 then
            flatLook = Vector3.new(0, 0, -1)
        end
        flatLook = flatLook.Unit

        -- Smooth lift out of the baseplate floor layout
        root.CFrame = CFrame.new(root.Position + Vector3.new(0, 2.5, 0), root.Position + Vector3.new(0, 2.5, 0) + flatLook)
        root.AssemblyLinearVelocity = Vector3.zero
        root.AssemblyAngularVelocity = Vector3.zero
        root.CanCollide = false
    end

    self.RagdollEvent:FireAllClients("StopSound", character, "rbxassetid://8227660256")

    local animator = humanoid:FindFirstChildOfClass("Animator")
    if not animator then
        Instance.new("Animator", humanoid)
    end

    humanoid.PlatformStand = false
    humanoid.AutoRotate = true

    if self.ReequipAfterRagdoll then
        self.ReequipAfterRagdoll = false
        self:Equip()
    end

    if humanoid.Health > 0 then
        humanoid:ChangeState(Enum.HumanoidStateType.GettingUp)
        task.delay(0.2, function()
            if humanoid and humanoid.Parent and humanoid.Health > 0
                and character:GetAttribute("RagdollToken") == expectedToken then
                humanoid:ChangeState(Enum.HumanoidStateType.Running)
            end
        end)
    end
end



function FightingStyle:Attack(animator: Animator)
    local isNPC = RunService:IsServer()
    if not (isNPC or RunService:IsClient()) or not self.IsActive then return end
    if #self.M1AnimsData == 0 then return end

    local character = getCharacter(self)
    if character and character:GetAttribute("IsRagdolled") == true then return end

    if isNPC then
        local humanoid = character and character:FindFirstChildOfClass("Humanoid")
        if not humanoid or humanoid.Health <= 0 then return end
        if character:GetAttribute("IsStunned") == true
            or character:GetAttribute("IsDizzy") == true
            or character:GetAttribute("IsBlocking") == true then
            return
        end
        animator = animator or humanoid:FindFirstChildOfClass("Animator") or Instance.new("Animator", humanoid)
    end
    
    local currentTime = os.clock()

    if not isNPC and currentTime - globalLastFireTime < GLOBAL_FIRE_GUARD then return end
    local activeCooldown = self.IsFinisherCooldown and self.EndComboCooldown or self.AttackCooldown
    
    if currentTime - self.LastPunchTime < activeCooldown then
        return
    end
    
    if currentTime - self.LastPunchTime > 1.5 then
        self.CurrentCombo = 1
    end
    
    self.IsFinisherCooldown = false
    self.LastPunchTime = currentTime
    if not isNPC then globalLastFireTime = currentTime end

    local comboIndex = self.CurrentCombo
    
    local punchAnim = Instance.new("Animation")
    punchAnim.AnimationId = self.M1AnimsData[comboIndex]
    
    local punchTrack = animator:LoadAnimation(punchAnim)
    punchTrack.Priority = Enum.AnimationPriority.Action4
    punchTrack:Play()

    game:GetService("Debris"):AddItem(punchAnim, 2)

    if isNPC then
        if self.OnNpcAttack then
            self.OnNpcAttack(character, self.StyleName, comboIndex)
        end
    else
        if self.LocalShakeEvent then
            self.LocalShakeEvent:Fire(0.3, 15, 0.1)
        end
        self.CombatEvent:FireServer(self.StyleName)
    end

    if self.CurrentCombo >= self.MaxCombo then
        self.CurrentCombo = 1
        self.IsFinisherCooldown = true 
    else
        self.CurrentCombo = self.CurrentCombo + 1
    end
end


function FightingStyle:ToggleBlock(animator: Animator, state: boolean)
    local isNPC = RunService:IsServer()
    if not (isNPC or RunService:IsClient()) or not self.IsActive then return end
    
    local character = getCharacter(self)
    if not character or character:GetAttribute("IsStunned") == true or character:GetAttribute("IsDizzy") == true
        or character:GetAttribute("IsRagdolled") == true then
        return 
    end
    
    local StylesData = require(ReplicatedStorage.shared.modules.StylesData)
    local styleConfig = StylesData[self.StyleName]
    if not styleConfig or not styleConfig.BlockAnimId then return end

    if state then
        -- Guard-break lockout: long punishment for actually breaking your shield.
        local guardBrokenAt = character:GetAttribute("GuardBrokenAt")
        if guardBrokenAt then
            local recoveryTime = styleConfig.BlockBreakRecoveryTime or 1.5
            if workspace:GetServerTimeNow() < guardBrokenAt + recoveryTime then
                return
            end
        end

        -- General re-block cooldown: short gap after you manually lower your
        -- shield, so you can't flicker block on/off every frame to dodge hits.
        local blockEndedAt = character:GetAttribute("BlockEndedAt")
        if blockEndedAt then
            local reblockCooldown = styleConfig.BlockReblockCooldown or 0.3
            if workspace:GetServerTimeNow() < blockEndedAt + reblockCooldown then
                return
            end
        end
    else
        character:SetAttribute("BlockEndedAt", workspace:GetServerTimeNow())
    end
    
    if isNPC then
        character:SetAttribute("IsBlocking", state)
        local humanoid = character:FindFirstChildOfClass("Humanoid")
        animator = animator or (humanoid and (humanoid:FindFirstChildOfClass("Animator") or Instance.new("Animator", humanoid)))
    else
        self.BlockEvent:FireServer(state)
    end
    
    if state then
        local blockAnim = Instance.new("Animation")
        blockAnim.AnimationId = styleConfig.BlockAnimId
        
        self.BlockTrack = animator:LoadAnimation(blockAnim)
        self.BlockTrack.Priority = Enum.AnimationPriority.Action3
        self.BlockTrack.Looped = true
        self.BlockTrack:Play()
        game:GetService("Debris"):AddItem(blockAnim, 2)
    else
        if self.BlockTrack then
            self.BlockTrack:Stop()
            self.BlockTrack = nil
        end
    end
end

function FightingStyle:Equip()
    self.IsActive = true
    local character = getCharacter(self)
    local humanoid = character and character:FindFirstChildOfClass("Humanoid")
    if not humanoid then return end

    if RunService:IsServer() then
        humanoid.WalkSpeed = self.CombatSpeed
    end

    if RunService:IsClient() then
        local animator = humanoid:WaitForChild("Animator")
        local walkAnim = Instance.new("Animation")
        walkAnim.AnimationId = self.AnimationId
        local idleAnim = Instance.new("Animation")
        idleAnim.AnimationId = self.IdleAnimationId
        
        local function ResumeLocomotion()
            if character then
                character:SetAttribute("NetworkBlockLock", nil)
                character:SetAttribute("WasBackstabbed", nil)
            end

            humanoid.PlatformStand = false
            humanoid.AutoRotate = true
            humanoid:ChangeState(Enum.HumanoidStateType.GettingUp)
            
            task.delay(0.1, function()
                if humanoid and humanoid.Parent and character:GetAttribute("IsRagdolled") ~= true then
                    humanoid:ChangeState(Enum.HumanoidStateType.Running)
                end
            end)

            for _, desc in ipairs(character:GetDescendants()) do
                if desc:IsA("Motor6D") then
                    desc.Enabled = true
                end
            end

            if humanoid.MoveDirection.Magnitude > 0.1 then
                self.CurrentTrack = animator:LoadAnimation(walkAnim)
                self.CurrentTrack.Priority = Enum.AnimationPriority.Movement
                self.CurrentTrack:Play()
                self.CurrentTrack:AdjustSpeed(0.6)
            else
                self.IdleTrack = animator:LoadAnimation(idleAnim)
                self.IdleTrack.Priority = Enum.AnimationPriority.Idle
                self.IdleTrack:Play()
            end
        end

        local function StopAllActions()
            if self.CurrentTrack then self.CurrentTrack:Stop(0) self.CurrentTrack = nil end
            if self.IdleTrack then self.IdleTrack:Stop(0) self.IdleTrack = nil end
            if self.BlockTrack then self.BlockTrack:Stop(0) self.BlockTrack = nil end
            
            for _, track in ipairs(animator:GetPlayingAnimationTracks()) do
                track:Stop(0)
            end

            humanoid.PlatformStand = true
            humanoid:ChangeState(Enum.HumanoidStateType.Physics)
            for _, desc in ipairs(character:GetDescendants()) do
                if desc:IsA("Motor6D") and desc.Name ~= "RootJoint" then
                    desc.Enabled = false
                end
            end

            self.CurrentCombo = 1
            self.IsFinisherCooldown = false
        end

        if character:GetAttribute("IsRagdolled") == true then
            StopAllActions()
        else
            ResumeLocomotion()
        end

        if self.RagdollConnection then self.RagdollConnection:Disconnect() end
        self.RagdollConnection = character:GetAttributeChangedSignal("IsRagdolled"):Connect(function()
            if character:GetAttribute("IsRagdolled") == true then
                StopAllActions()
            elseif self.IsActive then
                ResumeLocomotion()
            end
        end)
        
        if self.RunningConnection then self.RunningConnection:Disconnect() end
        self.RunningConnection = humanoid.Running:Connect(function(speed)
            if character:GetAttribute("IsRagdolled") == true then return end

            if speed > 0.1 then
                if self.IdleTrack then self.IdleTrack:Stop() self.IdleTrack = nil end
                if not self.CurrentTrack or not self.CurrentTrack.IsPlaying then
                    if self.CurrentTrack then self.CurrentTrack:Stop() end
                    self.CurrentTrack = animator:LoadAnimation(walkAnim)
                    self.CurrentTrack.Priority = Enum.AnimationPriority.Movement
                    self.CurrentTrack:Play()
                    self.CurrentTrack:AdjustSpeed(0.6)
                end
            else
                if self.CurrentTrack then self.CurrentTrack:Stop() self.CurrentTrack = nil end
                if not self.IdleTrack or not self.IdleTrack.IsPlaying then
                    if self.IdleTrack then self.IdleTrack:Stop() end
                    self.IdleTrack = animator:LoadAnimation(idleAnim)
                    self.IdleTrack.Priority = Enum.AnimationPriority.Idle
                    self.IdleTrack:Play()
                end
            end
        end)
    end
end


function FightingStyle:Unequip()
    self.IsActive = false

    self.ReequipAfterRagdoll = false
    local character = getCharacter(self)
    local humanoid = character and character:FindFirstChildOfClass("Humanoid")
    
    if RunService:IsServer() and humanoid then
        humanoid.WalkSpeed = self.NormalSpeed
    end

    if RunService:IsClient() then
        self.CurrentCombo = 1
        self.IsFinisherCooldown = false
        if self.RunningConnection then self.RunningConnection:Disconnect() self.RunningConnection = nil end
        if self.RagdollConnection then self.RagdollConnection:Disconnect() self.RagdollConnection = nil end
        if self.BlockTrack then self.BlockTrack:Stop() self.BlockTrack = nil end
        if self.CurrentTrack then self.CurrentTrack:Stop() self.CurrentTrack = nil end
        if self.IdleTrack then self.IdleTrack:Stop() self.IdleTrack = nil end
    end
end

return FightingStyle