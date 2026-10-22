--!strict
local NightRules={}
local function finite(value: any): boolean
	return type(value)=="number" and value==value and math.abs(value)<math.huge
end
function NightRules.cycle(elapsed: number,config: any): any
	local time=if finite(elapsed) then math.max(0,elapsed) else 0
	local phase=time%config.CycleSeconds
	local night=phase>=config.DaySeconds
	local hour=if night then 18+(phase-config.DaySeconds)/(config.CycleSeconds-config.DaySeconds)*12 else 6+phase/config.DaySeconds*12
	return {night=night,hour=hour%24,remaining=(if night then config.CycleSeconds else config.DaySeconds)-phase,id=math.floor(time/config.CycleSeconds)}
end
function NightRules.multiplier(night: boolean,dangerous: boolean,config: any): number
	return if night then (if dangerous then config.DangerousNightMultiplier else config.NightCaptureMultiplier) else 1
end
function NightRules.battery(remaining: number,on: boolean,elapsed: number): (number,boolean)
	local reserve=if finite(remaining) then math.max(0,remaining) else 0
	if on and finite(elapsed) and elapsed>0 then reserve=math.max(0,reserve-elapsed) end
	return reserve,on and reserve>0
end
function NightRules.hit(points: number,health: number,attack: any): any
	local loss=math.min(math.max(0,points),math.max(0,attack.points))
	local damage=math.min(math.max(0,health),math.max(0,attack.damage))
	return {points=math.floor(loss),damage=damage,lethal=health>0 and damage>=health}
end
function NightRules.canStrike(now: number,readyAt: number,nextHit: number,distance: number,clear: boolean,safe: boolean,restrained: boolean): boolean
	return readyAt>0 and now>=readyAt and now>=nextHit and distance<=8 and clear and not safe and not restrained
end
function NightRules.canSpawn(state: any,lastSpawn: number?,population: number): boolean
	return state.night==true and lastSpawn~=state.id and population==0
end
return NightRules
