local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local shared = ReplicatedStorage.shared
local remotes = shared.remotes

local CameraShakeEvent = remotes.CameraShakeEvent
local LocalShakeEvent = remotes.LocalShakeEvent

local camera = workspace.CurrentCamera

local shakeIntensity = 0
local shakeSpeed = 0
local shakeDuration = 0
local shakeStartTime = 0
local noiseSeedX = math.random(0, 1000)
local noiseSeedY = math.random(1000, 2000)

local function ShakeCamera(intensity: number, speed: number, duration: number)
    shakeIntensity = intensity
    shakeSpeed = speed
    shakeDuration = duration
    shakeStartTime = os.clock()
    noiseSeedX = math.random(0, 1000)
    noiseSeedY = math.random(1000, 2000)
end

RunService:BindToRenderStep("CombatCameraShake", Enum.RenderPriority.Camera.Value + 1, function()
    local elapsedTime = os.clock() - shakeStartTime
    
    if elapsedTime >= shakeDuration or shakeIntensity <= 0 then
        return
    end
    
    local fadeOut = 1 - (elapsedTime / shakeDuration)
    local timeWeight = os.clock() * shakeSpeed
    
    local xShake = math.noise(timeWeight, noiseSeedX) * shakeIntensity * fadeOut
    local yShake = math.noise(timeWeight, noiseSeedY) * shakeIntensity * fadeOut
    
    camera.CFrame = camera.CFrame * CFrame.Angles(math.rad(xShake), math.rad(yShake), 0)
end)

CameraShakeEvent.OnClientEvent:Connect(ShakeCamera)
LocalShakeEvent.Event:Connect(ShakeCamera)
