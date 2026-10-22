--!strict
local Config=require("../src/shared/Config")
local Catalog=require("../src/shared/Catalog")
local Night=require("../src/shared/NightRules")
local Rules=require("../src/shared/Rules").new(Catalog,Config)
local Wildlife=require("../src/shared/WildlifeRules")
local Ark=require("../src/shared/MapLayout")
local Islands=require("../src/shared/IslandLayouts")
local now=1800000000
local passed,failed=0,0
local function test(name: string,callback: ()->())
	local ok,problem=pcall(callback)
	if ok then passed+=1; print("PASS  "..name) else failed+=1; print("FAIL  "..name..": "..tostring(problem)) end
end
local function equal(a: any,b: any) assert(a==b,"expected "..tostring(b)..", got "..tostring(a)) end
local function ranger(): any local p=Rules.blank(now); p.owned.tranquilizer=true; p.owned.diving=true; return p end
test("day night boundaries wrap correctly with a twelve-minute cycle",function()
	equal(Config.DaySeconds,480); equal(Config.CycleSeconds-Config.DaySeconds,240)
	equal(Night.cycle(0,Config).hour,6); equal(Night.cycle(479.99,Config).night,false)
	local dusk=Night.cycle(480,Config); equal(dusk.night,true); equal(dusk.hour,18); equal(dusk.remaining,240)
	equal(Night.cycle(719.99,Config).night,true); equal(Night.cycle(720,Config).night,false); equal(Night.cycle(720,Config).hour,6)
	equal(Night.cycle(Config.CycleStartPhase,Config).hour,12)
end)
test("clock precision and invalid elapsed time do not create an endless night",function()
	for _,elapsed in {-1,0/0,math.huge} do equal(Night.cycle(elapsed,Config).night,false) end
	local state=Night.cycle(720*100+600.5,Config); equal(state.id,100); assert(state.night and state.hour>=0 and state.hour<24 and state.remaining>0)
end)
test("ordinary night captures double coins and points but count one animal",function()
	local day,night=Rules.blank(now),Rules.blank(now)
	assert(Rules.attempt(day,"rabbit",0,now,false,"ark","calm",false)); assert(Rules.attempt(night,"rabbit",0,now,false,"ark","calm",true))
	equal(night.coins-Config.StartingCoins,(day.coins-Config.StartingCoins)*2); equal(night.points,day.points*2)
	equal(night.inventory.rabbit,1); equal(night.stats.catches,1); equal(night.daily.catches,1); equal(night.exploration.catches.ark,1)
end)
test("dangerous night capture awards three times the base stipend and discovery points",function()
	for _,id in {"nightBoar","nightPanther","nightShark"} do
		local p=ranger(); local animal=Catalog.Species[id]
		assert(Rules.attempt(p,id,0,now,false,"moonstone","controlled",true))
		equal(p.coins-100,math.max(1,math.floor(animal.value*0.2))*3); equal(p.points,animal.points*3); equal(p.inventory[id],1); equal(p.stats.rare,1)
	end
end)
test("dawn rejects a predator capture without consuming bait or granting a reward",function()
	local p=ranger(); p.bait=2
	equal(Rules.attempt(p,"nightBoar",0,now,false,"ark","controlled",false),false)
	equal(p.bait,2); equal(p.coins,100); equal(p.points,0); equal(p.stats.catches,0)
end)
test("ordinary snares and owned tranquilizers alone do not bypass predator restraint",function()
	local p=ranger()
	equal(Rules.chance(p,"nightBoar","calm"),nil); equal(Rules.chance(p,"nightBoar","snared"),nil)
	assert(Rules.chance(p,"nightBoar","controlled"))
	equal(Rules.attempt(p,"nightBoar",0,now,false,"ark","snared",true),false); equal(p.points,0)
end)
test("restraint retains rescue-tier water-gear and full-pack requirements",function()
	local p=Rules.blank(now); equal(Rules.chance(p,"nightBoar","controlled"),nil)
	p.owned.rangerNet=true; assert(Rules.chance(p,"nightBoar","controlled")); equal(Rules.chance(p,"nightPanther","controlled"),nil)
	p.owned.expeditionNet=true; equal(Rules.chance(p,"nightShark","controlled"),nil)
	p.owned.snorkel=true; assert(Rules.chance(p,"nightShark","controlled"))
	p.inventory.rabbit=Rules.capacity(p); equal(Rules.chance(p,"nightBoar","controlled"),nil)
end)
test("failed night capture consumes only eligible bait and never awards doubled money",function()
	local p=ranger(); p.bait=2
	equal(Rules.attempt(p,"nightBoar",0.999,now,false,"ark","controlled",true),false)
	equal(p.bait,1); equal(p.coins,100); equal(p.points,0); equal(p.stats.catches,0)
end)
test("night bonus is not applied again to sanctuary trades or surprise chest prizes",function()
	local p=Rules.blank(now); assert(Rules.attempt(p,"rabbit",0,now,false,"ark","calm",true))
	local before=p.coins; assert(Rules.sell(p,"rabbit",1)); equal(p.coins-before,Catalog.Species.rabbit.value)
	local _,result=Rules.openChest(p,"arkNursery",0,0,now); assert(result.kind=="coins"); equal(p.coins-before-Catalog.Species.rabbit.value,40)
end)
test("night-only animals never enter normal spawn or chest pools",function()
	local plans: {any}={Ark,Islands.Islands[1],Islands.Islands[2]}
	for _,plan in plans do for _,zone in plan.Zones do for _,entry in Wildlife.distribution(Catalog,zone) do assert(not Catalog.Species[entry.id].nightOnly) end end end
	for i=0,99 do local p=ranger(); local _,result=Rules.openChest(p,"arkCellar",0.4,i/100,now); assert(not Catalog.Species[result.animal].nightOnly) end
end)
test("exactly three authored predator habitats exist on each island without ID collisions",function()
	local count=0; local plans: {any}={Ark,Islands.Islands[1],Islands.Islands[2]}
	for _,plan in plans do
		local found=0
		for _,zone in plan.Zones do
			local id=Catalog.NightHabitats[plan.Id..":"..zone.id]
			if id then found+=1; count+=1; assert(Catalog.Species[id].dangerous and Catalog.NightAttacks[id]) end
		end
		equal(found,3)
	end
	equal(count,9)
end)
test("one predator per habitat per night cannot be refarmed every replenishment",function()
	local first=Night.cycle(500,Config); assert(Night.canSpawn(first,nil,0)); equal(Night.canSpawn(first,nil,1),false)
	equal(Night.canSpawn(first,first.id,0),false); equal(Night.canSpawn(Night.cycle(720,Config),first.id,0),false)
	assert(Night.canSpawn(Night.cycle(1220,Config),first.id,0))
end)
test("flashlight battery drains only while on and stops exactly at exhaustion",function()
	local reserve,on=Night.battery(120,true,45); equal(reserve,75); equal(on,true)
	reserve,on=Night.battery(reserve,false,60); equal(reserve,75); equal(on,false)
	reserve,on=Night.battery(reserve,true,80); equal(reserve,0); equal(on,false)
	reserve,on=Night.battery(50,true,-10); equal(reserve,50); equal(on,true)
end)
test("night shop items accept either currency and unused supplies survive old-save migration",function()
	for _,id in {"flashlight","nightVision","predatorTrap"} do
		for _,currency in {"coins","points"} do
			local p=Rules.blank(now); p.coins=10000; p.points=10000; assert(Rules.buy(p,id,currency))
			local restored=Rules.sanitize(p,now)
			if Catalog.Items[id].stock then equal(restored.stock[id],1) else equal(restored.owned[id],true) end
		end
	end
	local old=Rules.sanitize({coins=99,points=77,inventory={rabbit=2},stock={animalTrap=3}},now)
	equal(old.coins,99); equal(old.points,77); equal(old.inventory.rabbit,2); equal(old.stock.animalTrap,3); equal(old.stock.flashlight,0); equal(old.stock.predatorTrap,0)
end)
test("limited night supplies cannot be consumed without stock or confused with vision ownership",function()
	local p=Rules.blank(now); equal(Rules.consume(p,"flashlight"),false); equal(Rules.consume(p,"predatorTrap"),false)
	p.stock.flashlight=1; assert(Rules.consume(p,"flashlight")); equal(p.stock.flashlight,0); equal(Rules.consume(p,"flashlight"),false)
	p.owned.nightVision=true; equal(Rules.consume(p,"nightVision"),false)
	equal(Config.PredatorTrapSeconds,180); equal(Config.PredatorHoldSeconds,180); equal(Config.TranquilizerSeconds,45)
end)
test("predator hits clamp point losses and can be lethal without negative health or balances",function()
	local hit=Night.hit(5,10,Catalog.NightAttacks.nightPanther)
	equal(hit.points,5); equal(hit.damage,10); equal(hit.lethal,true)
	hit=Night.hit(100,100,Catalog.NightAttacks.nightBoar); equal(hit.points,12); equal(hit.damage,18); equal(hit.lethal,false)
	hit=Night.hit(0,100,Catalog.NightAttacks.nightShark); equal(hit.points,0); equal(hit.damage,30)
end)
test("windup range visibility safe zones restraint and shared damage cooldown all block strikes",function()
	assert(Night.canStrike(12,11,10,7,true,false,false))
	equal(Night.canStrike(10,11,0,7,true,false,false),false); equal(Night.canStrike(12,11,13,7,true,false,false),false)
	equal(Night.canStrike(12,11,0,9,true,false,false),false); equal(Night.canStrike(12,11,0,7,false,false,false),false)
	equal(Night.canStrike(12,11,0,7,true,true,false),false); equal(Night.canStrike(12,11,0,7,true,false,true),false)
end)
test("night multiplier also applies to event captures without duplicating tide progress",function()
	local p=ranger(); assert(Rules.attempt(p,"auroraRay",0,now,true,"ark","calm",true))
	equal(p.event.captures,1); equal(p.points,Catalog.Species.auroraRay.points*2)
	equal(Night.multiplier(true,false,Config),2); equal(Night.multiplier(true,true,Config),3); equal(Night.multiplier(false,false,Config),1)
end)
print(string.format("Night: %d passed, %d failed (pure rules, not Studio AI/audio/lighting)",passed,failed))
if failed>0 then error("Night regressions failed") end
