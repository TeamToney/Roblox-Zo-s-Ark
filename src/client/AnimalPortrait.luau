--!nonstrict
local Shapes=require(game:GetService("ReplicatedStorage"):WaitForChild("ZoShared").AnimalShapes)
local Portrait={}
function Portrait.draw(frame,species,make)
	local view=make("ViewportFrame",{Size=UDim2.fromOffset(82,102),Position=UDim2.fromOffset(10,12),BackgroundColor3=Color3.fromRGB(35,63,65),BorderSizePixel=0,Ambient=Color3.fromRGB(190,205,215),LightColor=Color3.fromRGB(255,241,212),LightDirection=Vector3.new(-1,-0.7,-1)},frame)
	make("UICorner",{CornerRadius=UDim.new(0,10)},view)
	local loaded=false; local positionConnection,sizeConnection
	local function populate()
		if loaded or not view.Parent or view.AbsoluteSize.Y<=0 then return end
		local scroll=frame:FindFirstAncestorWhichIsA("ScrollingFrame")
		if scroll and (view.AbsolutePosition.Y+view.AbsoluteSize.Y<scroll.AbsolutePosition.Y or view.AbsolutePosition.Y>scroll.AbsolutePosition.Y+scroll.AbsoluteSize.Y) then return end
		local ancestor=view
		while ancestor and not ancestor:IsA("ScreenGui") do if ancestor:IsA("GuiObject") and not ancestor.Visible then return end; ancestor=ancestor.Parent end
		loaded=true
		if positionConnection then positionConnection:Disconnect() end; if sizeConnection then sizeConnection:Disconnect() end
		local world=make("WorldModel",{},view)
		for _,piece in Shapes.build(species).parts do
			local class=if piece.shape=="wedge" then "WedgePart" else "Part"
			local p=make(class,{Name=piece.name,Size=Vector3.new(unpack(piece.size)),CFrame=CFrame.new(unpack(piece.offset))*CFrame.Angles(math.rad(piece.rotation[1]),math.rad(piece.rotation[2]),math.rad(piece.rotation[3])),Color=Color3.fromRGB(unpack(piece.color)),Material=Enum.Material.SmoothPlastic,Anchored=true,CanCollide=false,CanTouch=false,CanQuery=false},world)
			if class=="Part" then p.Shape=if piece.shape=="ball" then Enum.PartType.Ball else Enum.PartType.Block end
		end
		local camera=make("Camera",{CFrame=CFrame.lookAt(Vector3.new(7,3.8,-10),Vector3.new(0,0.5,0)),FieldOfView=43},view)
		view.CurrentCamera=camera
	end
	positionConnection=view:GetPropertyChangedSignal("AbsolutePosition"):Connect(populate)
	sizeConnection=view:GetPropertyChangedSignal("AbsoluteSize"):Connect(populate)
	task.defer(populate)
end
return Portrait
