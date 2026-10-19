--!strict
local Config = require("../src/shared/Config")
local Catalog = require("../src/shared/Catalog")
local Rules = require("../src/shared/Rules").new(Catalog, Config)
local passed, failed = 0, 0
local now = 1800000000 -- Event start, with a stable daily bucket.
local function test(name: string, callback: () -> ())
	local ok, problem = pcall(callback)
	if ok then passed += 1; print("PASS  " .. name)
	else failed += 1; print("FAIL  " .. name .. ": " .. tostring(problem)) end
end
local function equal(actual: any, expected: any)
	assert(actual == expected, "expected " .. tostring(expected) .. ", got " .. tostring(actual))
end
local function expedition()
	local p = Rules.blank(now)
	p.owned.tranquilizer = true; p.owned.diving = true
	return p
end

test("fresh journals have independent collections and claims", function()
	local a, b = Rules.blank(now), Rules.blank(now)
	a.inventory.rabbit = 1; a.daily.claimed.catches = true
	equal(b.inventory.rabbit, nil); equal(b.daily.claimed.catches, nil)
	equal(a.coins, 100); equal(Rules.level(a.points), 1)
end)
test("successful rescue awards the exact stipend, points and discovery", function()
	local p = Rules.blank(now)
	assert(Rules.attempt(p, "rabbit", 0, now))
	equal(p.inventory.rabbit, 1); equal(p.coins, 104); equal(p.points, 12)
	equal(p.stats.catches, 1); equal(p.daily.catches, 1); equal(p.discovered.rabbit, true)
end)
test("failed eligible capture consumes one bait and awards nothing", function()
	local p = Rules.blank(now); p.bait = 2
	equal(Rules.attempt(p, "rabbit", 0.999, now), false)
	equal(p.bait, 1); equal(p.coins, 100); equal(p.points, 0); equal(Rules.count(p), 0)
end)
test("ineligible attempts do not consume bait", function()
	local p = Rules.blank(now); p.bait = 2
	equal(Rules.attempt(p, "deer", 0, now), false)
	equal(p.bait, 2); equal(p.coins, 100)
end)
test("a full pack rejects captures without consuming bait", function()
	local p = Rules.blank(now); p.inventory.rabbit = Config.BaseCapacity; p.bait = 1
	equal(Rules.attempt(p, "fox", 0, now), false)
	equal(Rules.count(p), Config.BaseCapacity); equal(p.bait, 1)
end)
test("unknown species and invalid random rolls never award animals", function()
	local p = Rules.blank(now)
	for _, roll in {-1, 1, math.huge, 0 / 0} do equal(Rules.attempt(p, "rabbit", roll, now), false) end
	equal(Rules.attempt(p, "dragon", 0, now), false); equal(Rules.count(p), 0)
end)
test("better gear and bait improve odds with a hard ceiling", function()
	local p = Rules.blank(now)
	local original = Rules.chance(p, "rabbit") :: number
	p.owned.rangerNet = true
	assert((Rules.chance(p, "rabbit") :: number) > original)
	p.bait = 1
	equal(Rules.chance(p, "rabbit"), 0.96)
end)
test("sea equipment remains required even with top-tier rescue gear", function()
	local p = Rules.blank(now); p.owned.tranquilizer = true
	equal(Rules.chance(p, "seaTurtle"), nil)
	p.owned.snorkel = true
	assert(Rules.chance(p, "seaTurtle")); equal(Rules.chance(p, "whale"), nil)
	p.owned.diving = true; p.owned.snorkel = nil
	assert(Rules.chance(p, "seaTurtle")); assert(Rules.chance(p, "whale"))
end)
test("rare rescues advance daily and lifetime rare counts", function()
	local p = expedition()
	assert(Rules.attempt(p, "parrot", 0, now))
	equal(p.stats.rare, 1); equal(p.daily.rare, 1)
end)
test("purchases debit the catalog price and cannot be bought twice", function()
	local p = Rules.blank(now); p.coins = 1000
	assert(Rules.buy(p, "rangerNet")); equal(p.coins, 820); equal(Rules.tier(p), 2)
	equal(Rules.buy(p, "rangerNet"), false); equal(p.coins, 820)
end)
test("insufficient funds and unknown items leave the profile intact", function()
	local p = Rules.blank(now)
	equal(Rules.buy(p, "tranquilizer"), false); equal(Rules.buy(p, "fake"), false)
	equal(p.coins, 100); equal(Rules.tier(p), 1)
end)
test("pack upgrades immediately increase usable capacity", function()
	local p = Rules.blank(now); p.coins = 500; p.inventory.rabbit = 24
	assert(Rules.buy(p, "fieldPack")); equal(Rules.capacity(p), 48)
	assert(Rules.attempt(p, "rabbit", 0, now)); equal(Rules.count(p), 25)
end)
test("bait is a repeatable bounded consumable", function()
	local p = Rules.blank(now); p.coins = 1000
	assert(Rules.buy(p, "bait")); assert(Rules.buy(p, "bait"))
	equal(p.bait, 10); equal(p.coins, 860); equal(p.owned.bait, nil)
	p.bait = 995; equal(Rules.buy(p, "bait"), false); equal(p.coins, 860)
end)
test("sanctuary transfers preserve discoveries and Ark Points", function()
	local p = Rules.blank(now)
	assert(Rules.attempt(p, "rabbit", 0, now)); assert(Rules.sell(p, "rabbit", 1))
	equal(p.coins, 124); equal(p.inventory.rabbit, 0); equal(p.discovered.rabbit, true)
	equal(p.points, 12); equal(p.stats.traded, 1); equal(p.daily.catches, 1)
	equal(Rules.sell(p, "rabbit", 1), false); equal(p.coins, 124)
end)
test("malformed trade quantities cannot mint money or animals", function()
	local p = Rules.blank(now); p.inventory.rabbit = 4
	local amounts: {any} = {0, -1, 0.5, 5, 1001, math.huge, 0 / 0, "1", {}, false}
	for _, amount in amounts do equal(Rules.sell(p, "rabbit", amount), false) end
	equal(Rules.sell(p, "rabbit", nil :: any), false)
	equal(Rules.sell(p, "fake", 1), false)
	equal(p.coins, 100); equal(p.inventory.rabbit, 4)
end)
test("bulk transfers are atomic and use listed values", function()
	local p = expedition(); p.inventory.whale = 2
	assert(Rules.sell(p, "whale", 2)); equal(p.coins, 2900); equal(p.stats.traded, 2)
	equal(Rules.sell(p, "whale", 2), false); equal(p.coins, 2900)
end)
test("travel rewards occur exactly at 500-stud boundaries", function()
	local p = Rules.blank(now)
	for _ = 1, 49 do equal(Rules.travel(p, 10, 1, now), false) end
	equal(p.coins, 100)
	equal(Rules.travel(p, 10, 1, now), true)
	equal(p.stats.distance, 500); equal(p.coins, 125); equal(p.points, 15)
	equal(Rules.travel(p, 1, 1, now), false); equal(p.coins, 125)
end)
test("teleports and invalid travel intervals earn nothing", function()
	local p = Rules.blank(now)
	for _, pair in {{1000, 1}, {10, 0}, {10, -1}, {10, 6}, {-1, 1}, {0 / 0, 1}, {math.huge, 1}, {10, 0 / 0}} do
		equal(Rules.travel(p, pair[1], pair[2], now), false)
	end
	equal(p.stats.distance, 0); equal(p.daily.distance, 0); equal(p.coins, 100)
end)
test("a daily reward must be earned and can only be claimed once", function()
	local p = Rules.blank(now)
	equal(Rules.claim(p, "catches", now), false)
	for _ = 1, 8 do assert(Rules.attempt(p, "rabbit", 0, now)) end
	local before = p.coins
	assert(Rules.claim(p, "catches", now)); equal(p.coins, before + 150)
	equal(Rules.claim(p, "catches", now), false); equal(p.coins, before + 150)
	equal(Rules.claim(p, "unknown", now), false)
end)
test("daily claims reset at UTC midnight without resetting lifetime stats", function()
	local p = Rules.blank(now); p.daily.catches = 8; p.stats.catches = 8
	assert(Rules.claim(p, "catches", now))
	Rules.refresh(p, (p.daily.day + 1) * 86400)
	equal(p.daily.catches, 0); equal(p.daily.claimed.catches, nil); equal(p.stats.catches, 8)
	equal(Rules.claim(p, "catches", (math.floor(now / 86400) + 1) * 86400), false)
end)
test("travel is credited to the new daily bucket after midnight", function()
	local p = Rules.blank(now); p.daily.distance = 1000
	Rules.travel(p, 20, 1, (p.daily.day + 1) * 86400)
	equal(p.daily.distance, 20); equal(p.stats.distance, 20)
end)
test("event activation and countdowns are correct at both boundaries", function()
	equal(Rules.eventWindow(now).active, true)
	equal(Rules.eventWindow(now + 479).remaining, 1)
	equal(Rules.eventWindow(now + 480).active, false)
	equal(Rules.eventWindow(now + 480).remaining, 1320)
	equal(Rules.eventWindow(now + 1800).active, true)
	equal(Rules.eventWindow(now + 1800).id, Rules.eventWindow(now).id + 1)
	equal(Rules.eventWindow(now + 900, true).active, true)
end)
test("inactive event animals give no reward or bait consumption", function()
	local p = expedition(); p.bait = 3
	equal(Rules.attempt(p, "auroraRay", 0, now + 900), false)
	equal(p.coins, 100); equal(p.bait, 3)
end)
test("event prize requires three catches in this tide and claims only once", function()
	local p = expedition()
	equal(Rules.claim(p, "event", now), false)
	for _ = 1, 3 do assert(Rules.attempt(p, "auroraRay", 0, now)) end
	local before = p.coins
	assert(Rules.claim(p, "event", now)); equal(p.coins, before + Config.EventCoins)
	equal(p.titles[Config.EventTitle], true); equal(p.event.claimed, true)
	equal(Rules.claim(p, "event", now), false); equal(p.coins, before + Config.EventCoins)
end)
test("a personal event rescue limit keeps the rare prize scarce", function()
	local p = expedition()
	for _ = 1, 3 do assert(Rules.attempt(p, "auroraRay", 0, now)) end
	equal(Rules.attempt(p, "auroraRay", 0, now), false); equal(p.inventory.auroraRay, 3)
end)
test("past event progress cannot claim a new tide's prize", function()
	local p = expedition()
	for _ = 1, 3 do assert(Rules.attempt(p, "auroraRay", 0, now)) end
	equal(Rules.claim(p, "event", now + 480), false)
	equal(Rules.claim(p, "event", now + 1800), false)
	assert(Rules.attempt(p, "auroraRay", 0, now + 1800))
	equal(p.event.captures, 1); equal(p.event.claimed, false)
end)
test("sanitization removes unknown items and invalid numeric values", function()
	local p = Rules.sanitize({coins = 0 / 0, points = math.huge, bait = -3, inventory = {rabbit = 2.9, dragon = 100, fox = -1}, owned = {tranquilizer = true, freeMoney = true}, discovered = {rabbit = true, dragon = true}}, now)
	equal(p.coins, 100); equal(p.points, 0); equal(p.bait, 0)
	equal(p.inventory.rabbit, 2); equal(p.inventory.fox, 0); equal(p.inventory.dragon, nil)
	equal(p.owned.tranquilizer, true); equal(p.owned.freeMoney, nil); equal(p.discovered.dragon, nil)
end)
test("valid saved progress and current-day claims survive loading", function()
	local p = expedition(); p.daily.catches = 8; p.inventory.parrot = 2
	p.daily.claimed.catches = true; p.titles[Config.EventTitle] = true; p.coins = 500
	local restored = Rules.sanitize(p, now)
	equal(restored.coins, 500); equal(restored.inventory.parrot, 2)
	equal(restored.daily.claimed.catches, true); equal(restored.titles[Config.EventTitle], true)
	equal(restored.owned.diving, true)
	local nextDay = Rules.sanitize(p, now + 86400)
	equal(nextDay.daily.catches, 0); equal(nextDay.daily.claimed.catches, nil)
end)
test("all catalog entries have valid habitats, rarity, prices and access gear", function()
	for _, id in Catalog.SpeciesOrder do
		local species = Catalog.Species[id]
		assert(species and Catalog.Rarities[species.rarity]); assert(species.tier >= 1 and species.tier <= 4)
		assert(species.value > 0 and species.points > 0 and species.weight > 0)
		if species.gear then assert(Catalog.Items[species.gear]) end
	end
	for _, id in Catalog.ItemOrder do assert(Catalog.Items[id].price > 0) end
end)
test("a long mixed session preserves currency and inventory invariants", function()
	math.randomseed(42)
	local p = Rules.blank(now)
	for step = 1, 1000 do
		local choice = math.random(1, 5)
		if choice == 1 then Rules.attempt(p, "rabbit", math.random(), now)
		elseif choice == 2 then Rules.sell(p, "rabbit", math.random(0, 3))
		elseif choice == 3 then Rules.buy(p, Catalog.ItemOrder[math.random(1, #Catalog.ItemOrder)])
		elseif choice == 4 then Rules.travel(p, math.random(0, 60), 1, now)
		else Rules.claim(p, "catches", now) end
		assert(p.coins >= 0 and p.coins % 1 == 0, "invalid currency at step " .. step)
		assert(Rules.count(p) <= Rules.capacity(p)); assert((p.inventory.rabbit or 0) >= 0)
	end
end)

print(string.format("\n%d passed, %d failed", passed, failed))
if failed > 0 then error("Zo's Ark domain checks failed") end
