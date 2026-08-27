if SERVER then
	AddCSLuaFile()
    util.AddNetworkString("BaronGlobalSound")
    util.AddNetworkString("BaronCreditsGained")

    resource.AddFile("materials/vgui/ttt/dynamic/roles/icon_baron.vmt")
    
    CreateConVar("ttt2_baron_health", "130", {FCVAR_REPLICATED, FCVAR_ARCHIVE, FCVAR_PROTECTED}, "Maximum health for Baron")
    CreateConVar("ttt2_baron_base_lives", "3", {FCVAR_REPLICATED, FCVAR_ARCHIVE, FCVAR_PROTECTED}, "Base lives for Baron (before scaling)")
    CreateConVar("ttt2_baron_lives_scale_threshold", "8", {FCVAR_REPLICATED, FCVAR_ARCHIVE, FCVAR_PROTECTED}, "Minimum players required before Baron lives scaling kicks in")
    CreateConVar("ttt2_baron_lives_scale_players", "6", {FCVAR_REPLICATED, FCVAR_ARCHIVE, FCVAR_PROTECTED}, "Number of additional players needed for 1 extra Baron life")
    CreateConVar("ttt2_baron_base_credits", "4", {FCVAR_REPLICATED, FCVAR_ARCHIVE, FCVAR_PROTECTED}, "Base credits given to Baron at round start")
    CreateConVar("ttt2_baron_credits_scale_threshold", "6", {FCVAR_REPLICATED, FCVAR_ARCHIVE, FCVAR_PROTECTED}, "Minimum players required before Baron credits scaling kicks in")
    CreateConVar("ttt2_baron_credits_scale_players", "4", {FCVAR_REPLICATED, FCVAR_ARCHIVE, FCVAR_PROTECTED}, "Number of additional players needed for 1 extra Baron starting credit")
    CreateConVar("ttt2_baron_revival_credits", "1", {FCVAR_REPLICATED, FCVAR_ARCHIVE, FCVAR_PROTECTED}, "Credits gained when Baron is revived")
    CreateConVar("ttt2_baron_modify_roles", "1", {FCVAR_REPLICATED, FCVAR_ARCHIVE, FCVAR_PROTECTED}, "Disable other special roles when Baron is present (1 = enabled, 0 = disabled)")
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
    self.isOmniscientRole = true
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
    local health = GetConVar("ttt2_baron_health"):GetInt()
    
    ply:SetMaxHealth(health)
    ply:SetHealth(health)

    local numPlayers = #player.GetAll()
    local scaleThreshold = GetConVar("ttt2_baron_credits_scale_threshold"):GetInt()
    local scalePlayers = GetConVar("ttt2_baron_credits_scale_players"):GetInt()
    local baseCredits = GetConVar("ttt2_baron_base_credits"):GetInt()
    
    local extraCredits = math.floor(math.max(numPlayers - scaleThreshold, 0) / scalePlayers)
    local totalCredits = baseCredits + extraCredits
    ply:AddCredits(totalCredits)
end

if SERVER then
    local function GiveBaronLives(ply)
        if not IsValid(ply) then return end
        if ply:GetSubRole() ~= ROLE_BARON then return end

        local numPlayers = #player.GetAll()
        local scaleThreshold = GetConVar("ttt2_baron_lives_scale_threshold"):GetInt()
        local scalePlayers = GetConVar("ttt2_baron_lives_scale_players"):GetInt()
        local baseLives = GetConVar("ttt2_baron_base_lives"):GetInt()
        
        local extraLives = math.floor(math.max(numPlayers - scaleThreshold, 0) / scalePlayers)
        ply:SetNW2Int("BaronLives", baseLives + extraLives)
    end

    local function ResolveSpawnHullPoints(origin, mins, maxs)
        return {
            origin + Vector(mins.x, mins.y, mins.z),
            origin + Vector(mins.x, mins.y, maxs.z),
            origin + Vector(mins.x, maxs.y, mins.z),
            origin + Vector(maxs.x, mins.y, mins.z),
            origin + Vector(mins.x, maxs.y, maxs.z),
            origin + Vector(maxs.x, maxs.y, mins.z),
            origin + Vector(maxs.x, mins.y, maxs.z),
            origin + Vector(maxs.x, maxs.y, maxs.z),
        }
    end

    local function GetLowestTableSize(tab)
        local lowest = math.huge
        local winners = {}

        for id, tbl in pairs( tab ) do
            if #tbl < lowest then
                winners = { id }
                lowest = #tbl
            elseif #tbl == lowest then
                table.insert(winners, id)
            end
        end

        return winners[math.random(#winners)]
    end

    local function TestBaronSpawnLOS(ply)
        local spawns = plyspawn.GetPlayerSpawnPoints()

        if #spawns > 0 then
            local pvs = {}

            for id, spawn in ipairs(spawns) do
                pvs[id] = {}

                for _, target in player.Iterator() do
                    if target:IsBot() then
                        target:AddFlags(FL_FROZEN)
                    end

                    if target:Alive() and target:IsActive() and target ~= ply and target:TestPVS(spawn.pos) then
                        table.insert(pvs[id], target)
                    end
                end
            end

            local los = {}

            for id, tbl in ipairs(pvs) do
                local mins, maxs = ply:GetHull()
                local points = ResolveSpawnHullPoints(spawns[id].pos, mins, maxs)

                los[id] = {}

                for _, target in ipairs(tbl) do
                    local origin = target:EyePos()

                    if origin:DistToSqr(spawns[id].pos) > 384.0 * 384.0 then
                        for _, point in ipairs(points) do
                            local tr = util.TraceLine({start = origin, endpos = point, filter = ply, mask = MASK_NPCWORLDSTATIC})
                            debugoverlay.Cross(tr.HitPos, 5.0, 10.0, COLOR_YELLOW, true)

                            if tr.Fraction == 1.0 then
                                debugoverlay.Text(point, tr.Fraction, 10.0, false)
                                debugoverlay.Line(origin, point, 10.0, color_white)
                                
                                table.insert(los[id], target)
                                break
                            else
                                debugoverlay.Text(point, tr.Fraction, 10.0, false)
                                debugoverlay.Line(origin, point, 10.0, COLOR_RED)
                            end
                        end
                    else
                        table.insert(los[id], target)
                        break
                    end
                end
            end

            return spawns[GetLowestTableSize(los)]
        end

        return plyspawn.GetRandomSafePlayerSpawnPoint(ply)
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

    hook.Add("TTT2SwapperModifyRevivalList", "BaronExcludeFromSwapper", function(reviveRoleCandidates)
        reviveRoleCandidates[ROLE_BARON] = nil
    end)

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

    hook.Add("PlayerDeath", "BaronRespawnHandler", function(victim)
        if victim:GetSubRole() ~= ROLE_BARON then return end

        local saved = victim.BaronSavedWeapons or {}

        local lives = math.max(0, victim:GetNW2Int("BaronLives", 3) - 1)
        victim:SetNW2Int("BaronLives", lives)
        
        if lives <= 0 then return end
        
        local spawnPoint = TestBaronSpawnLOS(victim)
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
                
                local revivalCredits = GetConVar("ttt2_baron_revival_credits"):GetInt()
                victim:AddCredits(revivalCredits)

                net.Start("BaronCreditsGained")
                net.WriteInt(revivalCredits, 8)
                net.Send(victim)

                net.Start("BaronGlobalSound")
                net.Broadcast()
            end,
            nil,
            false,
            REVIVAL_BLOCK_NONE
        )
    end)

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
        if GetConVar("ttt2_baron_modify_roles"):GetInt() == 0 then return end
        
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

        ply.BaronSavedCredits = ply:GetCredits()
    end)
end

if CLIENT then
    local creditsGainedTime = 0
    local creditsGainedAmount = 0

    hook.Add("TTT2HUDUpdated", "BaronLivesHUD", function()
        if not hudelements then return end

        local hudInfoElements = hudelements.GetAllTypeElements("tttinfopanel")

        for _, v in ipairs(hudInfoElements) do
            if v.SetSecondaryRoleInfoFunction then
                v:SetSecondaryRoleInfoFunction(function()
                    local ply = LocalPlayer()

                    if ply:GetSubRole() == ROLE_BARON then
                        return {
                            color = Color(212, 175, 55, 255),
                            text = "Lives: " .. ply:GetNW2Int("BaronLives", 0)
                        }
                    end
                end)
            end
        end
    end)

    hook.Add("HUDPaint", "BaronCreditsNotification", function()
        local currentTime = CurTime()
        if currentTime - creditsGainedTime < 3 then
            local alpha = 255 * (1 - (currentTime - creditsGainedTime) / 3)
            local notifX = ScrW() - 20
            local notifY = 20

            draw.SimpleText(
                "+ " .. creditsGainedAmount .. " Credits",
                "Trebuchet24",
                notifX,
                notifY,
                Color(255, 230, 0, alpha),
                TEXT_ALIGN_RIGHT,
                TEXT_ALIGN_TOP
            )
        end
    end)

    net.Receive("BaronCreditsGained", function()
        creditsGainedAmount = net.ReadInt(8)
        creditsGainedTime = CurTime()
    end)

    net.Receive("BaronGlobalSound", function()
        surface.PlaySound("tttbaron/laugh.wav")
    end)
end