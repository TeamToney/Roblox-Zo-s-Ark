--!nonstrict
local RunService = game:GetService("RunService")
local World = require(script.Parent.World)
local AnimalModels = require(script.Parent.AnimalModels)
local WildlifeRules = require(game:GetService("ReplicatedStorage"):WaitForChild("ZoShared").WildlifeRules)

local Wildlife = {}
Wildlife.__index = Wildlife

function Wildlife.new(world, catalog, rules, onCapture, preview)
	return setmetatable({world = world, catalog = catalog, rules = rules, onCapture = onCapture, preview = preview, random = Random.new(), records = {}, routing = 0}, Wildlife)
end

function Wildlife:choose(zone)
	return WildlifeRules.choose(self.catalog, zone, self.random:NextNumber())
end

function Wildlife:spawn(zone, id)
	local species = self.catalog.Species[id]
	local position = World.sample(self.world, zone, self.random, species.scale)
	if not position then return end
	local model = Instance.new("Model"); model.Name = species.name
	model.ModelStreamingMode = Enum.ModelStreamingMode.Atomic
	local scale = species.scale
	local root = self.world.part(model, "AnimalRoot", Vector3.one, CFrame.new(position + Vector3.new(0, if zone.marine then 0 else scale * 1.7, 0)), Color3.new())
	root.Transparency = 1; root.CanCollide = false; root.CanQuery = false
	model.PrimaryPart = root
	local rig = AnimalModels.build(self.world, model, root, species)
	local title = self.world.label(root, species.name .. "\n" .. species.rarity .. " • Tier " .. species.tier, 4 * scale, 240)
	title.TextColor3 = Color3.fromRGB(unpack(self.catalog.Rarities[species.rarity].color))
	local prompt = Instance.new("ProximityPrompt")
	prompt.ActionText = "Rescue animal"; prompt.ObjectText = species.name .. " • " .. species.rarity
	prompt.MaxActivationDistance = 15; prompt.HoldDuration = self.world.config.CaptureHold
	prompt.RequiresLineOfSight = true; prompt.Parent = root
	model:SetAttribute("SpeciesId", id); model.Parent = self.world.actors
	local record = {model = model, root = root, rig = rig, zone = zone, id = id, alive = true, busy = false, position = root.Position, path = {}, waypoint = 1, nextMove = os.clock() + self.random:NextNumber(3, 7), yaw = self.random:NextNumber(0, math.pi * 2)}
	self.records[model] = record
	prompt.Triggered:Connect(function(player)
		if not record.alive or record.busy then return end
		record.busy = true
		local ok, captured = pcall(self.onCapture, player, record)
		record.busy = false
		if not ok then warn("[Zo's Ark] Capture failed:", captured); return end
		if captured then
			record.alive = false; self.records[model] = nil; model:Destroy()
		end
	end)
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
			task.spawn(function()
				local ok, points = pcall(World.route, self.world, record.position, target.position + Vector3.new(0, species.scale * 1.7, 0), species.scale)
				self.routing -= 1; record.pending = false
				if ok and points and record.alive then record.path = points; record.waypoint = 2 end
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

function Wildlife:start()
	local function replenish()
		local active = self.rules.eventWindow(os.time(), self.preview).active
		for model, record in self.records do
			if self.catalog.Species[record.id].eventOnly and not active then record.alive = false; self.records[model] = nil; model:Destroy() end
		end
		for _, zone in self.world.zones do
			local ordinary, special = 0, 0
			for _, record in self.records do
				if record.zone == zone then
					if self.catalog.Species[record.id].eventOnly then special += 1 else ordinary += 1 end
				end
			end
			for _ = ordinary + 1, zone.count do
				local id = self:choose(zone); if id then self:spawn(zone, id) end
			end
			if active and zone.event then for _ = special + 1, 2 do self:spawn(zone, "auroraRay") end end
		end
	end
	replenish()
	task.spawn(function() while self.world.runtime.Parent do task.wait(6); replenish() end end)
	local elapsed = 0
	RunService.Heartbeat:Connect(function(dt)
		elapsed += dt; if elapsed < 0.15 then return end
		local interval = math.min(elapsed, 0.4); elapsed = 0
		local now = os.clock()
		for model, record in self.records do
			if now >= record.nextMove and not record.pending and record.waypoint > #record.path then
				self:planMove(record); record.nextMove = now + self.random:NextNumber(8, 16)
			end
			local moving = false
			local target = record.path[record.waypoint]
			if target then
				local delta = target - record.position
				local scale = self.catalog.Species[record.id].scale
				local step = math.min(delta.Magnitude, interval * math.min(7, scale * 4))
				if delta.Magnitude < 0.3 then record.waypoint += 1
				elseif World.canRoam(self.world, record.position, record.position + delta.Unit * step, scale) then
					record.position += delta.Unit * step; record.yaw = math.atan2(-delta.X, -delta.Z); moving = true
				else record.path = {}; record.waypoint = 1 end
			end
			model:PivotTo(CFrame.new(record.position + Vector3.new(0, math.sin(now * 1.8) * 0.12, 0)) * CFrame.Angles(0, record.yaw, 0))
			AnimalModels.animate(record.rig, record.root.CFrame, now, moving, record.zone.marine)
		end
	end)
end
return Wildlife
