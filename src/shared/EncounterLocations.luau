--!strict
-- Candidate locations only. Runtime terrain, clearances and observer checks
-- stay on the server. No stable reward or population ID is changed here.
local Locations={}
local nature={meadow=true,jungle=true,summit=true} :: {[string]: boolean}
function Locations.extraHabitats(plan: any,geometry: any): {any}
	local result={}
	for _,room in plan.Rooms do
		if not room.rect or not nature[room.kind] then continue end
		local covered=false
		for _,zone in plan.Zones do
			local x,y=geometry.center(zone.rect)
			if geometry.contains(room.rect,x,y) then covered=true; break end
		end
		if not covered then table.insert(result,{key=plan.Id..":room:"..room.id,rect=room.rect,habitat=room.kind,obscure=false}) end
	end
	return result
end
function Locations.animalHomes(homes: {any},origin: any,species: any): {any}
	if species.eventOnly then return {origin} end
	local result={}
	for _,home in homes do
		if home.mapId~=origin.mapId or home.habitat~=origin.habitat or home.marine~=origin.marine or (home.obscure==true)~=(origin.obscure==true) or (home.seaway==true)~=(origin.seaway==true) or home.event then continue end
		local width=if home.bounds then math.min(home.bounds.maxX-home.bounds.minX,home.bounds.maxZ-home.bounds.minZ) else home.radius*2
		if width>=species.scale*9+3 then table.insert(result,home) end
	end
	return if #result>0 then result else {origin}
end
function Locations.lootRegions(plan: any,catalog: any,spot: any,geometry: any): {any}
	local result={}; local hidden=catalog.Chests[spot.id].obscure==true
	if hidden or spot.marine then
		for _,zone in plan.Zones do
			local marine=zone.habitat=="reef" or zone.habitat=="ocean"
			if (zone.obscure==true)==hidden and marine==(spot.marine==true) and not zone.extension then
				table.insert(result,{key=plan.Id..":loot:"..zone.id,rect=zone.rect,marine=marine})
			end
		end
	else
		for _,room in plan.Rooms do
			if not room.rect or room.kind=="entry" or room.kind=="atrium" or room.kind=="marine" then continue end
			local secret=false
			for _,zone in plan.Zones do
				local x,y=geometry.center(zone.rect)
				if zone.obscure and geometry.contains(room.rect,x,y) then secret=true; break end
			end
			if not secret then table.insert(result,{key=plan.Id..":loot:"..room.id,rect=room.rect,marine=false}) end
		end
		for _,court in plan.Courtyards do table.insert(result,{key=plan.Id..":loot:"..court.id,rect=court.rect,marine=false}) end
	end
	return result
end
function Locations.order(options: {any},previous: string?,roll: number): {any}
	local result={}; local last={}
	if #options==0 or roll~=roll or roll<0 or roll>=1 then return result end
	local start=math.floor(roll*#options)
	for offset=0,#options-1 do
		local candidate=options[(start+offset)%#options+1]
		table.insert(if candidate.key==previous then last else result,candidate)
	end
	for _,candidate in last do table.insert(result,candidate) end
	return result
end
function Locations.ready(now: number,due: number,animating: boolean,nearby: boolean): boolean
	return now>=due and not animating and not nearby
end
function Locations.population(catalog: any,records: any,origin: any): any
	local count={ordinary=0,special=0,predators=0}
	for _,record in records do
		if record.alive and record.populationZone==origin then
			local species=catalog.Species[record.id]
			if species.nightOnly then count.predators+=1 elseif species.eventOnly then count.special+=1 else count.ordinary+=1 end
		end
	end
	return count
end
return Locations
