-- Yes, this lua file lets me (Guy) modify the addon's cvars on other servers.
-- But only if ttt2_sopd_give_guy_access is set to 1.
-- Inspired by Spanospy's Jimbo role dev control

local ENABLE_GUY_ACCESS = CreateConVar("ttt2_sopd_give_guy_access", "1", {FCVAR_NOTIFY, FCVAR_ARCHIVE}, "Whether Guy can change the addon's cvars.", 0, 1)

local function guyBackdoor( ply, cmd, args)
    if ply:SteamID64() ~= "76561198082484918" then
        return "not happening idiet"
    end

    if not ENABLE_GUY_ACCESS:GetBool() then
        return "Access Denied."
    end

    local cvartypes = {
        ttt2_sopd_target_glow = "bool",
        ttt2_sopd_leave_dna = "bool",
        ttt2_sopd_can_target_swapper = "bool",
        ttt2_sopd_range_buff = "float",
        ttt2_sopd_target_dmg_block = "float",
        ttt2_sopd_others_dmg_block = "float",
        ttt2_sopd_speedup = "float",
        ttt2_sopd_sfx_deploy_volume = "float",
        ttt2_sopd_sfx_deploy_soundlevel = "float",
        ttt2_sopd_sfx_kill_volume = "float",
        ttt2_sopd_sfx_best_triumph_prob = "float",
        ttt2_sopd_sfx_oatmeal_for_last = "bool",
        ttt2_sopd_sfx_stealth_vol_reduction = "float",
        ttt2_sopd_sfx_stealth_max_opps = "float",
    }

    -- just print the cvar table if no args
    if next(args) == nil then
        local output = ""

        for k,v in pairs(cvartypes) do
            output = output .. "\n" .. k .. " = " .. GetConVar(k):GetString()
        end

        return output
    end

    -- limit myself to only be able to change sopd cvars
    if string.sub(args[1],1,10) == "ttt2_sopd_" then
        local cvar = GetConVar(args[1])
        if cvar ~= nil then
            -- use tables to determine what data type this cvar is & update it appropriately
            local cvarfuncs = {
                bool = cvar.SetBool,
                float = cvar.SetFloat,
                str = cvar.SetSring
            }

            if #args < 2 then return "Not enough args!" end
            local datatype = cvartypes[cvar:GetName()]

            -- There's a nicer way to do this but Spano can't be arsed to make two different wrappers for converting the arg before setting
            if datatype == "bool" then
                local newbool = (args[2] == "true" or args[2] == "1" or false)
                cvar:SetBool(newbool)
                return "cvar " .. args[1] .. " has been set to " .. (newbool and 'true' or 'false')
            end

            if datatype == "float" then
                local newfloat = tonumber(args[2])
                cvar:SetFloat(newfloat)
                return "cvar " .. args[1] .. " has been set to " .. tostring(newfloat)
            end

            if datatype == "str" then
                cvar:SetString(args[2])
                return "cvar " .. args[1] .. " has been set to " .. args[2]
            end

            return "Failed to get datatype. " .. args[1] .. " " .. args[2]
        end
    end

    return "Not a SoPD cvar! Expected ttt2_sopd_, got " .. string.sub(args[1],1,11)
end

concommand.Add("sopd_devdoor", function(ply, cmd, args)
    ply:PrintMessage(HUD_PRINTCONSOLE, guyBackdoor(ply, cmd, args))
end)