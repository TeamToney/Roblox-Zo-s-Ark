--!strict
local WildlifeRules = {}
function WildlifeRules.canVisit(species: any, zone: any, target: any): boolean
	return (species.rarity == "Common" or species.rarity == "Uncommon") and not zone.obscure and not zone.marine and target.mapId == zone.mapId and target.width >= species.scale * 9 + 0.5
end
function WildlifeRules.eligible(_catalog: any, species: any, zone: any): boolean
	if species.eventOnly or species.nightOnly then return false end
	local marine = zone.habitat == "reef" or zone.habitat == "ocean"
	return species.habitat == zone.habitat or (marine and (species.form == "turtle" or species.form == "ray"))
end
function WildlifeRules.distribution(catalog: any, zone: any): {any}
	local groups: {[number]: any} = {}
	for _, id in catalog.SpeciesOrder do
		local species = catalog.Species[id]
		if WildlifeRules.eligible(catalog, species, zone) and (not zone.species or table.find(zone.species, id)) then
			local rank = catalog.Rarities[species.rarity].rank
			local group = groups[rank] or {weight = 0, ids = {}}
			group.weight += species.weight; table.insert(group.ids, id); groups[rank] = group
		end
	end
	local map = catalog.Maps[zone.mapId or "ark"] or catalog.Maps.ark
	local multiplier = (if zone.obscure then 1.8 else 1) * (if zone.seaway then 1.2 else 1)
	local rates = {[3] = (map.rare or catalog.Maps.ark.rare) * multiplier, [4] = (map.epic or catalog.Maps.ark.epic) * multiplier, [5] = (map.legendary or catalog.Maps.ark.legendary) * multiplier}
	local special = 0
	for rank, rate in rates do if groups[rank] then special += rate end end
	local ordinary = (if groups[1] then groups[1].weight else 0) + (if groups[2] then groups[2].weight else 0)
	local result = {}
	-- Missing rarity budgets flow back to the ordinary pool. Specialty-only
	-- imported zones normalize the budgets of their available species.
	for rank = 1, 5 do
		local group = groups[rank]
		if not group then continue end
		local budget = if rank < 3 then (1 - special) * group.weight / math.max(1, ordinary) else rates[rank]
		if ordinary == 0 then budget = (rates[rank] or 0) / math.max(0.000001, special) end
		for _, id in group.ids do table.insert(result, {id = id, probability = budget * catalog.Species[id].weight / group.weight}) end
	end
	return result
end
function WildlifeRules.choose(catalog: any, zone: any, roll: number): string?
	if roll ~= roll or roll < 0 or roll >= 1 then return nil end
	local pool = WildlifeRules.distribution(catalog, zone)
	local edge = 0
	for _, entry in pool do edge += entry.probability; if roll < edge then return entry.id end end
	return if #pool > 0 then pool[#pool].id else nil
end
return WildlifeRules
