--!nonstrict
local Debris=game:GetService("Debris")
local FX={scanner=nil}
local colors={Color3.fromRGB(145,232,191),Color3.fromRGB(255,207,116),Color3.fromRGB(118,184,255),Color3.fromRGB(222,151,245)}
local function part(parent,size,position,color,shape)
	local p=Instance.new("Part"); p.Size=size; p.CFrame=CFrame.new(position); p.Color=color; p.Anchored=true; p.CanCollide=false; p.CanTouch=false; p.CanQuery=false; p.CastShadow=false; p.Material=Enum.Material.Neon; p.Shape=shape or Enum.PartType.Block; p.Parent=parent; return p
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
