--!nonstrict
local Shared = game:GetService("ReplicatedStorage"):WaitForChild("ZoShared")
local Catalog = require(Shared.Catalog)
local Shapes = require(Shared.ItemShapes)
local Storefront = {}
function Storefront.build(world, part, label)
	local model = Instance.new("Model"); model.Name = "ArkOutfittersStorefront"; model.ModelStreamingMode = Enum.ModelStreamingMode.Atomic; model.Parent = world.runtime
	-- Open north-facing entrance, inside the existing pointed atrium.
	local origin = CFrame.new(world.hub + Vector3.new(17,0.5,15))
	local navy, mint, wood, cream = Color3.fromRGB(20,50,91), Color3.fromRGB(48,244,190), Color3.fromRGB(207,139,68), Color3.fromRGB(255,249,224)
	local function p(name, size, at, color, material)
		return part(model, name, size, origin * CFrame.new(at), color, material or Enum.Material.WoodPlanks)
	end
	p("ShopFloor",Vector3.new(38,0.4,24),Vector3.new(0,0,0),wood)
	p("BackWall",Vector3.new(38,12,0.6),Vector3.new(0,6,12),navy)
	for _, x in {-19,19} do
		p("SideWall",Vector3.new(0.6,12,24),Vector3.new(x,6,0),navy)
		p("FrontPost",Vector3.new(0.8,12,0.8),Vector3.new(x,6,-12),wood)
	end
	for _, x in {-11,11} do
		p("WindowBase",Vector3.new(15,2,0.6),Vector3.new(x,1,-12),navy)
		local glass = p("DisplayGlass",Vector3.new(14,5.5,0.2),Vector3.new(x,5,-12),Color3.fromRGB(175,225,227),Enum.Material.Glass)
		glass.Transparency = 0.75; glass.CanCollide = false
	end
	-- A short canopy keeps the interior visible to the normal third-person camera.
	for i = 0, 9 do p("StripedAwning",Vector3.new(4,0.5,5),Vector3.new(-18+i*4,10.4,-12),if i%2==0 then mint else cream,Enum.Material.Fabric) end
	local sign = p("StoreSign",Vector3.new(37,3,0.5),Vector3.new(0,12,-12),navy)
	local surface = Instance.new("SurfaceGui"); surface.Face = Enum.NormalId.Front; surface.CanvasSize = Vector2.new(900,100); surface.Parent = sign
	local lettering = Instance.new("TextLabel"); lettering.Size = UDim2.fromScale(1,1); lettering.BackgroundTransparency = 1; lettering.Text = "ARK OUTFITTERS  •  FIELD & SEA"; lettering.TextColor3 = mint; lettering.Font = Enum.Font.GothamBold; lettering.TextSize = 32; lettering.Parent = surface
	local counter = p("CheckoutCounter",Vector3.new(10,3,3),Vector3.new(0,1.7,6),wood)
	p("Countertop",Vector3.new(10.5,0.4,3.5),Vector3.new(0,3.4,6),mint)
	p("CashRegister",Vector3.new(1.5,1.2,1.3),Vector3.new(2,4.1,6),navy)
	label(counter,"ARK OUTFITTERS\nBrowse • buy • trade",5,270)
	for index, id in Catalog.ItemOrder do
		local row, column = math.floor((index-1)/8), (index-1)%8
		local center = Vector3.new(-16.1+column*4.6,3+row*3.8,10)
		p("DisplayShelf",Vector3.new(4.4,0.2,3),center+Vector3.new(0,-1.5,0),wood)
		local item = Catalog.Items[id]
		local display=Instance.new("Model"); display.Name="Merchandise_"..id; display.Parent=model
		for _, spec in Shapes.build(id,item.kind) do
			local prop = part(display,"Display_"..id,Vector3.new(unpack(spec.size))*0.55,origin*CFrame.new(center+Vector3.new(unpack(spec.at))*0.55),Color3.fromRGB(unpack(spec.color)),Enum.Material.SmoothPlastic,if spec.shape=="ball" then Enum.PartType.Ball else nil)
			prop.CanCollide = false; prop.CanQuery = true
		end
		local tag = p("PriceTag_"..id,Vector3.new(4.4,1,0.15),center+Vector3.new(0,-1.2,-1.6),navy)
		tag.Parent=display; display.PrimaryPart=tag
		local click=Instance.new("ClickDetector"); click.MaxActivationDistance=28; click.Parent=display
		click.MouseClick:Connect(function(player) if world.onMerchandise then world.onMerchandise(player,id,display) end end)
		local gui = Instance.new("SurfaceGui"); gui.Face = Enum.NormalId.Front; gui.CanvasSize = Vector2.new(320,100); gui.Parent = tag
		local text = Instance.new("TextLabel"); text.Size = UDim2.fromScale(1,1); text.BackgroundTransparency = 1; text.Text = item.name.."\n"..item.price.." coins / "..item.pointsPrice.." pts\nCLICK TO BUY"; text.TextColor3 = cream; text.Font = Enum.Font.GothamBold; text.TextSize = 19; text.TextWrapped = true; text.Parent = gui
	end
	for _, x in {-16,16} do
		p("Planter",Vector3.new(2.5,2,2.5),Vector3.new(x,1,-15),wood)
		part(model,"ShopTopiary",Vector3.new(3.5,4,3.5),origin*CFrame.new(x,3.5,-15),mint,Enum.Material.Grass,Enum.PartType.Ball)
	end
	return counter
end
return Storefront
