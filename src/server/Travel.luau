--!nonstrict
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local Shared = game:GetService("ReplicatedStorage"):WaitForChild("ZoShared")
local Geometry = require(Shared.MapGeometry)
local TravelRules = require(Shared.TravelRules)
local Travel = {}; Travel.__index = Travel
function Travel.new(world, catalog, config, rules, getProfile, notify, resetMovement)
	local self = setmetatable({world=world,catalog=catalog,config=config,rules=rules,getProfile=getProfile,notify=notify,resetMovement=resetMovement,regions={},cooldowns={},warnings={}},Travel)
	for _, plan in world.plans do
		local map = assert(catalog.Maps[plan.Id], "Register every new island in Catalog.Maps before building it")
		assert(plan.Id == "ark" or (map.free ~= true and map.price > 0 and map.pointsPrice > 0), "Additional islands require purchase prices")
		assert(world.checkpoints[map.checkpoint], "Every map needs a registered teleport landing")
		local a,b = plan.Bounds,plan.Source
		local x1,z1=Geometry.world(b,a[1],a[2]); local x2,z2=Geometry.world(b,a[3],a[4])
		if plan.Id~="ark" then table.insert(self.regions,{id=plan.Id,minX=x1-48,minZ=z1-48,maxX=x2+48,maxZ=z2+48}) end
	end
	return self
end
function Travel:mapAt(position) return TravelRules.locate(self.regions,position.X,position.Z) end
function Travel:allowed(player, id)
	local p=self.getProfile(player)
	return p~=nil and self.rules.canAccess(p,id)
end
function Travel:allowedPosition(player, position) return self:allowed(player,self:mapAt(position)) end
function Travel:respawn(profile)
	local id=profile.exploration.activeCheckpoint; local cp=self.catalog.Checkpoints[id]
	return if cp and self.rules.canAccess(profile,cp.mapId) then self.world.checkpoints[id] else nil
end
function Travel:teleport(player,id,currency)
	local p=self.getProfile(player); local character=player.Character
	local h=character and character:FindFirstChildOfClass("Humanoid"); local root=character and character:FindFirstChild("HumanoidRootPart")
	if not p or not h or not root or h.Health<=0 then return false,"Your explorer must be alive to teleport." end
	if h.SeatPart then return false,"Leave the boat before teleporting." end
	local now=os.clock()
	if now<(self.cooldowns[player] or 0) then return false,"Teleport cooling down. Wait a few seconds." end
	local map=self.catalog.Maps[id]; local destination=map and self.world.checkpoints[map.checkpoint]
	if not destination then return false,"That island's landing is unavailable. Nothing was charged." end
	if (root.Position-destination.Position).Magnitude<12 then return false,"You are already at this landing. Nothing was charged." end
	local before={coins=p.coins,points=p.points,passes=p.stock.teleportPass}
	local ok,message=self.rules.payTeleport(p,id,currency)
	if not ok then return false,message end
	-- PivotTo does not yield. Roll back just this debit if the destination fails.
	local moved=pcall(function()
		self.resetMovement(player)
		root.AssemblyLinearVelocity=Vector3.zero; root.AssemblyAngularVelocity=Vector3.zero
		character:PivotTo(destination.CFrame*CFrame.new(0,4,0))
	end)
	if not moved then
		p.coins=before.coins; p.points=before.points; p.stock.teleportPass=before.passes
		return false,"Teleport unavailable. Your payment was returned."
	end
	self.cooldowns[player]=now+self.config.TeleportCooldown
	return true,message
end
function Travel:start()
	local elapsed=0
	RunService.Heartbeat:Connect(function(dt)
		elapsed+=dt; if elapsed<0.2 then return end; elapsed=0
		for _,player in Players:GetPlayers() do
			local p=self.getProfile(player); local c=player.Character
			local root=c and c:FindFirstChild("HumanoidRootPart"); local h=c and c:FindFirstChildOfClass("Humanoid")
			if not p or not root or not h or h.Health<=0 then continue end
			local mapId=self:mapAt(root.Position)
			if not self.rules.canAccess(p,mapId) then
				local seat=h.SeatPart
				h.Sit=false
				local weld=seat and seat:FindFirstChild("SeatWeld")
				if weld and weld:IsA("Weld") and weld.Part1 and weld.Part1:IsDescendantOf(c) then weld:Destroy() end
				self.resetMovement(player)
				root.AssemblyLinearVelocity=Vector3.zero; root.AssemblyAngularVelocity=Vector3.zero
				c:PivotTo(self.world.spawn*CFrame.new(0,4,0)); player.RespawnLocation=self.world.spawnLocation
				if os.clock()>(self.warnings[player] or 0) then
					self.warnings[player]=os.clock()+5
					self.notify(player,"Unlock "..self.catalog.Maps[mapId].name.." in Travel before entering.","travel")
				end
			end
		end
	end)
	Players.PlayerRemoving:Connect(function(player) self.cooldowns[player]=nil; self.warnings[player]=nil end)
end
return Travel
