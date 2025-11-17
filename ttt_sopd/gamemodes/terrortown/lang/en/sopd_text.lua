local L = LANG.GetLanguageTableReference("en")

L["label_sopd_range_buff_desc"] = "Multiplier of the base TTT2 knife's range (1 = same range as knife)."
L["label_sopd_range_buff"] = "Sword range buff"
L["label_sopd_dmg_block_desc"] = "For the below two: 100% = fully block damage from player(s), 0% = no block. Affects shop description."
L["label_sopd_target_dmg_block"] = "Damage resist. from target player while holding sword (%)"
L["label_sopd_others_dmg_block"] = "Damage resist. from other players while holding sword (%)"
L["label_sopd_speedup"] = "Speed multiplier while holding sword"
L["label_sopd_leave_dna"] = "Sword leaves DNA"
L["label_sopd_target_glow"] = "Target glows through walls while holding sword"
L["label_sopd_can_target_swapper"] = "Swapper can be the target"

L["label_sopd_sfx_desc"] = [[Sound & Volume Settings
- You can set the base volume for both sound effect types (deploy and kill), before any stealth-related reductions.
- Deploy song audible range determines how far players can be & still hear it.
- Stealth: If there are n or more opponents (inno/side team members) left alive, the sword's sound effect volumes are reduced by v. For less than n opponents, this effect gets proportionally weaker, going away completely at 1 opponent left. 
  - If v = 0, no reduction occurs. 
  - If v = 1, the sword is silent at n or more opponents alive.
  - Formula: adjVol = vol * (1 - v * min(1, (oppCnt - 1) / (n - 1)))
- Triumph Noise: There are two rarer variants I didn't like as much that can show up.]]
L["label_sopd_sfx_deploy_soundlevel"] = "Sword deploy song audible range (dB)"
L["label_sopd_sfx_deploy_volume"] = "Base sword deploy song volume (%)"
L["label_sopd_sfx_kill_volume"] = "Base sword kill sound volume (%)"
L["label_sopd_sfx_stealth_vol_reduction"] = "[Stealth] v = Max volume reduction (%)"
L["label_sopd_sfx_stealth_max_opps"] = "[Stealth] n = Max reduction minimum opponent count"
L["label_sopd_best_triumph_prob"] = "Probability of playing sopd_triumph_best.mp3 on stab (%)"
L["label_sopd_sfx_oatmeal_for_last"] = "Sword plays \"1, 2, Oatmeal\" for last opponent when deployed"

L["sopd_instruction"] = "Left Click: Defeat"
L["sopd_instantkill"] = "DEFEAT"