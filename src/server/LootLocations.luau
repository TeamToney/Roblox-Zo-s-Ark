--!nonstrict
local Players=game:GetService("Players")
local Shared=game:GetService("ReplicatedStorage"):WaitForChild("ZoShared")
local Geometry=require(Shared.MapGeometry)
local Locations=require(Shared.EncounterLocations)
local World=require(script.Parent.World)
local LootLocations={}; LootLocations.__index=LootLocations
function LootLocations.new(world,catalog)
	local self=setmetatable({world=world,catalog=catalog,random=Random.new(),records={}},LootLocations)
	world.lootRecords=self.records
	return self
end
function LootLocations:observed(position)
	for _,player in Players:GetPlayers() do
		local root=player.Character and player.Character:FindFirstChild("HumanoidRootPart")
		if root and (root.Position-position).Magnitude<self.world.config.LootObserverDistance then return true end
	end
	return false
end
function LootLocations:position(spot,previous,oldKey)
	if not spot.plan then return nil end
	local plan=spot.plan
	local regions=Locations.order(Locations.lootRegions(plan,self.catalog,spot,Geometry),oldKey,self.random:NextNumber())
	for index,region in regions do
		if index>12 then break end
		local r=region.rect
		local x1,z1=Geometry.world(plan.Source,r[1],r[2]); local x2,z2=Geometry.world(plan.Source,r[3],r[4])
		local zone={marine=region.marine,center=Vector3.new((x1+x2)/2,if region.marine then plan.WaterY else plan.FloorY,(z1+z2)/2),bounds={minX=x1,maxX=x2,minZ=z1,maxZ=z2}}
		local separation=math.min(24,math.max(6,math.min(x2-x1,z2-z1)*0.25))
		local point=World.sample(self.world,zone,self.random,0.75,previous or spot.position,separation)
		if not point or self:observed(point) then continue end
		if region.marine and not World.inWater(point) then continue end
		local clear=true
		for _,entry in self.records do if entry.spot~=spot and (entry.box.Position-point).Magnitude<18 then clear=false; break end end
		for _,cp in self.world.checkpointSpots do if (cp.position-point).Magnitude<16 then clear=false; break end end
		if (point-self.world.spawn.Position).Magnitude<40 or (point-self.world.hub).Magnitude<60 then clear=false end
		for _,boat in self.world.boats:GetChildren() do if boat:IsA("Model") and (boat:GetPivot().Position-point).Magnitude<20 then clear=false; break end end
		local source=plan.Source
		local px=(point.X-(source.offsetX or 0))/source.scale+source.pivotX
		local py=(point.Z-(source.offsetZ or 0))/source.scale+source.pivotY
		for _,path in plan.Corridors do if Geometry.contains(path,px,py,-3/source.scale) then clear=false; break end end
		if clear then return point,region.key end
	end
	return nil
end
function LootLocations:add(entry)
	entry.nextMove=os.clock()+self.world.config.LootMoveSeconds
	table.insert(self.records,entry)
end
function LootLocations:start()
	if #self.records==0 then return end
	task.spawn(function()
		while self.world.runtime.Parent do
			for _,entry in self.records do
				task.wait(1)
				if not self.world.runtime.Parent then return end
				if not entry.model.Parent then continue end
				local now=os.clock()
				if not Locations.ready(now,entry.nextMove,entry.animating,self:observed(entry.box.Position)) then continue end
				local point,key=self:position(entry.spot,entry.box.Position-Vector3.new(0,1.6,0),entry.region)
				if point then
					entry.model:PivotTo(CFrame.new(point+Vector3.new(0,1.6,0))*CFrame.Angles(0,self.random:NextNumber(0,math.pi*2),0))
					entry.region=key; entry.nextMove=now+self.world.config.LootMoveSeconds
				else entry.nextMove=now+15 end
			end
		end
	end)
end
return LootLocations
