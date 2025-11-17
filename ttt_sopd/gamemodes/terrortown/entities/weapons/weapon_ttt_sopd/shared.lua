local DEFAULT_NAME = "Sword of Player Defeat"
local CLASS_NAME = "weapon_ttt_sopd"
local DEBUG = true
local SND_DEBUG = true

local SWORD_TARGET_MSG = "SoPD_SwordTargetMsg"
local SWORD_KILLED_MSG = "SoPD_SwordKilledMsg"
local HOOK_BEGIN_ROUND = "TTT_SoPD_ChooseTarget"
local HOOK_PRE_GLOW = "TTT_SoPD_TargetGlow"
local HOOK_RENDER_ENTINFO = "TTT_SoPD_TargetKillInfo"
local HOOK_TAKE_DAMAGE = "TTT_SoPD_DamageImmunity"
local HOOK_PLAYER_DEATH = "TTT_SoPD_ProcessDeaths"
local HOOK_PLAYER_SPAWN = "TTT_SoPD_ProcessSpawns"
local HOOK_PLAYER_STABBED = "TTT_SoPD_PlaySwordKillSound"
local HOOK_PLAYER_DISCONNECT = "TTT_SoPD_UnsetTargetMidround"
local HOOK_SPEEDMOD = "TTT_SoPD_HolderSpeedup"

local CVAR_FLAGS = {FCVAR_NOTIFY, FCVAR_ARCHIVE}
local ENABLE_TARGET_GLOW = CreateConVar("ttt2_sopd_target_glow", "1", CVAR_FLAGS, "Whether the target player glows for a player holding the sword.", 0, 1)
local LEAVE_DNA = CreateConVar("ttt2_sopd_leave_dna", "0", CVAR_FLAGS, "Whether stabbing with the sword leaves DNA.", 0, 1)
local CAN_TARGET_SWAPPER = CreateConVar("ttt2_sopd_can_target_swapper", "1", CVAR_FLAGS, "Whether the Swapper can be the target.", 0, 1)
local RANGE_BUFF = CreateConVar("ttt2_sopd_range_buff", "1.5", CVAR_FLAGS, "Multiplier for the original TTT knife's range.", 0.01, 5)
local TARGET_DMG_BLOCK = CreateConVar("ttt2_sopd_target_dmg_block", "100", CVAR_FLAGS, "Percent of damage the sword holder blocks from the target (0 = take full damage, 100 = take no damage)", 0, 100)
local OTHERS_DMG_BLOCK = CreateConVar("ttt2_sopd_others_dmg_block", "0", CVAR_FLAGS, "Percent of damage the sword holder blocks from non-targets (0 = take full damage, 100 = take no damage)", 0, 100)
local HOLDER_SPEEDUP = CreateConVar("ttt2_sopd_speedup", "1.3", CVAR_FLAGS, "Player speed multiplier while holding the sword.", 1, 5)

local DEPLOY_SND_SOUNDLEVEL = CreateConVar("ttt2_sopd_sfx_deploy_soundlevel", "90", CVAR_FLAGS, "The sword deploy song's soundlevel (how far it can be heard).", 0, 300)
local DEPLOY_SND_VOLUME = CreateConVar("ttt2_sopd_sfx_deploy_volume", "60", CVAR_FLAGS, "The sword deploy song's volume, before any reductions.", 0, 100)
local KILL_SND_VOLUME = CreateConVar("ttt2_sopd_sfx_kill_volume", "100", CVAR_FLAGS, "The sword kill sound's volume, before any reductions.", 0, 100)
local STEALTH_VOL_REDUCTION = CreateConVar("ttt2_sopd_sfx_stealth_vol_reduction", "90", CVAR_FLAGS, "The volume of sword sounds is reduced by this factor when many opponents (inno/side teams) are alive.", 0, 100)
local STEALTH_MAX_OPPS = CreateConVar("ttt2_sopd_sfx_stealth_max_opps", "10", CVAR_FLAGS, "The stealth volume reduction on sword sound effects is fully applied when this many opponents (inno/side teams) or more are alive, then goes down linearly with the number of remaining opponents (to zero effect when only one opponent left).", 2, 24)
local BEST_TRIUMPH_PROB = CreateConVar("ttt2_sopd_sfx_best_triumph_prob", "80", CVAR_FLAGS, "Chance sopd_triumph_best plays over the other two when target is stabbed.", 33, 100)
local OATMEAL_FOR_LAST = CreateConVar("ttt2_sopd_sfx_oatmeal_for_last", "1", CVAR_FLAGS, "Whether \"1, 2, Oatmeal\" plays as the deploy song when the target is the last opponent alive.", 0, 1)

local sounds = {
    triumph_best  = Sound("sopd/sopd_triumph_best.mp3"),
    triumph_nobgm = Sound("sopd/sopd_triumph_nobgm.mp3"),
    triumph_other = Sound("sopd/sopd_triumph_other.mp3"),
    oatmeal       = Sound("sopd/sopd_oatmeal.mp3"),
    gourmet       = Sound("sopd/sopd_gourmet.mp3")
}

--sword target, synchronized for server & client
local swordTargetPlayer = nil

function CanBeSlain(ply)
    return IsValid(ply) and ply:IsPlayer() and (swordTargetPlayer == nil or ply == swordTargetPlayer)
end

function HoldsSword(ply)
    if IsValid(ply) and ply:IsPlayer() then
        local wep = ply:GetActiveWeapon()

        if IsValid(wep) and wep:GetClass() == CLASS_NAME then
            return true
        end
    end

    return false
end

function IsLivingPlayer(ply)
    return IsValid(ply) and ply:IsPlayer() and ply:Alive() and not ply:IsSpec()
end

function CanStabTarget(ply)
    if not (IsValid(ply) and ply:IsPlayer()) then return false end
    local tr = ply:GetEyeTrace(MASK_SHOT)
    if not (tr.HitNonWorld and IsValid(tr.Entity)) then return false end

    return ply:GetShootPos():Distance(tr.HitPos) <= 110 * RANGE_BUFF:GetFloat() and CanBeSlain(tr.Entity)
end

function StartDeploySound(wep)
    if SND_DEBUG then print("Starting deploy sound.") end
    local owner = wep:GetOwner()

    if IsValid(owner) and (IsLivingPlayer(swordTargetPlayer) or not swordTargetPlayer) then
        local deploySnd = "gourmet"
        if GetOpponentCount() == 1 and OATMEAL_FOR_LAST:GetBool() then
            deploySnd = "oatmeal"
        end

        wep.DeploySound = CreateSound(owner, sounds[deploySnd])
        wep.DeploySound:SetSoundLevel(DEPLOY_SND_SOUNDLEVEL:GetInt())
        wep.DeploySound:PlayEx(AdjustVolume(DEPLOY_SND_VOLUME:GetFloat()/100), 100)
    end
end

function StopDeploySound(wep)
    if SND_DEBUG then print("Stopping deploy sound.") end
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
                and (CAN_TARGET_SWAPPER:GetBool() or ply:GetRole() ~= ROLE_SWAPPER) then

                table.insert(possibleTargetPool, ply)
            end
        end
    end

    return possibleTargetPool, livingPlayerCnt
end

function GetOpponentCount() --same as above pool's size but always without swapper
    local opponentCnt = 0

    for _, ply in ipairs(player.GetAll()) do
        --print("GetOpponentCount", ply:Nick(), opponentCnt)
        if IsLivingPlayer(ply) 
          and ply:GetTeam() ~= TEAM_TRAITOR
          and ply:GetTeam() ~= TEAM_JACKAL
          and ply:GetTeam() ~= TEAM_INFECTED
          and ply:GetRole() ~= ROLE_SWAPPER then

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

    if SND_DEBUG then
        print("base volume", base_vol)
        print("max reduction", maxReduction)
        print("max opps", maxOpps)
        print("opp count", GetOpponentCount())
        print("-> reduction strength", reductionStrength)
        print("-> adjusted volume", math.max(finalVolume, 0))
    end

    return math.max(finalVolume, 0)
end



if SERVER then
    AddCSLuaFile("shared.lua")
    util.AddNetworkString(SWORD_TARGET_MSG)
    util.AddNetworkString(SWORD_KILLED_MSG)
    resource.AddFile("materials/vgui/ttt/icon_sopd.vmt")
    if DEBUG then print("[SoPD Server] Initializing....") end

    -- Find the target player for this round!
    hook.Add("TTTBeginRound", HOOK_BEGIN_ROUND, function()
        local possibleTargetPool, playerCnt = GetPossibleTargetPool()

        -- Select target player
        if #possibleTargetPool > 0 and playerCnt > 2 then
            swordTargetPlayer = possibleTargetPool[math.random(1, #possibleTargetPool)]

            if DEBUG then print("[SoPD Server] Chosen sword target: " .. swordTargetPlayer:Nick() .. " (team: " .. swordTargetPlayer:GetTeam() .. ")") end
        else
            swordTargetPlayer = nil
            if DEBUG then print("[SoPD Server] No suitable target; SoPD will target anyone (without preventing damage).") end
        end

        -- Set/update damage hook for that player (if no target, just remove)
        hook.Remove("EntityTakeDamage", HOOK_TAKE_DAMAGE)
        if swordTargetPlayer then
            hook.Add("EntityTakeDamage", HOOK_TAKE_DAMAGE, function (target, dmgInfo)
                if HoldsSword(target) then
                    local dmgBlock = OTHERS_DMG_BLOCK:GetFloat()
                    if dmgInfo:GetAttacker() == swordTargetPlayer then
                        dmgBlock = TARGET_DMG_BLOCK:GetFloat()
                    end

                    dmgInfo:SetDamage(dmgInfo:GetDamage() * (1 - dmgBlock / 100))
                end
            end)
        end

        -- Broadcast chosen player
        net.Start(SWORD_TARGET_MSG)
        net.WritePlayer(swordTargetPlayer) --will send default (Entity(0)) if no target
        net.Broadcast()
    end)

    hook.Add("PlayerDeath", HOOK_PLAYER_DEATH, function(ply, inflictor, attacker)
        -- Find any held swords & adjust or end (if target died) their deploy sounds
        for _, p in ipairs(player.GetAll()) do
            local wep = p:GetActiveWeapon()
            if IsValid(wep) and wep:GetClass() == CLASS_NAME then
                if swordTargetPlayer and ply == swordTargetPlayer then
                    if SND_DEBUG then print("Stopping sword deploy sound due to target death | Target: ", swordTargetPlayer:Nick()) end
                    StopDeploySound(wep)
                elseif wep.DeploySound then
                    if SND_DEBUG then print("Changing sword deploy volume due to nontarget death | Died: ", ply:Nick()) end
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
        -- Find any held swords & adjust or start (if target respawned) their deploy sounds
        for _, p in ipairs(player.GetAll()) do
            local wep = p:GetActiveWeapon()
            if IsValid(wep) and wep:GetClass() == CLASS_NAME then
                if swordTargetPlayer and ply == swordTargetPlayer then
                    if SND_DEBUG then print("Starting sword deploy sound due to target respawn | Target: ", swordTargetPlayer:Nick()) end
                    StartDeploySound(wep)
                elseif wep.DeploySound then
                    if SND_DEBUG then print("Changing sword deploy volume due to nontarget respawn | Respawned: ", ply:Nick()) end
                    wep.DeploySound:ChangeVolume(AdjustVolume(DEPLOY_SND_VOLUME:GetFloat()/100))
                end
            end
        end
    end)

    -- fallback for if the target disconnects (become non-targeted sword)
    hook.Add("PlayerDisconnected", HOOK_PLAYER_DISCONNECT, function(ply)
        if ply == swordTargetPlayer then
            swordTargetPlayer = nil
            net.Start(SWORD_TARGET_MSG)
            net.WritePlayer(swordTargetPlayer)
            net.Broadcast()
        end
    end)

elseif CLIENT then
    if DEBUG then print("[SoPD Client] Initializing....") end

    SWEP.Icon = "vgui/ttt/icon_sopd"
    SWEP.PrintName = DEFAULT_NAME
    SWEP.Author = "Guy"
    SWEP.Instructions = LANG.TryTranslation("sopd_instruction")
    SWEP.Slot = 6

    SWEP.ViewModelFlip = false
    SWEP.ViewModelFOV  = 85
    SWEP.DrawCrosshair = false

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

    swordSWEP = SWEP --ugly hack but SWEP seems to become nil after initialization
    net.Receive(SWORD_TARGET_MSG, function(msgLen, ply)
        local swordTarget = net.ReadPlayer()
        if swordTarget == Entity(0) then
            if DEBUG then print("[SoPD Client] No sword target") end

            swordSWEP.PrintName = DEFAULT_NAME
            swordTargetPlayer = nil
        else
            if DEBUG then print("[SoPD Client] Known sword target: ".. swordTarget:Nick()) end

            swordSWEP.PrintName = "Sword of ".. swordTarget:Nick() .. " Defeat"
            if swordTarget:Nick() == "King Dedede" then
                swordSWEP.PrintName = swordSWEP.PrintName .. "!"
            end
            swordTargetPlayer = swordTarget
        end
    end)

    --display halo (through walls if convar is enabled & always if able to kill)
    hook.Add("PreDrawHalos", HOOK_PRE_GLOW, function()
        local localPlayer = LocalPlayer()

        if HoldsSword(localPlayer) then
            local canStab = CanStabTarget(localPlayer)
            local glowStrength = 1 + (canStab and 1 or 0) --increase strength for kill range

            local target = {swordTargetPlayer}
            if not swordTargetPlayer and canStab then
                target = {ply:GetEyeTrace(MASK_SHOT).Entity}
            end

            if canStab or ENABLE_TARGET_GLOW:GetBool() and IsLivingPlayer(swordTargetPlayer) then
                halo.Add(target, Color(254,215,0), glowStrength, glowStrength, glowStrength, true, true)
            end
        end
    end)

    --notify instakill in target's info if CanStabTarget
    hook.Add("TTTRenderEntityInfo", HOOK_RENDER_ENTINFO, function(tData)
        local localPlayer = LocalPlayer()

        if CanBeSlain(tData:GetEntity()) and CanStabTarget(localPlayer) and HoldsSword(localPlayer) then
            local role_color = localPlayer:GetRoleColor()
            tData:AddDescriptionLine(LANG.TryTranslation("sopd_instantkill"), role_color)

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
        if DEBUG then print("[SWORD_KILLED_MSG]", swordEnt, IsValid(swordEnt)) end
        local swordEnt = net.ReadEntity()

        if IsValid(swordEnt) then
            local choice
            local roll = math.random()
            local best_sfx_prob = BEST_TRIUMPH_PROB:GetFloat() / 100

            if roll <= best_sfx_prob then
                choice = "triumph_best"
            elseif roll <= best_sfx_prob + (1 - best_sfx_prob)/2 then
                choice = "triumph_nobgm"
            else
                choice = "triumph_other"
            end

            swordEnt:EmitSound(sounds[choice], SNDLVL_150dB, 100, AdjustVolume(KILL_SND_VOLUME:GetFloat()/100), CHAN_BODY)
        end
    end)

    -- bottom tooltip
    function SWEP:Initialize()
        self:AddTTT2HUDHelp("sopd_instruction")
        return self.BaseClass.Initialize(self)
    end
end

SWEP.Base       = "weapon_tttbase"
SWEP.HoldType   = "melee"
SWEP.ViewModel  = "models/ttt/sopd/v_sopd.mdl"
SWEP.WorldModel = "models/ttt/sopd/w_sopd.mdl"

SWEP.Primary.Damage      = 100
SWEP.Primary.ClipSize    = -1
SWEP.Primary.DefaultClip = -1
SWEP.Primary.Automatic   = true
SWEP.Primary.Delay       = 0.5
SWEP.Primary.Ammo        = "none"

SWEP.Kind         = WEAPON_EQUIP
SWEP.CanBuy       = {ROLE_TRAITOR, ROLE_JACKAL}
SWEP.LimitedStock = !DEBUG
SWEP.WeaponID     = AMMO_KNIFE

SWEP.IsSilent    = true --negated by the noises we Add
SWEP.AllowDrop   = true
SWEP.DeploySpeed = 2

function SWEP:PrimaryAttack()
    self:SetNextPrimaryFire( CurTime() + self.Primary.Delay )

    if not IsValid(self:GetOwner()) then return end
    self:GetOwner():LagCompensation(true)

    local spos = self:GetOwner():GetShootPos()
    local sdest = spos + (self:GetOwner():GetAimVector() * 100 * RANGE_BUFF:GetFloat())

    local kmins = Vector(1,1,1) * -10
    local kmaxs = Vector(1,1,1) * 10

    local tr = util.TraceHull({start=spos, endpos=sdest, filter=self:GetOwner(), mask=MASK_SHOT_HULL, mins=kmins, maxs=kmaxs})

    -- Hull might hit environment stuff that line does not hit
    if not IsValid(tr.Entity) then
        tr = util.TraceLine({start=spos, endpos=sdest, filter=self:GetOwner(), mask=MASK_SHOT_HULL})
    end
    local hitEnt = tr.Entity

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
        self:GetOwner():SetAnimation( PLAYER_ATTACK1 )

        if tr.Hit and tr.HitNonWorld and IsValid(hitEnt) then
            if CanBeSlain(hitEnt) then
                self:StabKill(tr, spos, sdest)
            elseif hitEnt:GetClass() == "prop_ragdoll" and hitEnt:IsPlayerRagdoll() and CanBeSlain(hitEnt.PlyOwner) and swordTargetPlayer then
                self:StabRagdoll(tr, spos, sdest)
            end
        end
    end

    self:GetOwner():LagCompensation(false)
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

    -- damage to killma player
    local dmg = DamageInfo()
    dmg:SetDamage(2000)
    if LEAVE_DNA:GetBool() then
        dmg:SetAttacker(self:GetOwner())
    end
    dmg:SetInflictor(self)
    dmg:SetDamageForce(self:GetOwner():GetAimVector())
    dmg:SetDamagePosition(self:GetOwner():GetPos())
    dmg:SetDamageType(DMG_SLASH)

    -- raycast to get entity hit by sword (which should be a player's limb)
    local retr = util.TraceLine({start=spos, endpos=sdest, filter=self:GetOwner(), mask=MASK_SHOT_HULL})
    if retr.Entity != target then
        local center = target:LocalToWorld(target:OBBCenter())
        retr = util.TraceLine({start=spos, endpos=center, filter=self:GetOwner(), mask=MASK_SHOT_HULL})
    end

    -- create knife effect creation fn
    local bone = retr.PhysicsBone
    local norm = tr.Normal
    local ang = adjStuckSwordAngle(norm)
    local pos = adjStuckSwordPos(retr, ang)
    local ignore = self:GetOwner()

    target.effect_fn = function(rag)
        -- redo raycast from previously hit point (we might find a better location)
        local rtr = util.TraceLine({start=pos, endpos=pos + norm * 40, filter=ignore, mask=MASK_SHOT_HULL})

        if IsValid(rtr.Entity) and rtr.Entity == rag then
            bone = rtr.PhysicsBone
            ang = adjStuckSwordAngle(rtr.Normal)
            pos = adjStuckSwordPos(rtr, ang)
        end

        local stuckSword = ents.Create("prop_physics")
        stuckSword:SetModel("models/ttt/sopd/w_sopd.mdl")
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

        -- play slay noise from stuck sword
        net.Start(SWORD_KILLED_MSG)
        net.WriteEntity(stuckSword)
        net.Broadcast()
        if DEBUG then print("[SWORD_KILLED_MSG] Sent") end
    end

    --dispatch killing attack, trigger sword sticking function & clean up
    target:DispatchTraceAttack(dmg, spos + (self:GetOwner():GetAimVector() * 3), sdest)
    if SND_DEBUG then print("Stopping deploy sound due to stab") end
    StopDeploySound(self)
    self:Remove()
end

function SWEP:StabRagdoll(tr, spos, sdest)
    local hitRagdoll = tr.Entity
    local ang = adjStuckSwordAngle(tr.Normal)
    local pos = adjStuckSwordPos(tr, ang)

    local stuckSword = ents.Create("prop_physics")
    stuckSword:SetModel("models/ttt/sopd/w_sopd.mdl")
    stuckSword:SetPos(pos)
    stuckSword:SetAngles(ang)
    stuckSword:SetCollisionGroup(COLLISION_GROUP_DEBRIS)
    stuckSword.CanPickup = false
    stuckSword:Spawn()

    local phys = stuckSword:GetPhysicsObject()
    if IsValid(phys) then phys:EnableCollisions(false) end

    constraint.Weld(hitRagdoll, stuckSword, tr.PhysicsBone or 0, 0, 0, true)
    hitRagdoll:CallOnRemove("ttt_sword_cleanup", function() SafeRemoveEntity(stuckSword) end)
    if SND_DEBUG then print("Stopping deploy sound due to stab (ragdoll)") end
    StopDeploySound(self)
    self:Remove()
end

function SWEP:SecondaryAttack()
end

function SWEP:Equip()
    self:SetNextPrimaryFire(CurTime() + (self.Primary.Delay * 1.5))
end

function SWEP:PreDrop()
    if SND_DEBUG then print("Stopping deploy sound due to item drop") end
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
    local form = vgui.CreateTTT2Form(parent, "header_equipment_additional")

    form:MakeHelp({
        label = "label_sopd_range_buff_desc"
    })
    form:MakeSlider({
        serverConvar = "ttt2_sopd_range_buff",
        label = "label_sopd_range_buff",
        min = 0.1,
        max = 5,
        decimal = 1
    })

    form:MakeSlider({
        serverConvar = "ttt2_sopd_speedup",
        label = "label_sopd_speedup",
        min = 1,
        max = 5,
        decimal = 1
    })

    form:MakeCheckBox({
        serverConvar = "ttt2_sopd_leave_dna",
        label = "label_sopd_leave_dna"
    })
    form:MakeCheckBox({
        serverConvar = "ttt2_sopd_target_glow",
        label = "label_sopd_target_glow"
    })
    form:MakeCheckBox({
        serverConvar = "ttt2_sopd_can_target_swapper",
        label = "label_sopd_can_target_swapper"
    })

    form:MakeHelp({
        label = "label_sopd_dmg_block_desc"
    })
    form:MakeSlider({
        serverConvar = "ttt2_sopd_target_dmg_block",
        label = "label_sopd_target_dmg_block",
        min = 0,
        max = 100,
        decimal = 0
    })
    form:MakeSlider({
        serverConvar = "ttt2_sopd_others_dmg_block",
        label = "label_sopd_others_dmg_block",
        min = 0,
        max = 100,
        decimal = 0
    })

    form:MakeHelp({
        label = "label_sopd_sfx_desc"
    })
    form:MakeSlider({
        serverConvar = "ttt2_sopd_sfx_deploy_soundlevel",
        label = "label_sopd_sfx_deploy_soundlevel",
        min = 0,
        max = 300,
        decimal = 0
    })
    form:MakeSlider({
        serverConvar = "ttt2_sopd_sfx_deploy_volume",
        label = "label_sopd_sfx_deploy_volume",
        min = 0,
        max = 100,
        decimal = 0
    })
    form:MakeSlider({
        serverConvar = "ttt2_sopd_sfx_kill_volume",
        label = "label_sopd_sfx_kill_volume",
        min = 0,
        max = 100,
        decimal = 0
    })
    form:MakeSlider({
        serverConvar = "ttt2_sopd_sfx_stealth_vol_reduction",
        label = "label_sopd_sfx_stealth_vol_reduction",
        min = 0,
        max = 100,
        decimal = 0
    })
    form:MakeSlider({
        serverConvar = "ttt2_sopd_sfx_stealth_max_opps",
        label = "label_sopd_sfx_stealth_max_opps",
        min = 2,
        max = 24,
        decimal = 0
    })
    form:MakeSlider({
        serverConvar = "ttt2_sopd_sfx_best_triumph_prob",
        label = "label_sopd_best_triumph_prob",
        min = 33,
        max = 100,
        decimal = 0
    })
    form:MakeCheckBox({
        serverConvar = "ttt2_sopd_sfx_oatmeal_for_last",
        label = "label_sopd_sfx_oatmeal_for_last"
    })
end

function SWEP:Deploy()
    if SND_DEBUG then print("Starting deploy sound due to deploy") end
    StartDeploySound(self)
    return true
end

function SWEP:Holster()
    if SND_DEBUG then print("Stopping deploy sound due to holster") end
    StopDeploySound(self)
    return true
end

hook.Add("TTTPlayerSpeedModifier", HOOK_SPEEDMOD, function(ply, _, _, noLag )
    if HoldsSword(ply) then
        if TTT2 then
            noLag[1] = noLag[1] * HOLDER_SPEEDUP:GetFloat()
        else
            return HOLDER_SPEEDUP:GetFloat()
        end
    end
end)