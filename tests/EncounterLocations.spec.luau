--!strict
local Locations=require("../src/shared/EncounterLocations")
local Geometry=require("../src/shared/MapGeometry")
local Ark=require("../src/shared/MapLayout")
local Islands=require("../src/shared/IslandLayouts")
local Catalog=require("../src/shared/Catalog")
local Rules=require("../src/shared/Rules").new(Catalog,require("../src/shared/Config"))
local passed,failed=0,0
local function test(name: string,callback: ()->())
	local ok,problem=pcall(callback)
	if ok then passed+=1; print("PASS  "..name) else failed+=1; print("FAIL  "..name..": "..tostring(problem)) end
end
local function equal(a: any,b: any) assert(a==b,"expected "..tostring(b)..", got "..tostring(a)) end
test("all twelve stable loot IDs have dry or marine candidates on their own island",function()
	local count=0; local plans: {any}={Ark,Islands.Islands[1],Islands.Islands[2]}
	for _,plan in plans do for _,spot in plan.Chests do
		local choices=Locations.lootRegions(plan,Catalog,spot,Geometry); assert(#choices>0,spot.id); count+=1
		for _,region in choices do
			assert(string.sub(region.key,1,#plan.Id)==plan.Id)
			local x,y=Geometry.center(region.rect)
			equal(Geometry.inWater(plan,x,y),spot.marine==true)
		end
	end end
	equal(count,12)
end)
test("concealed loot remains in secluded pools and public finds exclude secret rooms",function()
	local plans: {any}={Ark,Islands.Islands[1],Islands.Islands[2]}
	for _,plan in plans do for _,spot in plan.Chests do
		local hidden=Catalog.Chests[spot.id].obscure
		for _,region in Locations.lootRegions(plan,Catalog,spot,Geometry) do
			if hidden then
				local found=false
				for _,zone in plan.Zones do if region.rect==zone.rect and zone.obscure then found=true end end
				assert(found,spot.id.." lost hidden classification")
			else
				for _,zone in plan.Zones do
					local x,y=Geometry.center(zone.rect)
					assert(not (zone.obscure and Geometry.contains(region.rect,x,y)),spot.id.." moved into a secret room")
				end
			end
		end
	end end
end)
test("shuffled searches try another room first without dropping the safe fallback",function()
	local options={{key="old"},{key="new"},{key="third"}}
	local list=Locations.order(options,"old",0); equal(list[1].key,"new"); equal(list[3].key,"old"); equal(#list,3)
	equal(Locations.order(options,nil,0)[1].key,"old"); equal(Locations.order(options,nil,0.5)[1].key,"new")
	equal(#Locations.order(options,nil,0/0),0); equal(#Locations.order({},nil,0),0)
	equal(Locations.order({options[1]},"old",0)[1].key,"old")
end)
test("animal spawn rotation retains island biome concealment and seaway boundaries",function()
	local origin: any={key="base",mapId="ark",habitat="meadow",marine=false,obscure=false,radius=40}
	local good={key="new",mapId="ark",habitat="meadow",marine=false,obscure=false,radius=40}
	local choices: {any}={origin,good,
		{key="paid",mapId="canopy",habitat="meadow",marine=false,radius=40},
		{key="hidden",mapId="ark",habitat="meadow",marine=false,obscure=true,radius=40},
		{key="water",mapId="ark",habitat="meadow",marine=true,radius=40},
		{key="wrongBiome",mapId="ark",habitat="jungle",marine=false,radius=40},
		{key="seaway",mapId="ark",habitat="meadow",marine=false,seaway=true,radius=40}}
	local homes=Locations.animalHomes(choices,origin,Catalog.Species.rabbit)
	equal(#homes,2); equal(homes[2],good)
end)
test("event mantas stay in their event habitat and large animals reject undersized alternatives",function()
	local origin={key="base",mapId="ark",habitat="reef",marine=true,event=true,radius=50}
	local elsewhere={key="elsewhere",mapId="ark",habitat="reef",marine=true,radius=50}
	local homes=Locations.animalHomes({elsewhere},origin,Catalog.Species.auroraRay); equal(#homes,1); equal(homes[1],origin)
	local ocean={key="ocean",mapId="ark",habitat="ocean",marine=true,radius=50}
	local tiny={key="tiny",mapId="ark",habitat="ocean",marine=true,radius=7}
	homes=Locations.animalHomes({ocean,tiny},ocean,Catalog.Species.whale); equal(#homes,1); equal(homes[1],ocean)
end)
test("additional wildlife areas use uncovered nature rooms rather than ordinary indoor rooms",function()
	local total=0; local plans: {any}={Ark,Islands.Islands[1],Islands.Islands[2]}
	for _,plan in plans do
		for _,area in Locations.extraHabitats(plan,Geometry) do
			total+=1; assert(area.habitat=="meadow" or area.habitat=="jungle" or area.habitat=="summit")
			for _,zone in plan.Zones do local x,y=Geometry.center(zone.rect); assert(not Geometry.contains(area.rect,x,y)) end
		end
	end
	assert(total>=5)
end)
test("moving an animal's home cannot create extra population or predator slots",function()
	local origin,elsewhere={},{}
	local records={
		{populationZone=origin,zone=elsewhere,id="rabbit",alive=true},
		{populationZone=origin,zone=elsewhere,id="auroraRay",alive=true},
		{populationZone=origin,zone=elsewhere,id="nightBoar",alive=true},
		{populationZone=origin,zone=elsewhere,id="rabbit",alive=false},
		{populationZone=elsewhere,zone=origin,id="rabbit",alive=true},
	}
	local count=Locations.population(Catalog,records,origin); equal(count.ordinary,1); equal(count.special,1); equal(count.predators,1)
end)
test("loot relocation defers until due and cannot interrupt nearby explorers or lid animation",function()
	equal(Locations.ready(299,300,false,false),false)
	equal(Locations.ready(300,300,true,false),false); equal(Locations.ready(300,300,false,true),false)
	assert(Locations.ready(300,300,false,false)); assert(Locations.ready(500,300,false,false))
end)
test("a relocated chest or wrapped gift keeps its daily claim instead of rerolling a new reward",function()
	local now=1800000000; local p=Rules.blank(now)
	local ok=Rules.openChest(p,"arkNursery",0,0,now); assert(ok)
	local before=p.coins
	equal(Rules.openChest(p,"arkNursery",0.99,0.99,now+300),false); equal(p.coins,before)
	local restored=Rules.sanitize(p,now+301); equal(Rules.openChest(restored,"arkNursery",0,0,now+301),false)
	assert(Rules.openChest(restored,"arkNursery",0,0,now+86400))
end)
print(string.format("Encounter locations: %d passed, %d failed (pure pools and reservations, not Studio relocation)",passed,failed))
if failed>0 then error("Encounter-location regressions failed") end
