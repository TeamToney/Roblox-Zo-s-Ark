--!strict
local Catalog=require("../src/shared/Catalog")
local Config=require("../src/shared/Config")
local Rules=require("../src/shared/Rules").new(Catalog,Config)
local TravelModule=require("../src/shared/TravelRules")
local Travel=TravelModule.new(Catalog)
local Encounter=require("../src/shared/EncounterRules")
local Geometry=require("../src/shared/MapGeometry")
local Islands=require("../src/shared/IslandLayouts")
local Layout=require("../src/shared/MapLayout")
local now=1800000000
local passed,failed=0,0
local function test(name: string,callback: ()->())
	local ok,problem=pcall(callback)
	if ok then passed+=1; print("PASS  "..name) else failed+=1; print("FAIL  "..name..": "..tostring(problem)) end
end
local function equal(a: any,b: any) assert(a==b,"expected "..tostring(b)..", got "..tostring(a)) end
test("fresh players start with only Ark access and no teleport passes",function()
	local p=Rules.blank(now)
	assert(Travel.canAccess(p,"ark")); equal(Travel.canAccess(p,"canopy"),false); equal(Travel.canAccess(p,"moonstone"),false)
	equal(Travel.canAccess(p,"invented"),false); equal(Travel.canAccess(nil,"ark"),false); equal(p.stock.teleportPass,0)
end)
test("each paid map can be permanently unlocked with either server-listed currency",function()
	for _,id in {"canopy","moonstone"} do for _,currency in {"coins","points"} do
		local p=Rules.blank(now); p.coins=10000; p.points=10000; local map=Catalog.Maps[id]
		assert(Travel.unlock(p,id,currency)); assert(Travel.canAccess(p,id))
		equal(p.coins,10000-(if currency=="coins" then map.price else 0)); equal(p.points,10000-(if currency=="points" then map.pointsPrice else 0))
		local before=if currency=="coins" then p.coins else p.points; equal(Travel.unlock(p,id,currency),false); equal(if currency=="coins" then p.coins else p.points,before)
	end end
end)
test("invalid map currencies and insufficient balances never create access or debit money",function()
	local p=Rules.blank(now)
	for _,currency in {"robux","pass","coins","points"} do equal(Travel.unlock(p,"canopy",currency),false) end
	equal(Travel.unlock(p,"invented","coins"),false); equal(Travel.unlock(p,"ark","coins"),false)
	equal(p.coins,100); equal(p.points,0); equal(p.maps.canopy,nil)
end)
test("old visited checkpoints do not bypass purchase but journals retain their history",function()
	local p=Rules.sanitize({coins=1000,inventory={tiger=2},owned={snorkel=true},exploration={checkpoints={canopyDock=true},activeCheckpoint="canopyDock"}},now)
	equal(Travel.canAccess(p,"canopy"),false); equal(p.exploration.activeCheckpoint,"canopyDock"); equal(p.inventory.tiger,2); equal(p.owned.snorkel,true)
	equal(p.stock.teleportPass,0); assert(Travel.canAccess(p,"ark"))
end)
test("paid map rights and passes survive migration and unknown map flags are discarded",function()
	local p=Rules.blank(now); p.maps.canopy=true; p.stock.teleportPass=7
	local restored=Rules.sanitize(p,now); assert(Travel.canAccess(restored,"canopy")); equal(restored.stock.teleportPass,7)
	local invalid=Rules.sanitize({maps={invented=true,moonstone="yes"},stock={teleportPass=-8}},now)
	equal(invalid.maps.invented,nil); equal(Travel.canAccess(invalid,"moonstone"),false); equal(invalid.stock.teleportPass,0)
end)
test("teleports charge the listed currency or exactly one pass without affecting island rights",function()
	for _,id in Catalog.MapOrder do for _,currency in {"coins","points","pass"} do
		local p=Rules.blank(now); p.coins=1000; p.points=1000; p.stock.teleportPass=2; p.maps[id]=true
		assert(Travel.payTeleport(p,id,currency)); local map=Catalog.Maps[id]
		equal(p.coins,1000-(if currency=="coins" then map.teleportCoins else 0)); equal(p.points,1000-(if currency=="points" then map.teleportPoints else 0))
		equal(p.stock.teleportPass,if currency=="pass" then 1 else 2); assert(Travel.canAccess(p,id))
	end end
end)
test("a teleport pass cannot bypass a locked island or pay for an unknown destination",function()
	local p=Rules.blank(now); p.stock.teleportPass=3; p.coins=10000
	for _,id in {"canopy","moonstone","invented"} do for _,currency in {"coins","points","pass"} do equal(Travel.payTeleport(p,id,currency),false) end end
	equal(p.stock.teleportPass,3); equal(p.coins,10000)
end)
test("empty passes invalid payment types and insufficient funds do not partially charge a trip",function()
	local p=Rules.blank(now); p.coins=0
	for _,currency in {"coins","points","pass","robux"} do equal(Travel.payTeleport(p,"ark",currency),false) end
	equal(p.coins,0); equal(p.points,0); equal(p.stock.teleportPass,0)
end)
test("Robux map grants unlock permanently and repeat products have explicit compensation",function()
	local p=Rules.blank(now)
	assert(Rules.grantProduct(p,"canopyAccess")); assert(Travel.canAccess(p,"canopy")); equal(p.coins,100)
	assert(Rules.grantProduct(p,"canopyAccess")); equal(p.coins,1000)
	assert(Rules.grantProduct(p,"moonstoneAccess")); assert(Travel.canAccess(p,"moonstone"))
	assert(Rules.grantProduct(p,"teleportPack")); equal(p.stock.teleportPass,5)
	assert(Travel.payTeleport(p,"moonstone","pass")); equal(p.stock.teleportPass,4)
end)
test("future maps are locked by default even when no explicit free flag is provided",function()
	local catalog={Maps={ark=Catalog.Maps.ark,future={name="Future Island",price=3500,pointsPrice=2200,teleportCoins=110,teleportPoints=70}}}
	local travel=TravelModule.new(catalog); local p=Rules.blank(now); p.coins=5000
	equal(travel.canAccess(p,"future"),false); assert(travel.unlock(p,"future","coins")); equal(p.coins,1500); assert(travel.canAccess(p,"future"))
end)
test("every authored island is registered with a valid landing and explicit purchase prices",function()
	local plans: {any}={Layout}; for _,plan in Islands.Islands do table.insert(plans,plan) end
	for _,plan in plans do
		local map=Catalog.Maps[plan.Id]; assert(map and table.find(Catalog.MapOrder,plan.Id))
		assert(Catalog.Checkpoints[map.checkpoint].mapId==plan.Id)
		if plan.Id~="ark" then assert(map.free~=true and map.price>0 and map.pointsPrice>0 and Catalog.Products[map.product].mapId==plan.Id) end
	end
end)
test("paid island bounds include shoreline approaches while shared sea routes stay free",function()
	local regions: {any}={}
	for _,plan in Islands.Islands do
		local x1,z1=Geometry.world(plan.Source,plan.Bounds[1],plan.Bounds[2]); local x2,z2=Geometry.world(plan.Source,plan.Bounds[3],plan.Bounds[4])
		table.insert(regions,{id=plan.Id,minX=x1-48,minZ=z1-48,maxX=x2+48,maxZ=z2+48})
		local dockX,dockZ=Geometry.world(plan.Source,plan.Dock.x,plan.Dock.y)
		equal(TravelModule.locate(regions,dockX,dockZ),plan.Id)
	end
	for _,sea in require("../src/shared/SeawayLayout") do
		local r=sea.rect; assert(r[1]>Config.SeaBounds[1] and r[2]>Config.SeaBounds[2] and r[3]<Config.SeaBounds[3] and r[4]<Config.SeaBounds[4])
		for _,region in regions do assert(r[3]<region.minX or r[1]>region.maxX or r[4]<region.minZ or r[2]>region.maxZ,sea.id.." overlaps paid region") end
		equal(TravelModule.locate(regions,(r[1]+r[3])/2,(r[2]+r[4])/2),"ark")
	end
end)
test("capture pacing scales modestly with rarity and forged or stale holds fail",function()
	local previous=0
	for rank=1,6 do local hold=Encounter.holdTime(Config.CaptureHold,rank); assert(hold>=previous and hold>=0.65 and hold<=1.2); previous=hold end
	equal(Encounter.held(nil,10,0.65),false); equal(Encounter.held(10,10.1,0.65),false); equal(Encounter.held(0,10,0.65),false)
	assert(Encounter.held(10,10.7,0.65)); equal(Encounter.held(10,9,0.65),false)
end)
test("moderate capture odds preserve starter success and give rare gear and bait useful benefits",function()
	local p=Rules.blank(now); local rabbit=Rules.chance(p,"rabbit") :: number
	assert(rabbit>0.65 and rabbit<0.75)
	p.owned.tranquilizer=true
	local tiger=Rules.chance(p,"tiger") :: number; assert(tiger>0.35 and tiger<0.45)
	p.bait=1; local improved=Rules.chance(p,"tiger") :: number; assert(improved>tiger and improved<0.7)
	for _,id in Catalog.SpeciesOrder do
		p.owned.diving=true; local chance=Rules.chance(p,id,"snared") :: number
		assert(chance>=Config.CaptureMinimum and chance<=0.9)
	end
end)
print(string.format("\n%d travel/access cases passed, %d failed (pure rules, not Roblox teleports)",passed,failed))
if failed>0 then error("Travel checks failed") end
