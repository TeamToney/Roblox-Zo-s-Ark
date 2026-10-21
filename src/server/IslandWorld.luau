--!nonstrict
local Shared = game:GetService("ReplicatedStorage"):WaitForChild("ZoShared")
local Islands = require(Shared.IslandLayouts)
local Geometry = require(Shared.MapGeometry)
local Forestry = require(script.Parent.Forestry)
local colors={}
for key,value in require(Shared.Colors) do colors[key]=Color3.fromRGB(unpack(value)) end
local IslandWorld = {}
function IslandWorld.build(world, part, label)
	for _, plan in Islands.Islands do
		table.insert(world.plans, plan)
		local model = Instance.new("Folder"); model.Name = plan.Name; model.Parent = world.runtime
		local function point(x, y, height)
			local wx, wz = Geometry.world(plan.Source, x, y)
			return Vector3.new(wx, height or plan.FloorY, wz)
		end
		local function plate(parent, name, rect, top, depth, color, material)
			local x, y = Geometry.center(rect)
			return part(parent, name, Vector3.new((rect[3] - rect[1]) * plan.Source.scale, depth, (rect[4] - rect[2]) * plan.Source.scale), CFrame.new(point(x, y, top - depth / 2)), color, material)
		end
		for _, column in Geometry.foundationColumns(plan) do
			plate(model, "SolidIslandFoundation", column.rect, column.top, column.top - column.bottom, colors.ground, Enum.Material.Grass)
		end
		for _, corridor in plan.Corridors do plate(model, "GalleryPath", corridor, plan.FloorY + 0.06, 0.12, colors.corridor, Enum.Material.Sandstone) end
		for _, room in plan.Rooms do
			local roomModel = Instance.new("Model"); roomModel.Name = room.name; roomModel.Parent = model
			local tint = if room.kind == "jungle" then colors.jungle elseif room.kind == "meadow" then colors.meadow elseif room.kind == "summit" then colors.summit else colors.room
			local grass=room.kind=="meadow" or room.kind=="jungle"
			if room.rect then plate(roomModel, "RoomFloor", room.rect, plan.FloorY + 0.1, 0.2, tint, if grass then Enum.Material.Grass else Enum.Material.Concrete)
			else
				local low, high = math.huge, -math.huge
				for _, p in room.polygon do low = math.min(low, p[2]); high = math.max(high, p[2]) end
				for y = low, high - 1, 3 do
					local span = Geometry.scanline(room.polygon, y + 1.5)
					if #span == 2 then plate(roomModel, "PointedHallFloor", {span[1], y, span[2], math.min(high, y + 3)}, plan.FloorY + 0.1, 0.2, tint, Enum.Material.WoodPlanks) end
				end
			end
			for _, line in Geometry.walls(room) do
				local a, b = point(line[1], line[2], plan.FloorY + plan.WallHeight / 2), point(line[3], line[4], plan.FloorY + plan.WallHeight / 2)
				part(roomModel, "PlanWall", Vector3.new(plan.WallThickness, plan.WallHeight, (b - a).Magnitude), CFrame.lookAt((a + b) / 2, b), colors.wall, Enum.Material.Sandstone)
			end
		end
		for _, zone in plan.Zones do
			local marine = zone.habitat == "reef" or zone.habitat == "ocean"
			local x, y = Geometry.center(zone.rect)
			local a, b = point(zone.rect[1], zone.rect[2]), point(zone.rect[3], zone.rect[4])
			table.insert(world.zones, {id = zone.id, name = zone.name, habitat = zone.habitat, center = point(x, y, if marine then plan.WaterY else plan.FloorY), bounds = {minX = a.X, maxX = b.X, minZ = a.Z, maxZ = b.Z}, radius = math.min(b.X - a.X, b.Z - a.Z) / 2, marine = marine, count = zone.count, obscure = zone.obscure == true, mapId = plan.Id})
		end
		Forestry.build(plan,model,part)
		for _, exit in plan.ShoreExits do
			local center, outward = point(exit.x, exit.y), Vector3.new(exit.dx, 0, exit.dy)
			local cf = CFrame.lookAt(center, center + outward)
			local dock = exit.x == plan.Dock.x and exit.y == plan.Dock.y
			local bottom = if dock then plan.WaterY + 4 else plan.WaterY - 1
			for index = 1, 16 do
				local top = plan.FloorY - (plan.FloorY - bottom) * index / 16
				local p = center + outward * ((index - 0.5) * 1.5)
				part(model, "LandingStep", Vector3.new(12, 1, 1.5), CFrame.new(p.X, top - 0.5, p.Z) * cf.Rotation, Color3.fromRGB(171, 130, 82), Enum.Material.WoodPlanks)
			end
			local marker = part(model, "ExitSign", Vector3.new(1, 4, 1), CFrame.new(center - outward * 4 + Vector3.new(0, 2, 0)), Color3.fromRGB(145, 227, 186))
			label(marker, if dock then plan.Name .. "\nUnlock in Travel • checkpoint inland" else "SHORE EXIT\nRest to recover", 6, 270)
			if dock then
				local pier = center + outward * 36
				part(model, "IslandPier", Vector3.new(30, 1.2, 24), CFrame.new(pier.X, bottom - 0.6, pier.Z) * cf.Rotation, Color3.fromRGB(169, 127, 82), Enum.Material.WoodPlanks)
				local right = cf.RightVector
				for index = 1, 12 do
					local p = center + outward * 36 + right * (15 + (index - 0.5))
					local top = bottom - (bottom - plan.WaterY + 1) * index / 12
					part(model, "IslandSwimStep", Vector3.new(1, 0.8, 10), CFrame.new(p.X, top - 0.4, p.Z) * cf.Rotation, Color3.fromRGB(169, 127, 82), Enum.Material.WoodPlanks)
				end
				for _, side in {-10, 10} do
					local p = center + outward * 60 + right * side
					table.insert(world.boatSpawns, CFrame.lookAt(Vector3.new(p.X, plan.WaterY + 1.2, p.Z), Vector3.new(p.X, plan.WaterY + 1.2, p.Z) + outward))
				end
			end
		end
	end
end
return IslandWorld
