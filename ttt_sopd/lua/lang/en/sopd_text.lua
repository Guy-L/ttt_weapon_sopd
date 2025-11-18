local L = LANG.GetLanguageTableReference("en")

L["sopd_instruction"] = "Defeat"
L["sopd_instruction_pap"] = "Toggle copy ability (disguise)"
L["sopd_instantkill"] = "DEFEAT"


L["label_sopd_main_form"] = "General Gameplay"
L["label_sopd_range_buff_desc"] = "Multiplier of the base TTT2 knife's range (1 = same range as knife)."
L["label_sopd_range_buff"] = "Sword range buff"
L["label_sopd_dmg_block_desc"] = "For the below two: 100% = fully block damage from player(s), 0% = no block. Affects shop description."
L["label_sopd_target_dmg_block"] = "Damage resist. from target player while holding sword (%)"
L["label_sopd_others_dmg_block"] = "Damage resist. from other players while holding sword (%)"
L["label_sopd_speedup"] = "Speed multiplier while holding sword"
L["label_sopd_leave_dna"] = "Sword leaves DNA"
L["label_sopd_target_glow"] = "Target glows through walls while holding sword"
L["label_sopd_can_target_jesters"] = "Jesters can be the target"

L["label_sopd_pap_form"] = "Pack a Punch"
L["label_sopd_pap_heal"] = "Heal from inhaling enemy"
L["label_sopd_pap_dmg_block_desc"] = "Similar to (and adds to) the two damage resist. options in General Gameplay, but from any player and only if PaP'd."
L["label_sopd_pap_dmg_block"] = "Damage resist. from players while holding sword (%)"

L["label_sopd_sfx_form"] = "Sound & Volume"
L["label_sopd_sfx_deploy_soundlevel_desc"] = "Determines how far players can be & still hear the sword deploy song (100 or more covers most of any map)."
L["label_sopd_sfx_deploy_soundlevel"] = "Sword deploy song audible range (dB)"
L["label_sopd_sfx_volume_desc"] = "Base volume for both sound effect types before any stealth-related reductions."
L["label_sopd_sfx_deploy_volume"] = "Base sword deploy song volume (%)"
L["label_sopd_sfx_kill_volume"] = "Base sword kill sound volume (%)"
L["label_sopd_sfx_oatmeal_for_last"] = "Sword plays \"1, 2, Oatmeal\" when deployed with only one opponent left"
L["label_sopd_sfx_stealth_desc"] = [[
Stealth: If there are n or more opponents (inno/side team members) left alive, the sword's sound effect volumes are reduced by v. For less than n opponents, this effect gets proportionally weaker, going away completely at 1 opponent left. 
  - If v = 0, no reduction occurs. 
  - If v = 1, the sword is silent at n or more opponents alive.
  - Formula: adjVol = vol * (1 - v * min(1, (oppCnt - 1) / (n - 1)))]]
L["label_sopd_sfx_stealth_vol_reduction"] = "[Stealth] v = Max volume reduction (%)"
L["label_sopd_sfx_stealth_max_opps"] = "[Stealth] n = Max reduction minimum opponent count"

L["label_sopd_misc_form"] = "Debugging & Miscellaneous"
L["label_sopd_best_triumph_prob_desc"] = "Two other rarer variants I didn't like as much can show up."
L["label_sopd_best_triumph_prob"] = "Probability of playing sopd_triumph_best.mp3 on stab (%)"
L["label_sopd_give_guy_access"] = "Allow author to change Sword of Player Defeat convars"
L["label_sopd_debug"] = "Enable debug prints (+ rebuyable sword)"