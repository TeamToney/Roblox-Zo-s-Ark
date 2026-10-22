--!nonstrict
local Shared = game:GetService("ReplicatedStorage"):WaitForChild("ZoShared")
local Layout = require(Shared.MapLayout)
local Geometry = require(Shared.MapGeometry)
local Forestry = require(script.Parent.Forestry)

local PlanWorld = {}
local palette = {}
for key, color in require(Shared.Colors) do palette[key]=Color3.fromRGB(unpack(color)) end

function PlanWorld.build(world, part, label)
	local floorY, waterY = Layout.FloorY, Layout.WaterY
	local dockY = waterY + 4
	local map = Instance.new("Folder"); map.Name = "ZoMap1Campus"; map.Parent = world.runtime
	local grade=Instance.new("ColorCorrectionEffect"); grade.Name="ZoVibrantColors"; grade.Saturation=0.14; grade.Contrast=0.04; grade.Brightness=0.02; grade.Parent=game:GetService("Lighting")
	world.mapKind = "hybrid"; world.mapName = Layout.Name
	local function point(x, y, height)
		local wx, wz = Geometry.world(Layout.Source, x, y)
		return Vector3.new(wx, height or Layout.FloorY, wz)
	end
	local function plate(parent, name, rect, top, thickness, color, material)
		local x, y = Geometry.center(rect)
		return part(parent, name, Vector3.new((rect[3] - rect[1]) * Layout.Source.scale, thickness, (rect[4] - rect[2]) * Layout.Source.scale), CFrame.new(point(x, y, top - thickness / 2)), color, material or Enum.Material.Concrete)
	end
	local function stroke(parent, name, segment, bottom, height, thickness, color, material)
		local a, b = point(segment[1], segment[2], bottom + height / 2), point(segment[3], segment[4], bottom + height / 2)
		local p = part(parent, name, Vector3.new(thickness, height, (b - a).Magnitude), CFrame.lookAt((a + b) / 2, b), color, material)
		return p
	end
	workspace.Terrain.WaterColor = palette.water
	workspace.Terrain.WaterTransparency = 0.35
	workspace.Terrain.WaterWaveSize = 0.12; workspace.Terrain.WaterWaveSpeed = 7
	local waterDepth = waterY - Layout.SeabedY
	local sea = world.config.SeaBounds
	-- Chunked fills stay below Terrain's voxel-operation size limit.
	for x = sea[1], sea[3] - 1, 1024 do
		for z = sea[2], sea[4] - 1, 1024 do
			local width, depth = math.min(1024, sea[3] - x), math.min(1024, sea[4] - z)
			workspace.Terrain:FillBlock(CFrame.new(x + width / 2, Layout.SeabedY - 6, z + depth / 2), Vector3.new(width, 12, depth), Enum.Material.Rock)
			workspace.Terrain:FillBlock(CFrame.new(x + width / 2, waterY - waterDepth / 2, z + depth / 2), Vector3.new(width, waterDepth, depth), Enum.Material.Water)
		end
	end
	-- Extrude only dry tiles through the entire water column. The lagoon and
	-- sea gate remain open; no water-filled tunnel exists below the island.
	for _, column in Geometry.foundationColumns(Layout) do
		plate(map, "IslandBedrock", column.rect, column.top, column.top - column.bottom, palette.ground, Enum.Material.Grass)
	end
	plate(map, "LagoonBasin", Layout.WaterCuts[1], waterY - 17, 3, palette.navy, Enum.Material.Slate)

	for _, rect in Layout.Corridors do
		-- Split paving around water cuts: never bridge the sea gate accidentally.
		local patch = {Bounds = rect, WaterCuts = Layout.WaterCuts}
		for _, tile in Geometry.floorTiles(patch) do plate(map, "GardenPath", tile, Layout.FloorY + 0.05, 0.1, palette.corridor, Enum.Material.Sandstone) end
	end
	for _, room in Layout.Rooms do
		local model = Instance.new("Model"); model.Name = room.name; model.Parent = map
		local color = palette[room.kind] or palette.room
		local material = if room.kind == "atrium" then Enum.Material.WoodPlanks else (if room.kind == "jungle" or room.kind == "meadow" then Enum.Material.Grass else Enum.Material.Concrete)
		if room.rect and room.kind ~= "marine" then plate(model, "Floor", room.rect, Layout.FloorY + 0.1, 0.2, color, material)
		elseif room.polygon then
			local minY, maxY = math.huge, -math.huge
			for _, vertex in room.polygon do minY = math.min(minY, vertex[2]); maxY = math.max(maxY, vertex[2]) end
			for y = minY, maxY - 1, 2 do
				local span = Geometry.scanline(room.polygon, y + 1)
				if #span == 2 then plate(model, "AtriumFloor", {span[1], y, span[2], math.min(y + 2, maxY)}, Layout.FloorY + 0.1, 0.2, color, material) end
			end
		end
		local habitat = room.kind == "meadow" or room.kind == "jungle" or room.kind == "summit"
		local wallHeight = math.max(Layout.WallHeight,room.height or 0)
		local wallBottom = if room.id == "reefAlcove" then Layout.SeabedY else Layout.FloorY
		if room.id == "reefAlcove" then wallHeight = Layout.FloorY + Layout.WallHeight - wallBottom end
		for _, segment in Geometry.walls(room) do
			stroke(model, "PlanWall", segment, wallBottom, wallHeight, Layout.WallThickness, palette.wall, Enum.Material.Sandstone)
			stroke(model, "WallCap", segment, wallBottom + wallHeight, 0.25, Layout.WallThickness + 0.15, if habitat then palette.mint else palette.wood, Enum.Material.SmoothPlastic)
		end
		if room.kind == "entry" then
			local sign = part(model, "WelcomeSign", Vector3.new(16, 1, 1), CFrame.new(point(814, 1586, floorY + 3)), palette.navy)
			label(sign, "WELCOME TO ZO'S ARK\nGardens • wildlife • sea expeditions", 4, 320)
		elseif room.id == "marineHall" then
			local sign = part(model, "MarineSign", Vector3.one, CFrame.new(point(1122, 393, floorY + 4)), palette.navy)
			label(sign, "TIDEWATER HALL\nReef lagoon • bluewater pool • sea gate", 5, 320)
		end
	end

	for _, court in Layout.Courtyards do
		plate(map, court.name, court.rect, Layout.FloorY + 0.12, 0.24, palette[court.habitat], Enum.Material.Grass)
	end
	for _, zone in Layout.Zones do
		local x, y = Geometry.center(zone.rect)
		local marine = zone.habitat == "reef" or zone.habitat == "ocean"
		local a, b = point(zone.rect[1], zone.rect[2]), point(zone.rect[3], zone.rect[4])
		table.insert(world.zones, {
			id = zone.id, name = zone.name, habitat = zone.habitat,
			center = point(x, y, if marine then Layout.WaterY else Layout.FloorY),
			bounds = {minX = a.X, maxX = b.X, minZ = a.Z, maxZ = b.Z},
			radius = math.min(b.X - a.X, b.Z - a.Z) / 2,
			marine = marine, count = zone.count,
			mapId = "ark", seaway = zone.extension == true, obscure = zone.obscure == true, event = zone.event == true,
		})
		local signX = if marine then zone.rect[1] - 13 else x
		local signY = if marine then y else zone.rect[2] + 3
		local sign = part(map, zone.name .. "Sign", Vector3.new(1, 4, 1), CFrame.new(point(signX, signY, if zone.extension then waterY + 1 else floorY + 3)), palette.navy)
		if zone.extension then sign.Shape = Enum.PartType.Ball; sign.Size = Vector3.new(4, 4, 4); sign.Color = palette.mint end
		if not zone.obscure then label(sign, string.upper(zone.name), 5, 280) else sign:Destroy() end
	end
	Forestry.build(Layout,map,part)

	plate(map, "LowBoardingDock", Layout.Dock, dockY, 1.2, palette.wood, Enum.Material.WoodPlanks)
	local function steps(rect, high, low, count)
		for index = 1, count do
			local d = (rect[4] - rect[2]) / count
			local y = rect[2] + (index - 1) * d
			plate(map, "BoardingStep", {rect[1], y, rect[3], y + d}, low + (high - low) * index / count, 0.8, palette.wood, Enum.Material.WoodPlanks)
		end
	end
	steps(Layout.DockRamp, floorY, dockY, 8)
	steps(Layout.SwimSteps, dockY, waterY - 1, 10)
	for _, exit in Layout.ShoreExits do
		local center = point(exit.x, exit.y)
		local outward = Vector3.new(exit.dx, 0, exit.dy)
		local cf = CFrame.lookAt(center, center + outward)
		for index = 1, 16 do
			local top = floorY - (floorY - waterY + 1) * index / 16
			local position = center + outward * ((index - 0.5) * 1.5)
			part(map, "ShoreExitStep", Vector3.new(12, 1, 1.5), CFrame.new(position.X, top - 0.5, position.Z) * cf.Rotation, palette.wood, Enum.Material.WoodPlanks)
		end
		local sign = part(map, "ShoreExitSign", Vector3.new(1, 4, 1), CFrame.new(center - outward * 4 + Vector3.new(0, 2, 0)), palette.mint)
		label(sign, "SHORE EXIT\nRest on land to recover", 6, 250)
	end
	for _, boat in Layout.Boats do table.insert(world.boatSpawns, CFrame.new(point(boat[1], boat[2], waterY + 1.2))) end
	local dockSign = part(map, "DockSign", Vector3.one, CFrame.new(point(1305, 548, floorY + 2)), palette.navy)
	label(dockSign, "EXPEDITION DOCK\nUse the steps • free boats • east to sea", 5, 300)
	world.hub = point(Layout.Hub[1], Layout.Hub[2], floorY + 0.1)
	world.spawn = CFrame.new(point(Layout.Spawn[1], Layout.Spawn[2], floorY + 3))
	world.sourceLayout = Layout
	world.waterY = waterY
	return map
end
return PlanWorld
