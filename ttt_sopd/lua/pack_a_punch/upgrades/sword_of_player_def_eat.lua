local UPGRADE = {}
UPGRADE.id    = "sword_of_player_def_eat"
UPGRADE.class = CLASS_NAME
UPGRADE.desc  = "Inhale your enemy and make it later! (cannibalism + identity disguise on stab, even if the target is already dead)" -- no way to localize this?
--Note: ID disguise functionality requires Identity Disguiser addon to work

function UPGRADE:Apply(SWEP)
    UPGRADE.name = string.gsub(SWEP.PrintName, "Defeat", "Def-Eat")

    --targetless PaP swords have limited ammo for reasons that should be obvious
    if not swordTargetPlayer then self:SetClip(SWEP, 1) end

    SWEP.Packed = true
    if CLIENT then
        SWEP:AddTTT2HUDHelp("sopd_instruction_pap_lmb")
    end

    function SWEP:PackEffect(rag, owner)
        self.packVictim = rag.PlyOwner
        owner:EmitSound(sounds["inhale"], SNDLVL_150dB, 100, AdjustVolume(KILL_SND_VOLUME:GetFloat()/100), CHAN_VOICE)

        -- delays to line up with suck sfx
        timer.Simple(2, function()
            if IsValid(rag) then
                rag:Remove()
            end
        end)

        -- make it later :)
        timer.Simple(3, function()
            if not IsValid(owner) then return end
            owner:SetHealth(owner:Health() + PAP_HEAL:GetInt())

            if IsValid(self.packVictim) and owner.ActivateDisguiserTarget then
                owner:UpdateStoredDisguiserTarget(self.packVictim, self.packVictim:GetModel(), self.packVictim:GetSkin())
                owner:ActivateDisguiserTarget()

                net.Start(GAINED_DISGUISE_MSG)
                net.Send(owner)
            end
        end)
    end

    function SWEP:SecondaryAttack()
        local owner = self:GetOwner()

        if IsValid(owner) and owner.ToggleDisguiserTarget and IsValid(self.packVictim)
          and owner.storedDisguiserTarget == self.packVictim then
            owner:ToggleDisguiserTarget()
        end
    end
end

if CLIENT then
    net.Receive(GAINED_DISGUISE_MSG, function(msgLen, ply)
        for _, wep in ipairs(LocalPlayer():GetWeapons()) do
            if wep:GetClass() == CLASS_NAME then
                wep:AddTTT2HUDHelp("sopd_instruction_pap_lmb2", "sopd_instruction_pap_rmb")
            end
        end
    end)
end

TTTPAP:Register(UPGRADE)