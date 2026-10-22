--!nonstrict
local Players = game:GetService("Players")
local EncounterRules = require(game:GetService("ReplicatedStorage"):WaitForChild("ZoShared").EncounterRules)
local EscapeRules = require(game:GetService("ReplicatedStorage"):WaitForChild("ZoShared").EscapeRules)
local NightRules = require(game:GetService("ReplicatedStorage"):WaitForChild("ZoShared").NightRules)
local Locations = require(game:GetService("ReplicatedStorage"):WaitForChild("ZoShared").EncounterLocations)
local RunService = game:GetService("RunService")
local World = require(script.Parent.World)
local AnimalModels = require(script.Parent.AnimalModels)
local WildlifeRules = require(game:GetService("ReplicatedStorage"):WaitForChild("ZoShared").WildlifeRules)

local Wildlife = {}
Wildlife.__index = Wildlife

function Wildlife.new(world, catalog, rules, onCapture, preview, getOwned, cycle, hazards)
	return setmetatable({world = world, catalog = catalog, rules = rules, onCapture = onCapture, preview = preview, random = Random.new(), records = {}, routing = 0, getOwned = getOwned,cycle=cycle,hazards=hazards,nightSpawns={},lastHomes={},lastSpawns={}}, Wildlife)
end

function Wildlife:choose(zone)
	return WildlifeRules.choose(self.catalog, zone, self.random:NextNumber())
end

function Wildlife:spawn(zone, id)
	local species = self.catalog.Species[id]
	local populationZone=zone
	local homes=Locations.order(Locations.animalHomes(self.world.spawnHomes,zone,species),self.lastHomes[zone],self.random:NextNumber())
	local position=nil
	for index,home in homes do
		if index>8 then break end
		local candidate=World.sample(self.world,home,self.random,species.scale,self.lastSpawns[populationZone],10)
		if candidate then
			local clear=true
			for _,record in self.records do
				local other=self.catalog.Species[record.id]
				if Vector2.new(candidate.X-record.position.X,candidate.Z-record.position.Z).Magnitude<math.max(6,(other.scale+species.scale)*2) then clear=false; break end
			end
			if clear then position=candidate; zone=home; break end
		end
	end
	if not position then return end
	self.lastHomes[populationZone]=zone.key; self.lastSpawns[populationZone]=position
	local model = Instance.new("Model"); model.Name = species.name
	model.ModelStreamingMode = Enum.ModelStreamingMode.Atomic
	local scale = species.scale
	local root = self.world.part(model, "AnimalRoot", Vector3.one, CFrame.new(position + Vector3.new(0, if zone.marine then 0 else scale * 1.7, 0)), Color3.new())
	root.Transparency = 1; root.CanCollide = false; root.CanQuery = false
	model.PrimaryPart = root
	local rig = AnimalModels.build(self.world, model, root, species)
	local title = self.world.label(root, species.name .. "\n" .. species.rarity .. " • Tier " .. species.tier, 4 * scale, 240)
	title.TextColor3 = Color3.fromRGB(unpack(self.catalog.Rarities[species.rarity].color))
	if species.dangerous then
		title.Text=species.name.."\nDANGER • restrain before rescue"; title.TextColor3=Color3.fromRGB(255,105,112)
		local outline=Instance.new("Highlight"); outline.FillTransparency=1; outline.OutlineColor=Color3.fromRGB(255,90,105); outline.DepthMode=Enum.HighlightDepthMode.Occluded; outline.Parent=model
	end
	local prompt = Instance.new("ProximityPrompt")
	prompt.ActionText = "Rescue animal"; prompt.ObjectText = species.name .. " • " .. species.rarity
	prompt.MaxActivationDistance = 12; prompt.HoldDuration = EncounterRules.holdTime(self.world.config.CaptureHold,self.catalog.Rarities[species.rarity].rank)
	prompt.RequiresLineOfSight = true; prompt.Parent = root
	model:SetAttribute("SpeciesId", id); model:SetAttribute("Dangerous",species.dangerous==true); model.Parent = self.world.actors
	local record = {behavior=EscapeRules.behavior(self.catalog,id,zone.marine), routeVersion=0, nextEscapePlan=0, holds = {}, retryUntil = 0, prompt = prompt, fleeUntil = 0, fleeStarted = 0, restUntil = 0, snaredUntil = 0, flightHeight = 0, model = model, root = root, rig = rig, zone = zone,populationZone=populationZone, id = id, alive = true, busy = false, position = root.Position, path = {}, waypoint = 1, nextMove = os.clock() + self.random:NextNumber(1, 3), yaw = self.random:NextNumber(0, math.pi * 2)}
	self.records[model] = record
	prompt.PromptButtonHoldBegan:Connect(function(player)
		local c=player.Character; local body=c and c:FindFirstChild("HumanoidRootPart"); local h=c and c:FindFirstChildOfClass("Humanoid")
		if body and h and h.Health>0 and (body.Position-root.Position).Magnitude<=self.world.config.CaptureDistance and os.clock()>=record.retryUntil then record.holds[player]=os.clock() end
	end)
	prompt.PromptButtonHoldEnded:Connect(function(player)
		local started=record.holds[player]
		task.delay(0.15,function() if record.holds[player]==started then record.holds[player]=nil end end)
	end)
	prompt.Triggered:Connect(function(player)
		if not record.alive or record.busy or record.flightHeight > 2 or os.clock()<record.retryUntil or not EncounterRules.held(record.holds[player],os.clock(),prompt.HoldDuration) then return end
		record.holds[player]=nil
		record.busy = true
		local ok, captured, escaped = pcall(self.onCapture, player, record)
		record.busy = false
		if not ok then warn("[Zo's Ark] Capture failed:", captured); return end
		if captured then
			record.alive = false; self.records[model] = nil; model:Destroy()
		elseif escaped and player.Character then
			record.retryUntil=os.clock()+self.world.config.CaptureCooldown
			local body = player.Character:FindFirstChild("HumanoidRootPart")
			if body then self:flee(record, body.Position, player) end
		end
	end)
	return record
end

function Wildlife:planMove(record)
	local species = self.catalog.Species[record.id]
	if not record.zone.obscure and not record.zone.marine and not record.pending and self.routing < 2 and self.random:NextNumber() < 0.7 then
		local candidates = {}
		for _, target in self.world.roamTargets do
			local distance = (target.position - record.position).Magnitude
			if distance > 14 and distance < 150 and WildlifeRules.canVisit(species, record.zone, target) then table.insert(candidates, target) end
		end
		if #candidates > 0 then
			local target = candidates[self.random:NextInteger(1, #candidates)]
			record.pending = true; self.routing += 1
			local version=record.routeVersion
			task.spawn(function()
				local ok, points = pcall(World.route, self.world, record.position, target.position + Vector3.new(0, species.scale * 1.7, 0), species.scale)
				self.routing -= 1; record.pending = false
				if ok and points and record.alive and record.routeVersion==version and os.clock() >= record.fleeUntil and os.clock() >= record.snaredUntil then record.path = points; record.waypoint = 2 end
			end)
			return
		end
	end
	-- Secluded and marine animals stay in their home habitats. Failed paths
	-- are retried later; animals never teleport through a wall or across sea.
	for _ = 1, 8 do
		local position = World.sample(self.world, record.zone, self.random, species.scale)
		if position then
			position += Vector3.new(0, if record.zone.marine then 0 else species.scale * 1.7, 0)
			if (position - record.position).Magnitude < 45 and World.canRoam(self.world, record.position, position, species.scale) then record.path = {position}; record.waypoint = 1; return end
		end
	end
end

function Wildlife:escapePoint(record, threat, goal)
	local species=self.catalog.Species[record.id]
	local scale=species.scale
	local params=World.wildlifeParams(self.world)
	local restricted=record.zone.marine or record.zone.obscure or self.catalog.Rarities[species.rarity].rank>=3
	local function within(point)
		if not restricted then return true end
		local bounds=record.zone.bounds; local margin=math.max(1,scale*2)
		if bounds then return point.X>=bounds.minX+margin and point.X<=bounds.maxX-margin and point.Z>=bounds.minZ+margin and point.Z<=bounds.maxZ-margin end
		return Vector2.new(point.X-record.zone.center.X,point.Z-record.zone.center.Z).Magnitude<=record.zone.radius-margin
	end
	local probes=EscapeRules.probes(record.position.X,record.position.Z,threat.X,threat.Z,record.yaw)
	if goal then
		for _,probe in probes do probe.score=-Vector2.new(probe.x-goal.X,probe.z-goal.Z).Magnitude end
		table.sort(probes,function(a,b) return a.score>b.score end)
	end
	local chosen=EscapeRules.choose(probes,function(probe)
		local point=Vector3.new(probe.x,record.position.Y,probe.z)
		if goal and Vector2.new(point.X-goal.X,point.Z-goal.Z).Magnitude>=Vector2.new(record.position.X-goal.X,record.position.Z-goal.Z).Magnitude-0.5 then return false end
		if not within(point) or not World.canRoam(self.world,record.position,point,scale) then return false end
		-- Sweep across dry ground / real water as well as walls. Characters are
		-- excluded so standing on the animal cannot pin its navigation in place.
		local samples=math.max(2,math.ceil(probe.distance/3))
		for i=1,samples do
			local sample=record.position:Lerp(point,i/samples)
			if record.zone.marine then
				if not World.inWater(sample) then return false end
			else
				local hit=workspace:Raycast(sample+Vector3.new(0,3,0),Vector3.new(0,-scale*1.7-6,0),params)
				if not hit or hit.Normal.Y<0.8 or math.abs(hit.Position.Y-(record.position.Y-scale*1.7))>1.5 then return false end
			end
		end
		return true
	end)
	return if chosen then Vector3.new(chosen.x,record.position.Y,chosen.z) else nil
end

function Wildlife:planEscape(record, threat)
	record.nextEscapePlan=os.clock()+0.45
	local point=self:escapePoint(record,threat)
	if point then record.path={point}; record.waypoint=1; return true end
	-- A blocked doorway can need a turn before the animal gets farther away.
	-- Reuse the bounded path budget rather than teleporting through the wall.
	if not record.zone.marine and not record.pending and self.routing<2 then
		local species=self.catalog.Species[record.id]
		local target=World.sample(self.world,record.zone,self.random,species.scale)
		if target then
			record.pending=true; self.routing+=1; local version=record.routeVersion
			task.spawn(function()
				local ok,points=pcall(World.route,self.world,record.position,target+Vector3.new(0,species.scale*1.7,0),species.scale)
				self.routing-=1; record.pending=false
				if ok and points and record.alive and record.routeVersion==version and os.clock()<record.fleeUntil and os.clock()>=record.snaredUntil then record.path=points; record.waypoint=2 end
			end)
		end
	end
	return false
end

function Wildlife:flee(record, threat, player)
	local now=os.clock()
	if now<record.snaredUntil then return false end
	record.routeVersion+=1; record.holds={}; record.threat=threat; record.pursuer=player
	record.path={}; record.waypoint=1
	record.fleeStarted=now; record.fleeUntil=now+4; record.restUntil=now+14
	return self:planEscape(record,threat)
end

function Wildlife:start()
	local function replenish()
		local active = self.rules.eventWindow(os.time(), self.preview).active
		local cycleState=self.cycle:state(); local night=cycleState.night
		for model, record in self.records do
			if self.catalog.Species[record.id].eventOnly and not active then record.alive = false; self.records[model] = nil; model:Destroy() end
		end
		for _, zone in self.world.zones do
			local count=Locations.population(self.catalog,self.records,zone)
			local ordinary,special,predators=count.ordinary,count.special,count.predators
			for _ = ordinary + 1, zone.count do
				local id = self:choose(zone); if id then self:spawn(zone, id) end
			end
			if active and zone.event then for _ = special + 1, 2 do self:spawn(zone, "auroraRay") end end
			local predator=zone.id and self.catalog.NightHabitats[(zone.mapId or "ark")..":"..zone.id]
			if predator and NightRules.canSpawn(cycleState,self.nightSpawns[zone],predators) then
				if self:spawn(zone,predator) then self.nightSpawns[zone]=cycleState.id end
			end
		end
	end
	Players.PlayerRemoving:Connect(function(player) for _, record in self.records do record.holds[player]=nil end end)
	replenish()
	task.spawn(function() while self.world.runtime.Parent do task.wait(6); replenish() end end)
	local elapsed = 0
	RunService.Heartbeat:Connect(function(dt)
		elapsed += dt; if elapsed < 0.15 then return end
		local interval = math.min(elapsed, 0.4); elapsed = 0
		local now = os.clock()
		for model, record in self.records do
			local species = self.catalog.Species[record.id]
			if species.nightOnly and not self.cycle:state().night then record.alive=false; self.records[model]=nil; model:Destroy(); continue end
			local behavior = record.behavior
			local hunting,windup=nil,false
			if species.dangerous then
				hunting,windup=self.hazards:step(record,now)
				if windup then record.path={}; record.waypoint=1
				elseif hunting and now>=(record.nextHunt or 0) then
					record.routeVersion+=1; record.nextHunt=now+0.6
					local point=self:escapePoint(record,record.position*2-hunting,hunting)
					record.path=if point then {point} else {}; record.waypoint=1
				end
			end
			if behavior.alert>0 and now >= record.restUntil and now >= record.snaredUntil then
				for _, player in Players:GetPlayers() do
					local char=player.Character; local root=char and char:FindFirstChild("HumanoidRootPart"); local hum=char and char:FindFirstChildOfClass("Humanoid")
					local owned = self.getOwned(player)
					if root and hum and hum.Health>0 and owned and EncounterRules.alert(behavior,(root.Position-record.position).Magnitude,owned.camoCoat==true,now,record.restUntil,record.snaredUntil) then
						local params=RaycastParams.new(); params.FilterType=Enum.RaycastFilterType.Exclude; params.FilterDescendantsInstances={char,self.world.actors,self.world.boats}; params.IgnoreWater=true
						if not workspace:Raycast(record.root.Position,root.Position-record.root.Position,params) then self:flee(record,root.Position,player); break end
					end
				end
			end
			local condition=EncounterRules.condition(now,record.fleeUntil,record.snaredUntil)
			if condition=="fleeing" and record.waypoint>#record.path and not record.pending and now>=record.nextEscapePlan then
				local c=record.pursuer and record.pursuer.Character; local root=c and c:FindFirstChild("HumanoidRootPart")
				self:planEscape(record,if root then root.Position else record.threat)
			end
			if condition=="calm" and not hunting and not windup and now >= record.nextMove and not record.pending and record.waypoint > #record.path then
				self:planMove(record); record.nextMove = now + self.random:NextNumber(3, 7)
			end
			local moving = false
			local target = record.path[record.waypoint]
			if target and condition~="snared" then
				local delta = target - record.position
				local scale = self.catalog.Species[record.id].scale
				local step = math.min(delta.Magnitude, interval * (if hunting then self.catalog.NightAttacks[record.id].speed elseif condition=="fleeing" and behavior then behavior.speed else math.min(7, scale * 4)))
				if delta.Magnitude < 0.3 then record.waypoint += 1
				elseif World.canRoam(self.world, record.position, record.position + delta.Unit * step, scale) then
					record.position += delta.Unit * step; record.yaw = math.atan2(-delta.X, -delta.Z); moving = true
				else record.path = {}; record.waypoint = 1 end
			end
			local lift = EncounterRules.flight(if behavior then behavior.mode else "run",now,record.fleeStarted,record.fleeUntil)
			if condition=="snared" or not World.canRoam(self.world,record.position,record.position+Vector3.new(0,lift,0),species.scale) then lift=0 end
			record.flightHeight=lift; record.prompt.Enabled=lift<=2 and now>=record.retryUntil
			record.prompt.ActionText=if species.dangerous then (if now<(record.dangerRestraintUntil or 0) then "Rescue restrained predator • 3×" else "Restrain with tranquilizer / predator snare") elseif condition=="snared" then "Rescue snared animal" elseif condition=="fleeing" then "Rescue fleeing animal" else "Rescue animal"
			local lunge=Vector3.zero
			if now<(record.attackLungeUntil or 0) then lunge=Vector3.new(-math.sin(record.yaw),0,-math.cos(record.yaw))*math.sin((record.attackLungeUntil-now)/0.35*math.pi)*1.5 end
			model:PivotTo(CFrame.new(record.position + lunge + Vector3.new(0, lift + math.sin(now * 1.8) * 0.12, 0)) * CFrame.Angles(0, record.yaw, 0))
			AnimalModels.animate(record.rig, record.root.CFrame, now, moving or lift>0, record.zone.marine)
		end
	end)
end
return Wildlife
