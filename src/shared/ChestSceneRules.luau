--!strict
local ChestSceneRules = {}
function ChestSceneRules.plan(rank: number, trap: boolean): any
	local tier=math.clamp(math.floor(if rank==rank then rank else 0),0,6)
	return {
		openAt=0.9,revealAt=1.55,
		duration=if trap then 3.8 else 4.4+tier*0.35,
		confetti=if trap then 14 else 16+tier*5,
		balloons=if trap or tier<2 then 0 else math.min(7,tier+1),
		fireworks=if trap or tier<3 then 0 else math.min(4,tier-2),
		rank=tier,trap=trap,
	}
end
return ChestSceneRules
