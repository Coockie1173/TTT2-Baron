---
-- Baron Hat Item
-- Free item for Baron role - provides crush/physgun protection only (no headshot protection)

if SERVER then
	AddCSLuaFile()
end

ITEM.CanBuy = {ROLE_BARON}
ITEM.Free = true
ITEM.Rebuyable = true

if CLIENT then
	ITEM.EquipMenuData = {
		type = "item_active",
		name = "item_baron_hat",
		desc = "item_baron_hat_desc"
	}
	ITEM.material = "vgui/ttt/dynamic/roles/icon_baron"
else
	function ITEM:Equip(buyer)
		if not IsValid(buyer.baron_hat) then
			local hat = ents.Create("ttt2_hat_baron")
			if not IsValid(hat) then return end
			hat:WearHat(buyer)
			hat:Spawn()
		end
	end


	function ITEM:Reset(buyer)

	end

	function ITEM:Restore(buyer)
		if not IsValid(buyer.baron_hat) then
			local hat = ents.Create("ttt2_hat_baron")
			if not IsValid(hat) then return end
			hat:WearHat(buyer)
			hat:Spawn()
		end
	end

	hook.Add("DoPlayerDeath", "TTT2BaronHatRemoveOnDeath", function(ply, attacker, dmginfo)
		if IsValid(ply.baron_hat) then
			ply.baron_hat:Drop(dmginfo:GetDamageForce())
		end
	end)
end
