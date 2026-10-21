--!strict
-- Permanent entry and optional travel payments are separate transactions.
local TravelRules = {}
function TravelRules.locate(regions: {any}, x: number, z: number): string
	for _, region in regions do
		if x >= region.minX and x <= region.maxX and z >= region.minZ and z <= region.maxZ then return region.id end
	end
	return "ark" -- shared seas are open to everyone
end
function TravelRules.new(catalog: any)
	local api = {}
	function api.canAccess(p: any, id: string): boolean
		if type(p) ~= "table" then return false end
		local map = catalog.Maps[id]
		return map ~= nil and (map.free == true or (type(p.maps) == "table" and p.maps[id] == true))
	end
	local function debit(p: any, currency: any, coins: number, points: number): (boolean, string)
		if currency ~= "coins" and currency ~= "points" then return false, "Choose coins or Ark Points." end
		local cost = if currency == "coins" then coins else points
		if p[currency] < cost then return false, "Not enough " .. (if currency == "coins" then "coins." else "Ark Points.") end
		p[currency] -= cost
		return true, ""
	end
	function api.unlock(p: any, id: string, currency: any): (boolean, string)
		local map = catalog.Maps[id]
		if not map then return false, "Unknown island." end
		if api.canAccess(p, id) then return false, "This island is already unlocked." end
		local ok, reason = debit(p, currency, map.price, map.pointsPrice)
		if not ok then return false, reason end
		p.maps[id] = true
		return true, map.name .. " unlocked permanently! Sail there or purchase a teleport."
	end
	function api.payTeleport(p: any, id: string, currency: any): (boolean, string)
		if not api.canAccess(p, id) then return false, "Unlock this island before teleporting." end
		local map = catalog.Maps[id]
		if currency == "pass" then
			if (p.stock.teleportPass or 0) < 1 then return false, "You need a Teleport Pass." end
			p.stock.teleportPass -= 1
		else
			local ok, reason = debit(p, currency, map.teleportCoins, map.teleportPoints)
			if not ok then return false, reason end
		end
		return true, "Teleported to " .. map.name .. "."
	end
	return api
end
return TravelRules
