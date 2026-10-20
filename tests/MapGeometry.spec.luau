--!strict
local Layout = require("../src/shared/MapLayout")
local Geometry = require("../src/shared/MapGeometry")
local passed, failed = 0, 0
local function test(name: string, callback: () -> ())
	local ok, problem = pcall(callback)
	if ok then passed += 1; print("PASS  " .. name)
	else failed += 1; print("FAIL  " .. name .. ": " .. tostring(problem)) end
end
local function equal(actual: any, expected: any)
	assert(actual == expected, "expected " .. tostring(expected) .. ", got " .. tostring(actual))
end
local function room(id: string): any
	for _, entry in Layout.Rooms do if entry.id == id then return entry end end
	error("Missing room " .. id)
end
test("image north maps to world negative Z without mirroring east", function()
	local x, z = Geometry.world(Layout.Source, Layout.Source.pivotX, Layout.Source.pivotY)
	equal(x, 0); equal(z, 0)
	x, z = Geometry.world(Layout.Source, Layout.Source.pivotX + 10, Layout.Source.pivotY - 10)
	equal(x, 6); equal(z, -6)
end)
test("rectangular bounds respect an animal's edge clearance", function()
	local r = {0, 0, 100, 50}
	equal(Geometry.contains(r, 10, 10, 10), true)
	equal(Geometry.contains(r, 9, 10, 10), false)
	equal(Geometry.contains(r, 90, 40, 10), true)
	equal(Geometry.contains(r, 91, 40, 10), false)
end)
test("rectangular doors remove the middle of a wall and retain both sides", function()
	local example = {id = "test", rect = {0, 0, 100, 50}, doors = {{side = "north", center = 50, width = 20}}}
	local walls = Geometry.walls(example)
	equal(#walls, 5)
	local gapDistance = math.huge
	for _, wall in walls do gapDistance = math.min(gapDistance, Geometry.distanceToSegment(50, 0, wall)) end
	equal(gapDistance, 10)
end)
test("vertical doors work when the west edge runs in reverse", function()
	local example = {id = "west", rect = {0, 0, 100, 100}, doors = {{side = "west", center = 50, width = 30}}}
	local gapDistance = math.huge
	for _, wall in Geometry.walls(example) do gapDistance = math.min(gapDistance, Geometry.distanceToSegment(0, 50, wall)) end
	equal(gapDistance, 15)
end)
test("an out-of-bounds doorway fails before the world is built", function()
	local ok = pcall(function()
		Geometry.walls({id = "invalid", rect = {0, 0, 100, 50}, doors = {{side = "north", center = 4, width = 20}}})
	end)
	equal(ok, false)
end)
test("the pointed atrium outline and north doorway are preserved", function()
	local atrium = room("arkAtrium")
	equal(#atrium.polygon, 5); equal(atrium.polygon[4][1], 814); equal(atrium.polygon[4][2], 812)
	equal(atrium.doors[1].side, "north")
	local minDistance = math.huge
	for _, wall in Geometry.walls(atrium) do minDistance = math.min(minDistance, Geometry.distanceToSegment(814, 620, wall)) end
	equal(minDistance, 26)
end)
test("polygon floor strips narrow into the atrium's pointed end", function()
	local polygon = room("arkAtrium").polygon
	local top = Geometry.scanline(polygon, 700)
	local foot = Geometry.scanline(polygon, 790)
	equal(#top, 2); equal(#foot, 2)
	assert(top[2] - top[1] > foot[2] - foot[1])
	equal(#Geometry.scanline(polygon, 900), 0)
end)
test("nursery and meadow openings align instead of sealing one another", function()
	local nursery, meadow = room("nursery"), room("meadowHall")
	equal(nursery.doors[1].center, meadow.doors[2].center)
	equal(nursery.doors[1].width, meadow.doors[2].width)
end)
test("foundation area subtracts the lagoon and sea gate exactly once", function()
	local tiles = Geometry.floorTiles(Layout)
	local area = 0
	for _, tile in tiles do area += (tile[3] - tile[1]) * (tile[4] - tile[2]) end
	local b = Layout.Bounds
	local parcel = (b[3] - b[1]) * (b[4] - b[2])
	equal(area, parcel - (1380 - 1133) * (552 - 214) - (1490 - 1380) * (412 - 362))
	for i, a in tiles do
		for j = i + 1, #tiles do
			local c = tiles[j]
			local width = math.min(a[3], c[3]) - math.max(a[1], c[1])
			local depth = math.min(a[4], c[4]) - math.max(a[2], c[2])
			assert(width <= 0 or depth <= 0, "Foundation tiles overlap")
		end
	end
end)
test("a clipped corridor never fills the east sea gate", function()
	local tiles = Geometry.floorTiles({Bounds = {1370, 350, 1490, 430}, WaterCuts = Layout.WaterCuts})
	for _, tile in tiles do
		local x, y = Geometry.center(tile)
		assert(not Geometry.inWater(Layout, x, y))
	end
	equal(Geometry.inWater(Layout, 1430, 387), true)
	equal(Geometry.inWater(Layout, 1690, 420), true)
end)
test("outdoor courtyards are land and pool zones are water", function()
	for _, zone in Layout.Zones do
		local x, y = Geometry.center(zone.rect)
		equal(Geometry.inWater(Layout, x, y), zone.habitat == "reef" or zone.habitat == "ocean")
	end
end)
test("boarding transitions join the pool, low dock and ground", function()
	equal(Layout.SwimSteps[4], Layout.Dock[2])
	equal(Layout.Dock[4], Layout.DockRamp[2])
	equal(Layout.DockRamp[4], Layout.WaterCuts[1][4])
	assert(Layout.FloorY > Layout.WaterY)
	assert((Layout.DockRamp[4] - Layout.DockRamp[2]) * Layout.Source.scale > 4)
end)
test("dry-land foundation columns extend through the seabed without closing water routes", function()
	local columns = Geometry.foundationColumns(Layout)
	equal(#columns, #Geometry.floorTiles(Layout))
	for _, column in columns do
		assert(column.top == Layout.FloorY and column.bottom < Layout.SeabedY)
		local x, y = Geometry.center(column.rect)
		equal(Geometry.inWater(Layout, x, y), false)
		for _, boat in Layout.Boats do equal(Geometry.contains(column.rect, boat[1], boat[2]), false) end
		equal(Geometry.contains(column.rect, Layout.SeaGate[1], Layout.SeaGate[2]), false)
	end
end)
test("four shore exits lie on the parcel edge and descend outward into water", function()
	equal(#Layout.ShoreExits, 4)
	for _, exit in Layout.ShoreExits do
		equal(math.abs(exit.dx) + math.abs(exit.dy), 1)
		assert(Geometry.contains(Layout.Bounds, exit.x, exit.y))
		equal(Geometry.inWater(Layout, exit.x - exit.dx * 5, exit.y - exit.dy * 5), false)
		equal(Geometry.inWater(Layout, exit.x + exit.dx * 20, exit.y + exit.dy * 20), true)
	end
end)
print(string.format("\n%d map-geometry cases passed, %d failed", passed, failed))
if failed > 0 then error("Zo's Ark map geometry checks failed") end
