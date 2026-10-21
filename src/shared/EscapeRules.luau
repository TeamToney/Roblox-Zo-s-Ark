--!strict
local EscapeRules = {}
export type Probe = {x: number, z: number, distance: number, score: number}
function EscapeRules.behavior(catalog: any, id: string, marine: boolean): any
	local explicit = catalog.Escape[id]
	if explicit then return explicit end
	local animal = catalog.Species[id]
	return {mode=if marine then "swim" elseif animal.form=="bird" then "fly" else "run", alert=0, speed=if marine then 18 elseif animal.form=="rabbit" then 19 else 16}
end
-- Ordered local steering probes: away first, then room to sidestep, then a
-- short reverse step out of a corner. The engine validates walls and ground.
function EscapeRules.probes(x: number, z: number, tx: number, tz: number, yaw: number): {Probe}
	local dx,dz=x-tx,z-tz
	local length=math.sqrt(dx*dx+dz*dz)
	if length<0.01 then dx,dz=math.sin(yaw),math.cos(yaw) else dx,dz=dx/length,dz/length end
	local result: {Probe}={}
	for _,distance in {20,10,4} do
		for _,angle in {0,35,-35,70,-70,110,-110,150,-150,180} do
			local turn=math.rad(angle)
			local px=x+(dx*math.cos(turn)-dz*math.sin(turn))*distance
			local pz=z+(dx*math.sin(turn)+dz*math.cos(turn))*distance
			local separation=math.sqrt((px-tx)^2+(pz-tz)^2)
			table.insert(result,{x=px,z=pz,distance=distance,score=separation-length+distance*0.1})
		end
	end
	table.sort(result,function(a: Probe,b: Probe) return a.score>b.score end)
	return result
end
function EscapeRules.choose(probes: {Probe}, valid: (Probe)->boolean): Probe?
	for _,probe in probes do if valid(probe) then return probe end end
	return nil
end
return EscapeRules
