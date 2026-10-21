--!strict
-- Engine-independent cache/rate limit; provider is the server's AssetService.
local MusicLibrary = {}
function MusicLibrary.new(catalog: any, rules: any, provider: (string)->any, clock: ()->number): any
	local cache: {[string]: any}={}
	local nextSearch=0
	local pending=false
	local api={}
	function api.get(id: any): any
		if type(id)~="string" or not catalog.Styles[id] then return {ok=false,message="Choose a music style."} end
		local now=clock()
		local saved=cache[id]
		if saved and saved.tracks then return {ok=true,tracks=saved.tracks} end
		local pinned=rules.tracks(catalog.Tracks[id],catalog.MaxTracks)
		if #pinned>0 then cache[id]={tracks=pinned}; return {ok=true,tracks=pinned} end
		if saved and now<saved.retryAt then return {ok=false,retryAfter=math.ceil(saved.retryAt-now),message="This playlist is temporarily unavailable. Try another style."} end
		if pending or now<nextSearch then return {ok=false,retryAfter=math.max(2,math.ceil(nextSearch-now)),message="Tuning the radio…"} end
		pending=true; nextSearch=now+catalog.SearchInterval
		local ok,rows=pcall(provider,catalog.Styles[id].keyword)
		pending=false
		local tracks=if ok then rules.tracks(rows,catalog.MaxTracks) else {}
		if #tracks>0 then cache[id]={tracks=tracks}; return {ok=true,tracks=tracks} end
		cache[id]={retryAt=clock()+catalog.RetrySeconds}
		return {ok=false,retryAfter=catalog.RetrySeconds,message="This playlist is temporarily unavailable. Try another style."}
	end
	return api
end
return MusicLibrary
