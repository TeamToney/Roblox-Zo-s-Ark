--!strict
-- Closing is local and invalidates every earlier asynchronous inspection.
local NotebookState = {}
function NotebookState.new()
	local state = {visible=true, suspended=false, revision=0, suppressedUntil=0}
	local api = {state=state}
	function api.canInspect(now: number): boolean
		return not state.visible and not state.suspended and now >= state.suppressedUntil
	end
	function api.acceptInspection(revision: number, now: number): boolean
		return revision == state.revision and api.canInspect(now)
	end
	function api.open(): boolean
		if state.suspended then return false end
		state.revision += 1; state.visible=true
		return true
	end
	function api.close(now: number)
		state.revision += 1; state.visible=false; state.suppressedUntil=now+0.65
	end
	function api.suspend(now: number)
		api.close(now); state.suspended=true
	end
	function api.resume(now: number)
		state.suspended=false; state.suppressedUntil=now+0.65
	end
	return api
end
return NotebookState
