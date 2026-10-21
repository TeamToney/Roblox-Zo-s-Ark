--!strict
local Catalog=require("../src/shared/Catalog")
local Config=require("../src/shared/Config")
local Rules=require("../src/shared/Rules").new(Catalog,Config)
local Encounter=require("../src/shared/EncounterRules")
local Shapes=require("../src/shared/ItemShapes")
local passed,failed=0,0
local now=1800000000
local function test(name: string, callback: ()->())
	local ok,problem=pcall(callback)
	if ok then passed+=1; print("PASS  "..name) else failed+=1; print("FAIL  "..name..": "..tostring(problem)) end
end
local function equal(a: any,b: any) assert(a==b,"expected "..tostring(b)..", got "..tostring(a)) end
test("every item can be bought for either listed currency without a double debit",function()
	for _,id in Catalog.ItemOrder do
		local item=Catalog.Items[id]
		for _,currency in {"coins","points"} do
			local p=Rules.blank(now); p.coins=10000; p.points=10000
			assert(Rules.buy(p,id,currency))
			equal(p.coins,10000-(if currency=="coins" then item.price else 0))
			equal(p.points,10000-(if currency=="points" then item.pointsPrice :: number else 0))
			if item.stock then equal(p.stock[item.stock],item.quantity) end
		end
	end
end)
test("invalid currency and insufficient points leave ownership and balances intact",function()
	local p=Rules.blank(now); p.coins=10000
	equal(Rules.buy(p,"tracker","robux"),false); equal(Rules.buy(p,"tracker","points"),false)
	equal(p.coins,10000); equal(p.points,0); equal(p.owned.tracker,nil)
end)
test("supplies can be bought repeatedly and consumed exactly once each",function()
	local p=Rules.blank(now); p.coins=1000
	assert(Rules.buy(p,"speedBoost")); assert(Rules.buy(p,"speedBoost")); equal(p.stock.speedBoost,2)
	assert(Rules.consume(p,"speedBoost")); assert(Rules.consume(p,"speedBoost")); equal(Rules.consume(p,"speedBoost"),false)
	equal(Rules.consume(p,"tracker"),false); equal(Rules.consume(p,"invented"),false)
	p.stock.speedBoost=999; local coins=p.coins; equal(Rules.buy(p,"speedBoost"),false); equal(p.coins,coins)
end)
test("wardrobe requires ownership and toggles each slot independently",function()
	local p=Rules.blank(now); p.coins=10000
	equal(Rules.equip(p,"safariHat"),false); assert(Rules.buy(p,"safariHat")); assert(Rules.buy(p,"mintTrail"))
	assert(Rules.equip(p,"safariHat")); assert(Rules.equip(p,"mintTrail")); equal(p.wardrobe.hat,"safariHat"); equal(p.wardrobe.trail,"mintTrail")
	assert(Rules.equip(p,"safariHat")); equal(p.wardrobe.hat,nil); equal(p.wardrobe.trail,"mintTrail")
	equal(Rules.equip(p,"rangerNet"),false)
end)
test("v1 journals retain animals gear movement and gains additive kit defaults",function()
	local p=Rules.sanitize({coins=731,points=220,inventory={jaguar=2},owned={expeditionNet=true},stats={walkDistance=29.75}},now)
	equal(p.coins,731); equal(p.inventory.jaguar,2); equal(p.owned.expeditionNet,true); equal(p.stats.walkDistance,29.75)
	equal(p.stock.speedBoost,0); equal(p.stock.animalTrap,0); equal(next(p.wardrobe),nil); equal(next(p.receipts),nil)
end)
test("stock equipped style and paid receipts survive round trips; invalid slots are discarded",function()
	local p=Rules.blank(now); p.stock.speedBoost=8; p.stock.animalTrap=3; p.owned.safariHat=true; p.wardrobe.hat="safariHat"; p.receipts["purchase-42"]=true
	local restored=Rules.sanitize(p,now)
	equal(restored.stock.speedBoost,8); equal(restored.stock.animalTrap,3); equal(restored.wardrobe.hat,"safariHat"); equal(restored.receipts["purchase-42"],true)
	local bad=Rules.sanitize({stock={speedBoost=0/0,animalTrap=-3},wardrobe={hat="mintTrail",trail="safariHat"},owned={mintTrail=true},receipts={bad=false}},now)
	equal(bad.stock.speedBoost,0); equal(bad.stock.animalTrap,0); equal(next(bad.wardrobe),nil); equal(next(bad.receipts),nil)
end)
test("fleeing lowers capture odds; a snare raises them without bypassing gear or capacity",function()
	local p=Rules.blank(now); p.owned.tranquilizer=true
	local calm=Rules.chance(p,"tiger") :: number; local flee=Rules.chance(p,"tiger","fleeing") :: number; local held=Rules.chance(p,"tiger","snared") :: number
	assert(flee<calm and held>calm)
	local starter=Rules.blank(now); equal(Rules.chance(starter,"tiger","snared"),nil)
	equal(Rules.chance(p,"whale","snared"),nil)
	p.inventory.rabbit=Rules.capacity(p); equal(Rules.chance(p,"rabbit","snared"),nil)
end)
test("a fleeing escape awards nothing and a successful snared rescue counts normally",function()
	local p=Rules.blank(now); p.owned.tranquilizer=true
	equal(Rules.attempt(p,"tiger",0.5,now,false,"canopy","fleeing"),false); equal(p.coins,100); equal(p.stats.catches,0)
	assert(Rules.attempt(p,"tiger",0.5,now,false,"canopy","snared")); equal(p.inventory.tiger,1); equal(p.exploration.rareCatches.canopy,1)
end)
test("boosted movement earns step and stroke bonuses within its own server limits",function()
	local p=Rules.blank(now)
	equal(Rules.movement(p,"walk",28,1),0); equal(p.stats.walkDistance,0)
	Rules.movement(p,"walk",28,1,true); equal(p.stats.walkDistance,28)
	equal(Rules.movement(p,"walk",2,0.1,true),1); equal(p.coins,102)
	Rules.movement(p,"swim",24,1,true); equal(p.stats.swimDistance,24)
	Rules.movement(p,"swim",16,1,true); equal(p.coins,105); equal(p.points,3)
	local before=p.stats.walkDistance; Rules.movement(p,"walk",200,1,true); equal(p.stats.walkDistance,before)
end)
test("equipment chest range includes boosts and snares without consuming two daily openings",function()
	local p=Rules.blank(now)
	local ok,boost=Rules.openChest(p,"arkNursery",0.7,0.85,now); assert(ok); equal(boost.equipment,"speedBoost"); equal(p.stock.speedBoost,1)
	equal(Rules.openChest(p,"arkNursery",0.7,0.99,now),false); equal(p.stock.animalTrap,0)
	local _,trap=Rules.openChest(p,"canopyEntry",0.7,0.99,now); equal(trap.equipment,"animalTrap"); equal(p.stock.animalTrap,1)
	local _,style=Rules.openChest(p,"moonstonePoint",0.7,0.799999,now); equal(style.equipment,"mintTrail"); equal(p.owned.mintTrail,true)
end)
test("celebrations scale from coins to legendary animals and never celebrate harmful traps",function()
	local _,coins=Rules.openChest(Rules.blank(now),"arkNursery",0,0,now); equal(coins.celebration,1)
	local _,gear=Rules.openChest(Rules.blank(now),"arkNursery",0.7,0,now); equal(gear.celebration,3)
	local found=false
	for i=0,99 do local _,result=Rules.openChest(Rules.blank(now),"canopyThicket",0.5,i/100,now)
		if Catalog.Species[result.animal].rarity=="Legendary" then equal(result.celebration,5); found=true end
	end
	assert(found)
	for _,roll in {0.9,0.98} do local _,result=Rules.openChest(Rules.blank(now),"arkNursery",roll,0,now); equal(result.celebration,0) end
end)
test("camouflage reduces alert distance and snare or rest prevents another escape",function()
	local behavior=Catalog.Escape.deer
	assert(Encounter.alert(behavior,19,false,10,0,0)); equal(Encounter.alert(behavior,19,true,10,0,0),false)
	equal(Encounter.alert(behavior,5,false,10,11,0),false); equal(Encounter.alert(behavior,5,false,10,0,11),false)
	equal(Encounter.alert(nil,0,false,10,0,0),false)
	equal(Encounter.condition(10,12,13),"snared"); equal(Encounter.condition(12,13,11),"fleeing"); equal(Encounter.condition(14,13,11),"calm")
end)
test("flight is brief and always lands; ordinary runners never levitate",function()
	equal(Encounter.flight("fly",10,10,14),0); assert(Encounter.flight("fly",12,10,14)>6.9)
	equal(Encounter.flight("fly",14,10,14),0); equal(Encounter.flight("fly",9,10,14),0); equal(Encounter.flight("run",12,10,14),0)
end)
test("paid bundles have guaranteed contents and repeat cosmetic bundles have explicit compensation",function()
	local p=Rules.blank(now)
	assert(Rules.grantProduct(p,"sprintPack")); equal(p.stock.speedBoost,3)
	assert(Rules.grantProduct(p,"trapPack")); equal(p.stock.animalTrap,3)
	assert(Rules.grantProduct(p,"explorerStyle")); equal(p.owned.safariHat,true); equal(p.owned.mintTrail,true); equal(p.coins,100)
	assert(Rules.grantProduct(p,"explorerStyle")); equal(p.coins,500); equal(Rules.grantProduct(p,"madeUp"),false)
end)
test("every shop item has a finite visible display prop and an advertised currency price",function()
	for _,id in Catalog.ItemOrder do
		local item=Catalog.Items[id]; assert(item.pointsPrice and item.pointsPrice>0 and item.category)
		local parts=Shapes.build(id,item.kind); assert(#parts>0 and #parts<=30)
		for _,spec in parts do for _,value in spec.size do assert(value>0 and value<10) end; for _,value in spec.at do assert(value==value and math.abs(value)<10) end end
	end
end)
test("ranger products grant missing equipment and compensate only fully owned bundles",function()
	local p=Rules.blank(now); p.owned.rangerNet=true
	assert(Rules.grantProduct(p,"rangerKit")); equal(p.coins,100)
	for _,id in Catalog.Products.rangerKit.items do equal(p.owned[id],true) end
	assert(Rules.grantProduct(p,"rangerKit")); equal(p.coins,1300)
	local partial=Rules.blank(now); partial.owned.safariHat=true
	assert(Rules.grantProduct(partial,"explorerStyle")); equal(partial.coins,100); equal(partial.owned.mintTrail,true)
end)
print(string.format("\n%d outfitters/encounter cases passed, %d failed (pure rules, not Studio visuals)",passed,failed))
if failed>0 then error("Outfitters checks failed") end
