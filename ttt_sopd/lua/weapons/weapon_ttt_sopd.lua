CLASS_NAME = "weapon_ttt_sopd"
local DEFAULT_NAME = "Sword of Player Defeat"
local SWORD_VIEWMODEL = "models/ttt/sopd/v_sopd.mdl"
local SWORD_WORLDMODEL = "models/ttt/sopd/w_sopd.mdl"

local SWORD_TARGET_MSG   = "SoPD_SwordTargetMsg"
local SWORD_KILLED_MSG   = "SoPD_SwordKilledMsg"
local TARGET_DIED_MSG    = "SoPD_TargetDiedMsg"
local TARGET_SPAWNED_MSG = "SoPD_TargetSpawnedMsg"
GAINED_DISGUISE_MSG      = "SoPD_GainedDisguiseMsg" --used by PaP

local HOOK_BEGIN_ROUND = "TTT_SoPD_ChooseTarget"
local HOOK_PRE_GLOW = "TTT_SoPD_TargetGlow"
local HOOK_RENDER_ENTINFO = "TTT_SoPD_TargetKillInfo"
local HOOK_TAKE_DAMAGE = "TTT_SoPD_DamageImmunity"
local HOOK_PLAYER_DEATH = "TTT_SoPD_ProcessDeaths"
local HOOK_PLAYER_SPAWN = "TTT_SoPD_ProcessSpawns"
local HOOK_PLAYER_STABBED = "TTT_SoPD_PlaySwordKillSound"
local HOOK_PLAYER_DISCONNECT = "TTT_SoPD_UnsetTargetMidround"
local HOOK_BUY = "TTT_SoPD_NotifyDisconnectToBuyers"
local HOOK_SPEEDMOD = "TTT_SoPD_HolderSpeedup"
local DISCONNECT_NOTIF = "[SoPD] Target disconnected. Sword can now be used on anyone (no player-specific outline or damage resistance)." --tried to localize this but it wouldn't work reliably...

local CVAR_FLAGS = {FCVAR_NOTIFY, FCVAR_ARCHIVE}
local ENABLE_TARGET_GLOW = CreateConVar("ttt2_sopd_target_glow", "1", CVAR_FLAGS, "Whether the target player glows for a player holding the Sword.", 0, 1)
local LEAVE_DNA = CreateConVar("ttt2_sopd_leave_dna", "0", CVAR_FLAGS, "Whether stabbing with the Sword leaves DNA.", 0, 1)
local RAGDOLL_STAB_COVERUP = CreateConVar("ttt2_sopd_ragdoll_stab_coverup", "1", CVAR_FLAGS, "Whether stabbing a dead target with the Sword makes it seem like the Sword killed them (removing DNA if relevant convar is enabled).", 0, 1)
local CAN_TARGET_JESTERS = CreateConVar("ttt2_sopd_can_target_jesters", "1", CVAR_FLAGS, "Whether Jesters can be the target.", 0, 1)
local RANGE_BUFF = CreateConVar("ttt2_sopd_range_buff", "1.5", CVAR_FLAGS, "Multiplier for the original TTT knife's range.", 0.01, 5)
local TARGET_DMG_BLOCK = CreateConVar("ttt2_sopd_target_dmg_block", "100", CVAR_FLAGS, "Percent of damage the Sword holder blocks from the target (0 = take full damage, 100 = take no damage)", 0, 100)
local OTHERS_DMG_BLOCK = CreateConVar("ttt2_sopd_others_dmg_block", "0", CVAR_FLAGS, "Percent of damage the Sword holder blocks from non-targets (0 = take full damage, 100 = take no damage)", 0, 100)
local HOLDER_SPEEDUP = CreateConVar("ttt2_sopd_speedup", "1.3", CVAR_FLAGS, "Player speed multiplier while holding the Sword.", 1, 5)

-- used in PaP lua but may be referred to here
PAP_HEAL = CreateConVar("ttt2_sopd_pap_heal", "80", CVAR_FLAGS, "How much health is gained from inhaling an enemy with the Sword of Player Def-Eat.", 0, 200)
PAP_DMG_BLOCK = CreateConVar("ttt2_sopd_pap_dmg_block", "0", CVAR_FLAGS, "Percent of damage the Sword holder blocks from anyone if PAP'd (0 = take full damage, 100 = take no damage)", 0, 100)

local DEPLOY_SND_SOUNDLEVEL = CreateConVar("ttt2_sopd_sfx_deploy_soundlevel", "90", CVAR_FLAGS, "The Sword deploy song's soundlevel (how far it can be heard).", 0, 300)
local DEPLOY_SND_VOLUME = CreateConVar("ttt2_sopd_sfx_deploy_volume", "60", CVAR_FLAGS, "The Sword deploy song's volume, before any reductions.", 0, 100)
KILL_SND_VOLUME = CreateConVar("ttt2_sopd_sfx_kill_volume", "100", CVAR_FLAGS, "The Sword kill sound's volume, before any reductions.", 0, 100) --used by PaP
local STEALTH_VOL_REDUCTION = CreateConVar("ttt2_sopd_sfx_stealth_vol_reduction", "90", CVAR_FLAGS, "The volume of Sword sounds is reduced by this factor when many opponents (inno/side teams) are alive.", 0, 100)
local STEALTH_MAX_OPPS = CreateConVar("ttt2_sopd_sfx_stealth_max_opps", "10", CVAR_FLAGS, "The stealth volume reduction on Sword sound effects is fully applied when this many opponents (inno/side teams) or more are alive, then goes down linearly with the number of remaining opponents (to zero effect when only one opponent left).", 2, 24)
local OATMEAL_FOR_LAST = CreateConVar("ttt2_sopd_sfx_oatmeal_for_last", "1", CVAR_FLAGS, "Whether \"1, 2, Oatmeal\" plays as the deploy song when the target is the last opponent alive.", 0, 1)

local DEBUG = CreateConVar("ttt2_sopd_debug", "0", CVAR_FLAGS, "Activates some debug client/server prints & makes Sword re-buyable (should not be on for real play).", 0, 1)

sounds = {
    swing         = Sound("Weapon_Crowbar.Single"),
    triumph_best  = Sound("sopd/sopd_triumph_best.mp3"),
    triumph_nobgm = Sound("sopd/sopd_triumph_nobgm.mp3"),
    triumph_other = Sound("sopd/sopd_triumph_other.mp3"),
    oatmeal       = Sound("sopd/sopd_oatmeal.mp3"),
    gourmet       = Sound("sopd/sopd_gourmet.mp3"),
    inhale        = Sound("sopd/sopd_inhale.mp3"),
    rag_stab1     = Sound("sopd/sopd_rag_stab1.mp3"),
    rag_stab2     = Sound("sopd/sopd_rag_stab2.mp3"),
}

--sword target, synchronized for server & client
swordTargetPlayer = nil
roundTargetPoolSize = nil --needed to check if targetless due to low playercount

function CanBeSlain(ply)
    --print("CanBeSlain", IsValid(ply))
    --if IsValid(ply) then print(ply:IsPlayer(), swordTargetPlayer == nil, ply == swordTargetPlayer) end
    return IsValid(ply) and ply:IsPlayer() and (swordTargetPlayer == nil or ply == swordTargetPlayer)
end

function HoldsSword(ply, swordCanStab)
    if IsValid(ply) and ply:IsPlayer() then
        local wep = ply:GetActiveWeapon()

        return IsValid(wep) and wep:GetClass() == CLASS_NAME and (not swordCanStab or wep:CanStab())
    end

    return false
end

function IsLivingPlayer(ply)
    return IsValid(ply) and ply:IsPlayer() and ply:Alive() and not ply:IsSpec()
end

function InTargetStabRange(ply)
    if not (IsValid(ply) and ply:IsPlayer()) then return false end
    local tr = ply:GetEyeTrace(MASK_SHOT)
    if not (tr.HitNonWorld and IsValid(tr.Entity)) then return false end

    return ply:GetShootPos():Distance(tr.HitPos) <= 110 * RANGE_BUFF:GetFloat() and CanBeSlain(tr.Entity)
end

local function StartDeploySound(wep)
    if not SERVER then return end
    local owner = wep:GetOwner()

    if wep.DeploySound and wep.DeploySound:IsPlaying() then
        if DEBUG:GetBool() then print("[SFX] Not starting deploy sound (song already playing).") end
        return
    end

    if IsValid(owner) and wep:CanStab()
      and (IsLivingPlayer(swordTargetPlayer) or not swordTargetPlayer) then
        if DEBUG:GetBool() then print("[SFX] Starting deploy sound.") end

        local deploySnd = "gourmet"
        if GetOpponentCount() == 1 and OATMEAL_FOR_LAST:GetBool() then
            deploySnd = "oatmeal"
        end

        wep.DeploySound = CreateSound(owner, sounds[deploySnd])
        wep.DeploySound:SetSoundLevel(DEPLOY_SND_SOUNDLEVEL:GetInt())
        wep.DeploySound:PlayEx(AdjustVolume(DEPLOY_SND_VOLUME:GetFloat()/100), 100)
    end
end

local function StopDeploySound(wep)
    if not SERVER then return end

    if wep.DeploySound and not wep.DeploySound:IsPlaying() then
        if DEBUG:GetBool() then print("[SFX] Not stopping deploy sound (song not playing).") end
        return
    end

    if DEBUG:GetBool() then print("[SFX] Stopping deploy sound.") end
    if wep.DeploySound then
        wep.DeploySound:Stop()
        wep.DeploySound = nil
    end
end

function GetPossibleTargetPool()
    local possibleTargetPool = {}
    local livingPlayerCnt = 0

    for _, ply in ipairs(player.GetAll()) do
        if IsLivingPlayer(ply) then
            livingPlayerCnt = livingPlayerCnt + 1

            if ply:GetTeam() ~= TEAM_TRAITOR
                and ply:GetTeam() ~= TEAM_JACKAL
                and ply:GetTeam() ~= TEAM_INFECTED
                and (CAN_TARGET_JESTERS:GetBool() or ply:GetRole() ~= TEAM_JESTER) then

                table.insert(possibleTargetPool, ply)
            end
        end
    end

    return possibleTargetPool, livingPlayerCnt
end

function GetOpponentCount() --same as above pool's size but always without jesters
    local opponentCnt = 0

    for _, ply in ipairs(player.GetAll()) do
        if IsLivingPlayer(ply) 
          and ply:GetTeam() ~= TEAM_TRAITOR
          and ply:GetTeam() ~= TEAM_JACKAL
          and ply:GetTeam() ~= TEAM_INFECTED
          and ply:GetRole() ~= TEAM_JESTER then

            opponentCnt = opponentCnt + 1
        end
    end

    return opponentCnt
end

function AdjustVolume(base_vol) -- stealth volume reduction effect adjustment
    local maxReduction = STEALTH_VOL_REDUCTION:GetFloat() / 100
    local maxOpps      = STEALTH_MAX_OPPS:GetInt()

    -- we remove 1 from count/max so that 1 opp = 0 reduction & max opp or more = full reduction
    local reductionStrength = math.min((GetOpponentCount() - 1) / (maxOpps - 1), 1)
    local finalVolume = (1 - reductionStrength * maxReduction) * base_vol

    if DEBUG:GetBool() then
        print("[SFX] base volume", base_vol)
        print("[SFX] max reduction", maxReduction)
        print("[SFX] max opps", maxOpps)
        print("[SFX] opp count", GetOpponentCount())
        print("[SFX] -> reduction strength", reductionStrength)
        print("[SFX] -> adjusted volume", math.max(finalVolume, 0))
    end

    return math.max(finalVolume, 0)
end

function GetAllInvSwords()
    local invSwords = {}

    for _, ent in ipairs(ents.GetAll()) do
        if IsValid(ent) and ent:GetClass() == CLASS_NAME then
            table.insert(invSwords, ent)
        end
    end

    return invSwords
end

function UnTargetSwords() -- if target disconnects
    for _, sword in ipairs(GetAllInvSwords()) do
        sword.PrintName = DEFAULT_NAME

        if sword.Packed then
            sword.Primary.ClipSize = 1
            sword:SetClip1(not sword.StabbedTarget and 1 or 0)
        end

        if CLIENT then
            sword:UpdateTooltip(false)

            local owner = sword:GetOwner()
            if IsLivingPlayer(owner) then
                owner:ChatPrint(DISCONNECT_NOTIF)
            end
        end
    end
end

if SERVER then
    AddCSLuaFile("weapon_ttt_sopd.lua")
    util.AddNetworkString(SWORD_TARGET_MSG)
    util.AddNetworkString(SWORD_KILLED_MSG)
    util.AddNetworkString(TARGET_DIED_MSG)
    util.AddNetworkString(TARGET_SPAWNED_MSG)
    util.AddNetworkString(GAINED_DISGUISE_MSG)
    --resource.AddWorkshop("3607870957")
    resource.AddFile("materials/vgui/ttt/icon_sopd.vmt")
    if DEBUG:GetBool() then print("[SoPD Server] Initializing....") end

    -- Find the target player for this round!
    hook.Add("TTTBeginRound", HOOK_BEGIN_ROUND, function()
        local possibleTargetPool, playerCnt = GetPossibleTargetPool()
        roundTargetPoolSize = #possibleTargetPool

        -- Select target player
        if #possibleTargetPool > 0 and playerCnt > 2 then
            swordTargetPlayer = possibleTargetPool[math.random(1, #possibleTargetPool)]

            if DEBUG:GetBool() then print("[SoPD Server] Chosen sword target: " .. swordTargetPlayer:Nick() .. " (team: " .. swordTargetPlayer:GetTeam() .. ")") end
        else
            swordTargetPlayer = nil
            if DEBUG:GetBool() then print("[SoPD Server] No suitable target; SoPD will target anyone (without preventing damage).") end
        end

        -- Set/update damage resistance hook (updated every round because players may enter/exit deathmatch anytime)
        hook.Remove("EntityTakeDamage", HOOK_TAKE_DAMAGE)
        hook.Add("EntityTakeDamage", HOOK_TAKE_DAMAGE, function (target, dmgInfo)
            local attacker = dmgInfo:GetAttacker()

            if HoldsSword(target, true) and IsLivingPlayer(attacker) then
                local dmgBlock = OTHERS_DMG_BLOCK:GetFloat() / 100
                if attacker == swordTargetPlayer then
                    dmgBlock = TARGET_DMG_BLOCK:GetFloat() / 100
                end
                if target:GetActiveWeapon().Packed then
                    dmgBlock = dmgBlock + (PAP_DMG_BLOCK:GetFloat() / 100)
                end

                dmgInfo:SetDamage(dmgInfo:GetDamage() * (1 - math.min(1, dmgBlock)))
            end
        end)

        -- Broadcast chosen player
        net.Start(SWORD_TARGET_MSG)
        net.WritePlayer(swordTargetPlayer) --will send default (Entity(0)) if no target
        net.WriteFloat(roundTargetPoolSize)
        net.Broadcast()
    end)

    hook.Add("PlayerDeath", HOOK_PLAYER_DEATH, function(ply, inflictor, attacker)
        local targetDied = (swordTargetPlayer and ply == swordTargetPlayer)

        if targetDied then
            net.Start(TARGET_DIED_MSG)
            net.Broadcast()
        end

        -- Find any held swords & adjust or end (if target died) their deploy sounds
        for _, p in ipairs(player.GetAll()) do
            local wep = p:GetActiveWeapon()
            if IsValid(wep) and wep:GetClass() == CLASS_NAME then
                if targetDied then
                    if DEBUG:GetBool() then print("[SFX] Stopping sword deploy sound due to target death | Target: ", swordTargetPlayer:Nick()) end
                    StopDeploySound(wep)

                elseif wep.DeploySound and wep.DeploySound:IsPlaying() then
                    if DEBUG:GetBool() then print("[SFX] Actualizing sword deploy volume due to nontarget death | Died: ", ply:Nick()) end
                    wep.DeploySound:ChangeVolume(AdjustVolume(DEPLOY_SND_VOLUME:GetFloat()/100))
                end
            end
        end

        -- Store player ref in ragdoll for later use (GetRagdollOwner doesn't work as expected, maybe cause I'm testing with bots?)
        local rag = ply.server_ragdoll
        if IsValid(rag) then
            rag.PlyOwner = ply
        end
    end)

    hook.Add("PlayerSpawn", HOOK_PLAYER_SPAWN, function(ply)
        local targetSpawned = (IsLivingPlayer(swordTargetPlayer) and ply == swordTargetPlayer)

        if targetSpawned then
            net.Start(TARGET_SPAWNED_MSG)
            net.Broadcast()
        end

        -- Find any held swords & adjust or start (if target respawned) their deploy sounds
        for _, p in ipairs(player.GetAll()) do
            local wep = p:GetActiveWeapon()
            if IsValid(wep) and wep:GetClass() == CLASS_NAME then
                if targetSpawned then
                    if DEBUG:GetBool() then print("[SFX] Starting sword deploy sound due to target respawn | Target: ", swordTargetPlayer:Nick()) end
                    StartDeploySound(wep)

                elseif wep.DeploySound and wep.DeploySound:IsPlaying() then
                    if DEBUG:GetBool() then print("[SFX] Actualizing sword deploy volume due to nontarget respawn | Respawned: ", ply:Nick()) end
                    wep.DeploySound:ChangeVolume(AdjustVolume(DEPLOY_SND_VOLUME:GetFloat()/100))
                end
            end
        end
    end)

    -- fallback for if the target disconnects (become non-targeted sword)
    hook.Add("PlayerDisconnected", HOOK_PLAYER_DISCONNECT, function(ply)
        if ply == swordTargetPlayer then
            swordTargetPlayer = nil
            UnTargetSwords()

            -- yeah no, this doesn't work (TODO? shop reload?)
            --shopSWEP.PrintName = DEFAULT_NAME

            net.Start(SWORD_TARGET_MSG)
            net.WritePlayer(swordTargetPlayer)
            net.WriteFloat(roundTargetPoolSize) --(player count at start of round didn't change)
            net.Broadcast()
        end
    end)

elseif CLIENT then
    if DEBUG:GetBool() then print("[SoPD Client] Initializing....") end

    SWEP.Icon = "vgui/ttt/icon_sopd"
    SWEP.PrintName = DEFAULT_NAME
    SWEP.Author = "Guy"
    SWEP.Instructions = LANG.TryTranslation("sopd_instruction")
    SWEP.Slot = 6

    SWEP.ViewModelFlip = false
    SWEP.ViewModelFOV  = 80
    SWEP.DrawCrosshair = false
    SWEP.UseHands      = true

    local dmgReductionDesc = ""
    local targetDmgBlock = TARGET_DMG_BLOCK:GetFloat()
    if targetDmgBlock == 100 then
        dmgReductionDesc = "While you hold it, they cannot deal damage to you"
    elseif targetDmgBlock > 0 then
        dmgReductionDesc = "While you hold it, they deal " .. targetDmgBlock .. "% less damage to you"
    end

    local othersDmgBlock = OTHERS_DMG_BLOCK:GetFloat()
    if othersDmgBlock > 0 then
        if dmgReductionDesc == "" then
            dmgReductionDesc = "While you hold it, players "
        else
            dmgReductionDesc = dmgReductionDesc .. ", and others "
        end

        if othersDmgBlock == 100 then
            dmgReductionDesc = dmgReductionDesc .. "cannot damage you"
            if targetDmgBlock == 100 then
                dmgReductionDesc = dmgReductionDesc .. " either"
            end
        else
            dmgReductionDesc = dmgReductionDesc .. "deal " .. othersDmgBlock .. "% less damage to you"
        end
    end

    if dmgReductionDesc ~= "" then
        dmgReductionDesc = dmgReductionDesc .. ". "
    end

    SWEP.EquipMenuData = {
        type = "Melee Weapon",
        desc = "Swing to instantly and loudly defeat the person whose name is on this sword. " .. dmgReductionDesc .. "What a triumph is that!"
    }

    shopSWEP = SWEP --ugly hack but not sure how else to do it
    net.Receive(SWORD_TARGET_MSG, function(msgLen, ply)
        local newTarget = net.ReadPlayer()
        roundTargetPoolSize = net.ReadFloat()

        if newTarget == Entity(0) or not newTarget then
            if DEBUG:GetBool() then print("[SoPD Client] No sword target") end

            shopSWEP.PrintName = DEFAULT_NAME
            swordTargetPlayer = nil
            UnTargetSwords()

        else
            if DEBUG:GetBool() then print("[SoPD Client] Known sword target: ".. newTarget:Nick()) end

            shopSWEP.PrintName = "Sword of ".. newTarget:Nick() .. " Defeat"

            local plyNick = string.lower(newTarget:Nick())
            if plyNick == "king dedede" or plyNick == "dedede" then
                shopSWEP.PrintName = shopSWEP.PrintName .. "!"
            end
            swordTargetPlayer = newTarget
        end
    end)

    --display halo (through walls if convar is enabled & always if able to kill)
    hook.Add("PreDrawHalos", HOOK_PRE_GLOW, function()
        local localPlayer = LocalPlayer()

        if HoldsSword(localPlayer, true) then
            local inRange = InTargetStabRange(localPlayer)
            local glowStrength = 1 + (inRange and 1 or 0) --increase strength for kill range

            local target = {swordTargetPlayer}
            if not swordTargetPlayer and inRange then
                target = {ply:GetEyeTrace(MASK_SHOT).Entity}
            end

            if inRange or ENABLE_TARGET_GLOW:GetBool() and IsLivingPlayer(swordTargetPlayer) then
                halo.Add(target, Color(254,215,0), glowStrength, glowStrength, glowStrength, true, true)
            end
        end
    end)

    --notify instakill in target's info if InTargetStabRange
    hook.Add("TTTRenderEntityInfo", HOOK_RENDER_ENTINFO, function(tData)
        local localPlayer = LocalPlayer()

        if CanBeSlain(tData:GetEntity()) and InTargetStabRange(localPlayer) and HoldsSword(localPlayer, true) then
            local role_color = localPlayer:GetRoleColor()
            local insta_label = "sopd_instantkill"
            if localPlayer:GetActiveWeapon().Packed then
                insta_label = "sopd_instanteat"
            end
            tData:AddDescriptionLine(LANG.TryTranslation(insta_label), role_color)

            -- draw instant-kill maker
            local x = ScrW() * 0.5
            local y = ScrH() * 0.5
            local outer = 20
            local inner = 10

            surface.SetDrawColor(clr(role_color))
            surface.DrawLine(x - outer, y - outer, x - inner, y - inner)
            surface.DrawLine(x + outer, y + outer, x + inner, y + inner)
            surface.DrawLine(x - outer, y + outer, x - inner, y + inner)
            surface.DrawLine(x + outer, y - outer, x + inner, y - inner)
        end
    end)

    -- ensure the sword's kill noise plays if the server considers it killed a player
    net.Receive(SWORD_KILLED_MSG, function()
        local isPapped = net.ReadBool()
        local swordEnt = net.ReadEntity()
        if DEBUG:GetBool() then print("[SWORD_KILLED_MSG]", swordEnt, IsValid(swordEnt), isPapped) end

        if not isPapped and IsValid(swordEnt) then
            local choice
            local roll = math.random()
            local best_sfx_prob = 0.8

            if roll <= best_sfx_prob then
                choice = "triumph_best"
            elseif roll <= best_sfx_prob + (1 - best_sfx_prob)/2 then
                choice = "triumph_nobgm"
            else
                choice = "triumph_other"
            end

            if DEBUG:GetBool() then print("[SFX] Playing on-kill triumph sound", choice) end
            swordEnt:EmitSound(sounds[choice], SNDLVL_150dB, 100, AdjustVolume(KILL_SND_VOLUME:GetFloat()/100), CHAN_BODY)
        end
    end)

    function SWEP:UpdateTooltip(targetAlive)
        if self.Packed then return end
        if DEBUG:GetBool() then print("Updating sword tooltip...") end

        if roundTargetPoolSize < 2 then
            self:AddTTT2HUDHelp("sopd_instruction_targeted")
        else
            if swordTargetPlayer then
                if targetAlive then
                    self:AddTTT2HUDHelp("sopd_instruction_targeted")
                else
                    if RAGDOLL_STAB_COVERUP:GetBool() then
                        self:AddTTT2HUDHelp("sopd_instruction_stab_coverup")
                    else
                        self:AddTTT2HUDHelp("sopd_instruction_stab")
                    end
                end
            else
                self:AddTTT2HUDHelp("sopd_instruction_targetless")
            end
        end
    end

    net.Receive(TARGET_DIED_MSG, function()
        for _, sword in ipairs(GetAllInvSwords()) do
            sword:UpdateTooltip(false)
        end
    end)

    net.Receive(TARGET_SPAWNED_MSG, function()
        for _, sword in ipairs(GetAllInvSwords()) do
            sword:UpdateTooltip(true)
        end
    end)

    function SWEP:Initialize() --on buy (local to 1 player)
        self:UpdateTooltip(IsLivingPlayer(swordTargetPlayer))

        -- chat notification if you buy sword after the target disconnects
        local localPlayer = LocalPlayer()

        if not swordTargetPlayer and roundTargetPoolSize > 1
          and localPlayer:GetRole() != ROLE_DEATHMATCHER then
            localPlayer:ChatPrint(DISCONNECT_NOTIF)
        end

        return self.BaseClass.Initialize(self)
    end
end

SWEP.Base         = "weapon_tttbase"
SWEP.HoldType     = "melee"
SWEP.ViewModel    = SWORD_VIEWMODEL
SWEP.WorldModel   = SWORD_WORLDMODEL
SWEP.idleResetFix = true

SWEP.Primary.Damage      = 100
SWEP.Primary.ClipSize    = -1
SWEP.Primary.DefaultClip = -1
SWEP.Primary.Automatic   = true
SWEP.Primary.Delay       = 0.5
SWEP.Primary.Ammo        = "none"

SWEP.Kind         = WEAPON_EQUIP
SWEP.CanBuy       = {ROLE_TRAITOR, ROLE_JACKAL}
SWEP.LimitedStock = !DEBUG:GetBool()
SWEP.WeaponID     = AMMO_KNIFE
SWEP.IsSilent    = true --(negated by the noises we add lol)
SWEP.AllowDrop   = true
SWEP.DeploySpeed = 2

function SWEP:PrimaryAttack()
    self:SetNextPrimaryFire(CurTime() + self.Primary.Delay)
    self:EmitSound(sounds["swing"])

    local owner = self:GetOwner()
    if not IsValid(owner) then return end
    owner:LagCompensation(true)

    local spos = owner:GetShootPos()
    local sdest = spos + (owner:GetAimVector() * 100 * RANGE_BUFF:GetFloat())

    local kmins = Vector(1,1,1) * -10
    local kmaxs = Vector(1,1,1) * 10

    -- raycast to get entity hit by sword, ignoring owner & other swords
    local function SwordTraceFilter(ent)
        return ent != owner and ent:GetModel() != SWORD_WORLDMODEL
    end

    local tr = util.TraceHull({start=spos, endpos=sdest, filter=SwordTraceFilter, mask=MASK_SHOT_HULL, mins=kmins, maxs=kmaxs})

    -- Hull might hit environment stuff that line does not hit
    if not IsValid(tr.Entity) then
        tr = util.TraceLine({start=spos, endpos=sdest, filter=SwordTraceFilter, mask=MASK_SHOT_HULL})
    end

    local hitEnt = tr.Entity
    if DEBUG:GetBool() then print("SoPD Primary Hit Entity", hitEnt) end

    -- effects
    if IsValid(hitEnt) then
        self:SendWeaponAnim(ACT_VM_HITCENTER)

        local edata = EffectData()
        edata:SetStart(spos)
        edata:SetOrigin(tr.HitPos)
        edata:SetNormal(tr.Normal)
        edata:SetEntity(hitEnt)

        if CanBeSlain(hitEnt) or hitEnt:GetClass() == "prop_ragdoll" then
            util.Effect("BloodImpact", edata)
        end
    else
        self:SendWeaponAnim(ACT_VM_MISSCENTER)
    end

    if SERVER then
        owner:SetAnimation(PLAYER_ATTACK1)

        if DEBUG:GetBool() then print("SoPD Primary Attack Check 1:", self:CanStab(), tr.Hit, tr.HitNonWorld, IsValid(hitEnt)) end

        if self:CanStab() and tr.Hit and tr.HitNonWorld and IsValid(hitEnt) then
            if DEBUG:GetBool() then print("SoPD Primary Attack Check 2:", CanBeSlain(hitEnt), hitEnt:GetClass() == "prop_ragdoll", hitEnt:IsPlayerRagdoll(), CanBeSlain(hitEnt.PlyOwner), swordTargetPlayer or self.Packed, "from", swordTargetPlayer and 1 or 0, self.Packed) end

            if CanBeSlain(hitEnt) and owner:GetTeam() != TEAM_JESTER then
                self:StabKill(tr, spos, sdest)
            elseif hitEnt:GetClass() == "prop_ragdoll" and hitEnt:IsPlayerRagdoll() and CanBeSlain(hitEnt.PlyOwner) and (swordTargetPlayer or self.Packed) then
                self:StabRagdoll(tr, spos, sdest)
            end
        end
    end

    owner:LagCompensation(false)
end

function SWEP:CanStab()
    return self.Primary.ClipSize == -1 or self:Clip1() > 0
end

local function adjStuckSwordAngle(norm)
    local ang = norm:Angle()
    ang:RotateAroundAxis(ang:Up(), 180)
    return ang
end

local function adjStuckSwordPos(retr, ang)
    return retr.HitPos + (ang:Forward() * 10)
end

function SWEP:StabKill(tr, spos, sdest)
    --arg2/3 = shooting origin/dest world positions
    --serverside only
    local target = tr.Entity
    local owner = self:GetOwner()

    --wish I knew how to make this not ugly (TODO?)
    local packEffect = self.PackEffect
    local swepRef = self

    -- damage to killma player
    local dmg = DamageInfo()
    dmg:SetDamage(12047)
    if LEAVE_DNA:GetBool() or target:GetTeam() == TEAM_JESTER then
        dmg:SetAttacker(owner)
    end
    dmg:SetInflictor(self)
    dmg:SetDamageForce(owner:GetAimVector())
    dmg:SetDamagePosition(owner:GetPos())
    dmg:SetDamageType(DMG_SLASH)

    -- raycast to get entity hit by sword (which should be a player's limb)
    local retr = util.TraceLine({start=spos, endpos=sdest, filter=owner, mask=MASK_SHOT_HULL})
    if retr.Entity != target then
        local center = target:LocalToWorld(target:OBBCenter())
        retr = util.TraceLine({start=spos, endpos=center, filter=owner, mask=MASK_SHOT_HULL})
    end

    -- create knife effect creation fn
    local bone = retr.PhysicsBone
    local norm = tr.Normal
    local ang = adjStuckSwordAngle(norm)
    local pos = adjStuckSwordPos(retr, ang)

    target.effect_fn = function(rag)
        local stuckSword

        if not packEffect then
            -- redo raycast from previously hit point (we might find a better location)
            local rtr = util.TraceLine({start=pos, endpos=pos + norm * 40, filter=owner, mask=MASK_SHOT_HULL})

            if IsValid(rtr.Entity) and rtr.Entity == rag then
                bone = rtr.PhysicsBone
                ang = adjStuckSwordAngle(rtr.Normal)
                pos = adjStuckSwordPos(rtr, ang)
            end

            stuckSword = ents.Create("prop_physics")
            stuckSword:SetModel(SWORD_WORLDMODEL)
            stuckSword:SetPos(pos)
            stuckSword:SetCollisionGroup(COLLISION_GROUP_DEBRIS)
            stuckSword:SetAngles(ang)
            stuckSword.CanPickup = false
            stuckSword:Spawn()

            local phys = stuckSword:GetPhysicsObject()
            if IsValid(phys) then phys:EnableCollisions(false) end
            constraint.Weld(rag, stuckSword, bone, 0, 0, true)

            -- need to close over sword in order to keep a valid ref to it
            rag:CallOnRemove("ttt_sword_cleanup", function() SafeRemoveEntity(stuckSword) end)
        end

        -- play slay noise from stuck sword
        net.Start(SWORD_KILLED_MSG)
        net.WriteBool(packEffect)
        net.WriteEntity(stuckSword)
        net.Broadcast()
        if packEffect then packEffect(swepRef, rag, owner) end
        if DEBUG:GetBool() then print("[SWORD_KILLED_MSG] Sent") end
    end

    --dispatch killing attack, trigger sword sticking function & clean up
    target:DispatchTraceAttack(dmg, spos + (owner:GetAimVector() * 3), sdest)
    self:Consume(false)
end

function SWEP:StabRagdoll(tr, spos, sdest)
    local hitRagdoll = tr.Entity

    if not self.Packed then
        local ang = adjStuckSwordAngle(tr.Normal)
        local pos = adjStuckSwordPos(tr, ang)
        local stabVol = 0.2

        local stuckSword = ents.Create("prop_physics")
        stuckSword:SetModel(SWORD_WORLDMODEL)
        stuckSword:SetPos(pos)
        stuckSword:SetAngles(ang)
        stuckSword:SetCollisionGroup(COLLISION_GROUP_DEBRIS)
        stuckSword.CanPickup = false
        stuckSword:Spawn()

        local phys = stuckSword:GetPhysicsObject()
        if IsValid(phys) then phys:EnableCollisions(false) end

        constraint.Weld(hitRagdoll, stuckSword, tr.PhysicsBone or 0, 0, 0, true)
        hitRagdoll:CallOnRemove("ttt_sword_cleanup", function() SafeRemoveEntity(stuckSword) end)

        -- concealing death cause here if enabled
        if RAGDOLL_STAB_COVERUP:GetBool() then
            --gameplay relevant mechanic should have SOME risk
            stabVol = math.max(stabVol, AdjustVolume(KILL_SND_VOLUME:GetFloat()/100))

            hitRagdoll.was_headshot = false
            hitRagdoll.dmgwep = CLASS_NAME
            hitRagdoll.dmgtype = DMG_SLASH
            hitRagdoll.scene.lastDamage = 12047
            hitRagdoll.scene.hit_trace = util.TraceHull({start=Vector(1,1,1), endpos=Vector(1,1,1)}) --pointblank attack
            hitRagdoll.scene.waterLevel  = 0
            if not LEAVE_DNA:GetBool() then hitRagdoll.killer_sample = nil end
        end

        local stabSnd = "rag_stab1"
        if math.random() > 0.8 then stabSnd = "rag_stab2" end

        if DEBUG:GetBool() then print("[SFX] Playing ragdoll stab sound", stabSnd, "vol", stabVol) end
        stuckSword:EmitSound(sounds[stabSnd], SNDLVL_70dB, 100, stabVol, CHAN_BODY)
    end

    self:Consume(true, hitRagdoll)
end

function SWEP:Consume(doPap, rag)
    if DEBUG:GetBool() then print("[SFX] Stopping deploy sound due to consumption") end
    StopDeploySound(self)

    if swordTargetPlayer then
        self.StabbedTarget = true
    end

    if self.Packed then
        if self.Primary.ClipSize != -1 then
            self:SetClip1(0)
        end

        if doPap and rag and not self.packVictim then
            self:PackEffect(rag, self:GetOwner())
        end
    else
        self:Remove()
    end
end

function SWEP:SecondaryAttack()
end

function SWEP:Equip()
    self:SetNextPrimaryFire(CurTime() + (self.Primary.Delay * 1.5))
end

function SWEP:PreDrop()
    if DEBUG:GetBool() then print("[SFX] Stopping deploy sound due to item drop") end
    StopDeploySound(self)
    self.fingerprints = {}
end

function SWEP:OnRemove()
    if CLIENT and IsValid(self:GetOwner()) 
      and self:GetOwner() == LocalPlayer() 
      and self:GetOwner():Alive() then
        RunConsoleCommand("lastinv")
    end
end

function SWEP:AddToSettingsMenu(parent)
    local formMain = vgui.CreateTTT2Form(parent, "label_sopd_main_form")

    formMain:MakeHelp({
        label = "label_sopd_range_buff_desc"
    })
    formMain:MakeSlider({
        serverConvar = "ttt2_sopd_range_buff",
        label = "label_sopd_range_buff",
        min = 0.1,
        max = 5,
        decimal = 1
    })

    formMain:MakeSlider({
        serverConvar = "ttt2_sopd_speedup",
        label = "label_sopd_speedup",
        min = 1,
        max = 5,
        decimal = 1
    })

    formMain:MakeCheckBox({
        serverConvar = "ttt2_sopd_leave_dna",
        label = "label_sopd_leave_dna"
    })
    formMain:MakeCheckBox({
        serverConvar = "ttt2_sopd_ragdoll_stab_coverup",
        label = "label_sopd_ragdoll_stab_coverup"
    })
    formMain:MakeCheckBox({
        serverConvar = "ttt2_sopd_target_glow",
        label = "label_sopd_target_glow"
    })
    formMain:MakeCheckBox({
        serverConvar = "ttt2_sopd_can_target_jesters",
        label = "label_sopd_can_target_jesters"
    })

    formMain:MakeHelp({
        label = "label_sopd_dmg_block_desc"
    })
    formMain:MakeSlider({
        serverConvar = "ttt2_sopd_target_dmg_block",
        label = "label_sopd_target_dmg_block",
        min = 0,
        max = 100,
        decimal = 0
    })
    formMain:MakeSlider({
        serverConvar = "ttt2_sopd_others_dmg_block",
        label = "label_sopd_others_dmg_block",
        min = 0,
        max = 100,
        decimal = 0
    })

    local formPaP = vgui.CreateTTT2Form(parent, "label_sopd_pap_form")
    formPaP:MakeSlider({
        serverConvar = "ttt2_sopd_pap_heal",
        label = "label_sopd_pap_heal",
        min = 0,
        max = 200,
        decimal = 0
    })
    formPaP:MakeHelp({
        label = "label_sopd_pap_dmg_block_desc"
    })
    formPaP:MakeSlider({
        serverConvar = "ttt2_sopd_pap_dmg_block",
        label = "label_sopd_pap_dmg_block",
        min = 0,
        max = 100,
        decimal = 0
    })

    local formSFX = vgui.CreateTTT2Form(parent, "label_sopd_sfx_form")
    formSFX:MakeHelp({
        label = "label_sopd_sfx_deploy_soundlevel_desc"
    })
    formSFX:MakeSlider({
        serverConvar = "ttt2_sopd_sfx_deploy_soundlevel",
        label = "label_sopd_sfx_deploy_soundlevel",
        min = 0,
        max = 300,
        decimal = 0
    })
    formSFX:MakeHelp({
        label = "label_sopd_sfx_volume_desc"
    })
    formSFX:MakeSlider({
        serverConvar = "ttt2_sopd_sfx_deploy_volume",
        label = "label_sopd_sfx_deploy_volume",
        min = 0,
        max = 100,
        decimal = 0
    })
    formSFX:MakeSlider({
        serverConvar = "ttt2_sopd_sfx_kill_volume",
        label = "label_sopd_sfx_kill_volume",
        min = 0,
        max = 100,
        decimal = 0
    })
    formSFX:MakeCheckBox({
        serverConvar = "ttt2_sopd_sfx_oatmeal_for_last",
        label = "label_sopd_sfx_oatmeal_for_last"
    })
    formSFX:MakeHelp({
        label = "label_sopd_sfx_stealth_desc"
    })
    formSFX:MakeSlider({
        serverConvar = "ttt2_sopd_sfx_stealth_vol_reduction",
        label = "label_sopd_sfx_stealth_vol_reduction",
        min = 0,
        max = 100,
        decimal = 0
    })
    formSFX:MakeSlider({
        serverConvar = "ttt2_sopd_sfx_stealth_max_opps",
        label = "label_sopd_sfx_stealth_max_opps",
        min = 2,
        max = 24,
        decimal = 0
    })

    local formMisc = vgui.CreateTTT2Form(parent, "label_sopd_misc_form")
    formMisc:MakeCheckBox({
        serverConvar = "ttt2_sopd_give_guy_access",
        label = "label_sopd_give_guy_access"
    })
    formMisc:MakeCheckBox({
        serverConvar = "ttt2_sopd_debug",
        label = "label_sopd_debug"
    })
end

function SWEP:Deploy()
    self.Weapon:SendWeaponAnim(ACT_VM_DRAW)

    if DEBUG:GetBool() then print("[SFX] Starting deploy sound due to deploy") end
    StartDeploySound(self)
    return true
end

function SWEP:Holster()
    if DEBUG:GetBool() then print("[SFX] Stopping deploy sound due to holster") end
    StopDeploySound(self)
    return true
end

hook.Add("TTTPlayerSpeedModifier", HOOK_SPEEDMOD, function(ply, _, _, noLag )
    if HoldsSword(ply, false) then
        if TTT2 then
            noLag[1] = noLag[1] * HOLDER_SPEEDUP:GetFloat()
        else
            return HOLDER_SPEEDUP:GetFloat()
        end
    end
end)