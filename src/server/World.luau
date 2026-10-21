--!nonstrict
local CollectionService = game:GetService("CollectionService")
local RunService = game:GetService("RunService")
local Players = game:GetService("Players")
local PathfindingService = game:GetService("PathfindingService")

local PlanWorld = require(script.Parent.PlanWorld)
local IslandWorld = require(script.Parent.IslandWorld)
local Shared = game:GetService("ReplicatedStorage"):WaitForChild("ZoShared")
local Geometry = require(Shared.MapGeometry)

local World = {}
local C = {
	wood = Color3.fromRGB(124, 80, 51), deck = Color3.fromRGB(190, 145, 92),
	green = Color3.fromRGB(102, 168, 121), jungle = Color3.fromRGB(61, 125, 104),
	sand = Color3.fromRGB(235, 215, 164), snow = Color3.fromRGB(215, 231, 231),
	navy = Color3.fromRGB(25, 51, 63), mint = Color3.fromRGB(127, 225, 185),
}

local function part(parent, name, size, cf, color, material, shape)
	local p = Instance.new(if shape == "wedge" then "WedgePart" else "Part")
	p.Name = name; p.Size = size; p.CFrame = cf; p.Color = color
	p.Anchored = true; p.Material = material or Enum.Material.SmoothPlastic
	p.TopSurface = Enum.SurfaceType.Smooth; p.BottomSurface = Enum.SurfaceType.Smooth
	if shape and shape ~= "wedge" then p.Shape = shape end
	p.Parent = parent
	return p
end

local function label(parent, text, height, width)
	local gui = Instance.new("BillboardGui")
	gui.Name = "Label"; gui.Size = UDim2.fromOffset(width or 240, 64)
	gui.StudsOffsetWorldSpace = Vector3.new(0, height or 5, 0)
	gui.MaxDistance = 210; gui.AlwaysOnTop = false; gui.Parent = parent
	local textLabel = Instance.new("TextLabel")
	textLabel.Size = UDim2.fromScale(1, 1); textLabel.BackgroundTransparency = 1
	textLabel.Text = text; textLabel.TextColor3 = Color3.fromRGB(255, 245, 219)
	textLabel.TextStrokeTransparency = 0.5; textLabel.TextSize = 19
	textLabel.Font = Enum.Font.GothamBold; textLabel.TextWrapped = true
	textLabel.Parent = gui
	return textLabel
end

local function prompt(parent, action, object, distance)
	local p = Instance.new("ProximityPrompt")
	p.ActionText = action; p.ObjectText = object
	p.MaxActivationDistance = distance or 16; p.HoldDuration = 0.3
	p.RequiresLineOfSight = false; p.Parent = parent
	return p
end

function World.build(config)
	local runtime = Instance.new("Folder"); runtime.Name = "ZoRuntime"; runtime.Parent = workspace
	local actors = Instance.new("Folder"); actors.Name = "Wildlife"; actors.Parent = runtime
	local boats = Instance.new("Folder"); boats.Name = "Boats"; boats.Parent = runtime
	local self = {runtime = runtime, actors = actors, boats = boats, zones = {}, boatSpawns = {}, config = config, plans = {}, roamTargets = {}, checkpoints = {}, checkpointSpots = {}, chestSpots = {}}
	local imported = workspace:FindFirstChild("ZoMap")
	if imported then
		-- An explicit Studio map always overrides the generated Map 1 campus.
		for _, marker in CollectionService:GetTagged("ZoAnimalZone") do
			if marker:IsA("BasePart") and marker:IsDescendantOf(imported) then
				local habitat = marker:GetAttribute("Habitat")
				if table.find({"meadow", "jungle", "summit", "reef", "ocean"}, habitat) then
					table.insert(self.zones, {habitat = habitat, center = marker.Position, radius = math.clamp(tonumber(marker:GetAttribute("Radius")) or 60, 12, 180), marine = habitat == "reef" or habitat == "ocean", count = math.clamp(math.floor(tonumber(marker:GetAttribute("Population")) or 6), 1, 12)})
				end
			end
		end
		local hub = imported:FindFirstChild("ZoHub", true)
		local spawn = imported:FindFirstChild("ZoSpawn", true)
		assert(hub and hub:IsA("BasePart") and spawn and spawn:IsA("BasePart") and #self.zones > 0, "ZoMap needs ZoHub, ZoSpawn, and tagged ZoAnimalZone parts. See docs/MAP_IMPORT.md")
		self.hub = hub.Position; self.spawn = spawn.CFrame; self.mapKind = "imported"; self.mapName = "Custom Sanctuary"
		for _, marker in CollectionService:GetTagged("ZoBoatSpawn") do
			if marker:IsA("BasePart") and marker:IsDescendantOf(imported) then table.insert(self.boatSpawns, marker.CFrame) end
		end
	else
		PlanWorld.build(self, part, label)
		table.insert(self.plans, self.sourceLayout)
		IslandWorld.build(self, part, label)
		for _, plan in self.plans do
			local function position(x, y, height)
				local wx, wz = Geometry.world(plan.Source, x, y)
				return Vector3.new(wx, height, wz)
			end
			for _, room in plan.Rooms do
				if room.rect and room.kind ~= "marine" then
					local x, y = Geometry.center(room.rect)
					table.insert(self.roamTargets, {mapId = plan.Id, position = position(x, y, plan.FloorY + 0.2), width = math.min(room.rect[3] - room.rect[1], room.rect[4] - room.rect[2]) * plan.Source.scale})
				end
			end
			for _, cp in plan.Checkpoints do table.insert(self.checkpointSpots, {id = cp.id, position = position(cp.x, cp.y, plan.FloorY + 0.2)}) end
			for _, chest in plan.Chests do table.insert(self.chestSpots, {id = chest.id, position = position(chest.x, chest.y, if chest.marine then plan.WaterY else plan.FloorY + 0.2)}) end
		end
	end
	local spawn = Instance.new("SpawnLocation")
	spawn.Name = "ZoSpawn"; spawn.Size = Vector3.new(10, 1, 10); spawn.CFrame = self.spawn
	spawn.Transparency = 1; spawn.Anchored = true; spawn.CanCollide = false; spawn.Neutral = true
	spawn.Duration = 0; spawn.Parent = runtime
	self.spawnLocation = spawn
	local kiosk = part(runtime, "ArkStation", Vector3.new(10, 6, 5), CFrame.new(self.hub + Vector3.new(13, 2, 0)), C.navy, Enum.Material.WoodPlanks)
	part(runtime, "StationAwning", Vector3.new(13, 1, 8), kiosk.CFrame * CFrame.new(0, 4, 0), C.mint, Enum.Material.Fabric)
	label(kiosk, "ARK OUTFITTERS\nGear • sanctuary trades", 8, 280)
	self.shopPosition = kiosk.Position
	self.shopPrompt = prompt(kiosk, "Open store & sanctuary", "Ark Outfitters", 22)
	local board = part(runtime, "ChallengeBoard", Vector3.new(10, 7, 1), CFrame.new(self.hub + Vector3.new(-17, 3, 0)), C.wood, Enum.Material.WoodPlanks)
	label(board, "EXPEDITION BOARD\nDaily challenges + rare prizes", 7, 280)
	self.challengePrompt = prompt(board, "View challenges", "Expedition Board", 20)
	local hubValue = Instance.new("Vector3Value"); hubValue.Name = "ZoShopPosition"; hubValue.Value = self.shopPosition; hubValue.Parent = game:GetService("ReplicatedStorage")
	local mapInfo = Instance.new("Folder"); mapInfo.Name = "ZoMapInfo"; mapInfo:SetAttribute("Imported", imported ~= nil); mapInfo:SetAttribute("MapKind", self.mapKind); mapInfo:SetAttribute("MapName", self.mapName)
	local hubPoint = Instance.new("Vector3Value"); hubPoint.Name = "ZO'S ARK"; hubPoint.Value = self.hub; hubPoint.Parent = mapInfo
	local names = {meadow = "MEADOW", jungle = "CANOPY COVE", summit = "CLOUDPEAK", reef = "SUNLIT REEF", ocean = "BLUE EXPANSE"}
	local extent = math.max(math.abs(self.hub.X), math.abs(self.hub.Z)) + 100
	for _, zone in self.zones do
		if not zone.obscure then
			local point = Instance.new("Vector3Value"); point.Name = zone.name or names[zone.habitat]; point.Value = zone.center; point.Parent = mapInfo
		end
		extent = math.max(extent, math.abs(zone.center.X) + zone.radius, math.abs(zone.center.Z) + zone.radius)
	end
	if #self.plans > 0 then
		local minX, minZ, maxX, maxZ = math.huge, math.huge, -math.huge, -math.huge
		for _, plan in self.plans do
			local x1, z1 = Geometry.world(plan.Source, plan.Bounds[1], plan.Bounds[2])
			local x2, z2 = Geometry.world(plan.Source, plan.Bounds[3], plan.Bounds[4])
			minX = math.min(minX, x1); minZ = math.min(minZ, z1); maxX = math.max(maxX, x2); maxZ = math.max(maxZ, z2)
		end
		mapInfo:SetAttribute("CenterX", (minX + maxX) / 2); mapInfo:SetAttribute("CenterZ", (minZ + maxZ) / 2)
		mapInfo:SetAttribute("Extent", math.max(maxX - minX, maxZ - minZ) * 1.12)
	else mapInfo:SetAttribute("Extent", math.max(900, extent * 2.2)) end
	mapInfo.Parent = game:GetService("ReplicatedStorage")
	self.part = part; self.label = label
	return self
end

function World.sample(self, zone, random, scale)
	scale = scale or 1
	local margin = math.max(3, scale * 4.5)
	if zone.bounds and (zone.bounds.maxX - zone.bounds.minX <= margin * 2 or zone.bounds.maxZ - zone.bounds.minZ <= margin * 2) then return nil end
	if not zone.bounds and zone.radius <= margin then return nil end
	local params = RaycastParams.new(); params.FilterType = Enum.RaycastFilterType.Exclude
	params.FilterDescendantsInstances = {self.actors, self.boats}; params.IgnoreWater = true
	local overlap = OverlapParams.new(); overlap.FilterType = Enum.RaycastFilterType.Exclude
	overlap.FilterDescendantsInstances = {self.actors, self.boats, workspace.Terrain}; overlap.RespectCanCollide = true
	for _ = 1, 12 do
		local position
		if zone.bounds then
			position = Vector3.new(random:NextNumber(zone.bounds.minX + margin, zone.bounds.maxX - margin), zone.center.Y, random:NextNumber(zone.bounds.minZ + margin, zone.bounds.maxZ - margin))
		else
			local angle = random:NextNumber(0, math.pi * 2); local radius = math.sqrt(random:NextNumber()) * (zone.radius - margin)
			position = zone.center + Vector3.new(math.cos(angle) * radius, 0, math.sin(angle) * radius)
		end
		if not zone.marine then
			local hit = workspace:Raycast(position + Vector3.new(0, 120, 0), Vector3.new(0, -240, 0), params)
			position = if hit and hit.Normal.Y > 0.8 and hit.Position.Y > 3 and math.abs(hit.Position.Y - zone.center.Y) < 12 then hit.Position else nil
		end
		if position then
			local root = position + Vector3.new(0, if zone.marine then 0 else scale * 1.7, 0)
			if #workspace:GetPartBoundsInBox(CFrame.new(root), Vector3.new(9, 3, 9) * scale, overlap) == 0 then return position end
		end
	end
	return nil
end

function World.canRoam(self, origin, target, scale)
	local delta = target - origin
	if delta.Magnitude < 0.01 then return true end
	local params = RaycastParams.new(); params.FilterType = Enum.RaycastFilterType.Exclude
	params.FilterDescendantsInstances = {self.actors, self.boats}; params.IgnoreWater = true
	return workspace:Blockcast(CFrame.new(origin), Vector3.new(9, 3, 9) * scale, delta, params) == nil
end

function World.inWater(position)
	-- Check actual server Terrain, including imported maps. A swimming state
	-- reported by a client is insufficient to award strokes or bypass fatigue.
	local region = Region3.new(position - Vector3.new(0.5, 2, 0.5), position + Vector3.new(0.5, 0.1, 0.5)):ExpandToGrid(4)
	local materials, occupancy = workspace.Terrain:ReadVoxels(region, 4)
	for x = 1, materials.Size.X do
		for y = 1, materials.Size.Y do
			for z = 1, materials.Size.Z do
				if materials[x][y][z] == Enum.Material.Water and occupancy[x][y][z] > 0.25 then return true end
			end
		end
	end
	return false
end

function World.route(self, origin, target, scale)
	local path = PathfindingService:CreatePath({AgentRadius = math.max(2, scale * 4.5), AgentHeight = math.max(5, scale * 5), AgentCanJump = false, AgentCanClimb = false, WaypointSpacing = 5, Costs = {Water = math.huge}})
	local ok = pcall(function() path:ComputeAsync(origin, target) end)
	if not ok or path.Status ~= Enum.PathStatus.Success then return nil end
	local points = {}
	local params = RaycastParams.new(); params.FilterType = Enum.RaycastFilterType.Exclude; params.IgnoreWater = true
	params.FilterDescendantsInstances = {self.actors, self.boats}
	for _, waypoint in path:GetWaypoints() do
		if waypoint.Action == Enum.PathWaypointAction.Jump then return nil end
		local hit = workspace:Raycast(waypoint.Position + Vector3.new(0, 10, 0), Vector3.new(0, -22, 0), params)
		if not hit or hit.Normal.Y < 0.8 or math.abs(hit.Position.Y - (origin.Y - scale * 1.7)) > 2 then return nil end
		table.insert(points, hit.Position + Vector3.new(0, scale * 1.7, 0))
	end
	return if #points > 1 and #points <= 80 then points else nil
end

function World.startBoats(self, inputEvent)
	local records, bySeat, inputTimes = {}, {}, {}
	for index, home in self.boatSpawns do
		local model = Instance.new("Model"); model.Name = "ExpeditionBoat" .. index; model.Parent = self.boats
		local hull = part(model, "Hull", Vector3.new(10, 1.8, 16), home, C.deck, Enum.Material.WoodPlanks)
		model.PrimaryPart = hull
		for _, x in {-4.6, 4.6} do part(model, "Gunwale", Vector3.new(1, 2, 16), home * CFrame.new(x, 1, 0), C.wood, Enum.Material.Wood) end
		local seat = Instance.new("VehicleSeat"); seat.Name = "PilotSeat"; seat.Size = Vector3.new(3, 1, 3)
		seat.CFrame = home * CFrame.new(0, 1.7, 1); seat.Anchored = true; seat.Color = C.navy; seat.Parent = model
		seat.HeadsUpDisplay = false; seat.MaxSpeed = 0
		for _, x in {-3, 3} do
			local passenger = Instance.new("Seat"); passenger.Size = Vector3.new(2, 1, 2); passenger.Anchored = true
			passenger.CFrame = home * CFrame.new(x, 1.7, 4); passenger.Color = C.navy; passenger.Parent = model
		end
		label(hull, "EXPEDITION BOAT\nSit to pilot • jump to leave", 6, 250)
		local board = prompt(hull, "Board expedition boat", "Free shared boat", 16)
		board.Triggered:Connect(function(player)
			local root = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
			local humanoid = player.Character and player.Character:FindFirstChildOfClass("Humanoid")
			if root and humanoid and humanoid.Health > 0 and not seat.Occupant and (root.Position - hull.Position).Magnitude < 20 then seat:Sit(humanoid) end
		end)
		local record = {model = model, seat = seat, home = home, idle = 0, throttle = 0, steer = 0, lastInput = 0}
		table.insert(records, record); bySeat[seat] = record
		seat:GetPropertyChangedSignal("Occupant"):Connect(function() record.throttle = 0; record.steer = 0; record.lastInput = 0 end)
	end
	inputEvent.OnServerEvent:Connect(function(player, throttle, steer)
		if type(throttle) ~= "number" or type(steer) ~= "number" or throttle ~= throttle or steer ~= steer or math.abs(throttle) > 1 or math.abs(steer) > 1 then return end
		local now = os.clock()
		if now - (inputTimes[player] or 0) < 0.07 then return end
		inputTimes[player] = now
		local humanoid = player.Character and player.Character:FindFirstChildOfClass("Humanoid")
		local boat = humanoid and bySeat[humanoid.SeatPart]
		if not boat or boat.seat.Occupant ~= humanoid or humanoid.Health <= 0 then return end
		boat.throttle = throttle; boat.steer = steer; boat.lastInput = now
	end)
	Players.PlayerRemoving:Connect(function(player) inputTimes[player] = nil end)
	RunService.Heartbeat:Connect(function(dt)
		dt = math.min(dt, 0.1)
		for _, boat in records do
			local occupied = false
			for _, child in boat.model:GetChildren() do
				if child:IsA("Seat") or child:IsA("VehicleSeat") then if child.Occupant then occupied = true end end
			end
			if occupied then boat.idle = 0 else boat.idle += dt end
			if boat.idle > 45 then boat.model:PivotTo(boat.home); boat.idle = 0 end
			local seat = boat.seat
			if seat.Occupant and Players:GetPlayerFromCharacter(seat.Occupant.Parent) then
				if os.clock() - boat.lastInput > 0.65 then boat.throttle = 0; boat.steer = 0 end
				local current = boat.model:GetPivot()
				local rotated = current * CFrame.Angles(0, -boat.steer * dt * 1.5, 0)
				local proposed = rotated + rotated.LookVector * boat.throttle * self.config.BoatSpeed * dt
				local pos = proposed.Position; local sea = self.config.SeaBounds
				local allowed = pos.X > sea[1] + 24 and pos.X < sea[3] - 24 and pos.Z > sea[2] + 24 and pos.Z < sea[4] - 24
				-- Sweep the hull ahead to keep it out of docks and imported-map shorelines.
				local offset = proposed.Position - current.Position
				if offset.Magnitude > 0.01 then
					local params = RaycastParams.new(); params.FilterType = Enum.RaycastFilterType.Exclude; params.IgnoreWater = true
					local excluded = {self.boats, self.actors}
					for _, child in boat.model:GetChildren() do
						if (child:IsA("Seat") or child:IsA("VehicleSeat")) and child.Occupant then table.insert(excluded, child.Occupant.Parent) end
					end
					params.FilterDescendantsInstances = excluded
					local hit = workspace:Blockcast(current + Vector3.new(0, 1, 0), Vector3.new(8, 2, 12), offset.Unit * (offset.Magnitude + 1), params)
					if hit then allowed = false end
				end
				if allowed then boat.model:PivotTo(proposed) else boat.model:PivotTo(rotated) end
			end
		end
	end)
end

return World
