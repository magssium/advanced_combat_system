local UserInputService = game:GetService("UserInputService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")

local Shared = ReplicatedStorage:WaitForChild("shared")
local Remotes = Shared:WaitForChild("remotes")
local ToggleStyleEvent = Remotes.ToggleStyleEvent

local KeybindsData = require(Shared.modules.KeybindsData)
local StylesData = require(Shared.modules.StylesData)
local FightingStyle = require(Shared.modules.FightingStyle)

local player = Players.LocalPlayer
local activeStyleName = nil

local combatStyles = {}
for styleName, data in pairs(StylesData) do
    combatStyles[styleName] = FightingStyle.new(
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


UserInputService.InputBegan:Connect(function(input, gameProcessedEvent)
    if gameProcessedEvent then return end 

    local targetStyle = KeybindsData[input.KeyCode]
    if targetStyle then
        if activeStyleName == targetStyle then
            ToggleStyleEvent:FireServer(nil)
        else
            ToggleStyleEvent:FireServer(targetStyle)
        end
        return
    end
    
    local character = player.Character
    if character and (character:GetAttribute("IsStunned") == true or character:GetAttribute("IsDizzy") == true) then
        return
    end

    if input.UserInputType == Enum.UserInputType.MouseButton1 and activeStyleName ~= nil then
        if character and character:GetAttribute("IsBlocking") == true then return end
        
        local humanoid = character and character:FindFirstChildOfClass("Humanoid")
        local animator = humanoid and humanoid:FindFirstChildOfClass("Animator")
        
        if animator then
            combatStyles[activeStyleName]:Attack(animator)
        end
    elseif input.KeyCode == Enum.KeyCode.F and activeStyleName ~= nil then
        local humanoid = character and character:FindFirstChildOfClass("Humanoid")
        local animator = humanoid and humanoid:FindFirstChildOfClass("Animator")
        if animator then
            combatStyles[activeStyleName]:ToggleBlock(animator, true)
        end
    end
end)


UserInputService.InputEnded:Connect(function(input, gameProcessedEvent)
    if activeStyleName == nil or not combatStyles[activeStyleName] then return end
    
    if input.KeyCode == Enum.KeyCode.F then
        local character = player.Character
        local humanoid = character and character:FindFirstChildOfClass("Humanoid")
        local animator = humanoid and humanoid:FindFirstChildOfClass("Animator")
        if animator then
            combatStyles[activeStyleName]:ToggleBlock(animator, false)
        end
    end
end)

ToggleStyleEvent.OnClientEvent:Connect(function(confirmedStyleName)
    if activeStyleName and combatStyles[activeStyleName] then
        combatStyles[activeStyleName]:Unequip()
    end
    
    activeStyleName = confirmedStyleName
    
    if activeStyleName and combatStyles[activeStyleName] then
        combatStyles[activeStyleName]:Equip()
    end
end)

player.CharacterAdded:Connect(function(character)
    activeStyleName = nil
    for _, styleInstance in pairs(combatStyles) do
        styleInstance:Unequip()
    end
    
    character:GetAttributeChangedSignal("IsStunned"):Connect(function()
        if character:GetAttribute("IsStunned") == true and character:GetAttribute("IsBlocking") == true then
            local humanoid = character:FindFirstChildOfClass("Humanoid")
            local animator = humanoid and humanoid:FindFirstChildOfClass("Animator")
            if animator and activeStyleName and combatStyles[activeStyleName] then
                combatStyles[activeStyleName]:ToggleBlock(animator, false)
            end
        end
    end)
end)
