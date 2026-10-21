--!strict
local WildlifeRules = {}
function WildlifeRules.canVisit(species: any, zone: any, target: any): boolean
	return (species.rarity == "Common" or species.rarity == "Uncommon") and not zone.obscure and not zone.marine and target.mapId == zone.mapId and target.width >= species.scale * 9 + 0.5
end
function WildlifeRules.eligible(catalog: any, species: any, zone: any): boolean
	if species.eventOnly or species.habitat ~= zone.habitat then return false end
	return catalog.Rarities[species.rarity].rank < 3 or zone.obscure == true
end
function WildlifeRules.choose(catalog: any, zone: any, roll: number): string?
	if roll ~= roll or roll < 0 or roll >= 1 then return nil end
	local candidates, total = {}, 0
	for _, id in catalog.SpeciesOrder do
		local species = catalog.Species[id]
		if WildlifeRules.eligible(catalog, species, zone) and (not zone.species or table.find(zone.species, id)) then
			total += species.weight; table.insert(candidates, {id = id, edge = total})
		end
	end
	if total == 0 then return nil end
	for _, candidate in candidates do if roll * total < candidate.edge then return candidate.id end end
	return candidates[#candidates].id
end
return WildlifeRules
