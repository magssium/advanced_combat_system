local StylesData = {
    -- this is the template to copy to create fighting styles
    Boxing = {
        RagdollLimits = {
            ["Left Shoulder"]  = { Attachment = Vector3.new(-1, 0.5, 0), Joint = Vector3.new(0.5, 0.5, 0) },
            ["Right Shoulder"] = { Attachment = Vector3.new(1, 0.5, 0),  Joint = Vector3.new(-0.5, 0.5, 0) },
            ["Left Hip"]       = { Attachment = Vector3.new(-0.5, -1, 0), Joint = Vector3.new(0, 1, 0) },
            ["Right Hip"]      = { Attachment = Vector3.new(0.5, -1, 0),  Joint = Vector3.new(0, 1, 0) },
            ["Neck"]           = { Attachment = Vector3.new(0, 1, 0), Joint = Vector3.new(0, -0.5, 0) }
        },

        WalkSpeed = 10,
        AnimId = "rbxassetid://93058271893361",
        IdleAnimId = "rbxassetid://107947709017426",
        Keybind = Enum.KeyCode.C,

        BlockDamageMultiplier = 0.2,
        BlockWalkSpeed = 7,

        BlockBreakRecoveryTime = 1.5,
        BlockBreakStunTime = 1.0,
        BlockReblockCooldown = 0.3,
        
        BlockDamage = 20,
        MaxBlockHealth = 100,

        BlockAnimId = "rbxassetid://79588376940657",
        BlockHitAnimId = "rbxassetid://131810728266246",

        MaxCombo = 5,
        AttackCooldown = 0.35,
        EndComboCooldown = 1.2,

        M1Anims = {
            "rbxassetid://91020479072859", 
            "rbxassetid://105305073680971", 
            "rbxassetid://122151385391676",
            "rbxassetid://106012934069913",
            "rbxassetid://70872702053314"
        },

        ComboDamage = {4, 5, 7, 9, 11},
        ComboKnockback = {5, 8, 11, 11, 12},
        HitboxDelay = {0.1, 0.1, 0.12, 0.15, 0.25},

        ComboStun = {0.4, 0.4, 0.45, 0.5, 0.8},

        SwingSoundId = "rbxassetid://112758963155190",
        HitSoundId = "rbxassetid://8595980577",

        HitAnimId = "rbxassetid://132229793990364",

        HitboxSettings = {
            Size = Vector3.new(6, 6, 6),
            Offset = Vector3.new(0, 0, -5)
        }
    },
}

return StylesData
