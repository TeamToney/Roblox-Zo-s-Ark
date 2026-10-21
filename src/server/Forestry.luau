--!nonstrict
local Shared=game:GetService("ReplicatedStorage"):WaitForChild("ZoShared")
local Layout=require(Shared.ForestryLayout)
local Geometry=require(Shared.MapGeometry)
local Forestry={}
local function rgb(r,g,b) return Color3.fromRGB(r,g,b) end
function Forestry.build(plan,parent,part)
	local folder=Instance.new("Folder"); folder.Name="OutdoorForestry"; folder.Parent=parent
	local plants=Layout.generate(plan,Geometry)
	for _,collection in {plants.trees,plants.ground} do
		for _,plant in collection do
			local model=Instance.new("Model"); model.Name="Forest_"..plant.kind; model.ModelStreamingMode=Enum.ModelStreamingMode.Atomic
			local x,z=Geometry.world(plan.Source,plant.x,plant.y)
			local origin=CFrame.new(x,plan.FloorY+0.14,z)*CFrame.Angles(0,plant.yaw,0)
			local size=plant.scale
			local wood=rgb(116+plant.tint*24,75+plant.tint*16,43)
			local leaf=rgb(31+plant.tint*45,132+plant.tint*57,66+plant.tint*22)
			local light=leaf:Lerp(rgb(144,222,83),0.28)
			if plan.Id=="moonstone" then leaf=leaf:Lerp(rgb(45,143,137),0.4); light=leaf:Lerp(rgb(164,219,156),0.25) end
			local function p(name,dimensions,at,color,material,shape,rotation)
				local result=part(model,name,dimensions*size,origin*CFrame.new(at*size)*(rotation or CFrame.identity),color,material or Enum.Material.Grass,shape)
				-- These are scenery, so they never pin wildlife or block rescue rays.
				result.CanCollide=false; result.CanTouch=false; result.CanQuery=false
				result.CastShadow=collection==plants.trees
				return result
			end
			local function branch(name,a,b,width,color)
				local cf=CFrame.lookAt((a+b)/2,b)*CFrame.Angles(0,math.pi/2,0)
				return p(name,Vector3.new((b-a).Magnitude,width,width),(a+b)/2,color,Enum.Material.Wood,Enum.PartType.Cylinder,cf.Rotation)
			end
			if plant.kind=="broadleaf" or plant.kind=="birch" then
				local birch=plant.kind=="birch"
				local bark=if birch then rgb(225,224,203) else wood
				branch("Trunk",Vector3.zero,Vector3.new(0,20,0),if birch then 1.6 else 2.5,bark)
				for _,side in {-1,1} do
					branch("Fork",Vector3.new(0,13,0),Vector3.new(side*4,22,side*1.5),1,bark)
					p("LeafCrown",Vector3.new(14,11,14),Vector3.new(side*4,23,side*1.5),if side==1 then light else leaf,nil,Enum.PartType.Ball)
				end
				p("HighCrown",Vector3.new(13,12,13),Vector3.new(0,27,0),light,nil,Enum.PartType.Ball)
				if birch then
					for i=1,3 do p("BarkMark",Vector3.new(1.65,0.3,0.12),Vector3.new(0,i*4,0.79),rgb(85,91,81),Enum.Material.Wood) end
				end
			elseif plant.kind=="pine" then
				branch("PineTrunk",Vector3.zero,Vector3.new(0,25,0),2,wood)
				for i=1,4 do
					p("EvergreenLayer",Vector3.new(17-i*3,12,17-i*3),Vector3.new(0,11+i*4,0),if i%2==0 then light else leaf,nil,Enum.PartType.Ball)
				end
			elseif plant.kind=="palm" then
				local a,b,c=Vector3.new(0,8,0),Vector3.new(1.3,15,0),Vector3.new(3,22,0)
				branch("PalmBase",Vector3.zero,a,2,wood); branch("PalmBend",a,b,1.6,wood); branch("PalmTop",b,c,1.2,wood)
				for i=1,6 do
					local angle=i*math.pi/3
					p("PalmFrond",Vector3.new(3,1.2,12),c+Vector3.new(math.sin(angle)*4.2,0,math.cos(angle)*4.2),if i%2==0 then light else leaf,nil,Enum.PartType.Ball,CFrame.Angles(0,angle,0)*CFrame.Angles(math.rad(13),0,0))
				end
				p("Coconut",Vector3.one*1.4,c-Vector3.new(0,1.2,0.8),wood,Enum.Material.Wood,Enum.PartType.Ball)
			elseif plant.kind=="fern" then
				for i=1,4 do
					local angle=i*math.pi/2
					p("FernFrond",Vector3.new(1,0.28,3.5),Vector3.new(math.sin(angle),0.8,math.cos(angle)),if i%2==0 then light else leaf,nil,Enum.PartType.Ball,CFrame.Angles(0,angle,0)*CFrame.Angles(math.rad(18),0,0))
				end
			elseif plant.kind=="flowers" then
				for i=1,3 do
					local at=Vector3.new((i-2)*1.1,0.6,if i%2==0 then 0.5 else -0.5)
					p("FlowerLeaf",Vector3.new(1.7,0.4,1.5),at-Vector3.new(0,0.35,0),leaf,nil,Enum.PartType.Ball)
					p("Wildflower",Vector3.new(0.9,0.6,0.9),at,if plant.tint>0.5 then rgb(255,191,61) else rgb(231,116,215),Enum.Material.SmoothPlastic,Enum.PartType.Ball)
				end
			elseif plant.kind=="log" then
				branch("FallenLog",Vector3.new(-3.5,0.8,0),Vector3.new(3.5,0.8,0),1.5,wood)
				p("Moss",Vector3.new(5,0.4,1.25),Vector3.new(0,1.5,0),leaf,nil,Enum.PartType.Ball)
			elseif plant.kind=="rock" then
				p("WoodlandStone",Vector3.new(3.5,2.1,3),Vector3.new(0,0.85,0),rgb(115,143,128),Enum.Material.Slate,Enum.PartType.Ball)
				p("RockMoss",Vector3.new(2.5,0.45,2),Vector3.new(0,1.8,0),leaf,nil,Enum.PartType.Ball)
			end
			model.Parent=folder
		end
	end
	folder:SetAttribute("TreeCount",#plants.trees); folder:SetAttribute("UndergrowthCount",#plants.ground)
	return folder
end
return Forestry
