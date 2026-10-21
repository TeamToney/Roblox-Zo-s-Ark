--!strict
local MusicRules = {}
export type Track = {id: number, title: string, artist: string, duration: number}
local function finite(value: any): boolean
	return type(value)=="number" and value==value and math.abs(value)<math.huge
end
local function clean(value: any, fallback: string): string
	if type(value)~="string" or value=="" then return fallback end
	return string.sub((string.gsub(value,"%c"," ")),1,120)
end
function MusicRules.volume(value: any): number
	return if finite(value) then math.clamp(value,0,1) else 0.25
end
function MusicRules.tracks(rows: any, limit: number): {Track}
	local result: {Track}={}; local seen: {[number]: boolean}={}
	if type(rows)~="table" then return result end
	for index=1,math.min(#rows,100) do
		local row=rows[index]
		if type(row)~="table" then continue end
		local id=tonumber(row.Id or row.AssetId or row.AudioId or row.id)
		if not finite(id) or not id or id<=0 or id%1~=0 or id>9007199254740991 or seen[id] then continue end
		local duration=tonumber(row.Duration or row.duration)
		table.insert(result,{id=id,title=clean(row.Title or row.Name or row.title,"Island soundtrack"),artist=clean(row.Artist or row.artist,"Roblox music library"),duration=if finite(duration) and duration and duration>0 then math.min(duration,3600) else 0})
		seen[id]=true
		if #result>=math.clamp(math.floor(limit),1,100) then break end
	end
	return result
end
function MusicRules.nextIndex(tracks: {Track}, current: number, direction: number, failed: {[number]: boolean}): number?
	local count=#tracks
	if count==0 then return nil end
	local step=if direction<0 then -1 else 1
	local start=if current==0 and step<0 then 1 else current
	for offset=1,count do
		local index=(start-1+offset*step)%count+1
		if not failed[tracks[index].id] then return index end
	end
	return nil
end
function MusicRules.current(serial: number, pending: number, enabled: boolean): boolean
	return enabled and serial==pending
end
return MusicRules
