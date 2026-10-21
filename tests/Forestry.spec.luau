--!strict
local Forestry=require("../src/shared/ForestryLayout")
local Geometry=require("../src/shared/MapGeometry")
local Ark=require("../src/shared/MapLayout")
local Islands=require("../src/shared/IslandLayouts")
local plans: {any}={Ark,Islands.Islands[1],Islands.Islands[2]}
local forests: {any}={}
for i,plan in plans do forests[i]=Forestry.generate(plan,Geometry) end
local passed,failed=0,0
local function test(name: string,callback: ()->())
	local ok,problem=pcall(callback)
	if ok then passed+=1; print("PASS  "..name) else failed+=1; print("FAIL  "..name..": "..tostring(problem)) end
end
test("all three islands gain substantial woodland within fixed scenery budgets",function()
	for i,plan in plans do
		local forest=forests[i]
		assert(#forest.trees>=75 and #forest.trees<=Forestry.MaxTrees,plan.Id.." tree budget")
		assert(#forest.ground>=100 and #forest.ground<=Forestry.MaxGround,plan.Id.." undergrowth budget")
		local kinds={}; for _,tree in forest.trees do kinds[tree.kind]=true end
		if plan.Id=="canopy" then assert(kinds.palm and kinds.broadleaf) elseif plan.Id=="moonstone" then assert(kinds.pine and kinds.birch) else assert(kinds.broadleaf and kinds.birch) end
	end
end)
test("forest placement is repeatable without changing source-map data",function()
	for i,plan in plans do
		local again=Forestry.generate(plan,Geometry)
		assert(#again.trees==#forests[i].trees and #again.ground==#forests[i].ground)
		for j,tree in again.trees do
			local old=forests[i].trees[j]
			assert(tree.x==old.x and tree.y==old.y and tree.kind==old.kind and tree.scale==old.scale)
		end
	end
end)
test("roots and undergrowth stay on dry ground clear of paved routes and indoor rooms",function()
	for i,plan in plans do
		local s=plan.Source.scale
		for group,plants in {forests[i].trees,forests[i].ground} do
			local radius=if group==1 then 5 else 2.5
			for _,plant in plants do
				for _,delta in {{0,0},{1,1},{1,-1},{-1,1},{-1,-1}} do
					assert(not Geometry.inWater(plan,plant.x+delta[1]*radius/s,plant.y+delta[2]*radius/s),plan.Id.." plant in water")
				end
				for _,path in plan.Corridors do assert(not Geometry.contains(path,plant.x,plant.y,-(radius+3)/s),plan.Id.." path covered") end
				for _,room in plan.Rooms do
					if room.rect and room.kind~="meadow" and room.kind~="jungle" and room.kind~="summit" then assert(not Geometry.contains(room.rect,plant.x,plant.y,-radius/s),plan.Id.." indoor tree") end
				end
			end
		end
	end
end)
test("checkpoint chest shore spawn and shop approaches retain clearings",function()
	for i,plan in plans do
		local s=plan.Source.scale
		for _,plant in forests[i].trees do
			for _,name in {"Checkpoints","Chests","ShoreExits"} do
				for _,point in plan[name] do
					local clearance=if name=="ShoreExits" then 24 else 20
					assert(((plant.x-point.x)^2+(plant.y-point.y)^2)*s*s>=clearance^2,plan.Id.." marker covered")
				end
			end
			for _,point in {plan.Spawn or {},plan.Hub or {}} do
				if point[1] then assert(((plant.x-point[1])^2+(plant.y-point[2])^2)*s*s>=33^2) end
			end
		end
	end
end)
test("trunk spacing and bounded plant sizes preserve open woodland lanes",function()
	for i,plan in plans do
		local s=plan.Source.scale; local trees=forests[i].trees
		for j,tree in trees do
			assert(tree.scale>=0.8 and tree.scale<=1.25 and tree.yaw==tree.yaw)
			for k=j+1,#trees do assert(((tree.x-trees[k].x)^2+(tree.y-trees[k].y)^2)*s*s>=14^2) end
		end
	end
end)
test("animal habitats retain central gathering clearings with pines in mountain areas",function()
	for i,plan in plans do
		local s=plan.Source.scale
		for _,zone in plan.Zones do
			if zone.habitat=="reef" or zone.habitat=="ocean" then continue end
			local cx,cy=Geometry.center(zone.rect)
			local radius=math.min(18,math.min(zone.rect[3]-zone.rect[1],zone.rect[4]-zone.rect[2])*s*0.23)+5
			for _,tree in forests[i].trees do
				if Geometry.contains(zone.rect,tree.x,tree.y) then
					assert(((tree.x-cx)^2+(tree.y-cy)^2)*s*s>=radius^2)
					if zone.habitat=="summit" then assert(tree.kind=="pine") end
				end
			end
		end
	end
end)
print(string.format("Forestry: %d passed, %d failed (layout data, not Studio rendering)",passed,failed))
if failed>0 then error("Forestry regressions failed") end
