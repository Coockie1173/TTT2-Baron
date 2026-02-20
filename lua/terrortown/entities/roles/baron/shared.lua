if SERVER then
	AddCSLuaFile()
    util.AddNetworkString("BaronGlobalSound")

    resource.AddFile("materials/vgui/ttt/dynamic/roles/icon_baron.vmt")
end

roles.InitCustomTeam(ROLE.name, {
    icon = "vgui/ttt/dynamic/roles/icon_baron",
	color = Color(212, 175, 55, 255)
})

function ROLE:PreInitialize()
    self.color = Color(212, 175, 55, 255)
    self.abbr = "baron"

    -- Score multipliers
    self.score.surviveBonusMultiplier = 0.2
    self.score.timelimitMultiplier = -0.5
    self.score.killsMultiplier = 2
    self.score.teamKillsMultiplier = -4
    self.score.bodyFoundMuliplier = 0

    -- Team settings
    self.unknownTeam = true
    self.defaultTeam = TEAM_BARON

    -- Role convars
    self.conVarData = {
        pct          = 0.1,
        maximum      = 1,
        minPlayers   = 8,
        random       = 10,
        shopFallback = SHOP_FALLBACK_TRAITOR,
    }

    self.canUseTraitorButtons = true
    self.canUseRagdollPinner = true   
end

function ROLE:GiveRoleLoadout(ply, isRoleChange)
    ply:SetMaxHealth(130)
    ply:SetHealth(130)
    ply:SetArmor(20)

    local numPlayers = #player.GetAll()
    local extraCredits = math.floor(math.max(numPlayers - 6, 0) / 4)
    local totalCredits = 4 + extraCredits
    ply:AddCredits(totalCredits)
end

if SERVER then
    local function GiveBaronLives(ply)
        if not IsValid(ply) then return end
        if ply:GetSubRole() ~= ROLE_BARON then return end

        local numPlayers = #player.GetAll()
        local extraLives = math.floor(math.max(numPlayers - 8, 0) / 6)
        ply:SetNW2Int("BaronLives", 3 + extraLives)

    end

    hook.Add("TTTBeginRound", "BaronInitLives", function()
        for _, ply in ipairs(player.GetAll()) do
            GiveBaronLives(ply)
        end
    end)

    hook.Add("TTT2UpdateSubrole", "BaronRoleChangeLives", function(ply, oldRole, newRole)
        if newRole == ROLE_BARON then
            timer.Simple(0, function()
                if IsValid(ply) then
                    GiveBaronLives(ply)
                end
            end)
        end
    end)


end

if CLIENT then
    hook.Add("HUDPaint", "BaronLivesHUD", function()
        local ply = LocalPlayer()
        if not IsValid(ply) or ply:GetSubRole() ~= ROLE_BARON then return end

        local lives = ply:GetNW2Int("BaronLives", 0)

        draw.SimpleText(
            "Lives Remaining: " .. lives,
            "Trebuchet24",
            ScrW() / 2,
            ScrH() - 80,
            Color(255, 230, 0),
            TEXT_ALIGN_CENTER,
            TEXT_ALIGN_CENTER
        )
    end)

    net.Receive("BaronGlobalSound", function()
        surface.PlaySound("tttbaron/laugh.wav")
    end)

end

if SERVER then
    hook.Add("TTTCheckForWin", "BaronSoloWinCheck", function()
        local baronAlive = nil
        local othersAlive = false

        for _, ply in ipairs(player.GetAll()) do
            if not ply:Alive() or ply:IsSpec() then continue end

            local role = ply:GetSubRole()
            local team = ply:GetTeam()


            if role == ROLE_BARON then
                baronAlive = ply
            else
                othersAlive = true
            end
        end

        if IsValid(baronAlive) and not othersAlive then
            return TEAM_BARON
        end
    end)
end

if SERVER then
    hook.Add("PlayerDeath", "BaronRespawnHandler", function(victim)
        if victim:GetSubRole() ~= ROLE_BARON then return end

        local saved = victim.BaronSavedWeapons or {}

        local lives = victim:GetNW2Int("BaronLives", 3) - 1
        victim:SetNW2Int("BaronLives", lives)

        
        if lives <= 0 then return end
        
        local spawnPoint = plyspawn.GetRandomSafePlayerSpawnPoint(victim)
        if not spawnPoint then return end
        
        victim:Revive(
            1,
            function(ply)
                ply:SetPos(spawnPoint.pos)
                ply:SetEyeAngles(spawnPoint.ang)
                
                for _, class in ipairs(saved) do
                    ply:Give(class)
                end

                if victim.BaronSavedWeapons then
                    for _, class in ipairs(victim.BaronSavedWeapons) do
                        ply:Give(class)
                    end
                end

                if victim.BaronSavedCredits then
                    ply:SetCredits(victim.BaronSavedCredits)
                end
                
                victim:AddCredits(1)

                net.Start("BaronGlobalSound")
                net.Broadcast()
            end,
            nil,
            false,
            REVIVAL_BLOCK_NONE
        )
    end)
end

if SERVER then
    hook.Add("TTTCheckForWin", "BaronPreventRoundEndWhileRespawning", function()
        for _, ply in ipairs(player.GetAll()) do
            if ply:GetSubRole() == ROLE_BARON then
                local lives = ply:GetNW2Int("BaronLives", 0)

                if lives > 0 and not ply:Alive() then
                    return WIN_NONE
                end
            end
        end
    end)


    hook.Add("TTT2ModifyFinalRoles", "BARON_MODIFYTTT2ModifyFinalRoles", function(finalRoles)        
        local players = player.GetAll()
        local baronExists = false
        for _, ply in ipairs(players) do
            if finalRoles[ply] == ROLE_BARON or ply:GetTeam() == TEAM_BARON then
                baronExists = true
                break
            end
        end
        if not baronExists then return end

        local detectiveRoles = {ROLE_DETECTIVE}
        for _, subRole in ipairs(roles.GetByIndex(ROLE_DETECTIVE):GetSubRoles()) do
            table.insert(detectiveRoles, subRole.index)
        end

        for _, ply in ipairs(players) do
            local r = finalRoles[ply]
            if r == ROLE_BARON or ply:GetTeam() == TEAM_BARON then
                continue
            end

            if table.HasValue(detectiveRoles, r) then
                continue
            end

            if r == ROLE_DEFECTIVE then
                finalRoles[ply] = ROLE_DETECTIVE
            elseif r ~= ROLE_INNOCENT then
                finalRoles[ply] = ROLE_INNOCENT
            end
        end
    end)

    hook.Add("PlayerCanDropWeapon", "BaronNoDrop", function(ply, _, _, _, reason)
        if ply:GetSubRole() == ROLE_BARON then
            return false
        end
    end)

    hook.Add("DoPlayerDeath", "BaronSuppressWeaponDrops", function(ply, attacker, dmginfo)
        if ply:GetSubRole() ~= ROLE_BARON then return end

        ply.BaronSavedWeapons = {}
        for _, wep in ipairs(ply:GetWeapons()) do
            table.insert(ply.BaronSavedWeapons, wep:GetClass())
            ply:StripWeapon(wep:GetClass())
        end

        -- Save credits
        ply.BaronSavedCredits = ply:GetCredits()
    end)


end
