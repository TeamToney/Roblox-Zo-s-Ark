--!strict
local Config = require("../src/shared/Config")
local Swim = require("../src/shared/SwimRules").new(Config)
local passed, failed = 0, 0
local function test(name: string, callback: () -> ())
	local ok, problem = pcall(callback)
	if ok then passed += 1; print("PASS  " .. name) else failed += 1; print("FAIL  " .. name .. ": " .. tostring(problem)) end
end
local function equal(actual: any, expected: any) assert(actual == expected, "expected " .. tostring(expected) .. ", got " .. tostring(actual)) end
test("starter endurance lasts thirty seconds even while stationary in water", function()
	local s = Swim.blank()
	for _ = 1, 120 do equal(Swim.advance(s, {}, true, 0.25), 0) end
	equal(Swim.snapshot(s, {}, true).remaining, 0)
	equal(Swim.advance(s, {}, true, 1), 10)
end)
test("only the exhausted portion of a tick damages health", function()
	local s = Swim.blank(); s.used = 29.75
	equal(Swim.advance(s, {}, true, 0.5), 2.5); equal(s.used, 30)
end)
test("snorkel and diving capacities do not double-count snorkel ownership", function()
	equal(Swim.limit({}), 30); equal(Swim.limit({snorkel = true}), 60)
	equal(Swim.limit({diving = true}), 180); equal(Swim.limit({diving = true, snorkel = true}), 180)
end)
test("a life jacket adds sixty seconds to each equipment tier", function()
	equal(Swim.limit({lifeJacket = true}), 90)
	equal(Swim.limit({lifeJacket = true, snorkel = true}), 120)
	equal(Swim.limit({lifeJacket = true, diving = true}), 240)
end)
test("ground and boat rest recover endurance without exceeding capacity", function()
	local s = Swim.blank(); s.used = 20
	equal(Swim.advance(s, {}, false, 1, true), 0); equal(s.used, 12)
	Swim.advance(s, {}, false, 2, true); equal(s.used, 0)
end)
test("airtime and jumping cannot refill swim endurance", function()
	local s = Swim.blank(); s.used = 25
	Swim.advance(s, {}, false, 1, false); equal(s.used, 25)
end)
test("life rings restore endurance and prevent fatigue for twenty seconds", function()
	local s = Swim.blank(); s.used = 30
	local ok, heal = Swim.pickup(s, "float"); equal(ok, true); equal(heal, 0); equal(s.used, 15)
	for _ = 1, 20 do equal(Swim.advance(s, {}, true, 1), 0) end
	equal(s.used, 15); equal(s.floating, 0)
	Swim.advance(s, {}, true, 1); equal(s.used, 16)
end)
test("a flotation period ending mid-tick charges only unsupported time", function()
	local s = Swim.blank(); s.used = 30; s.floating = 0.25
	equal(Swim.advance(s, {}, true, 0.5), 2.5); equal(s.floating, 0)
end)
test("first aid restores twenty seconds and requests twenty-five health", function()
	local s = Swim.blank(); s.used = 28
	local ok, heal = Swim.pickup(s, "health"); equal(ok, true); equal(heal, 25); equal(s.used, 8)
	Swim.pickup(s, "health"); equal(s.used, 0)
end)
test("repeated life rings cannot stack an unbounded flotation timer", function()
	local s = Swim.blank()
	for _ = 1, 100 do Swim.pickup(s, "float") end
	equal(s.floating, 20); equal(s.used, 0)
end)
test("unknown pickups and invalid elapsed time never change state", function()
	local s = Swim.blank(); s.used = 20; s.floating = 5
	equal(Swim.pickup(s, "freeAir"), false)
	for _, dt in {-1, 0, 3, 0 / 0, math.huge} do equal(Swim.advance(s, {}, true, dt), 0) end
	equal(s.used, 20); equal(s.floating, 5)
end)
test("equipment upgrades preserve fatigue and respawns start a fresh reserve", function()
	local s = Swim.blank(); s.used = 25
	equal(Swim.snapshot(s, {snorkel = true}, true).remaining, 35)
	equal(Swim.snapshot(Swim.blank(), {}, false).remaining, 30)
end)
print(string.format("\n%d swim-endurance cases passed, %d failed (pure rules, not Roblox physics)", passed, failed))
if failed > 0 then error("Swim-endurance checks failed") end
