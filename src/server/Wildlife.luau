--!nonstrict
local RunService = game:GetService("RunService")
local World = require(script.Parent.World)
local AnimalModels = require(script.Parent.AnimalModels)

local Wildlife = {}
Wildlife.__index = Wildlife

function Wildlife.new(world, catalog, rules, onCapture, preview)
	return setmetatable({world = world, catalog = catalog, rules = rules, onCapture = onCapture, preview = preview, random = Random.new(), records = {}}, Wildlife)
end

function Wildlife:choose(habitat)
	local candidates, total = {}, 0
	for _, id in self.catalog.SpeciesOrder do
		local species = self.catalog.Species[id]
		if species.habitat == habitat and not species.eventOnly then
			total += species.weight; table.insert(candidates, {id = id, edge = total})
		end
	end
	if total == 0 then return nil end
	local roll = self.random:NextNumber(0, total)
	for _, candidate in candidates do if roll < candidate.edge then return candidate.id end end
	return candidates[#candidates].id
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
	prompt.MaxActivationDistance = 15; prompt.HoldDuration = 0.65
	prompt.RequiresLineOfSight = true; prompt.Parent = root
	model:SetAttribute("SpeciesId", id); model.Parent = self.world.actors
	local record = {model = model, root = root, rig = rig, zone = zone, id = id, alive = true, busy = false, position = root.Position, origin = root.Position, target = root.Position, movedAt = os.clock(), nextMove = os.clock() + self.random:NextNumber(3, 7), yaw = self.random:NextNumber(0, math.pi * 2)}
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

function Wildlife:start()
	local function replenish()
		local active = self.rules.eventWindow(os.time(), self.preview).active
		for model, record in self.records do
			if self.catalog.Species[record.id].eventOnly and not active then
				record.alive = false; self.records[model] = nil; model:Destroy()
			end
		end
		for _, zone in self.world.zones do
			local ordinary, special = 0, 0
			for _, record in self.records do
				if record.zone == zone then
					if self.catalog.Species[record.id].eventOnly then special += 1 else ordinary += 1 end
				end
			end
			for _ = ordinary + 1, zone.count do
				local id = self:choose(zone.habitat); if id then self:spawn(zone, id) end
			end
			if active and zone.habitat == "reef" then
				for _ = special + 1, 2 do self:spawn(zone, "auroraRay") end
			end
		end
	end
	replenish()
	task.spawn(function() while self.world.runtime.Parent do task.wait(6); replenish() end end)
	local elapsed = 0
	RunService.Heartbeat:Connect(function(dt)
		elapsed += dt; if elapsed < 0.15 then return end; elapsed = 0
		local now = os.clock()
		for model, record in self.records do
			if now >= record.nextMove then
				for _ = 1, 8 do
					local animalScale = self.catalog.Species[record.id].scale
					local pos = World.sample(self.world, record.zone, self.random, animalScale)
					if pos then
						pos += Vector3.new(0, if record.zone.marine then 0 else self.catalog.Species[record.id].scale * 1.7, 0)
						if (pos - record.position).Magnitude < 40 and World.canRoam(self.world, record.position, pos, animalScale) then
							record.origin = record.position; record.target = pos; record.movedAt = now
							local delta = pos - record.position
							if delta.Magnitude > 0.1 then record.yaw = math.atan2(-delta.X, -delta.Z) end
							break
						end
					end
				end
				record.nextMove = now + self.random:NextNumber(6, 10)
			end
			record.position = record.origin:Lerp(record.target, math.clamp((now - record.movedAt) / 5, 0, 1))
			model:PivotTo(CFrame.new(record.position + Vector3.new(0, math.sin(now * 1.8) * 0.12, 0)) * CFrame.Angles(0, record.yaw, 0))
			AnimalModels.animate(record.rig, record.root.CFrame, now, (record.target - record.origin).Magnitude > 0.5 and now - record.movedAt < 5, record.zone.marine)
		end
	end)
end

return Wildlife
