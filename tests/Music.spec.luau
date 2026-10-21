--!strict
local Catalog=require("../src/shared/MusicCatalog")
local Rules=require("../src/shared/MusicRules")
local Library=require("../src/shared/MusicLibrary")
local passed,failed=0,0
local function test(name: string,callback: ()->())
	local ok,problem=pcall(callback)
	if ok then passed+=1; print("PASS  "..name) else failed+=1; print("FAIL  "..name..": "..tostring(problem)) end
end
local function equal(a: any,b: any) assert(a==b,"expected "..tostring(b)..", got "..tostring(a)) end
local function tracks(): any return {{Id=101,Title="Tidal Groove",Artist="Test Artist",Duration=120},{AssetId="202",Title="Canopy Skies",Duration=90},{id=303,title="Moonlight",artist="Test",duration=70}} end
test("all requested genres and Ambient have bounded library search terms",function()
	equal(#Catalog.Order,6)
	for _,id in {"lofi","hiphop","pop","club","trap","ambient"} do
		assert(Catalog.Styles[id]); assert(#Catalog.Styles[id].keyword>0 and #Catalog.Styles[id].keyword<60)
	end
end)
test("library rows and normalized client rows retain IDs and credits",function()
	local result=Rules.tracks(tracks(),12); equal(#result,3)
	equal(result[1].id,101); equal(result[2].id,202); equal(result[3].artist,"Test")
	local client=Rules.tracks(result,12); equal(client[1].title,result[1].title); equal(client[1].duration,120)
end)
test("malformed IDs duplicates oversized metadata and non-finite durations are sanitized",function()
	local result=Rules.tracks({{},false,{Id=-1},{Id=1.5},{Id=math.huge},{Id=0/0},{Id=9007199254740992},{Id=42,Title=string.rep("x",150).."\n",Duration=math.huge},{Id=42},{Id=43,Title="Hello\nWorld",Duration=-1}},12)
	equal(#result,2); equal(#result[1].title,120); equal(result[1].duration,0); equal(result[2].title,"Hello World"); equal(result[2].duration,0)
	equal(#Rules.tracks(nil,12),0)
end)
test("a playlist is capped before replication or playback",function()
	local rows={}; for i=1,200 do table.insert(rows,{Id=i,Title="Track"}) end
	equal(#Rules.tracks(rows,Catalog.MaxTracks),12)
end)
test("next previous automatic wrap and single-track repeat stay in bounds",function()
	local list=Rules.tracks(tracks(),12)
	equal(Rules.nextIndex(list,0,1,{}),1); equal(Rules.nextIndex(list,3,1,{}),1)
	equal(Rules.nextIndex(list,1,-1,{}),3); equal(Rules.nextIndex(list,0,-1,{}),3)
	equal(Rules.nextIndex({list[1]},1,1,{}),1)
end)
test("unavailable audio is skipped and an exhausted list stops instead of looping forever",function()
	local list=Rules.tracks(tracks(),12)
	equal(Rules.nextIndex(list,1,1,{[202]=true}),3)
	equal(Rules.nextIndex(list,1,-1,{[303]=true}),2)
	equal(Rules.nextIndex(list,0,1,{[101]=true,[202]=true,[303]=true}),nil)
	equal(Rules.nextIndex({},0,1,{}),nil)
end)
test("muting or a newer genre invalidates pending library and audio-load callbacks",function()
	assert(Rules.current(4,4,true)); equal(Rules.current(4,4,false),false); equal(Rules.current(5,4,true),false)
end)
test("volume is bounded and handles NaN infinity and unexpected input",function()
	equal(Rules.volume(-1),0); equal(Rules.volume(2),1); equal(Rules.volume(0),0)
	equal(Rules.volume(0.7),0.7); equal(Rules.volume(0/0),0.25); equal(Rules.volume(math.huge),0.25); equal(Rules.volume("loud"),0.25)
end)
test("invalid genres never reach the external provider",function()
	local calls=0
	local library=Library.new(Catalog,Rules,function() calls+=1; return tracks() end,function() return 0 end)
	for _,id in {"unknown","rbxassetid://123","",{},999} do equal(library.get(id).ok,false) end
	equal(calls,0)
end)
test("server cache shares one search among players without rate-limiting cached reads",function()
	local calls=0
	local library=Library.new(Catalog,Rules,function(keyword) calls+=1; equal(keyword,Catalog.Styles.lofi.keyword); return tracks() end,function() return 0 end)
	for _=1,20 do local result=library.get("lofi"); assert(result.ok); equal(#result.tracks,3) end
	equal(calls,1)
end)
test("switching genres respects the global search interval",function()
	local now,calls=0,0
	local library=Library.new(Catalog,Rules,function() calls+=1; return tracks() end,function() return now end)
	assert(library.get("lofi").ok)
	local busy=library.get("trap"); equal(busy.ok,false); equal(busy.retryAfter,Catalog.SearchInterval); equal(calls,1)
	now=Catalog.SearchInterval; assert(library.get("trap").ok); equal(calls,2)
end)
test("in-flight reentrant requests cannot start duplicate provider queries",function()
	local library: any; local calls=0
	library=Library.new(Catalog,Rules,function()
		calls+=1; equal(library.get("lofi").ok,false); equal(library.get("pop").ok,false); return tracks()
	end,function() return 0 end)
	assert(library.get("lofi").ok); equal(calls,1)
end)
test("service failures and empty results have a cooldown and a recoverable retry",function()
	local now,calls=0,0
	local library=Library.new(Catalog,Rules,function()
		calls+=1; if calls==1 then error("Service unavailable") elseif calls==2 then return {} else return tracks() end
	end,function() return now end)
	equal(library.get("lofi").ok,false); equal(calls,1)
	now=20; equal(library.get("lofi").ok,false); equal(calls,1)
	now=45; equal(library.get("lofi").ok,false); equal(calls,2)
	now=90; assert(library.get("lofi").ok); equal(calls,3)
end)
test("owner-curated tracks bypass search and remain normalized",function()
	local catalog={Styles=Catalog.Styles,Tracks={lofi=tracks()},MaxTracks=2,SearchInterval=8,RetrySeconds=45}
	local library=Library.new(catalog,Rules,function() error("Should not search") end,function() return 0 end)
	local result=library.get("lofi"); assert(result.ok); equal(#result.tracks,2); equal(result.tracks[1].id,101)
end)
print(string.format("Music: %d passed, %d failed",passed,failed)); if failed>0 then error("Music regressions failed") end
