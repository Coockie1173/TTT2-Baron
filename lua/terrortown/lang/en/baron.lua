local L = LANG.GetLanguageTableReference("en")

L[BARON.name] = "Baron"
L[BARON.defaultTeam] = "The Baron"
L["hilite_win_" .. BARON.defaultTeam] = "THE BARON WON"
L["win_" .. BARON.defaultTeam] = "THE BARON WON"
L["info_popup_" .. BARON.name] = "Baron, you stand alone. Kill them all before you run out of lives!"
L["body_found_" .. BARON.abbr] = "They were the Baron!"
L["search_role_" .. BARON.abbr] = "This person was the Baron."
L["ev_win_" .. BARON.defaultTeam] = "The baron has won the round!"
L["target_" .. BARON.name] = "Baron"
L["ttt2_desc_" .. BARON.name] = [[The Baron needs to kill every player to win, without running out of lives.]]

-- Baron Hat Item
L["item_baron_hat"] = "Baron Hat"
L["item_baron_hat_desc"] = "A protective hat that shields you from crush and physgun damage. Headshots will still penetrate."
L["item_baron_hat_pickup"] = "Press {usekey} to wear the hat"
L["item_baron_hat_retrieve"] = "You are now wearing the Baron Hat. It will absorb crush and physgun damage."