--!strict
local Notebook=require("../src/shared/NotebookState")
local Escape=require("../src/shared/EscapeRules")
local Scenes=require("../src/shared/ChestSceneRules")
local Catalog=require("../src/shared/Catalog")
local Rules=require("../src/shared/Rules").new(Catalog,require("../src/shared/Config"))
local passed,failed=0,0
local function test(name: string,callback: ()->())
	local ok,problem=pcall(callback)
	if ok then passed+=1; print("PASS  "..name) else failed+=1; print("FAIL  "..name..": "..tostring(problem)) end
end
local function equal(a: any,b: any) assert(a==b,"expected "..tostring(b)..", got "..tostring(a)) end
test("closing invalidates an in-flight shelf inspection even after the click guard expires",function()
	local ui=Notebook.new(); ui.close(0)
	assert(ui.canInspect(1)); local pending=ui.state.revision
	ui.close(1.1); equal(ui.state.visible,false)
	equal(ui.acceptInspection(pending,1.2),false); equal(ui.acceptInspection(pending,20),false)
	assert(ui.canInspect(20))
end)
test("a close-button click cannot also activate the shelf item behind the panel",function()
	local ui=Notebook.new(); ui.close(10)
	equal(ui.canInspect(10),false); equal(ui.canInspect(10.64),false); assert(ui.canInspect(10.66))
	assert(ui.open()); equal(ui.canInspect(11),false)
end)
test("only the current intentional inspection can open the shop",function()
	local ui=Notebook.new(); ui.close(0); local request=ui.state.revision
	assert(ui.acceptInspection(request,1)); assert(ui.open())
	equal(ui.acceptInspection(request,2),false)
	ui.close(3); local nextRequest=ui.state.revision
	assert(ui.acceptInspection(nextRequest,4)); equal(ui.acceptInspection(request,4),false)
end)
test("cutscene suspension blocks shop opens and cancellation restores local controls for menus",function()
	local ui=Notebook.new(); ui.close(0); local old=ui.state.revision
	ui.suspend(2); equal(ui.open(),false); equal(ui.canInspect(20),false)
	ui.resume(20); equal(ui.state.visible,false); equal(ui.acceptInspection(old,30),false)
	assert(ui.canInspect(21)); assert(ui.open()); ui.close(21.1); equal(ui.state.visible,false)
end)
test("explicit navigation can reopen immediately while delayed world clicks stay suppressed",function()
	local ui=Notebook.new(); ui.close(10); assert(ui.open()); equal(ui.state.visible,true)
	ui.close(10.1); equal(ui.canInspect(10.2),false)
end)
test("every species including starter rabbits and marine animals has a real miss escape mode",function()
	for _,id in Catalog.SpeciesOrder do
		local animal=Catalog.Species[id]; local marine=animal.habitat=="reef" or animal.habitat=="ocean"
		local behavior=Escape.behavior(Catalog,id,marine)
		assert(behavior.speed>=10 and behavior.speed<=30)
		assert(behavior.mode=="run" or behavior.mode=="fly" or behavior.mode=="swim")
	end
	equal(Escape.behavior(Catalog,"rabbit",false).mode,"run")
	equal(Escape.behavior(Catalog,"reefFish",true).mode,"swim")
	equal(Escape.behavior(Catalog,"monkey",false).alert,0)
end)
test("standing directly above an animal produces finite nonzero escape destinations",function()
	local probes=Escape.probes(0,0,0,0,0)
	equal(#probes,30)
	local target=assert(Escape.choose(probes,function(_) return true end))
	assert(math.sqrt(target.x^2+target.z^2)>=19.9)
	for _,probe in probes do assert(probe.x==probe.x and probe.z==probe.z and math.abs(probe.x)<21 and math.abs(probe.z)<21) end
end)
test("blocked straight escapes can sidestep rather than abandoning all movement",function()
	local target=assert(Escape.choose(Escape.probes(0,0,-2,0,0),function(probe) return probe.x>0 and probe.z>5 end))
	assert(target.z>5 and target.distance>=10)
end)
test("a cramped habitat can choose a short escape while a sealed habitat cannot teleport",function()
	local probes=Escape.probes(0,0,-2,0,0)
	local target=assert(Escape.choose(probes,function(p) return math.abs(p.x)<=5 and math.abs(p.z)<=5 end))
	equal(target.distance,4)
	equal(Escape.choose(probes,function(_) return false end),nil)
end)
test("escape probes are bounded and prefer increased separation from the pursuer",function()
	local probes=Escape.probes(20,10,0,10,1)
	local target=assert(Escape.choose(probes,function(_) return true end))
	assert(target.x>35); assert(math.abs(target.z-10)<0.01)
	local previous=math.huge
	for _,p in probes do assert(p.score<=previous+0.00001); previous=p.score end
end)
test("chest movies reveal after opening and always have a short finite automatic exit",function()
	for rank=0,6 do
		local plan=Scenes.plan(rank,false)
		assert(plan.openAt>0 and plan.revealAt>plan.openAt and plan.duration>plan.revealAt and plan.duration<=7)
		assert(plan.confetti<=46 and plan.fireworks<=4 and plan.balloons<=7)
	end
end)
test("higher prizes get larger cinematic celebrations while traps use no party effects",function()
	local small,legendary=Scenes.plan(1,false),Scenes.plan(5,false)
	assert(legendary.duration>small.duration and legendary.confetti>small.confetti and legendary.fireworks>small.fireworks)
	local trap=Scenes.plan(5,true); equal(trap.balloons,0); equal(trap.fireworks,0); assert(trap.duration<4)
	local invalid=Scenes.plan(0/0,false); equal(invalid.rank,0)
end)
test("server chest results identify the exact cinematic prize without changing reward reservation",function()
	local now=1800000000
	for _,roll in {0.1,0.5,0.7,0.9,0.98} do
		local p=Rules.blank(now); local ok,result=Rules.openChest(p,"arkNursery",roll,0,now)
		assert(ok and type(result.title)=="string" and #result.title>0 and #result.message>0)
		equal(Rules.openChest(p,"arkNursery",roll,0,now),false)
	end
end)
test("a missed rescue explains the snare exception without granting rewards",function()
	local p=Rules.blank(1800000000)
	local ok,message=Rules.attempt(p,"rabbit",0.999,1800000000,false,"ark","snared")
	equal(ok,false); assert(string.find(message,"snare")~=nil); equal(p.coins,100); equal(p.stats.catches,0)
end)
print(string.format("\n%d presentation/escape regression cases passed, %d failed (pure state and routing, not Studio input/rendering)",passed,failed))
if failed>0 then error("Presentation checks failed") end
