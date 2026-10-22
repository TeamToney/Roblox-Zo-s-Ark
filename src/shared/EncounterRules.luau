--!strict
local EncounterRules = {}
function EncounterRules.holdTime(base: number, rank: number): number
	return math.min(1.2, base + math.max(0, rank - 1) * 0.12)
end
function EncounterRules.held(started: number?, now: number, duration: number): boolean
	return started ~= nil and now - started >= duration * 0.85 and now - started <= 8
end
function EncounterRules.alert(behavior: any, distance: number, camouflaged: boolean, now: number, restUntil: number, snaredUntil: number): boolean
	return behavior ~= nil and now >= restUntil and now >= snaredUntil and distance <= behavior.alert * (if camouflaged then 0.55 else 1)
end
function EncounterRules.condition(now: number, fleeUntil: number, snaredUntil: number): string
	return if now < snaredUntil then "snared" elseif now < fleeUntil then "fleeing" else "calm"
end
function EncounterRules.flight(mode: string, now: number, started: number, untilTime: number): number
	if mode ~= "fly" or now < started or now >= untilTime then return 0 end
	return math.sin(math.clamp((now - started) / math.max(0.01, untilTime - started), 0, 1) * math.pi) * 7
end
function EncounterRules.identification(distance: number,visible: boolean,dangerous: boolean,config: any): string
	if not visible or distance~=distance or distance<0 then return "hidden" end
	if distance<=config.AnimalIdentifyDistance then return "identify" end
	return if dangerous and distance<=config.PredatorWarningDistance then "warning" else "hidden"
end
return EncounterRules
