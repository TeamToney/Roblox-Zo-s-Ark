--!strict
local Catalog = require("../src/shared/Catalog")
local Layout = require("../src/shared/MapLayout")
local Islands = require("../src/shared/IslandLayouts")
local Wildlife = require("../src/shared/WildlifeRules")
local passed, failed = 0, 0
local function test(name: string, callback: () -> ())
	local ok, problem = pcall(callback)
	if ok then passed += 1; print("PASS  " .. name) else failed += 1; print("FAIL  " .. name .. ": " .. tostring(problem)) end
end
test("all visible habitats exclude Rare, Epic, Legendary and Mythic wildlife", function()
	for _, habitat in {"meadow", "jungle", "summit", "reef", "ocean"} do
		for index = 0, 99 do
			local id = assert(Wildlife.choose(Catalog, {habitat = habitat}, index / 100))
			assert(Catalog.Rarities[Catalog.Species[id].rarity].rank < 3)
		end
	end
end)
test("every ordinary species has at least one eligible authored habitat", function()
	local plans: {any} = {Layout}; for _, plan in Islands.Islands do table.insert(plans, plan) end
	for _, id in Catalog.SpeciesOrder do
		local species = Catalog.Species[id]
		if species.eventOnly then continue end
		local found = false
		for _, plan in plans do for _, zone in plan.Zones do if Wildlife.eligible(Catalog, species, zone) then found = true end end end
		assert(found, id .. " has no spawn habitat")
	end
end)
test("all authored ordinary habitats have a nonempty species pool", function()
	local plans: {any} = {Layout}; for _, plan in Islands.Islands do table.insert(plans, plan) end
	for _, plan in plans do for _, zone in plan.Zones do assert(Wildlife.choose(Catalog, zone, 0), zone.id) end end
end)
test("the event has exactly one designated secluded reef habitat", function()
	local count = 0
	local plans: {any} = {Layout}; for _, plan in Islands.Islands do table.insert(plans, plan) end
	for _, plan in plans do for _, zone in plan.Zones do if zone.event then count += 1; assert(zone.obscure and zone.habitat == "reef") end end end
	assert(count == 1)
end)
test("room visits are limited to the same island and sufficient body clearance", function()
	local rabbit = Catalog.Species.rabbit
	assert(Wildlife.canVisit(rabbit, {mapId = "canopy"}, {mapId = "canopy", width = 20}))
	assert(not Wildlife.canVisit(rabbit, {mapId = "canopy"}, {mapId = "moonstone", width = 20}))
	assert(not Wildlife.canVisit(rabbit, {mapId = "canopy"}, {mapId = "canopy", width = 2}))
	assert(not Wildlife.canVisit(rabbit, {mapId = "canopy", obscure = true}, {mapId = "canopy", width = 20}))
	assert(not Wildlife.canVisit(Catalog.Species.seal, {mapId = "ark", marine = true}, {mapId = "ark", width = 20}))
	assert(not Wildlife.canVisit(Catalog.Species.tiger, {mapId = "canopy"}, {mapId = "canopy", width = 30}))
end)
test("invalid spawn rolls cannot choose wildlife", function()
	for _, roll in {-1, 1, math.huge, 0 / 0} do assert(Wildlife.choose(Catalog, {habitat = "meadow"}, roll) == nil) end
end)
print(string.format("\n%d wildlife-placement cases passed, %d failed (eligibility, not Roblox navigation)", passed, failed))
if failed > 0 then error("Wildlife placement checks failed") end
