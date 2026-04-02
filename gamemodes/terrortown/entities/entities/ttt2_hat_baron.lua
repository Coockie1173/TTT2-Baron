---
-- @class ENT
-- @section ttt2_hat_baron

AddCSLuaFile()

ENT.Type = "anim"
ENT.Base = "base_anim"

ENT.PrintName = "item_baron_hat"
ENT.Model = Model("models/baron/baron_helmet.mdl")
ENT.CanHavePrints = true
ENT.CanUseKey = true

ENT.LossSounds = {
	Sound("tttbaron/hat_drop.wav"),
}
ENT.EquipSounds = {
	Sound("tttbaron/hat_equip.wav"),
}

function ENT:PlaySound(tbl)
	local snd = tbl[ math.random(#tbl) ]
	sound.Play(snd, self:GetPos())
end

---
-- @realm shared
function ENT:SetupDataTables()
	self:NetworkVar("Bool", 0, "BeingWorn")
end

---
-- @realm shared
function ENT:Initialize()
	self:SetModel(self.Model)

	self:DrawShadow(false)

	self:AddEffects(bit.bor(EF_BONEMERGE, EF_BONEMERGE_FASTCULL, EF_PARENT_ANIMATES))

	self.fingerprints = self.fingerprints or {}
end

if CLIENT then
	net.Receive("item_ttt2_baron_hat_equip", function(len, ply)
		local ent = net.ReadEntity()
		local state = net.ReadBool()
		if IsValid(ent) and ent.PlaySound then
			if state then
				ent:PlaySound(ent.EquipSounds)
			else
				ent:PlaySound(ent.LossSounds)
			end
		end
	end)

	local key_params = {
		usekey = Key("+use", "USE"),
	}

	hook.Add("TTTRenderEntityInfo", "HUDDrawTargetIDBaronHat", function(tData)
		local client = LocalPlayer()
		local ent = tData:GetEntity()

		if not IsValid(client) or not client:IsTerror() or not client:Alive()
		or not IsValid(ent) or tData:GetEntityDistance() > 100 or ent:GetClass() ~= "ttt2_hat_baron" then
			return
		end

		tData:EnableText()
		tData:EnableOutline()
		tData:SetOutlineColor(client:GetRoleColor())
		tData:SetKey(input.GetKeyCode(key_params.usekey))

		tData:SetTitle(LANG.TryTranslation("item_baron_hat"))
		tData:SetSubtitle(LANG.GetParamTranslation("item_baron_hat_pickup", key_params))
	end)

end

if SERVER then
	util.AddNetworkString("item_ttt2_baron_hat_equip")

	function ENT:NetSound(state)
		net.Start("item_ttt2_baron_hat_equip")
		net.WriteEntity(self)
		net.WriteBool(state)
		net.Broadcast()
	end

	function ENT:WearHat(ply)
		self.fingerprints = self.fingerprints or {}
		if not table.HasValue(self.fingerprints, ply) then
			self.fingerprints[#self.fingerprints + 1] = ply
		end

		self:NetSound(true)

		local bottom, top = ply:GetHull()
		local size = top - bottom

		self:SetParent(ply)
		local bone = ply:LookupBone("ValveBiped.Bip01_Head1")
		if bone then
			local pos, ang = ply:GetBonePosition(bone)
			self:SetPos(pos)
			self:SetAngles(ang)
		else
			self:SetPos(ply:GetPos() + Vector(0, 0, size.z))
			self:SetAngles(ply:GetAngles())
		end

		self:SetMoveType(MOVETYPE_NONE)
		self:SetSolid(SOLID_NONE)
		self:SetCollisionGroup(COLLISION_GROUP_DEBRIS)

		self:SetParent(ply)
		self.Wearer = ply

		ply.baron_hat = self

		self:SetBeingWorn(true)

		if not ply:HasEquipmentItem("item_ttt2_baron_hat") then
			ply:GiveEquipmentItem("item_ttt2_baron_hat")
		end
	end

	---
	-- @realm server
	function ENT:OnRemove()
		if IsValid(self.Wearer) and self.Wearer:HasEquipmentItem("item_ttt2_baron_hat") then
			self.Wearer:RemoveEquipmentItem("item_ttt2_baron_hat")
		end

		self:SetBeingWorn(false)
	end

	---
	-- @param Vector dir The drop direction.
	-- @realm server
	function ENT:Drop(dir)
		local ply = self:GetParent()

		ply.baron_hat = nil
		self.Wearer = nil
		self:SetParent(nil)

		self:SetBeingWorn(false)
		self:SetUseType(SIMPLE_USE)

		self:PhysicsInit(SOLID_VPHYSICS)
		self:SetSolid(SOLID_VPHYSICS)
		self:SetMoveType(MOVETYPE_VPHYSICS)

		if IsValid(ply) then
			self:NetSound(false)

			if ply:HasEquipmentItem("item_ttt2_baron_hat") then
				ply:RemoveEquipmentItem("item_ttt2_baron_hat")
			end

			local bone = ply:LookupBone("ValveBiped.Bip01_Head1")
			if bone then
				local pos, ang = ply:GetBonePosition(bone)
				self:SetPos(pos)
				self:SetAngles(ang)
			else
				local pos = ply:GetPos()
				pos.z = pos.z + 68

				self:SetPos(pos)
			end
		end

		local phys = self:GetPhysicsObject()
		if IsValid(phys) then
			phys:SetMass(10)

			if IsValid(ply) then
				phys:SetVelocityInstantaneous(ply:GetVelocity())
			end

			if not dir then
				phys:ApplyForceCenter(Vector(0, 0, 1200))
			else
				phys:ApplyForceCenter(Vector(0, 0, 700) + dir * 500)
			end

			phys:AddAngleVelocity(VectorRand() * 200)

			phys:Wake()
		end
	end

	---
	-- @param Player ply
	-- @realm server
	function ENT:UseOverride(ply)
		if IsValid(ply) and not self:GetBeingWorn() then
			if GetRoundState() ~= ROUND_ACTIVE then
				SafeRemoveEntity(self)
				return
			elseif IsValid(ply.baron_hat) then
				return
			end

			self:WearHat(ply)

			LANG.Msg(ply, "item_baron_hat_retrieve")
		end
	end
end
