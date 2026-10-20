--!strict
-- Session-only endurance. No Roblox services, health writes or client authority.
export type State = {used: number, floating: number}
local SwimRules = {}
function SwimRules.new(config: any)
	local api = {}
	function api.limit(owned: {[string]: boolean}): number
		local seconds = if owned.diving then config.DivingSeconds elseif owned.snorkel then config.SnorkelSeconds else config.SwimSeconds
		return seconds + (if owned.lifeJacket then config.LifeJacketExtraSeconds else 0)
	end
	function api.blank(): State return {used = 0, floating = 0} end
	function api.snapshot(state: State, owned: {[string]: boolean}, swimming: boolean)
		local limit = api.limit(owned)
		return {remaining = math.max(0, limit - state.used), maximum = limit, floating = state.floating, swimming = swimming}
	end
	function api.advance(state: State, owned: {[string]: boolean}, swimming: boolean, elapsed: number, resting: boolean?): number
		if elapsed ~= elapsed or elapsed <= 0 or elapsed > 2 then return 0 end
		local supported = math.min(state.floating, elapsed)
		state.floating = math.max(0, state.floating - elapsed)
		local limit = api.limit(owned)
		if not swimming then
			if resting then state.used = math.max(0, state.used - config.SwimRecoveryPerSecond * elapsed) end
			return 0
		end
		local drain = elapsed - supported
		local remaining = math.max(0, limit - state.used)
		state.used = math.min(limit, state.used + drain)
		return math.max(0, drain - remaining) * config.ExhaustionDamagePerSecond
	end
	function api.pickup(state: State, kind: string): (boolean, number)
		if kind == "float" then
			state.used = math.max(0, state.used - config.FloatRecovery)
			state.floating = config.FloatSeconds
			return true, 0
		elseif kind == "health" then
			state.used = math.max(0, state.used - config.HealthRecovery)
			return true, config.HealthPickupHeal
		end
		return false, 0
	end
	return api
end
return SwimRules
