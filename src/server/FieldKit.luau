--!nonstrict
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local World = require(script.Parent.World)
local TravelRules=require(game:GetService("ReplicatedStorage"):WaitForChild("ZoShared").TravelRules)
local FieldKit = {}; FieldKit.__index = FieldKit
function FieldKit.new(world, config, catalog, rules, getProfile, notify, effects)
	return setmetatable({world=world, config=config, catalog=catalog, rules=rules, getProfile=getProfile, notify=notify, effects=effects, access=TravelRules.new(catalog), records={}, traps={}},FieldKit)
end
function FieldKit:record(player)
	if not self.records[player] then self.records[player] = {boostUntil=0,scanUntil=0,nextScan=0,nextTrap=0} end
	return self.records[player]
end
function FieldKit:boosted(player) return self:record(player).boostUntil > os.clock() end
function FieldKit:snapshot(player)
	local r=self:record(player); return {boost=math.max(0,r.boostUntil-os.clock()),scan=math.max(0,r.scanUntil-os.clock())}
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
	if id=="speedBoost" then
		if r.boostUntil>now then return false,"Your sprint is already active." end
		if not self.rules.consume(profile,id) then return false,"Buy or find an Expedition Sprint first." end
		r.boostUntil=now+self.config.BoostSeconds; return true,"Sprint boost active for 45 seconds!"
	elseif id=="tracker" then
		if not profile.owned.tracker then return false,"You need a Wildlife Scanner." end
		if now<r.nextScan then return false,"Scanner cooling down. Try again shortly." end
		r.scanUntil=now+self.config.ScanSeconds; r.nextScan=now+30; return true,"Scanner active: follow the nearby wildlife signals."
	elseif id=="animalTrap" then
		if now<r.nextTrap then return false,"Wait a moment before placing another snare." end
		local count=0; for _, t in self.traps do if t.owner==player then count+=1 end end
		if count>=2 then return false,"You can place two snares at a time." end
		if hum.SeatPart or World.inWater(root.Position) then return false,"Place snares on dry land." end
		local position=root.Position+root.CFrame.LookVector*6
		if workspace:Raycast(root.Position,position-root.Position,self:params()) then return false,"Find a clear spot in front of you." end
		local hit=workspace:Raycast(position,Vector3.new(0,-8,0),self:params())
		if not hit or hit.Normal.Y<0.8 or hit.Position.Y<4 then return false,"Place a snare on level dry ground." end
		if not self.rules.consume(profile,id) then return false,"Buy or find a Gentle Animal Snare first." end
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
		local caption=self.world.label(base,"GENTLE SNARE\n45 seconds • land animals",3,220)
		table.insert(self.traps,{owner=player,model=model,position=spot,expires=now+self.config.TrapSeconds,caption=caption})
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
	local elapsed,scanElapsed=0,0
	RunService.Heartbeat:Connect(function(dt)
		elapsed+=dt; scanElapsed+=dt; if elapsed<0.2 then return end; elapsed=0
		local now=os.clock()
		for _, player in Players:GetPlayers() do
			local p=self.getProfile(player); local c=player.Character; local h=c and c:FindFirstChildOfClass("Humanoid"); local root=c and c:FindFirstChild("HumanoidRootPart")
			if not p or not h or not root or h.Health<=0 then continue end
			local r=self:record(player); local boost=math.max(0,r.boostUntil-now)
			local speed=if boost>0 then (if h:GetState()==Enum.HumanoidStateType.Swimming then self.config.BoostSwimSpeed else self.config.BoostWalkSpeed) else 18
			if h.WalkSpeed~=speed then h.WalkSpeed=speed end
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
			if now>=trap.expires or not self.getProfile(trap.owner) then trap.model:Destroy(); table.remove(self.traps,i); continue end
			for _, animal in wildlife.records do
				if animal.alive and not animal.zone.marine and (animal.flightHeight or 0)<1 and (animal.snaredUntil or 0)<=now and (animal.position-trap.position).Magnitude<=8 and not workspace:Raycast(trap.position+Vector3.new(0,1,0),animal.root.Position-trap.position-Vector3.new(0,1,0),self:params()) then
					animal.snaredUntil=now+self.config.SnareSeconds; animal.fleeUntil=0; animal.restUntil=now+self.config.SnareSeconds+10; animal.path={}; animal.waypoint=1
					trap.caption.Text="ANIMAL HELD\nRescue within 8 seconds!"; trap.expires=now+self.config.SnareSeconds
					-- One animal per consumable; its snare stays visible until release.
					trap.spent=true; self.notify(trap.owner,"Your gentle snare caught an animal! Rescue it quickly.","success"); break
				end
			end
			if trap.spent then trap.position=Vector3.new(100000,0,100000) end
		end
	end)
	Players.PlayerRemoving:Connect(function(player) self.records[player]=nil end)
end
return FieldKit
