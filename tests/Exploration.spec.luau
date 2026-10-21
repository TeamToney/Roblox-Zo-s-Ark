--!strict
local Config = require("../src/shared/Config")
local Catalog = require("../src/shared/Catalog")
local Rules = require("../src/shared/Rules").new(Catalog, Config)
local Layout = require("../src/shared/MapLayout")
local Islands = require("../src/shared/IslandLayouts")
local passed, failed = 0, 0
local now = 1800000000
local function test(name: string, callback: () -> ())
	local ok, problem = pcall(callback)
	if ok then passed += 1; print("PASS  " .. name) else failed += 1; print("FAIL  " .. name .. ": " .. tostring(problem)) end
end
local function equal(actual: any, expected: any) assert(actual == expected, "expected " .. tostring(expected) .. ", got " .. tostring(actual)) end
test("checkpoints reward their first activation and can switch respawn without farming", function()
	local p = Rules.blank(now)
	assert(Rules.checkpoint(p, "canopyDock")); equal(p.coins, 115); equal(p.points, 10)
	assert(Rules.checkpoint(p, "canopyDock")); equal(p.coins, 115)
	assert(Rules.checkpoint(p, "moonstoneDock")); equal(p.exploration.activeCheckpoint, "moonstoneDock")
	assert(Rules.checkpoint(p, "canopyDock")); equal(p.exploration.activeCheckpoint, "canopyDock"); equal(p.coins, 130)
	equal(Rules.checkpoint(p, "madeUp"), false); equal(p.exploration.activeCheckpoint, "canopyDock")
end)
test("old journals receive exploration defaults without losing existing animals or gear", function()
	local p = Rules.sanitize({coins = 523, points = 145, inventory = {fox = 2}, owned = {snorkel = true}, stats = {walkDistance = 29.75}}, now)
	equal(p.coins, 523); equal(p.points, 145); equal(p.inventory.fox, 2); equal(p.owned.snorkel, true)
	equal(p.stats.walkDistance, 29.75); equal(p.exploration.activeCheckpoint, "")
	equal(next(p.exploration.chests), nil); equal(next(p.exploration.checkpoints), nil)
end)
test("visited checkpoints and expedition data survive sanitization", function()
	local p = Rules.blank(now); Rules.checkpoint(p, "canopyDock")
	Rules.openChest(p, "canopyEntry", 0, 0, now)
	p.exploration.catches.canopy = 4; p.exploration.rareCatches.canopy = 2; p.exploration.claimed.canopySurvey = true
	local restored = Rules.sanitize(p, now)
	equal(restored.exploration.activeCheckpoint, "canopyDock"); equal(restored.exploration.catches.canopy, 4)
	equal(restored.exploration.rareCatches.canopy, 2); equal(restored.exploration.claimed.canopySurvey, true)
	equal(Rules.openChest(restored, "canopyEntry", 0.7, 0, now), false)
end)
test("invalid exploration entries cannot activate unvisited checkpoints or claim prizes", function()
	local p = Rules.sanitize({exploration = {activeCheckpoint = "canopyVault", checkpoints = {invented = true}, claimed = {invented = true}, chests = {invented = 1, arkNursery = math.huge}, catches = {canopy = 0 / 0}}}, now)
	equal(p.exploration.activeCheckpoint, ""); equal(next(p.exploration.checkpoints), nil)
	equal(next(p.exploration.chests), nil); equal(next(p.exploration.claimed), nil); equal(p.exploration.catches.canopy, 0)
end)
test("chest coins cover their bounded reward range", function()
	local a, b = Rules.blank(now), Rules.blank(now)
	local ok, result = Rules.openChest(a, "arkNursery", 0, 0, now)
	assert(ok); equal(result.kind, "coins"); equal(a.coins, 140)
	Rules.openChest(b, "arkNursery", 0.1, 0.999999, now); equal(b.coins, 250)
end)
test("a chest opening is reserved once per player per UTC day including across reconnect", function()
	local p = Rules.blank(now)
	assert(Rules.openChest(p, "arkNursery", 0, 0, now)); equal(p.coins, 140)
	equal(Rules.openChest(p, "arkNursery", 0.96, 0, now), false); equal(p.coins, 140)
	local restored = Rules.sanitize(p, now)
	equal(Rules.openChest(restored, "arkNursery", 0, 0, now), false)
	assert(Rules.openChest(restored, "arkNursery", 0, 0, now + 86400)); equal(restored.coins, 180)
end)
test("different explorers have independent daily chest openings", function()
	local a, b = Rules.blank(now), Rules.blank(now)
	assert(Rules.openChest(a, "arkNursery", 0, 0, now)); assert(Rules.openChest(b, "arkNursery", 0, 0, now))
	equal(a.coins, 140); equal(b.coins, 140)
end)
test("invalid chest IDs and random values do not consume openings or award anything", function()
	local p = Rules.blank(now)
	equal(Rules.openChest(p, "invented", 0, 0, now), false)
	for _, value in {-1, 1, math.huge, 0 / 0} do
		equal(Rules.openChest(p, "arkNursery", value, 0, now), false)
		equal(Rules.openChest(p, "arkNursery", 0, value, now), false)
	end
	equal(p.coins, 100); equal(next(p.exploration.chests), nil)
end)
test("ordinary chests never contain Rare+ or event-only animals", function()
	for index = 0, 99 do
		local p = Rules.blank(now)
		local ok, result = Rules.openChest(p, "arkNursery", 0.5, index / 100, now)
		assert(ok); local species = Catalog.Species[result.animal]
		assert(not species.eventOnly); assert(Catalog.Rarities[species.rarity].rank < 3)
		equal(p.inventory[result.animal], 1); equal(p.stats.catches, 0)
	end
end)
test("obscure chests can reveal legendary animals but never event mantas", function()
	local legendary = false
	for index = 0, 99 do
		local p = Rules.blank(now); local _, result = Rules.openChest(p, "canopyThicket", 0.5, index / 100, now)
		local species = Catalog.Species[result.animal]; assert(not species.eventOnly)
		if species.rarity == "Legendary" then legendary = true end
	end
	assert(legendary)
end)
test("an animal chest with a full pack trades the prize without exceeding capacity", function()
	local p = Rules.blank(now); p.inventory.rabbit = Config.BaseCapacity
	local _, result = Rules.openChest(p, "arkNursery", 0.5, 0, now)
	equal(result.animal, "rabbit"); equal(p.coins, 120); equal(p.points, 12)
	equal(Rules.count(p), Config.BaseCapacity); equal(p.discovered.rabbit, true)
end)
test("equipment chests award unowned permanent gear and fall back to coins when complete", function()
	local p = Rules.blank(now)
	local _, first = Rules.openChest(p, "arkNursery", 0.7, 0, now)
	equal(first.equipment, "rangerNet"); equal(p.owned.rangerNet, true)
	local _, second = Rules.openChest(p, "canopyEntry", 0.7, 0, now)
	assert(second.equipment ~= first.equipment)
	for _, id in Catalog.ChestEquipment do p.owned[id] = true end
	Rules.openChest(p, "canopyArchive", 0.7, 0, now); equal(p.coins, 220)
end)
test("point traps never create negative points or levels below one", function()
	local p = Rules.blank(now); p.points = 5
	local ok, result = Rules.openChest(p, "arkNursery", 0.9, 0, now)
	assert(ok); equal(result.kind, "pointsTrap"); equal(p.points, 0); equal(Rules.level(p.points), 1)
	equal(Rules.openChest(p, "arkNursery", 0, 0, now), false)
	p.points = 1000; Rules.openChest(p, "canopyEntry", 0.9, 0, now); equal(p.points, 880)
end)
test("death traps request character death while preserving inventory gear and checkpoints", function()
	local p = Rules.blank(now); p.inventory.fox = 1; p.owned.snorkel = true
	Rules.checkpoint(p, "canopyDock")
	local ok, result = Rules.openChest(p, "canopyEntry", 0.96, 0, now)
	assert(ok); equal(result.kill, true); equal(p.inventory.fox, 1); equal(p.owned.snorkel, true)
	equal(p.exploration.activeCheckpoint, "canopyDock")
	equal(Rules.openChest(Rules.sanitize(p, now), "canopyEntry", 0, 0, now), false)
end)
test("all five surprise outcomes occupy nonempty probability ranges", function()
	local expected = {"coins", "animal", "equipment", "pointsTrap", "deathTrap"}
	for index, roll in {0.1, 0.5, 0.7, 0.9, 0.98} do
		local _, result = Rules.openChest(Rules.blank(now), "arkNursery", roll, 0, now)
		equal(result.kind, expected[index])
	end
end)
test("island captures count only successful rescues in the correct region", function()
	local p = Rules.blank(now)
	equal(Rules.attempt(p, "rabbit", 0.999, now, false, "canopy"), false)
	equal(p.exploration.catches.canopy, nil)
	assert(Rules.attempt(p, "rabbit", 0, now, false, "canopy"))
	equal(p.exploration.catches.canopy, 1); equal(p.exploration.catches.moonstone, nil)
	Rules.openChest(p, "canopyEntry", 0.5, 0, now); equal(p.exploration.catches.canopy, 1)
end)
test("Canopy expedition requires all three checkpoints and four captures then pays once", function()
	local p = Rules.blank(now)
	for _, id in Catalog.Expeditions.canopySurvey.checkpoints do Rules.checkpoint(p, id) end
	for _ = 1, 3 do Rules.attempt(p, "rabbit", 0, now, false, "canopy") end
	equal(Rules.claim(p, "canopySurvey", now), false)
	Rules.attempt(p, "rabbit", 0, now, false, "canopy")
	local before = p.coins; assert(Rules.claim(p, "canopySurvey", now)); equal(p.coins, before + 300)
	equal(Rules.claim(p, "canopySurvey", now), false)
end)
test("Moonstone expedition requires a rare rescue in addition to its route and catch goal", function()
	local p = Rules.blank(now); p.owned.rangerNet = true
	for _, id in Catalog.Expeditions.moonstoneSurvey.checkpoints do Rules.checkpoint(p, id) end
	for _ = 1, 3 do Rules.attempt(p, "rabbit", 0, now, false, "moonstone") end
	equal(Rules.claim(p, "moonstoneSurvey", now), false)
	assert(Rules.attempt(p, "peacock", 0, now, false, "moonstone"))
	assert(Rules.claim(p, "moonstoneSurvey", now)); equal(p.exploration.rareCatches.moonstone, 1)
end)
test("the chest challenge counts distinct chests rather than repeated days", function()
	local p = Rules.blank(now)
	for day = 0, 2 do Rules.openChest(p, "arkNursery", 0, 0, now + day * 86400) end
	equal(Rules.claim(p, "chestScout", now), false)
	Rules.openChest(p, "canopyEntry", 0.9, 0, now); Rules.openChest(p, "moonstonePoint", 0.96, 0, now)
	assert(Rules.claim(p, "chestScout", now)); equal(Rules.claim(p, "chestScout", now), false)
end)
test("three-island rewards require the Ark and both island landings", function()
	local p = Rules.blank(now)
	Rules.checkpoint(p, "ark"); Rules.checkpoint(p, "canopyDock")
	equal(Rules.claim(p, "archipelagoVoyager", now), false)
	Rules.checkpoint(p, "moonstoneDock"); assert(Rules.claim(p, "archipelagoVoyager", now))
end)
test("layout checkpoint and chest IDs match their catalog exactly once", function()
	local checkpoints: {[string]: number}, chests: {[string]: number} = {}, {}
	local plans: {any} = {Layout}; for _, plan in Islands.Islands do table.insert(plans, plan) end
	for _, plan in plans do
		for _, cp in plan.Checkpoints do
			assert(Catalog.Checkpoints[cp.id] and Catalog.Checkpoints[cp.id].mapId == plan.Id)
			checkpoints[cp.id] = (checkpoints[cp.id] or 0) + 1
		end
		for _, chest in plan.Chests do assert(Catalog.Chests[chest.id]); chests[chest.id] = (chests[chest.id] or 0) + 1 end
	end
	for id in Catalog.Checkpoints do equal(checkpoints[id], 1) end
	for id in Catalog.Chests do equal(chests[id], 1) end
	for _, challenge in Catalog.Expeditions do for _, id in challenge.checkpoints do assert(Catalog.Checkpoints[id]) end end
end)
print(string.format("\n%d exploration/loot cases passed, %d failed (pure rules, not engine interactions)", passed, failed))
if failed > 0 then error("Exploration checks failed") end
