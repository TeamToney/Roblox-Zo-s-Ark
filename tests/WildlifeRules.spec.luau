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
test("visible habitats allow matching rare wildlife with a small normalized budget", function()
	for _,habitat in {"meadow","jungle","summit","reef","ocean"} do
		local sum,special=0,0
		for _,entry in Wildlife.distribution(Catalog,{habitat=habitat,mapId="ark"}) do
			sum+=entry.probability
			if Catalog.Rarities[Catalog.Species[entry.id].rarity].rank>=3 then special+=entry.probability end
		end
		assert(math.abs(sum-1)<0.000001); assert(special>0 and special<0.03)
	end
end)
test("every ordinary species has at least one eligible authored habitat", function()
	local plans: {any} = {Layout}; for _, plan in Islands.Islands do table.insert(plans, plan) end
	for _, id in Catalog.SpeciesOrder do
		local species = Catalog.Species[id]
		if species.eventOnly or species.nightOnly then continue end
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
test("every map supports rare epic and legendary wildlife without excluding public habitats", function()
	local plans: {any}={Layout}; for _,plan in Islands.Islands do table.insert(plans,plan) end
	for _,plan in plans do
		local ranks: {[number]: boolean}={}
		for _,zone in plan.Zones do
			for _,entry in Wildlife.distribution(Catalog,{habitat=zone.habitat,mapId=plan.Id,obscure=zone.obscure}) do
				if entry.probability>0 then ranks[Catalog.Rarities[Catalog.Species[entry.id].rarity].rank]=true end
			end
		end
		assert(ranks[3] and ranks[4] and ranks[5],plan.Id.." must support all three scarce tiers")
	end
end)
test("paid islands and hidden habitats increase scarce-tier probability while commons remain the majority", function()
	local previous=0
	for _,mapId in Catalog.MapOrder do
		local total,hidden=0,0
		for _,entry in Wildlife.distribution(Catalog,{habitat="jungle",mapId=mapId}) do if Catalog.Rarities[Catalog.Species[entry.id].rarity].rank>=3 then total+=entry.probability end end
		for _,entry in Wildlife.distribution(Catalog,{habitat="jungle",mapId=mapId,obscure=true}) do if Catalog.Rarities[Catalog.Species[entry.id].rarity].rank>=3 then hidden+=entry.probability end end
		assert(total>previous and hidden>total and hidden<0.3); previous=total
	end
end)
test("all seaways have rare epic and legendary possibilities with no event-only drops", function()
	for _,zone in require("../src/shared/SeawayLayout") do
		local ranks: {[number]: boolean}={}; local sum=0
		for _,entry in Wildlife.distribution(Catalog,{habitat=zone.habitat,seaway=true,mapId="ark"}) do
			assert(not Catalog.Species[entry.id].eventOnly); sum+=entry.probability
			ranks[Catalog.Rarities[Catalog.Species[entry.id].rarity].rank]=true
		end
		assert(ranks[3] and ranks[4] and ranks[5]); assert(math.abs(sum-1)<0.000001)
	end
end)
test("sampler boundaries use the full rarity distribution including the smallest legendary budget", function()
	local zone={habitat="jungle",mapId="ark"}; local edge=0
	for _,entry in Wildlife.distribution(Catalog,zone) do
		local selected=Wildlife.choose(Catalog,zone,edge+entry.probability/2)
		assert(selected==entry.id); edge+=entry.probability
	end
	assert(math.abs(edge-1)<0.000001)
end)
print(string.format("\n%d wildlife-placement cases passed, %d failed (eligibility, not Roblox navigation)", passed, failed))
if failed > 0 then error("Wildlife placement checks failed") end
