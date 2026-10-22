--!nonstrict
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local World = require(script.Parent.World)
local TravelRules=require(game:GetService("ReplicatedStorage"):WaitForChild("ZoShared").TravelRules)
local NightRules=require(game:GetService("ReplicatedStorage"):WaitForChild("ZoShared").NightRules)
local FieldKit = {}; FieldKit.__index = FieldKit
function FieldKit.new(world, config, catalog, rules, getProfile, notify, effects)
	return setmetatable({world=world, config=config, catalog=catalog, rules=rules, getProfile=getProfile, notify=notify, effects=effects, access=TravelRules.new(catalog), records={}, traps={}},FieldKit)
end
function FieldKit:record(player)
	if not self.records[player] then self.records[player] = {boostUntil=0,leapUntil=0,scanUntil=0,nextScan=0,nextTrap=0,flashRemaining=0,flashOn=false,visionOn=false,character=player.Character,lastGear=os.clock(),nextDart=0} end
	return self.records[player]
end
function FieldKit:boosted(player) return self:record(player).boostUntil > os.clock() end
function FieldKit:snapshot(player)
	local r=self:record(player); return {boost=math.max(0,r.boostUntil-os.clock()),jump=math.max(0,r.leapUntil-os.clock()),scan=math.max(0,r.scanUntil-os.clock()),flashlight=r.flashRemaining,flashlightOn=r.flashOn,nightVision=r.visionOn,dartCooldown=math.max(0,r.nextDart-os.clock())}
end
function FieldKit:restrain(animal,seconds)
	local now=os.clock()
	animal.snaredUntil=now+seconds; animal.dangerRestraintUntil=now+seconds; animal.fleeUntil=0; animal.restUntil=now+seconds+10
	animal.routeVersion+=1; animal.path={}; animal.waypoint=1; animal.attackAt=0; animal.attackTarget=nil
end
function FieldKit:gearCharacter(r,char)
	if r.character~=char then r.character=char; r.leapUntil=0; r.flashRemaining=0; r.flashOn=false; r.visionOn=false; r.lastGear=os.clock() end
end
function FieldKit:params()
	local p=RaycastParams.new(); p.FilterType=Enum.RaycastFilterType.Exclude; p.IgnoreWater=true; p.RespectCanCollide=true
	local excluded={self.world.actors,self.world.boats}
	for _, player in Players:GetPlayers() do if player.Character then table.insert(excluded,player.Character) end end
	p.FilterDescendantsInstances=excluded; return p
end
function FieldKit:use(player,id)
	local profile=self.getProfile(player); local char=player.Character
	local root=char and char:FindFirstChild("HumanoidRootPart"); local hum=char and char:FindFirstChildOfClass("Humanoid")
	if not profile or not root or not hum or hum.Health<=0 then return false,"Your explorer must be alive." end
	local r=self:record(player); local now=os.clock()
	self:gearCharacter(r,char)
	r.flashRemaining,r.flashOn=NightRules.battery(r.flashRemaining,r.flashOn,now-r.lastGear); r.lastGear=now
	if id=="flashlight" then
		if r.flashOn then r.flashOn=false; return true,"Flashlight off. Remaining battery saved until respawn." end
		if r.flashRemaining<=0 then
			if not self.rules.consume(profile,id) then return false,"Buy a Field Flashlight Cell at Outfitters." end
			r.flashRemaining=self.config.FlashlightSeconds
		end
		r.flashOn=true; r.lastGear=now; return true,"Flashlight on • "..math.ceil(r.flashRemaining).." seconds of battery."
	elseif id=="nightVision" then
		if not profile.owned.nightVision then return false,"Buy Night Vision Goggles at Outfitters first." end
		r.visionOn=not r.visionOn; return true,if r.visionOn then "Night vision enabled. It activates after dark." else "Night vision off."
	elseif id=="tranquilizer" then
		if not profile.owned.tranquilizer then return false,"Buy the Rescue Tranquilizer at Outfitters." end
		if now<r.nextDart then return false,"Tranquilizer cooling down for "..math.ceil(r.nextDart-now).." seconds." end
		local target,distance=nil,self.config.TranquilizerRange
		for _,animal in (self.wildlife and self.wildlife.records or {}) do
			local d=(animal.root.Position-root.Position).Magnitude
			if animal.alive and self.catalog.Species[animal.id].dangerous and self.access.canAccess(profile,animal.zone.mapId or "ark") and now>=(animal.dangerRestraintUntil or 0) and d<=distance and not workspace:Raycast(root.Position,animal.root.Position-root.Position,self:params()) then target=animal; distance=d end
		end
		if not target then return false,"No unrestrained predator in clear view within 35 studs." end
		self:restrain(target,self.config.TranquilizerSeconds); r.nextDart=now+self.config.TranquilizerCooldown
		return true,"Predator sedated for 45 seconds! Approach and hold Rescue."
	elseif id=="jumpBoost" then
		if r.leapUntil>now then return false,"Your Trail Leap is already active." end
		if hum.SeatPart or hum.FloorMaterial==Enum.Material.Air or World.inWater(root.Position) then return false,"Activate Trail Leap while standing on land, outside a boat." end
		if not self.rules.consume(profile,id) then return false,"Buy a Trail Leap at Outfitters first." end
		r.leapUntil=now+self.config.JumpBoostSeconds
		hum.UseJumpPower=false; hum.JumpHeight=self.config.JumpBoostHeight
		return true,"Trail Leap active for 45 seconds! Jump to clear campus walls."
	elseif id=="speedBoost" then
		if r.boostUntil>now then return false,"Your sprint is already active." end
		if not self.rules.consume(profile,id) then return false,"Buy or find an Expedition Sprint first." end
		r.boostUntil=now+self.config.BoostSeconds; return true,"Sprint boost active for 45 seconds!"
	elseif id=="tracker" then
		if not profile.owned.tracker then return false,"You need a Wildlife Scanner." end
		if now<r.nextScan then return false,"Scanner cooling down. Try again shortly." end
		r.scanUntil=now+self.config.ScanSeconds; r.nextScan=now+30; return true,"Scanner active: follow the nearby wildlife signals."
	elseif id=="animalTrap" or id=="predatorTrap" then
		local predator=id=="predatorTrap"
		if now<r.nextTrap then return false,"Wait a moment before placing another snare." end
		local count=0; for _, t in self.traps do if t.owner==player then count+=1 end end
		if count>=2 then return false,"You can place two snares at a time." end
		if hum.SeatPart or World.inWater(root.Position) then return false,"Place snares on dry land." end
		local position=root.Position+root.CFrame.LookVector*6
		if workspace:Raycast(root.Position,position-root.Position,self:params()) then return false,"Find a clear spot in front of you." end
		local hit=workspace:Raycast(position,Vector3.new(0,-8,0),self:params())
		if not hit or hit.Normal.Y<0.8 or hit.Position.Y<4 then return false,"Place a snare on level dry ground." end
		if not self.rules.consume(profile,id) then return false,"Buy or find "..self.catalog.Items[id].name.." first." end
		local model=Instance.new("Model"); model.Name="GentleAnimalSnare"; model.Parent=self.world.actors
		local spot=hit.Position+Vector3.new(0,0.25,0)
		local base=self.world.part(model,"SnarePad",Vector3.new(5,0.25,5),CFrame.new(spot),Color3.fromRGB(145,232,191),Enum.Material.Fabric)
		base.CanCollide=false; base.CanQuery=false
		for _, x in {-2,2} do
			local pole=self.world.part(model,"SnarePole",Vector3.new(0.22,3.5,0.22),CFrame.new(spot+Vector3.new(x,1.75,0)),Color3.fromRGB(205,167,112))
			pole.CanCollide=false; pole.CanQuery=false; pole.CanTouch=false
		end
		for i=1,12 do
			local angle=i*math.pi/6
			local rope=self.world.part(model,"SoftRopeLoop",Vector3.new(0.14,0.14,0.3),CFrame.new(spot+Vector3.new(math.cos(angle)*1.6,1.8+math.sin(angle)*1.6,0)),Color3.fromRGB(255,207,116))
			rope.CanCollide=false; rope.CanQuery=false; rope.CanTouch=false
		end
		local caption=self.world.label(base,if predator then "PREDATOR RESCUE SNARE\n3 minutes • dangerous land animals" else "GENTLE SNARE\n45 seconds • land animals",3,250)
		if predator then base.Color=Color3.fromRGB(255,157,65) end
		table.insert(self.traps,{owner=player,model=model,position=spot,expires=now+(if predator then self.config.PredatorTrapSeconds else self.config.TrapSeconds),caption=caption,predator=predator})
		r.nextTrap=now+1; return true,"Snare placed! Lure a land animal close, then rescue it."
	end
	return false,"Unknown field-kit action."
end
function FieldKit:appearance(player, profile, character)
	if profile.wardrobe.hat and not character:FindFirstChild("Head") then return end
	local signature=(profile.wardrobe.hat or "")..":"..(profile.wardrobe.trail or "")
	if character:GetAttribute("ZoStyleSignature")==signature then return end
	character:SetAttribute("ZoStyleSignature",signature)
	local old=character:FindFirstChild("ZoCosmetics"); if old then old:Destroy() end
	local folder=Instance.new("Folder"); folder.Name="ZoCosmetics"; folder.Parent=character
	local head=character:FindFirstChild("Head"); local root=character:FindFirstChild("HumanoidRootPart")
	if head and profile.wardrobe.hat=="safariHat" then
		for _, spec in {{Vector3.new(3.3,0.2,3),0.65},{Vector3.new(1.8,0.9,1.7),1.1},{Vector3.new(1.9,0.18,1.8),0.8}} do
			local part=self.world.part(folder,"RangerHat",spec[1],head.CFrame*CFrame.new(0,spec[2],0),if spec[2]==0.8 then Color3.fromRGB(145,232,191) else Color3.fromRGB(205,167,112))
			part.Anchored=false; part.Massless=true; part.CanCollide=false; part.CanQuery=false; part.CanTouch=false
			local weld=Instance.new("WeldConstraint"); weld.Part0=head; weld.Part1=part; weld.Parent=part
		end
	end
	if root and profile.wardrobe.trail=="mintTrail" then
		local a=Instance.new("Attachment"); a.Position=Vector3.new(-0.6,-1,0); a.Parent=root
		local b=Instance.new("Attachment"); b.Position=Vector3.new(0.6,-1,0); b.Parent=root
		-- Attachments must live on the body; destroy them with this style folder.
		folder.Destroying:Connect(function() a:Destroy(); b:Destroy() end)
		local trail=Instance.new("Trail"); trail.Attachment0=a; trail.Attachment1=b; trail.Lifetime=0.65; trail.MinLength=0.15
		trail.Color=ColorSequence.new(Color3.fromRGB(145,232,191),Color3.fromRGB(255,207,116)); trail.Transparency=NumberSequence.new(0.2,1); trail.Parent=folder
	end
end
function FieldKit:start(wildlife)
	self.wildlife=wildlife
	local elapsed,scanElapsed=0,0
	RunService.Heartbeat:Connect(function(dt)
		elapsed+=dt; scanElapsed+=dt; if elapsed<0.2 then return end; elapsed=0
		local now=os.clock()
		for _, player in Players:GetPlayers() do
			local p=self.getProfile(player); local c=player.Character; local h=c and c:FindFirstChildOfClass("Humanoid"); local root=c and c:FindFirstChild("HumanoidRootPart")
			if not p or not h or not root or h.Health<=0 then continue end
			local r=self:record(player); self:gearCharacter(r,c)
			r.flashRemaining,r.flashOn=NightRules.battery(r.flashRemaining,r.flashOn,now-r.lastGear); r.lastGear=now
			c:SetAttribute("ZoFlashlightRemaining",math.ceil(r.flashRemaining)); c:SetAttribute("ZoFlashlightOn",r.flashOn); c:SetAttribute("ZoNightVisionOn",r.visionOn)
			local boost=math.max(0,r.boostUntil-now)
			local speed=if boost>0 then (if h:GetState()==Enum.HumanoidStateType.Swimming then self.config.BoostSwimSpeed else self.config.BoostWalkSpeed) else 18
			if h.WalkSpeed~=speed then h.WalkSpeed=speed end
			local jump=math.max(0,r.leapUntil-now)
			local height=if jump>0 then self.config.JumpBoostHeight else self.config.JumpHeight
			h.UseJumpPower=false; if h.JumpHeight~=height then h.JumpHeight=height end
			c:SetAttribute("ZoJumpRemaining",math.ceil(jump))
			c:SetAttribute("ZoBoostRemaining",math.ceil(boost)); self:appearance(player,p,c)
			if scanElapsed>=1 and now<r.scanUntil then
				local targets={}
				for _, animal in wildlife.records do
					local distance=(animal.root.Position-root.Position).Magnitude
					if animal.alive and self.access.canAccess(p,animal.zone.mapId or "ark") and distance<=self.config.ScanRadius then table.insert(targets,{position=animal.root.Position,name=self.catalog.Species[animal.id].name,distance=distance,model=animal.model}) end
				end
				table.sort(targets,function(a,b) return a.distance<b.distance end)
				while #targets>6 do table.remove(targets) end
				self.effects:FireClient(player,{kind="scan",targets=targets})
			end
		end
		if scanElapsed>=1 then scanElapsed=0 end
		for i=#self.traps,1,-1 do
			local trap=self.traps[i]
			if now>=trap.expires or not self.getProfile(trap.owner) or (trap.animal and not trap.animal.alive) then trap.model:Destroy(); table.remove(self.traps,i); continue end
			for _, animal in wildlife.records do
				local dangerous=self.catalog.Species[animal.id].dangerous==true
				if animal.alive and dangerous==trap.predator and not animal.zone.marine and (animal.flightHeight or 0)<1 and (animal.snaredUntil or 0)<=now and (animal.position-trap.position).Magnitude<=8 and not workspace:Raycast(trap.position+Vector3.new(0,1,0),animal.root.Position-trap.position-Vector3.new(0,1,0),self:params()) then
					local seconds=if trap.predator then self.config.PredatorHoldSeconds else self.config.SnareSeconds
					self:restrain(animal,seconds)
					trap.caption.Text="ANIMAL HELD\nRescue within "..seconds.." seconds!"; trap.expires=now+seconds
					-- One animal per consumable; its snare stays visible until release.
					trap.spent=true; trap.animal=animal; self.notify(trap.owner,if trap.predator then "Predator restrained for 3 minutes! Rescue it before dawn." else "Your gentle snare caught an animal! Rescue it quickly.","success"); break
				end
			end
			if trap.spent then trap.position=Vector3.new(100000,0,100000) end
		end
	end)
	Players.PlayerRemoving:Connect(function(player) self.records[player]=nil end)
end
return FieldKit
