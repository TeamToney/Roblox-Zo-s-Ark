--!strict
-- Pure, deterministic domain logic. Roblox services and randomness stay on the server.
export type Profile = {
	coins: number, points: number, inventory: {[string]: number}, owned: {[string]: boolean},
	discovered: {[string]: boolean}, titles: {[string]: boolean}, bait: number,
	stats: {catches: number, rare: number, distance: number, traded: number},
	daily: {day: number, catches: number, rare: number, distance: number, claimed: {[string]: boolean}},
	event: {id: number, captures: number, claimed: boolean},
}
local Rules = {}

local function integer(value: any, default: number, maximum: number?): number
	if type(value) ~= "number" or value ~= value or math.abs(value) == math.huge then
		return default
	end
	return math.clamp(math.floor(value), 0, maximum or 1000000000)
end

function Rules.new(catalog: any, config: any)
	local api = {}
	function api.eventWindow(now: number, preview: boolean?)
		local phase = now % config.EventPeriod
		return {
			id = if preview then -1 else math.floor(now / config.EventPeriod),
			active = preview == true or phase < config.EventDuration,
			remaining = if preview then config.EventDuration else (if phase < config.EventDuration then config.EventDuration - phase else config.EventPeriod - phase),
		}
	end
	function api.blank(now: number): Profile
		return {
			coins = config.StartingCoins, points = 0, inventory = {}, owned = {}, discovered = {}, titles = {}, bait = 0,
			stats = {catches = 0, rare = 0, distance = 0, traded = 0},
			daily = {day = math.floor(now / 86400), catches = 0, rare = 0, distance = 0, claimed = {}},
			event = {id = -2, captures = 0, claimed = false},
		}
	end
	function api.refresh(p: Profile, now: number)
		local day = math.floor(now / 86400)
		if p.daily.day ~= day then
			p.daily = {day = day, catches = 0, rare = 0, distance = 0, claimed = {}}
		end
	end
	function api.sanitize(raw: any, now: number): Profile
		local p = api.blank(now)
		if type(raw) ~= "table" then return p end
		p.coins = integer(raw.coins, config.StartingCoins)
		p.points = integer(raw.points, 0)
		p.bait = integer(raw.bait, 0, 999)
		for id in catalog.Species do
			p.inventory[id] = integer(if type(raw.inventory) == "table" then raw.inventory[id] else nil, 0, 1000)
			if type(raw.discovered) == "table" and raw.discovered[id] == true then p.discovered[id] = true end
		end
		for id in catalog.Items do
			if type(raw.owned) == "table" and raw.owned[id] == true then p.owned[id] = true end
		end
		if type(raw.titles) == "table" and raw.titles[config.EventTitle] == true then p.titles[config.EventTitle] = true end
		if type(raw.stats) == "table" then
			for key in p.stats :: any do (p.stats :: any)[key] = integer(raw.stats[key], 0) end
		end
		if type(raw.daily) == "table" and raw.daily.day == p.daily.day then
			for _, key in {"catches", "rare", "distance"} do
				(p.daily :: any)[key] = integer(raw.daily[key], 0)
			end
			if type(raw.daily.claimed) == "table" then
				for id in catalog.Challenges do p.daily.claimed[id] = raw.daily.claimed[id] == true end
			end
		end
		if type(raw.event) == "table" then
			p.event = {id = if type(raw.event.id) == "number" and raw.event.id == raw.event.id and math.abs(raw.event.id) < 1000000000 then math.floor(raw.event.id) else -2, captures = integer(raw.event.captures, 0), claimed = raw.event.claimed == true}
		end
		return p
	end
	function api.capacity(p: Profile): number
		return if p.owned.fieldPack then catalog.Items.fieldPack.capacity else config.BaseCapacity
	end
	function api.count(p: Profile): number
		local count = 0
		for _, amount in p.inventory do count += amount end
		return count
	end
	function api.tier(p: Profile): number
		local tier = 1
		for id, item in catalog.Items do
			if p.owned[id] and item.kind == "net" then tier = math.max(tier, item.tier) end
		end
		return tier
	end
	function api.level(points: number): number
		return 1 + math.floor(math.sqrt(points / 120))
	end
	function api.chance(p: Profile, id: string): (number?, string?)
		local animal = catalog.Species[id]
		if not animal then return nil, "Unknown animal." end
		if api.count(p) >= api.capacity(p) then return nil, "Your pack is full. Trade at the Ark." end
		local tier = api.tier(p)
		if tier < animal.tier then return nil, "This animal needs Tier " .. animal.tier .. " rescue gear." end
		if animal.gear and not p.owned[animal.gear] and not (animal.gear == "snorkel" and p.owned.diving) then
			return nil, "Buy the " .. catalog.Items[animal.gear].name .. " at the Ark first."
		end
		return math.clamp(0.93 - animal.difficulty + (tier - 1) * 0.08 + (if p.bait > 0 then 0.15 else 0), 0.12, 0.96), nil
	end
	function api.attempt(p: Profile, id: string, roll: number, now: number, preview: boolean?): (boolean, string)
		if type(roll) ~= "number" or roll ~= roll or roll < 0 or roll >= 1 then return false, "Invalid capture roll." end
		local animal = catalog.Species[id]
		if not animal then return false, "Unknown animal." end
		local event = api.eventWindow(now, preview)
		if animal.eventOnly and not event.active then return false, "The Aurora Tide event has ended." end
		if animal.eventOnly and p.event.id == event.id and p.event.captures >= config.EventGoal then return false, "You rescued this tide's three mantas! Claim your prize on the expedition board." end
		local chance, reason = api.chance(p, id)
		if not chance then return false, reason or "Unable to capture." end
		api.refresh(p, now)
		if p.bait > 0 then p.bait -= 1 end
		if roll >= chance then return false, "Nearly! The animal slipped away. Try again." end
		p.inventory[id] = (p.inventory[id] or 0) + 1
		p.discovered[id] = true
		p.stats.catches += 1
		p.daily.catches += 1
		if catalog.Rarities[animal.rarity].rank >= 3 then p.stats.rare += 1; p.daily.rare += 1 end
		local coins = math.max(1, math.floor(animal.value * 0.2))
		p.coins += coins
		p.points += animal.points
		if animal.eventOnly then
			if p.event.id ~= event.id then p.event = {id = event.id, captures = 0, claimed = false} end
			p.event.captures += 1
		end
		return true, "Collected " .. animal.name .. "! +" .. coins .. " coins • +" .. animal.points .. " Ark Points"
	end
	function api.buy(p: Profile, id: string): (boolean, string)
		local item = catalog.Items[id]
		if not item then return false, "Unknown item." end
		if item.kind ~= "consumable" and p.owned[id] then return false, "You already own this upgrade." end
		if item.kind == "consumable" and p.bait > 994 then return false, "You have enough bait for now." end
		if p.coins < item.price then return false, "You need " .. (item.price - p.coins) .. " more coins." end
		p.coins -= item.price
		if item.kind == "consumable" then p.bait += 5 else p.owned[id] = true end
		return true, "Purchased " .. item.name .. ". Permanent gear is used automatically."
	end
	function api.sell(p: Profile, id: string, amount: number): (boolean, string)
		local animal = catalog.Species[id]
		if not animal or type(amount) ~= "number" or amount ~= amount or amount % 1 ~= 0 or amount < 1 or amount > 1000 then return false, "Invalid trade." end
		if (p.inventory[id] or 0) < amount then return false, "You do not have that many animals." end
		p.inventory[id] -= amount
		p.coins += animal.value * amount
		p.stats.traded += amount
		return true, "Traded " .. amount .. " " .. animal.name .. " to the sanctuary for " .. (animal.value * amount) .. " coins."
	end
	function api.travel(p: Profile, distance: number, elapsed: number, now: number): boolean
		if type(distance) ~= "number" or distance ~= distance or distance <= 0 or elapsed ~= elapsed or elapsed <= 0 or elapsed > 5 or distance > config.MaxTravelPerSecond * elapsed then return false end
		api.refresh(p, now)
		local before = math.floor(p.stats.distance / config.DistanceStep)
		p.stats.distance += distance
		p.daily.distance += distance
		local milestones = math.floor(p.stats.distance / config.DistanceStep) - before
		p.coins += milestones * config.DistanceCoins
		p.points += milestones * config.DistancePoints
		return milestones > 0
	end
	function api.claim(p: Profile, id: string, now: number, preview: boolean?): (boolean, string)
		api.refresh(p, now)
		if id == "event" then
			local event = api.eventWindow(now, preview)
			if not event.active or p.event.id ~= event.id or p.event.captures < config.EventGoal then return false, "Collect " .. config.EventGoal .. " Aurora Mantas during this tide." end
			if p.event.claimed then return false, "You already claimed this tide's prize." end
			p.event.claimed = true
			p.coins += config.EventCoins; p.points += config.EventPoints; p.titles[config.EventTitle] = true
			return true, "Aurora Tide complete! +350 coins, +250 Ark Points, and the Aurora Voyager title."
		end
		local challenge = catalog.Challenges[id]
		if not challenge then return false, "Unknown challenge." end
		if p.daily.claimed[id] then return false, "Reward already claimed today." end
		if (p.daily :: any)[id] < challenge.goal then return false, "Keep exploring to finish this challenge." end
		p.daily.claimed[id] = true; p.coins += challenge.coins; p.points += challenge.points
		return true, "Challenge complete! +" .. challenge.coins .. " coins • +" .. challenge.points .. " Ark Points"
	end
	return api
end
return Rules
