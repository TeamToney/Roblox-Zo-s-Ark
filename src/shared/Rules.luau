--!strict
-- Pure, deterministic domain logic. Roblox services and randomness stay on the server.
export type Profile = {
	coins: number, points: number, inventory: {[string]: number}, owned: {[string]: boolean},
	discovered: {[string]: boolean}, titles: {[string]: boolean}, bait: number,
	stats: {catches: number, rare: number, distance: number, traded: number, walkDistance: number, swimDistance: number},
	daily: {day: number, catches: number, rare: number, distance: number, claimed: {[string]: boolean}},
	event: {id: number, captures: number, claimed: boolean},
	exploration: {checkpoints: {[string]: boolean}, activeCheckpoint: string, claimed: {[string]: boolean}, chests: {[string]: number}, catches: {[string]: number}, rareCatches: {[string]: number}},
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
			stats = {catches = 0, rare = 0, distance = 0, traded = 0, walkDistance = 0, swimDistance = 0},
			daily = {day = math.floor(now / 86400), catches = 0, rare = 0, distance = 0, claimed = {}},
			event = {id = -2, captures = 0, claimed = false},
			exploration = {checkpoints = {}, activeCheckpoint = "", claimed = {}, chests = {}, catches = {}, rareCatches = {}},
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
			-- Additive fields default to zero for existing v1 journals. Preserve
			-- fractional strides so reconnecting neither duplicates nor loses bonuses.
			for _, key in {"walkDistance", "swimDistance", "distance"} do
				local value = raw.stats[key]
				if type(value) == "number" and value == value and math.abs(value) < math.huge then
					(p.stats :: any)[key] = math.clamp(value, 0, 1000000000)
				end
			end
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
		if type(raw.exploration) == "table" then
			local e = raw.exploration
			for id in catalog.Checkpoints do
				if type(e.checkpoints) == "table" and e.checkpoints[id] == true then p.exploration.checkpoints[id] = true end
			end
			if type(e.activeCheckpoint) == "string" and p.exploration.checkpoints[e.activeCheckpoint] then p.exploration.activeCheckpoint = e.activeCheckpoint end
			for id in catalog.Expeditions do if type(e.claimed) == "table" and e.claimed[id] == true then p.exploration.claimed[id] = true end end
			for id in catalog.Chests do
				if type(e.chests) == "table" and type(e.chests[id]) == "number" and e.chests[id] == e.chests[id] and e.chests[id] >= 0 and e.chests[id] <= math.floor(now / 86400) then
					p.exploration.chests[id] = integer(e.chests[id], 0, math.floor(now / 86400))
				end
			end
			for _, mapId in {"ark", "canopy", "moonstone"} do
				p.exploration.catches[mapId] = integer(if type(e.catches) == "table" then e.catches[mapId] else nil, 0)
				p.exploration.rareCatches[mapId] = integer(if type(e.rareCatches) == "table" then e.rareCatches[mapId] else nil, 0)
			end
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
	function api.attempt(p: Profile, id: string, roll: number, now: number, preview: boolean?, mapId: string?): (boolean, string)
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
		local region = if mapId == "canopy" or mapId == "moonstone" then mapId else "ark"
		p.exploration.catches[region] = (p.exploration.catches[region] or 0) + 1
		if catalog.Rarities[animal.rarity].rank >= 3 then p.exploration.rareCatches[region] = (p.exploration.rareCatches[region] or 0) + 1 end
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
	-- Steps/strokes are estimated from verified server displacement, never a
	-- client-supplied counter. Boats, airborne movement and teleports are excluded
	-- by the server sampler as well as these mode/speed/interval checks.
	function api.movement(p: Profile, mode: string, distance: number, elapsed: number): number
		if mode ~= "walk" and mode ~= "swim" then return 0 end
		local swimming = mode == "swim"
		local speed = if swimming then config.MaxSwimPerSecond else config.MaxWalkPerSecond
		if distance ~= distance or distance < 0.15 or distance == math.huge or elapsed ~= elapsed or elapsed <= 0 or elapsed > 2 or distance > speed * elapsed then return 0 end
		local key = if swimming then "swimDistance" else "walkDistance"
		local stride = if swimming then config.StrokeStuds else config.StepStuds
		local stats: any = p.stats
		local before = stats[key]
		local after = math.min(1000000000, before + distance)
		stats[key] = after
		local awards = math.floor(after / (stride * config.MovementBonusEvery)) - math.floor(before / (stride * config.MovementBonusEvery))
		p.coins += awards * (if swimming then config.SwimBonusCoins else config.WalkBonusCoins)
		p.points += awards * (if swimming then config.SwimBonusPoints else config.WalkBonusPoints)
		return awards
	end
	function api.checkpoint(p: Profile, id: string): (boolean, string)
		local checkpoint = catalog.Checkpoints[id]
		if not checkpoint then return false, "Unknown checkpoint." end
		p.exploration.activeCheckpoint = id
		if p.exploration.checkpoints[id] then return true, "Respawn set to " .. checkpoint.name .. "." end
		p.exploration.checkpoints[id] = true; p.coins += 15; p.points += 10
		return true, "Checkpoint: " .. checkpoint.name .. "! +15 coins • +10 points. Respawn saved."
	end
	function api.expeditionProgress(p: Profile, id: string): (number, number)
		local challenge = catalog.Expeditions[id]
		if not challenge then return 0, 1 end
		local value, goal = 0, #challenge.checkpoints + challenge.catches + challenge.rare + (challenge.chests or 0)
		for _, cp in challenge.checkpoints do if p.exploration.checkpoints[cp] then value += 1 end end
		if challenge.mapId then
			value += math.min(challenge.catches, p.exploration.catches[challenge.mapId] or 0)
			value += math.min(challenge.rare, p.exploration.rareCatches[challenge.mapId] or 0)
		end
		if challenge.chests then
			local count = 0; for _ in p.exploration.chests do count += 1 end
			value += math.min(challenge.chests, count)
		end
		return value, goal
	end
	function api.openChest(p: Profile, id: string, roll: number, choice: number, now: number): (boolean, any)
		local chest = catalog.Chests[id]
		if not chest or roll ~= roll or choice ~= choice or roll < 0 or roll >= 1 or choice < 0 or choice >= 1 then return false, {message = "Invalid chest."} end
		local day = math.floor(now / 86400)
		if (p.exploration.chests[id] or -1) >= day then return false, {message = "You already opened this chest today. Try another one!"} end
		local total = 0; for _, outcome in catalog.Loot do total += outcome.weight end
		local kind, edge = "coins", 0
		for _, outcome in catalog.Loot do edge += outcome.weight; if roll * total < edge then kind = outcome.kind; break end end
		-- No yield occurs between reserving today's opening and applying its result.
		p.exploration.chests[id] = day
		local result: any = {kind = kind, kill = false}
		if kind == "animal" then
			local pool = {}
			for _, speciesId in catalog.SpeciesOrder do
				local animal = catalog.Species[speciesId]
				if not animal.eventOnly and (chest.obscure or catalog.Rarities[animal.rarity].rank < 3) then table.insert(pool, speciesId) end
			end
			local speciesId = pool[math.floor(choice * #pool) + 1]
			local animal = catalog.Species[speciesId]; result.animal = speciesId
			p.discovered[speciesId] = true; p.points += animal.points
			if api.count(p) >= api.capacity(p) then
				p.coins += animal.value; result.message = "Found " .. animal.name .. "! Your pack is full: prize converted to +" .. animal.value .. " coins, +" .. animal.points .. " points."
			else
				p.inventory[speciesId] = (p.inventory[speciesId] or 0) + 1
				result.message = "An animal was hiding inside: " .. animal.name .. "! +" .. animal.points .. " points."
			end
		elseif kind == "equipment" then
			local pool = {}; for _, itemId in catalog.ChestEquipment do if not p.owned[itemId] then table.insert(pool, itemId) end end
			if #pool > 0 then
				local itemId = pool[math.floor(choice * #pool) + 1]; p.owned[itemId] = true; result.equipment = itemId
				result.message = "Hidden equipment: " .. catalog.Items[itemId].name .. "! It is now active."
			else p.coins += 120; result.message = "You own all the chest equipment. Found 120 coins instead!" end
		elseif kind == "pointsTrap" then
			local lost = math.min(p.points, math.max(10, math.floor(p.points * 0.12)))
			p.points -= lost; result.message = "Point trap! Lost " .. lost .. " Ark Points."
		elseif kind == "deathTrap" then result.kill = true; result.message = "A surprise trap! Respawning at your active checkpoint."
		else
			local coins = 40 + math.floor(choice * 111); p.coins += coins; result.message = "Treasure! Found " .. coins .. " coins."
		end
		return true, result
	end
	function api.claim(p: Profile, id: string, now: number, preview: boolean?): (boolean, string)
		api.refresh(p, now)
		local expedition = catalog.Expeditions[id]
		if expedition then
			if p.exploration.claimed[id] then return false, "Expedition prize already claimed." end
			local value, goal = api.expeditionProgress(p, id)
			if value < goal then return false, "Keep exploring to finish this expedition." end
			p.exploration.claimed[id] = true; p.coins += expedition.coins; p.points += expedition.points
			return true, "Expedition complete! +" .. expedition.coins .. " coins • +" .. expedition.points .. " Ark Points"
		end
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
