--!nonstrict
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local Shared = game:GetService("ReplicatedStorage"):WaitForChild("ZoShared")
local SwimRules = require(Shared.SwimRules)
local World = require(script.Parent.World)
local WaterSafety = {}
WaterSafety.__index = WaterSafety

function WaterSafety.new(world, config, getOwned, onMovement, notify, isBoosted)
	return setmetatable({world = world, config = config, rules = SwimRules.new(config), getOwned = getOwned,
		onMovement = onMovement, notify = notify, isBoosted = isBoosted, records = {}, pickups = {}, random = Random.new()}, WaterSafety)
end

function WaterSafety:remove(player)
	local record = self.records[player]
	if record and record.ring then record.ring:Destroy() end
	self.records[player] = nil
end

function WaterSafety:snapshot(player)
	local record = self.records[player]
	local owned = self.getOwned(player)
	if not owned then return nil end
	return self.rules.snapshot(if record then record.state else self.rules.blank(), owned, record ~= nil and record.swimming)
end

function WaterSafety:params(extra)
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude; params.IgnoreWater = true; params.RespectCanCollide = true
	local excluded = {self.world.actors, self.world.boats}
	if extra then table.insert(excluded, extra) end
	for _, player in Players:GetPlayers() do if player.Character then table.insert(excluded, player.Character) end end
	params.FilterDescendantsInstances = excluded
	return params
end

function WaterSafety:grounded(root, humanoid)
	local state = humanoid:GetState()
	if state ~= Enum.HumanoidStateType.Running and state ~= Enum.HumanoidStateType.RunningNoPhysics and state ~= Enum.HumanoidStateType.Landed then return false end
	local reach = math.max(4.5, humanoid.HipHeight + root.Size.Y / 2 + 1)
	local hit = workspace:Raycast(root.Position, Vector3.new(0, -reach, 0), self:params())
	return hit ~= nil and hit.Normal.Y > 0.5 and hit.Instance:IsA("BasePart") and hit.Instance.Anchored
end

function WaterSafety:position(region)
	for _ = 1, 16 do
		local x = self.random:NextNumber(region.minX, region.maxX)
		local z = self.random:NextNumber(region.minZ, region.maxZ)
		local p = Vector3.new(x, region.y, z)
		local obstacle = workspace:Raycast(p + Vector3.new(0, 6, 0), Vector3.new(0, -9, 0), self:params())
		local spaced = true
		for _, pickup in self.pickups do
			if (pickup.home - p).Magnitude < 12 then spaced = false; break end
		end
		if spaced and not obstacle and World.inWater(p) then return p end
	end
	return nil
end

function WaterSafety:ring(parent, root, worn)
	local model = Instance.new("Model"); model.Name = "RescueFloatRing"; model.Parent = parent
	for index = 1, 12 do
		local angle = index * math.pi / 6
		local cf = root.CFrame * CFrame.new(math.cos(angle) * 2.3, if worn then -0.8 else 0, math.sin(angle) * 2.3) * CFrame.Angles(0, -angle, 0)
		local p = self.world.part(model, "FloatSegment", Vector3.new(1, 0.75, 1.4), cf,
			if index % 3 == 0 then Color3.fromRGB(250, 243, 220) else Color3.fromRGB(244, 133, 63))
		p.CanCollide = false; p.CanQuery = false; p.CanTouch = false
		if worn then
			p.Anchored = false; p.Massless = true
			local weld = Instance.new("WeldConstraint"); weld.Part0 = root; weld.Part1 = p; weld.Parent = p
		end
	end
	return model
end

function WaterSafety:spawnPickup(region, kind)
	local home = self:position(region)
	if not home then return end
	local model = Instance.new("Model"); model.Name = if kind == "float" then "FloatingLifeRing" else "FloatingFirstAid"
	model.ModelStreamingMode = Enum.ModelStreamingMode.Atomic; model.Parent = self.world.runtime
	local root = self.world.part(model, "PickupRoot", Vector3.one, CFrame.new(home), Color3.new())
	root.Transparency = 1; root.CanCollide = false; root.CanQuery = false; root.CanTouch = false; model.PrimaryPart = root
	if kind == "float" then self:ring(model, root, false)
	else
		local case = self.world.part(model, "FirstAidCase", Vector3.new(3, 1.5, 2.3), root.CFrame, Color3.fromRGB(245, 241, 219))
		case.CanCollide = false; case.CanQuery = false; case.CanTouch = false
		for _, size in {Vector3.new(1.8, 0.15, 0.55), Vector3.new(0.55, 0.15, 1.6)} do
			local cross = self.world.part(model, "RecoveryCross", size, root.CFrame * CFrame.new(0, 0.82, 0), Color3.fromRGB(81, 188, 133))
			cross.CanCollide = false; cross.CanQuery = false; cross.CanTouch = false
		end
	end
	self.world.label(root, if kind == "float" then "LIFE RING\n+15s endurance • 20s flotation" else "FIRST AID\n+25 health • +20s endurance", 4, 260)
	local prompt = Instance.new("ProximityPrompt"); prompt.ActionText = if kind == "float" then "Use life ring" else "Recover health & endurance"
	prompt.ObjectText = "Water survival pickup"; prompt.HoldDuration = 0.35; prompt.MaxActivationDistance = 10; prompt.RequiresLineOfSight = false; prompt.Parent = root
	local pickup = {model = model, root = root, home = home, region = region, kind = kind, prompt = prompt, readyAt = 0, parts = {}}
	for _, child in model:GetDescendants() do
		if child:IsA("BasePart") and child ~= root then table.insert(pickup.parts, child) end
	end
	table.insert(self.pickups, pickup)
	prompt.Triggered:Connect(function(player)
		local now = os.clock()
		local record = self.records[player]
		local character = player.Character
		local body = character and character:FindFirstChild("HumanoidRootPart")
		local humanoid = character and character:FindFirstChildOfClass("Humanoid")
		if now < pickup.readyAt or not record or record.character ~= character or not self.getOwned(player) or not body or not humanoid or humanoid.Health <= 0 or humanoid.SeatPart then return end
		if (body.Position - root.Position).Magnitude > 12 or not World.inWater(body.Position) then return end
		if workspace:Raycast(body.Position, root.Position - body.Position, self:params(model)) then return end
		-- Reserve the shared pickup before changing any player state.
		pickup.readyAt = now + self.config.WaterPickupRespawn; prompt.Enabled = false
		for _, p in pickup.parts do p.Transparency = 1 end
		for _, gui in model:GetDescendants() do if gui:IsA("BillboardGui") then gui.Enabled = false end end
		local _, heal = self.rules.pickup(record.state, kind)
		humanoid.Health = math.min(humanoid.MaxHealth, humanoid.Health + heal)
		self.notify(player, if kind == "float" then "Life ring! +15s endurance and 20 seconds of flotation." else "First aid! +25 health and +20s swim endurance.", "success")
	end)
end

function WaterSafety:seedPickups()
	for _, zone in self.world.zones do
		if zone.marine then
			local b = zone.bounds or {minX = zone.center.X - zone.radius, maxX = zone.center.X + zone.radius, minZ = zone.center.Z - zone.radius, maxZ = zone.center.Z + zone.radius}
			local region = {minX = b.minX + 8, maxX = b.maxX - 8, minZ = b.minZ + 8, maxZ = b.maxZ - 8, y = self.world.waterY or zone.center.Y}
			if region.maxX > region.minX and region.maxZ > region.minZ then
				for _ = 1, if zone.id == "openSea" then 2 else 1 do self:spawnPickup(region, "float"); self:spawnPickup(region, "health") end
			end
		end
	end
	for _, layout in self.world.plans do
		for _, exit in layout.ShoreExits do
			local x = (exit.x - layout.Source.pivotX) * layout.Source.scale + exit.dx * 55
			local z = (exit.y - layout.Source.pivotY) * layout.Source.scale + exit.dy * 55
			local region = {minX = x - 18, maxX = x + 18, minZ = z - 18, maxZ = z + 18, y = layout.WaterY}
			self:spawnPickup(region, "float"); self:spawnPickup(region, "health")
		end
	end
end

function WaterSafety:start()
	self:seedPickups()
	local elapsed = 0
	RunService.Heartbeat:Connect(function(dt)
		elapsed += dt; if elapsed < 0.25 then return end
		local interval = math.min(elapsed, 2); elapsed = 0
		local now = os.clock()
		for _, pickup in self.pickups do
			if not pickup.prompt.Enabled and now >= pickup.readyAt then
				-- Hide the old placement from the spacing check while choosing anew.
				local old = pickup.home; pickup.home = Vector3.new(10000, 0, 10000)
				pickup.home = self:position(pickup.region) or old
				pickup.model:PivotTo(CFrame.new(pickup.home)); pickup.prompt.Enabled = true
				for _, p in pickup.parts do p.Transparency = 0 end
				for _, gui in pickup.model:GetDescendants() do if gui:IsA("BillboardGui") then gui.Enabled = true end end
			end
		end
		for _, player in Players:GetPlayers() do
			local owned = self.getOwned(player)
			local character = player.Character
			local root = character and character:FindFirstChild("HumanoidRootPart")
			local humanoid = character and character:FindFirstChildOfClass("Humanoid")
			if not owned or not root or not humanoid or humanoid.Health <= 0 then self:remove(player); continue end
			local record = self.records[player]
			if not record or record.character ~= character then
				self:remove(player)
				record = {character = character, state = self.rules.blank(), warned = false}
				self.records[player] = record
			end
			local swimming = not humanoid.SeatPart and World.inWater(root.Position)
			local grounded = not swimming and not humanoid.SeatPart and self:grounded(root, humanoid)
			local mode = if swimming then "swim" elseif grounded then "walk" else nil
			local damage = self.rules.advance(record.state, owned, swimming, interval, grounded or humanoid.SeatPart ~= nil)
			record.swimming = swimming
			if damage > 0 then humanoid:TakeDamage(damage) end
			if mode and record.mode == mode and record.position then
				local delta = root.Position - record.position
				local boosted = self.isBoosted(player)
				local speed = if boosted then (if swimming then self.config.BoostSwimSpeed+4 else self.config.BoostWalkSpeed+4) else (if swimming then self.config.MaxSwimPerSecond else self.config.MaxWalkPerSecond)
				if delta.Magnitude <= speed * interval then
					self.onMovement(player, mode, Vector2.new(delta.X, delta.Z).Magnitude, interval)
				end
			end
			record.position = root.Position; record.mode = mode
			local status = self.rules.snapshot(record.state, owned, swimming)
			character:SetAttribute("ZoSwimRemaining", math.floor(status.remaining * 10) / 10)
			character:SetAttribute("ZoSwimMaximum", status.maximum)
			character:SetAttribute("ZoSwimFloating", status.floating)
			character:SetAttribute("ZoSwimming", swimming)
			if swimming and status.remaining <= 10 and not record.warned then
				record.warned = true; self.notify(player, "Low swim endurance! Find a shore exit, boat, life ring or first-aid float.", "info")
			elseif status.remaining > 10 then record.warned = false end
			if record.state.floating > 0 and swimming then
				if not record.ring then record.ring = self:ring(character, root, true) end
			elseif record.ring then record.ring:Destroy(); record.ring = nil end
		end
	end)
end
return WaterSafety
