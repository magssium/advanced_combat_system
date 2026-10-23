local Players = game:GetService("Players")
local BanManager = {}


local function GenerateBanCode(): string
    local alphabet = "0123456789ABCDEFGHJKMNPQRSTVWXYZ" 
    local codeLength = 6
    local result = ""

    for i = 1, codeLength do
        local randomIndex = math.random(1, #alphabet)
        result ..= string.sub(alphabet, randomIndex, randomIndex) 
    end

    return string.format("TKT-%s", result)
end


function BanManager.BanPlayer(userId: number, durationInSeconds: number, actualReason: string)
    local trackingCode = GenerateBanCode()

    -- what the player would see for their ban reasoning
    local publicDisplay = string.format(
        "Ban Code: %s. If you believe this was an error, please open a support ticket in our discord server.",
        trackingCode
    )

    local privateHistory = string.format(
        "Code: %s | Real Reason: %s",
        trackingCode,
        actualReason
    )

    local config = {
        UserIds = { userId },
        Duration = durationInSeconds,
        DisplayReason = publicDisplay,
        PrivateReason = privateHistory,
        ExcludeAltAccounts = false,
        ApplyToUniverse = true
    }

    local success, error = pcall(function(args)
        return Players:BanAsync(config)
    end)

    if success then
        print(string.format("Banned UserId %d. Reference Code Generated: %s", userId, trackingCode))
    else
        warn("BanAsync failed: " .. tostring(error))
    end

    return success, trackingCode
end


function BanManager.UnbanPlayer(userId: number): boolean
    local config = {
        UserIds = { userId },
        ApplyToUniverse = true 
    }

    local success, err = pcall(function()
        return Players:UnbanAsync(config)
    end)

    if success then
        print(string.format("Successfully unbanned UserId %d from the experience universe.", userId))
    else
        warn(string.format("UnbanAsync failed for UserId %d: %s", userId, tostring(err)))
    end

    return success
end

return BanManager