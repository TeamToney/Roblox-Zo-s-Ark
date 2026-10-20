--!strict
local Catalog = require("../src/shared/Catalog")
local Shapes = require("../src/shared/AnimalShapes")
local passed, failed = 0, 0
local function test(name: string, callback: () -> ())
	local ok, problem = pcall(callback)
	if ok then passed += 1; print("PASS  " .. name) else failed += 1; print("FAIL  " .. name .. ": " .. tostring(problem)) end
end
local function count(id: string, name: string): number
	local n = 0
	for _, p in Shapes.build(Catalog.Species[id]).parts do if p.name == name then n += 1 end end
	return n
end
test("every species has a complete bounded blueprint with two visible eyes", function()
	for _, id in Catalog.SpeciesOrder do
		local blueprint = Shapes.build(Catalog.Species[id])
		assert(#blueprint.parts >= 14 and #blueprint.parts <= 80, id .. " part budget")
		assert(count(id, "Eye") == 2)
		for _, p in blueprint.parts do
			for _, value in p.size do assert(value > 0 and value < 10, id .. " invalid size") end
			for _, value in p.color do assert(value >= 0 and value <= 255) end
			assert(p.shape == "ball" or p.shape == "block" or p.shape == "wedge")
			if p.joint then assert(blueprint.joints[p.joint], id .. " missing animation joint") end
		end
	end
end)
test("resting animal geometry fits the shared habitat clearance and ground height", function()
	for _, id in Catalog.SpeciesOrder do
		for _, p in Shapes.build(Catalog.Species[id]).parts do
			local x, y, z = math.rad(p.rotation[1]), math.rad(p.rotation[2]), math.rad(p.rotation[3])
			local cx, sx, cy, sy, cz, sz = math.cos(x), math.sin(x), math.cos(y), math.sin(y), math.cos(z), math.sin(z)
			local rows = {{cy * cz, -cy * sz, sy}, {sx * sy * cz + cx * sz, -sx * sy * sz + cx * cz, -sx * cy}, {-cx * sy * cz + sx * sz, cx * sy * sz + sx * cz, cx * cy}}
			for axis = 1, 3 do
				local extent = 0
				for k = 1, 3 do extent += math.abs(rows[axis][k]) * p.size[k] / 2 end
				if axis ~= 2 then assert(math.abs(p.offset[axis]) + extent <= 4.5, id .. "/" .. p.name .. " exceeds habitat clearance")
				else assert(p.offset[2] - extent >= -1.7, id .. "/" .. p.name .. " intersects ground") end
			end
		end
	end
end)
test("birds have two legs, folded feathered wings, and no quadruped legs", function()
	for _, id in {"parrot", "eagle"} do
		assert(count(id, "BirdLeg") == 2 and count(id, "Leg") == 0)
		assert(count(id, "FoldedWing") == 2 and count(id, "FlightFeather") == 6)
	end
end)
test("species silhouettes retain their identifying anatomy", function()
	assert(count("rabbit", "LongEar") == 2 and count("fox", "WhiteTailTip") == 1)
	assert(count("deer", "AntlerTine") == 4 and count("goat", "GoatBeard") == 1)
	assert(count("jaguar", "Rosette") == 14 and count("snowLeopard", "Rosette") == 14)
	assert(count("monkey", "LongArm") == 2 and count("monkey", "CurledTail") == 6)
	assert(count("reefFish", "VerticalTail") == 1 and count("reefFish", "HorizontalFluke") == 0)
	assert(count("dolphin", "HorizontalFluke") == 2 and count("whale", "ThroatPleat") == 3)
	assert(count("seaTurtle", "SeaFlipper") == 4 and count("seaTurtle", "CentralScute") == 3)
	assert(count("auroraRay", "DiamondWing") == 2 and count("auroraRay", "WhipTail") == 1)
end)
print(string.format("\n%d animal-blueprint cases passed, %d failed (geometry data, not a Studio render)", passed, failed))
if failed > 0 then error("Animal blueprint checks failed") end
