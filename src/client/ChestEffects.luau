--!nonstrict
local TweenService=game:GetService("TweenService")
local Debris=game:GetService("Debris")
local FX={active=0,scanner=nil}
local colors={Color3.fromRGB(145,232,191),Color3.fromRGB(255,207,116),Color3.fromRGB(118,184,255),Color3.fromRGB(222,151,245)}
local random=Random.new()
local function part(parent,size,position,color,shape)
	local p=Instance.new("Part"); p.Size=size; p.CFrame=CFrame.new(position); p.Color=color; p.Anchored=true; p.CanCollide=false; p.CanTouch=false; p.CanQuery=false; p.CastShadow=false; p.Material=Enum.Material.Neon; p.Shape=shape or Enum.PartType.Block; p.Parent=parent; return p
end
function FX.chest(data)
	if FX.active>=3 or typeof(data.position)~="Vector3" then return end
	FX.active+=1
	local rank=math.clamp(data.rank or 0,0,6); local origin=data.position+Vector3.new(0,3,0)
	local folder=Instance.new("Folder"); folder.Name="ZoChestCelebration"; folder.Parent=workspace
	Debris:AddItem(folder,9); task.delay(9,function() FX.active=math.max(0,FX.active-1) end)
	local count=if data.trap then 14 else 10+rank*7
	for i=1,count do
		local color=if data.trap then Color3.fromRGB(130,70,95) else colors[(i-1)%#colors+1]
		local p=part(folder,Vector3.new(0.18,0.5,0.2),origin,color)
		local goal=origin+Vector3.new(random:NextNumber(-3-rank,3+rank),random:NextNumber(2,4+rank),random:NextNumber(-3-rank,3+rank))
		TweenService:Create(p,TweenInfo.new(1.5+rank*0.15,Enum.EasingStyle.Quad,Enum.EasingDirection.Out),{Position=goal,Transparency=1,Orientation=Vector3.new(120,40*i,90)}):Play()
	end
	if data.trap then return end
	if rank>=2 then
		for i=1,math.min(8,rank+1) do
			local home=origin+Vector3.new(random:NextNumber(-3,3),0,random:NextNumber(-3,3))
			local balloon=part(folder,Vector3.new(1.4,1.9,1.4),home,colors[(i-1)%#colors+1],Enum.PartType.Ball); balloon.Material=Enum.Material.SmoothPlastic
			local string=part(folder,Vector3.new(0.04,2.4,0.04),home-Vector3.new(0,2,0),Color3.fromRGB(240,235,220)); string.Material=Enum.Material.SmoothPlastic
			for _, object in {balloon,string} do TweenService:Create(object,TweenInfo.new(4+rank*0.3),{Position=object.Position+Vector3.new(i-3,14+rank*2,0),Transparency=1}):Play() end
		end
	end
	if rank>=3 then
		for burst=1,math.min(4,rank-2) do
			task.delay(burst*0.5,function()
				if not folder.Parent then return end
				local center=origin+Vector3.new((burst-2)*5,8+rank*2,0)
				for ray=1,12+rank*3 do
					local angle=ray*math.pi*2/(12+rank*3)
					local direction=Vector3.new(math.cos(angle),math.sin(angle),random:NextNumber(-0.4,0.4)).Unit
					local spark=part(folder,Vector3.new(0.16,0.16,1.4),center,colors[(ray-1)%#colors+1]); spark.CFrame=CFrame.lookAt(center,center+direction)
					TweenService:Create(spark,TweenInfo.new(1.4),{CFrame=spark.CFrame+direction*(4+rank),Transparency=1}):Play()
				end
			end)
		end
	end
end
function FX.scan(data)
	if FX.scanner then FX.scanner:Destroy() end
	local folder=Instance.new("Folder"); folder.Name="ZoScannerSignals"; folder.Parent=workspace; FX.scanner=folder; Debris:AddItem(folder,1.4)
	for _, target in data.targets or {} do
		local p=part(folder,Vector3.one,target.position,colors[1]); p.Transparency=1
		local gui=Instance.new("BillboardGui"); gui.Adornee=p; gui.AlwaysOnTop=true; gui.Size=UDim2.fromOffset(170,44); gui.StudsOffset=Vector3.new(0,4,0); gui.Parent=p
		local label=Instance.new("TextLabel"); label.Size=UDim2.fromScale(1,1); label.BackgroundColor3=Color3.fromRGB(17,36,46); label.BackgroundTransparency=0.15; label.TextColor3=colors[1]; label.Font=Enum.Font.GothamBold; label.TextSize=12; label.TextWrapped=true; label.Text=target.name.."\n"..math.floor(target.distance).." studs"; label.Parent=gui
	end
end
return FX
