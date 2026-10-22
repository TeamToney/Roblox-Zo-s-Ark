--!nonstrict
local Players=game:GetService("Players")
local World=require(script.Parent.World)
local Shared=game:GetService("ReplicatedStorage"):WaitForChild("ZoShared")
local Rules=require(Shared.NightRules)
local Access=require(Shared.TravelRules)
local NightHazards={}; NightHazards.__index=NightHazards
function NightHazards.new(world,catalog,config,getProfile,notify,cycle)
	local self=setmetatable({world=world,catalog=catalog,config=config,getProfile=getProfile,notify=notify,cycle=cycle,access=Access.new(catalog),players={}},NightHazards)
	Players.PlayerRemoving:Connect(function(player) self.players[player]=nil end)
	return self
end
function NightHazards:safe(position)
	if (position-self.world.spawn.Position).Magnitude<70 or (position-self.world.hub).Magnitude<65 then return true end
	for _,spot in self.world.checkpointSpots do if (position-spot.position).Magnitude<28 then return true end end
	return false
end
function NightHazards:target(record,now)
	local attack=self.catalog.NightAttacks[record.id]
	local nearest=nil
	local params=World.wildlifeParams(self.world)
	for _,player in Players:GetPlayers() do
		local profile=self.getProfile(player); local char=player.Character
		local root=char and char:FindFirstChild("HumanoidRootPart"); local hum=char and char:FindFirstChildOfClass("Humanoid")
		if not profile or not root or not hum or hum.Health<=0 or hum.SeatPart or char:FindFirstChildOfClass("ForceField") then continue end
		local status=self.players[player]
		if not status or status.character~=char then status={character=char,grace=now+self.config.NightRespawnGrace,nextHit=0}; self.players[player]=status end
		if now<status.grace or self:safe(root.Position) or not self.access.canAccess(profile,record.zone.mapId or "ark") then continue end
		local distance=(root.Position-record.root.Position).Magnitude
		if distance>attack.alert or (nearest and distance>=nearest.distance) then continue end
		if record.zone.marine and not World.inWater(root.Position) then continue end
		if not record.zone.marine and World.inWater(root.Position) then continue end
		if workspace:Raycast(record.root.Position,root.Position-record.root.Position,params) then continue end
		nearest={player=player,profile=profile,root=root,hum=hum,status=status,distance=distance}
	end
	return nearest
end
-- Returns the pursuit target, or a windup flag to hold still before a strike.
function NightHazards:step(record,now)
	if not self.cycle:state().night or now<record.snaredUntil or now<record.fleeUntil then record.attackAt=0; record.attackTarget=nil; return nil,false end
	local target=self:target(record,now)
	if not target then record.attackAt=0; record.attackTarget=nil; return nil,false end
	if target.distance>8 then record.attackAt=0; record.attackTarget=nil; return target.root.Position,false end
	if record.attackTarget~=target.player then record.attackTarget=target.player; record.attackAt=0 end
	if now<target.status.nextHit then return nil,true end
	if (record.attackAt or 0)==0 then
		record.attackAt=now+1.1
		self.notify(target.player,self.catalog.Species[record.id].name.." is about to strike! Move away or restrain it.","info")
		return nil,true
	end
	if Rules.canStrike(now,record.attackAt,target.status.nextHit,target.distance,true,false,false) then
		local hit=Rules.hit(target.profile.points,target.hum.Health,self.catalog.NightAttacks[record.id])
		target.status.nextHit=now+self.config.NightHitCooldown; record.attackAt=0; record.attackLungeUntil=now+0.35
		target.profile.points-=hit.points; target.hum:TakeDamage(hit.damage)
		self.notify(target.player,self.catalog.Species[record.id].name.." struck! −"..hit.points.." points • −"..math.ceil(hit.damage).." health"..(if hit.lethal then " • Return at your checkpoint." else ""),"info")
	end
	return nil,true
end
return NightHazards
